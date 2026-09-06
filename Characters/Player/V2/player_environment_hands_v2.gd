extends Node3D
## Phase 1 only: reads evaluated bones and world collision, never writes either.
@export var enabled: bool = true
@export var environment_hand_debug: bool = false
@export_range(0.35,0.70,0.01) var hand_interaction_reach_distance: float = 0.50
@export_range(0.05,0.12,0.01) var hand_probe_radius: float = 0.08
@export_range(0,0.25,0.01) var hand_probe_forward_bias: float = 0.10
@export_flags_3d_physics var hand_collision_mask: int = 1
@export_range(0.01,0.05,0.005) var hand_surface_offset: float = 0.025
@export var hand_min_vertical_offset: float = -0.40
@export var hand_max_vertical_offset: float = 0.25
@export_range(0.10,0.20,0.01) var hand_max_behind_distance: float = 0.15
@export_range(8,20,0.5) var hand_target_smoothing_speed: float = 14.0
@export_range(8,15,0.5) var hand_normal_smoothing_speed: float = 12.0
@export_range(0.05,0.20,0.01) var hand_target_loss_grace_time: float = 0.15
@export var hand_interaction_max_speed: float = 4.5

class Candidate:
	var probe: ShapeCast3D
	var marker: Marker3D
	var bone: int
	var sign_x: float
	var valid: bool = false
	var provisional: bool = false
	var surface := Vector3.ZERO
	var normal := Vector3.ZERO
	var raw_normal := Vector3.ZERO
	var raw := Vector3.ZERO
	var smoothed := Vector3.ZERO
	var origin := Vector3.ZERO
	var cast_end := Vector3.ZERO
	var distance: float = 0.0
	var score: float = 0.0
	var missed: float = 0.0
	var collider: Object
	var reason: String = "INACTIVE"

var left := Candidate.new()
var right := Candidate.new()
var skeleton: Skeleton3D
var state_reason: String = "INITIALIZING"
var probe_updates: int = 0
var _debug_mesh: MeshInstance3D
var _mesh := ImmediateMesh.new()
@onready var motor=get_parent()

var left_hand_surface_valid: bool:
	get: return left.valid
var right_hand_surface_valid: bool:
	get: return right.valid
var left_hand_surface_position: Vector3:
	get: return left.surface
var right_hand_surface_position: Vector3:
	get: return right.surface
var left_surface_normal: Vector3:
	get: return left.normal
var right_surface_normal: Vector3:
	get: return right.normal
var left_hand_surface_normal: Vector3:
	get: return left.normal
var right_hand_surface_normal: Vector3:
	get: return right.normal
var left_raw_target_position: Vector3:
	get: return left.raw
var right_raw_target_position: Vector3:
	get: return right.raw
var left_smoothed_target_position: Vector3:
	get: return left.smoothed
var right_smoothed_target_position: Vector3:
	get: return right.smoothed
var left_hand_target_position: Vector3:
	get: return left.smoothed
var right_hand_target_position: Vector3:
	get: return right.smoothed
var left_hand_target_score: float:
	get: return left.score
var right_hand_target_score: float:
	get: return right.score

func _ready() -> void:
	process_physics_priority=30 # After motor (0), animation (10), tree (20).
	skeleton=motor.get_node_or_null("VisualRoot/MasterRig/Base Armature and Mesh/Skeleton3D")
	for item in [[left,"Left",-1.0],[right,"Right",1.0]]:
		var side: Candidate=item[0]
		side.sign_x=item[2]
		side.bone=skeleton.find_bone("mixamorig_"+item[1]+"Arm") if skeleton!=null else -1
		side.probe=get_node(item[1]+"HandProbe")
		side.marker=get_node(item[1]+"HandTarget")
		side.probe.enabled=false # Only explicitly query while eligible.
		side.probe.shape=SphereShape3D.new()
		side.probe.collide_with_areas=false
		side.probe.collide_with_bodies=true
		side.probe.max_results=8
		side.probe.add_exception(motor)
	_debug_mesh=MeshInstance3D.new()
	_debug_mesh.name="DebugGeometry"
	_debug_mesh.mesh=_mesh
	add_child(_debug_mesh)
	_debug_mesh.top_level=true
	_debug_mesh.global_transform=Transform3D.IDENTITY # Vertices are world-space.
	var material:=StandardMaterial3D.new()
	material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo=true
	material.no_depth_test=true
	_debug_mesh.material_override=material

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode==KEY_F11:
		environment_hand_debug=not environment_hand_debug

