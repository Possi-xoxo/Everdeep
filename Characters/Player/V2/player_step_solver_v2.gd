extends Node3D
## Ground-initiated, bounded predictive lift. Never writes the body transform.
@export var enabled: bool = true
@export_range(0.02, 0.5, 0.01) var max_step_height: float = 0.35
@export_range(0.01, 0.1, 0.01) var min_step_height: float = 0.025
@export_range(1.0, 8.0, 0.1) var step_up_speed: float = 5.0
@export_range(0.06, 0.25, 0.01) var minimum_lift_duration: float = 0.06
@export var debug_steps: bool = false
var active: bool = false
var step_height: float = 0.0
var step_target_y: float = 0.0
var reason: String = "NOT_MOVING"
var candidate: bool = false
var top_walkable: bool = false
var head_clearance: bool = false
var steps_started: int = 0
var _direction := Vector3.ZERO
var _goal := Vector3.ZERO
var _elapsed: float = 0.0
var _lift_time: float = 0.0
var _start_y: float = 0.0
var _duration: float = 0.1
var _lines: Array[Vector3] = []
var _hits: Array[Vector3] = []
var _debug_mesh: MeshInstance3D
@onready var body: CharacterBody3D = get_parent()
@onready var collision: CollisionShape3D = $"../CollisionShape3D"

func cancel(why: String = "CANCELLED") -> void:
	active = false
	candidate = false
	reason = why

func _ray(a: Vector3, b: Vector3) -> Dictionary:
	_lines.append_array([a,b])
	var q := PhysicsRayQueryParameters3D.create(a,b,body.collision_mask,[body.get_rid()])
	var hit := body.get_world_3d().direct_space_state.intersect_ray(q)
	if not hit.is_empty():
		_hits.append(hit.position)
	return hit

func _free_at(base: Vector3) -> bool:
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = collision.shape
	q.transform = collision.global_transform
	q.transform.origin += base - body.global_position
	q.collision_mask = body.collision_mask
	q.exclude = [body.get_rid()]
	q.margin = body.safe_margin
	return body.get_world_3d().direct_space_state.intersect_shape(q,1).is_empty()

## Called after gait/turn resolution and before the existing slide.
func prepare(delta: float, horizontal: Vector3, intent: Vector3, allowed: bool) -> bool:
	if not enabled or not allowed:
		_lines.clear()
		_hits.clear()
		cancel("AIRBORNE_OR_ACTION" if enabled else "DISABLED")
		return false
	if horizontal.length() < 0.1 or intent.is_zero_approx():
		cancel("NOT_MOVING")
		return false
	var direction := horizontal.normalized()
	if active:
		_elapsed += delta
		# Cached support is not permission to hover if geometry disappears.
		var support_query := PhysicsRayQueryParameters3D.create(_goal+Vector3.UP*0.02,_goal-Vector3.UP*0.04,body.collision_mask,[body.get_rid()])
		var support := body.get_world_3d().direct_space_state.intersect_ray(support_query)
		if support.is_empty() or support.normal.dot(Vector3.UP)<cos(body.floor_max_angle):
			cancel("SUPPORT_LOST")
			return false
		if direction.dot(_direction) < 0.8 or _elapsed > 0.6:
			cancel("DIRECTION_CHANGED_OR_TIMEOUT")
			return false
		if not _free_at(Vector3(body.global_position.x,step_target_y,body.global_position.z)):
			cancel("NO_BODY_CLEARANCE")
			return false
		if body.global_position.y < step_target_y-0.002:
			return true
		# A completed lift may see the next riser before the centre reaches the
		# previous top. Continue only from this already validated support chain.
	if not body.is_on_floor() and not active:
		reason = "AIRBORNE"
		return false
	candidate = false
	_lines.clear()
	_hits.clear()
	top_walkable = false
	head_clearance = false
	var base := body.global_position
	var radius: float = collision.shape.radius
	# Look ahead far enough to finish lifting before the leading capsule edge.
	var reach := radius + horizontal.length() * (_lift_duration(max_step_height) + delta * 2.0) + 0.06
	var low := _ray(base + Vector3.UP * 0.025, base + Vector3.UP * 0.025 + direction * reach)
	if low.is_empty():
		reason = "NO_LOW_HIT"
		return active
	if low.normal.dot(Vector3.UP) >= cos(body.floor_max_angle):
		reason = "ORDINARY_SLOPE"
		return active
	var point: Vector3 = low.position
	var distance := (point-base).dot(direction)
	var high := _ray(base + Vector3.UP * (max_step_height+0.012), base + Vector3.UP * (max_step_height+0.012) + direction * (distance+0.065))
	if not high.is_empty():
		reason = "UPPER_BLOCKED"
		return active
	var beyond := point + direction * 0.065
	var top := _ray(Vector3(beyond.x,base.y+max_step_height+0.015,beyond.z),Vector3(beyond.x,base.y+min_step_height-0.005,beyond.z))
	if top.is_empty():
		reason = "NO_TOP_SURFACE"
		return active
	step_height = top.position.y-base.y
	if step_height < min_step_height or step_height > max_step_height+0.002:
		reason = "TOO_TALL" if step_height > max_step_height else "TOO_SMALL"
		return active
	top_walkable = top.normal.dot(Vector3.UP) >= cos(body.floor_max_angle)
	if not top_walkable:
		reason = "TOP_TOO_STEEP"
		return active
	# Ignore distant small curbs until their own lift lead-in is needed.
	if distance > radius + horizontal.length() * (_lift_duration(step_height)+delta*2.0)+0.06:
		reason = "APPROACHING"
		return active
	var target_y: float = top.position.y + 0.006
	var goal := Vector3(beyond.x,target_y,beyond.z)
	# Require usable lateral support rather than balancing on a thin edge.
	var side: Vector3 = low.normal.cross(Vector3.UP).normalized() * radius * 0.5
	for offset in [side,-side]:
		var support := _ray(goal+offset+Vector3.UP*0.025,goal+offset-Vector3.UP*0.04)
		if support.is_empty() or support.normal.dot(Vector3.UP)<cos(body.floor_max_angle):
			reason = "NO_TOP_SUPPORT"
			return active
	var raised := base
	raised.y = target_y
	head_clearance = _free_at(raised) and _free_at(goal)
	if not head_clearance or body.test_move(body.global_transform,Vector3.UP*(target_y-base.y)):
		reason = "NO_BODY_CLEARANCE"
		return active
	var raised_transform := body.global_transform
	raised_transform.origin = raised
	if body.test_move(raised_transform,goal-raised):
		reason = "NO_BODY_CLEARANCE"
		return active
	step_target_y = target_y
	_goal = goal
	candidate = true
	active = true
	_direction = direction
	_elapsed = 0.0
	_lift_time = 0.0
	_start_y = base.y
	_duration = _lift_duration(step_target_y-base.y)
	steps_started += 1
	reason = "VALID"
	return true

