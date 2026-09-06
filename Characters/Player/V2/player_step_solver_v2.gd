extends Node3D
## Ground-initiated, bounded predictive lift. Never writes the body transform.
@export var enabled: bool = true
@export_range(0.02, 0.5, 0.01) var max_step_height: float = 0.35
@export_range(0.01, 0.1, 0.01) var min_step_height: float = 0.025
@export_range(1.0, 8.0, 0.1) var step_up_speed: float = 5.0
@export_range(0.06, 0.25, 0.01) var minimum_lift_duration: float = 0.06
@export var debug_steps: bool = false
@export_range(0.10,0.20,0.01) var candidate_lateral_offset: float = 0.15
var sample_status: Array[String] = ["NOT_TESTED","NOT_TESTED","NOT_TESTED"]
var chosen_candidate: String = "NONE"
var support_valid: bool = false
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
	sample_status.assign(["NOT_TESTED","NOT_TESTED","NOT_TESTED"])
	chosen_candidate="NONE"
	support_valid=false
	var lateral:=direction.cross(Vector3.UP).normalized()*minf(candidate_lateral_offset,radius*0.45)
	var rejection: String="NO_LOW_HIT"
	# Center first, then lateral candidates. A center miss/rejection does not
	# discard a legitimate corner detected by a side ray.
	for i in 3:
		var offset: Vector3=[Vector3.ZERO,-lateral,lateral][i]
		var result:=_evaluate_candidate(delta,horizontal,direction,base,radius,reach,offset,i)
		if result.is_empty():
			if sample_status[i]=="HIT":
				sample_status[i]+=" / "+reason
				if rejection=="NO_LOW_HIT": rejection=reason
			continue
		step_target_y=result.goal.y
		_goal=result.goal
		chosen_candidate=["CENTER","LEFT","RIGHT"][i]
		candidate=true
		active=true
		_direction=direction
		_elapsed=0.0
		_lift_time=0.0
		_start_y=base.y
		_duration=_lift_duration(step_target_y-base.y)
		steps_started+=1
		reason="VALID"
		return true
	reason=rejection
	return active

func _evaluate_candidate(delta: float, horizontal: Vector3, direction: Vector3, base: Vector3, radius: float, reach: float, offset: Vector3, sample: int) -> Dictionary:
	var origin:=base+offset
	var low := _ray(origin + Vector3.UP * 0.025, origin + Vector3.UP * 0.025 + direction * reach)
	if low.is_empty():
		sample_status[sample]="MISS"
		reason = "NO_LOW_HIT"
		return {}
	sample_status[sample]="HIT"
	if low.normal.dot(Vector3.UP) >= cos(body.floor_max_angle):
		reason = "ORDINARY_SLOPE"
		return {}
	var point: Vector3 = low.position
	var distance := (point-base).dot(direction)
	var high := _ray(origin + Vector3.UP * (max_step_height+0.012), origin + Vector3.UP * (max_step_height+0.012) + direction * (distance+0.065))
	if not high.is_empty():
		reason = "UPPER_BLOCKED"
		return {}
	var beyond := point + direction * 0.065
	var top := _ray(Vector3(beyond.x,base.y+max_step_height+0.015,beyond.z),Vector3(beyond.x,base.y+min_step_height-0.005,beyond.z))
	if top.is_empty():
		reason = "NO_TOP_SURFACE"
		return {}
	step_height = top.position.y-base.y
	if step_height < min_step_height or step_height > max_step_height+0.002:
		reason = "TOO_TALL" if step_height > max_step_height else "TOO_SMALL"
		return {}
	top_walkable = top.normal.dot(Vector3.UP) >= cos(body.floor_max_angle)
	if not top_walkable:
		reason = "TOP_TOO_STEEP"
		return {}
	# Ignore distant small curbs until their own lift lead-in is needed.
	if distance > radius + horizontal.length() * (_lift_duration(step_height)+delta*2.0)+0.06:
		reason = "APPROACHING"
		return {}
	var target_y: float = top.position.y + 0.006
	# The destination stays on the actual movement centerline (no sideways
	# steering toward a ray). Inset enough to test support in BOTH dimensions.
	# First inset preserves short stair-tread clearance. The deeper fallback
	# can support a narrow short-side entry without forcing its lateral rays
	# to balance at the very front edge of the top.
	for inset in [radius*0.45,radius*0.65]:
		var goal: Vector3=base+direction*(distance+inset)
		goal.y=target_y
		support_valid=_supported_at(goal,direction,radius)
		if not support_valid:
			reason="NO_TOP_SUPPORT"
			continue
		if _clear_destination(base,goal): return {"goal":goal}
	return {}

func _clear_destination(base: Vector3, goal: Vector3) -> bool:
	var target_y:=goal.y
	var raised := base
	raised.y = target_y
	head_clearance = _free_at(raised) and _free_at(goal)
	if not head_clearance or body.test_move(body.global_transform,Vector3.UP*(target_y-base.y)):
		reason = "NO_BODY_CLEARANCE"
		return false
	var raised_transform := body.global_transform
	raised_transform.origin = raised
	if body.test_move(raised_transform,goal-raised):
		reason = "NO_BODY_CLEARANCE"
		return false
	return true

func _supported_at(goal: Vector3, direction: Vector3, radius: float) -> bool:
	var center:=_ray(goal+Vector3.UP*0.025,goal-Vector3.UP*0.04)
	if center.is_empty() or center.normal.dot(Vector3.UP)<cos(body.floor_max_angle): return false
	var side:=direction.cross(Vector3.UP).normalized()
	var supported:=0
	for i in 8:
		var angle:=TAU*i/8.0
		var offset: Vector3=(direction*cos(angle)+side*sin(angle))*radius*0.6
		var hit:=_ray(goal+offset+Vector3.UP*0.025,goal+offset-Vector3.UP*0.04)
		if not hit.is_empty() and hit.normal.dot(Vector3.UP)>=cos(body.floor_max_angle): supported+=1
	# Center plus at least 75% of the inner footprint: not a thin balancing rail.
	return supported>=6

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
	return "Step Candidate: %s\nHeight: %.3f m / Max: %.2f m\nTop Walkable: %s\nHead Clearance: %s\nStepping: %s\nReason: %s\nCenter/Left/Right: %s / %s / %s\nChosen: %s / Footprint Support: %s" % [candidate,step_height,max_step_height,top_walkable,head_clearance,active,reason,sample_status[0],sample_status[1],sample_status[2],chosen_candidate,support_valid]