func can_use_environment_hand_ik() -> bool:
	return eligibility()=="WALK"

func eligibility(_allow_idle: bool = false) -> String:
	if not enabled: return "DISABLED"
	var ik=motor.get_node_or_null("EnvironmentalHandIK")
	if ik!=null and not ik.enabled: return "DISABLED"
	if skeleton==null or left.bone<0 or right.bone<0: return "MISSING_RIG"
	var s=motor.animation_state
	if s.locked_on: return "LOCKED"
	if motor.dodge.is_dodging or motor.dodge.run_roll_recovery_visible: return "DODGE"
	var animation=motor.get_node("AnimationController")
	if s.jump_started or animation.current_state in [&"JumpStanding",&"JumpMoving"]: return "JUMP"
	if animation.current_state==&"Fall": return "FALL"
	if animation.current_state==&"Land": return "LAND"
	if not s.is_grounded or s.is_airborne: return "NOT_GROUNDED"
	if s.gait==2: return "SPRINT"
	if s.gait!=0: return "RUN"
	if motor.turn_180!=null and motor.turn_180.active: return "TURN"
	if motor.step_solver.active or motor.roll_traversal.active: return "TRAVERSAL"
	if animation.current_state!=&"Locomotion" or animation.grounded.transition!=&"Loops": return "ACTION"
	if s.move_input_magnitude<=.01 or s.horizontal_speed<=.1: return "IDLE"
	if s.horizontal_speed>hand_interaction_max_speed: return "TOO_FAST"
	return "WALK"

func _physics_process(delta: float) -> void:
	sample(delta)

func sample(delta: float, _held_side: int = -1) -> void:
	state_reason=eligibility()
	if not can_use_environment_hand_ik():
		invalidate(left,state_reason)
		invalidate(right,state_reason)
	else:
		update_side(left,delta)
		update_side(right,delta)
	_debug_mesh.visible=environment_hand_debug
	if environment_hand_debug: draw_debug()

func environment_collider(object: Object) -> bool:
	if not is_instance_valid(object) or not object is StaticBody3D: return false
	var node: Node=object
	while node!=null:
		if node==motor or node.is_queued_for_deletion(): return false
		for group in ["lock_on_target","enemy","enemies","hitbox","weapon"]:
			if node.is_in_group(group): return false
		node=node.get_parent()
	return true

func within_reach(side: Candidate, point: Vector3) -> bool:
	var forward: Vector3=-motor.visual.global_basis.z.normalized()
	var lateral: Vector3=motor.visual.global_basis.x.normalized()*side.sign_x
	var offset:=point-side.origin
	return offset.length()<=hand_interaction_reach_distance+.0001 and offset.y>=hand_min_vertical_offset and offset.y<=hand_max_vertical_offset and (point-motor.global_position).dot(forward)>=-hand_max_behind_distance and offset.dot(lateral)>=-.02

func invalidate(side: Candidate, reason: String) -> void:
	side.valid=false
	side.provisional=false
	side.missed=0
	side.score=0
	side.distance=0
	side.collider=null
	side.surface=Vector3.ZERO
	side.normal=Vector3.ZERO
	side.raw_normal=Vector3.ZERO
	side.raw=Vector3.ZERO
	side.smoothed=Vector3.ZERO
	side.reason=reason
	side.marker.visible=false
	side.marker.position=Vector3.ZERO