func _lift_duration(height: float) -> float:
	# Smoothstep has a peak derivative of 1.5; retain the exported speed cap.
	return maxf(minimum_lift_duration,1.5*(height+0.006)/step_up_speed)

func lift(delta: float) -> void:
	_lift_time += delta
	var progress := clampf(_lift_time/_duration,0.0,1.0)
	var desired := lerpf(_start_y,step_target_y,smoothstep(0.0,1.0,progress))
	var rise := minf(step_up_speed * delta,maxf(0.0,desired-body.global_position.y))
	if rise > 0.0 and body.move_and_collide(Vector3.UP*rise) != null:
		cancel("NO_BODY_CLEARANCE")

func finish() -> void:
	if not active:
		return
	# Only hand back to ordinary snap when the centre is over the verified top.
	if body.global_position.y >= step_target_y-0.002 and (body.global_position-_goal).dot(_direction)>=0.0:
		body.apply_floor_snap()
		cancel("COMPLETE")

func _process(_delta: float) -> void:
	if _debug_mesh == null:
		_debug_mesh = MeshInstance3D.new()
		_debug_mesh.top_level = true
		add_child(_debug_mesh)
	_debug_mesh.visible = debug_steps
	if not debug_steps or _lines.is_empty():
		return
	var mesh := ImmediateMesh.new()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.no_depth_test = true
	mat.albedo_color = Color.GREEN if candidate else Color.ORANGE_RED
	mesh.surface_begin(Mesh.PRIMITIVE_LINES,mat)
	for p in _lines:
		mesh.surface_add_vertex(p)
	for p in _hits:
		for axis in [Vector3.RIGHT,Vector3.UP,Vector3.FORWARD]:
			mesh.surface_add_vertex(p-axis*0.04)
			mesh.surface_add_vertex(p+axis*0.04)
	mesh.surface_end()
	_debug_mesh.mesh = mesh

func debug_text() -> String:
	return "Step Candidate: %s\nHeight: %.3f m / Max: %.2f m\nTop Walkable: %s\nHead Clearance: %s\nStepping: %s\nReason: %s" % [candidate,step_height,max_step_height,top_walkable,head_clearance,active,reason]