func update_side(side: Candidate, delta: float) -> void:
	side.origin=skeleton.global_transform*skeleton.get_bone_global_pose(side.bone).origin
	var outward: Vector3=motor.visual.global_basis.x.normalized()*side.sign_x
	var forward: Vector3=-motor.visual.global_basis.z.normalized()
	var cast_direction: Vector3=(outward+forward*hand_probe_forward_bias).normalized()
	side.cast_end=side.origin+cast_direction*hand_interaction_reach_distance
	var probe:=side.probe
	probe.global_transform=Transform3D(Basis.IDENTITY,side.origin)
	probe.shape.radius=hand_probe_radius
	probe.collision_mask=hand_collision_mask
	probe.target_position=cast_direction*hand_interaction_reach_distance
	probe.force_shapecast_update()
	probe_updates+=1
	var best: int=-1
	var best_distance:=INF
	for index in probe.get_collision_count():
		if not environment_collider(probe.get_collider(index)): continue
		var normal:=probe.get_collision_normal(index).normalized()
		var point:=probe.get_collision_point(index)
		if absf(normal.y)>.6 or normal.dot(outward)>-.1: continue
		if not within_reach(side,point) or not within_reach(side,point+normal*hand_surface_offset): continue
		var distance:=side.origin.distance_to(point)
		if distance<best_distance:
			best=index
			best_distance=distance
	if best<0:
		side.missed+=delta
		if side.valid and side.missed<=hand_target_loss_grace_time and is_instance_valid(side.collider) and environment_collider(side.collider) and within_reach(side,side.smoothed):
			side.provisional=true
			side.reason="GRACE"
			return
		invalidate(side,"NO_VALID_SURFACE")
		return
	var collider:=probe.get_collider(best)
	var normal:=probe.get_collision_normal(best).normalized()
	var surface:=probe.get_collision_point(best)
	var raw:=surface+normal*hand_surface_offset
	var continuous: bool=side.valid and side.collider==collider and side.normal.dot(normal)>.7 and within_reach(side,side.smoothed)
	side.smoothed=side.smoothed.lerp(raw,1-exp(-hand_target_smoothing_speed*delta)) if continuous else raw
	side.normal=side.normal.lerp(normal,1-exp(-hand_normal_smoothing_speed*delta)).normalized() if continuous else normal
	side.raw_normal=normal
	side.surface=surface
	side.raw=raw
	side.collider=collider
	side.distance=best_distance
	side.score=clampf(1-best_distance/hand_interaction_reach_distance,0,1)
	side.valid=true
	side.provisional=false
	side.missed=0
	side.reason="HIT"
	side.marker.global_position=side.smoothed
	side.marker.visible=environment_hand_debug

func line(a: Vector3,b: Vector3,color: Color) -> void:
	_mesh.surface_set_color(color)
	_mesh.surface_add_vertex(a)
	_mesh.surface_set_color(color)
	_mesh.surface_add_vertex(b)

func cross_at(point: Vector3,color: Color,size: float = .035) -> void:
	for axis in [Vector3.RIGHT,Vector3.UP,Vector3.FORWARD]: line(point-axis*size,point+axis*size,color)

func draw_debug() -> void:
	_mesh.clear_surfaces()
	if state_reason not in ["WALK","IDLE_HOLD"]: return
	_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	for side in [left,right]:
		var color:=Color.GREEN if side.valid else Color.RED
		if state_reason in ["WALK","IDLE_HOLD"]:
			line(side.origin,side.cast_end,color)
			cross_at(side.origin,Color.WHITE)
			for i in 16:
				var a:=TAU*i/16
				var b:=TAU*(i+1)/16
				for center in [side.origin,side.cast_end]:
					line(center+Vector3(0,cos(a),sin(a))*hand_probe_radius,center+Vector3(0,cos(b),sin(b))*hand_probe_radius,color)
		if side.valid:
			cross_at(side.surface,Color.YELLOW)
			line(side.surface,side.surface+side.normal*.2,Color.YELLOW)
			cross_at(side.raw,Color.CYAN)
			cross_at(side.smoothed,Color.MAGENTA,.05)
	_mesh.surface_end()

func debug_text() -> String:
	var result: String="ENVIRONMENT HAND INTERACTION (F11)\nEnabled: %s / State: %s / Queries: %d" % [enabled,state_reason,probe_updates]
	for pair in [["LEFT",left],["RIGHT",right]]:
		var side: Candidate=pair[1]
		result+="\n%s Valid: %s / %s / Distance: %.2f m / Score: %.2f\nTarget: %s / Normal: %s" % [pair[0],side.valid,side.reason,side.distance,side.score,side.smoothed,side.normal]
	return result
