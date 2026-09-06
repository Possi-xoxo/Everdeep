extends Node3D
## Targets opt in via group + child Marker3D. No enemy/dummy path coupling.
enum MovementMode { FREE, LOCKED_ON }
@export_range(1,50,0.5) var lock_on_max_distance: float = 20.0
@export_range(1,80,0.5) var lock_on_break_distance: float = 30.0
@export_range(10,120,1) var lock_on_max_acquisition_angle: float = 80.0
@export_range(1,25,0.5) var lock_on_rotation_speed: float = 12.0
@export_group("Dodge Facing Recovery")
@export_range(5,15,0.5) var lock_roll_realign_start_angle: float = 8.0
@export_range(2,8,0.5) var lock_roll_realign_finish_angle: float = 4.0
@export_range(90,720,10) var lock_roll_realign_speed: float = 450.0
@export_range(0,0.08,0.01) var lock_roll_realign_delay: float = 0.0
@export_range(0.2,0.4,0.01) var lock_roll_realign_max_duration: float = 0.30
var lock_roll_realign_active: bool = false
var lock_roll_realign_elapsed: float = 0.0
var lock_roll_realign_start_facing := Vector3.FORWARD
var target: Node3D
var movement_mode: MovementMode = MovementMode.FREE
var combat_input := Vector2.ZERO
var target_angle: float = 0.0
var indicator: MeshInstance3D
@onready var motor = get_parent()

func _ready() -> void:
	indicator=MeshInstance3D.new()
	indicator.name="LockIndicator"
	var mesh:=TorusMesh.new()
	mesh.inner_radius=0.13
	mesh.outer_radius=0.18
	indicator.mesh=mesh
	var material:=StandardMaterial3D.new()
	material.albedo_color=Color(1.0,0.85,0.15)
	material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	material.no_depth_test=true # Marker is at the chest, inside the dummy mesh.
	indicator.material_override=material
	add_child(indicator)
	indicator.top_level=true
	indicator.visible=false

func is_locked() -> bool:
	return movement_mode==MovementMode.LOCKED_ON and _valid(target)

func _valid(candidate: Node) -> bool:
	return is_instance_valid(candidate) and candidate is Node3D and candidate.is_inside_tree() and not candidate.is_queued_for_deletion() and candidate.is_in_group("lock_on_target") and candidate.get_node_or_null("LockOnPoint") is Marker3D and not candidate.get_node("LockOnPoint").is_queued_for_deletion()

func point() -> Vector3:
	return target.get_node("LockOnPoint").global_position if _valid(target) else motor.global_position

func direction() -> Vector3:
	var to: Vector3=point()-motor.global_position
	to.y=0
	return to.normalized() if to.length_squared()>0.0001 else -motor.visual.global_basis.z.normalized()

func distance() -> float:
	return motor.global_position.distance_to(point()) if is_locked() else 0.0

func toggle() -> void:
	if movement_mode==MovementMode.LOCKED_ON:
		clear()
		return
	var forward: Vector3=-motor.camera.global_basis.z
	forward.y=0
	if forward.length_squared()<0.0001: forward=-motor.visual.global_basis.z
	forward=forward.normalized()
	var best: Node3D
	var best_score:=INF
	for candidate in get_tree().get_nodes_in_group("lock_on_target"):
		if candidate==motor or not _valid(candidate): continue
		var offset: Vector3=candidate.get_node("LockOnPoint").global_position-motor.global_position
		var range_to:=offset.length()
		if range_to>lock_on_max_distance: continue
		offset.y=0
		var angle:=rad_to_deg(acos(clampf(forward.dot(offset.normalized()),-1,1))) if offset.length_squared()>0.0001 else 0.0
		if angle>lock_on_max_acquisition_angle: continue
		var score:=angle/maxf(lock_on_max_acquisition_angle,1)+0.25*range_to/lock_on_max_distance
		if score<best_score:
			best=candidate
			best_score=score
	if best==null: return
	target=best
	target.tree_exiting.connect(clear)
	movement_mode=MovementMode.LOCKED_ON
	motor._run_time=0.0
	motor.animation_state.run_buildup_ratio=0.0
	motor.animation_state.gait=mini(motor.animation_state.gait,1)
	motor.turn_arc_active=false
	if motor.turn_180!=null:
		motor.turn_180.cancel()
		motor.turn_180.resume_pending=false
		motor.turn_180.started=false
	update_target()

func clear() -> void:
	cancel_roll_realign()
	if is_instance_valid(target) and target.tree_exiting.is_connected(clear): target.tree_exiting.disconnect(clear)
	target=null
	movement_mode=MovementMode.FREE
	combat_input=Vector2.ZERO
	target_angle=0.0
	if is_instance_valid(indicator): indicator.visible=false

func update_target() -> void:
	if movement_mode!=MovementMode.LOCKED_ON: return
	if not _valid(target) or motor.global_position.distance_to(point())>maxf(lock_on_break_distance,lock_on_max_distance):
		clear()
		return
	indicator.visible=true
	indicator.global_position=point()
	# Ring faces the camera, without changing the camera or body orientation.
	indicator.global_basis=motor.camera.global_basis*Basis(Vector3.RIGHT,PI/2)
	var forward: Vector3=-motor.camera.global_basis.z
	forward.y=0
	target_angle=rad_to_deg(acos(clampf(forward.normalized().dot(direction()),-1,1)))

func face_target(delta: float) -> void:
	if not is_locked(): return
	if lock_roll_realign_active:
		update_roll_realign(delta)
		return
	var forward:=direction()
	var yaw:=atan2(-forward.x,-forward.z)
	motor.visual.global_rotation.y=lerp_angle(motor.visual.global_rotation.y,yaw,1-exp(-lock_on_rotation_speed*delta))

func facing_error() -> float:
	if not is_locked(): return 0.0
	var forward:=direction()
	return wrapf(atan2(-forward.x,-forward.z)-motor.visual.global_rotation.y,-PI,PI)

func begin_roll_realign() -> void:
	cancel_roll_realign()
	if not is_locked() or absf(rad_to_deg(facing_error()))<=lock_roll_realign_start_angle: return
	lock_roll_realign_start_facing=-motor.visual.global_basis.z
	lock_roll_realign_elapsed=0.0
	lock_roll_realign_active=true

func cancel_roll_realign() -> void:
	lock_roll_realign_active=false

func update_roll_realign(delta: float) -> void:
	if not is_locked():
		cancel_roll_realign()
		return
	var previous_elapsed:=lock_roll_realign_elapsed
	lock_roll_realign_elapsed+=delta
	var rotating_delta:=maxf(0.0,lock_roll_realign_elapsed-maxf(previous_elapsed,lock_roll_realign_delay))
	var error:=facing_error()
	var max_turn:=deg_to_rad(lock_roll_realign_speed)*rotating_delta
	motor.visual.global_rotation.y+=clampf(error,-max_turn,max_turn)
	# Timeout relinquishes ownership without a terminal yaw assignment.
	if absf(rad_to_deg(facing_error()))<=lock_roll_realign_finish_angle or lock_roll_realign_elapsed>=lock_roll_realign_max_duration:
		cancel_roll_realign()

func realign_debug_text() -> String:
	var owner: String="DODGE" if motor.dodge.is_dodging else ("POST_ROLL_REALIGN" if lock_roll_realign_active else ("NORMAL_LOCK" if is_locked() else "FREE"))
	return "LOCK ROLL REALIGN\nActive: %s / Yaw Owner: %s\nFacing Error: %.1f deg / Start: %.1f / Finish: %.1f\nRotation Speed: %.1f deg/s / Elapsed: %.3f\nDelay: %.2f / Max Duration: %.2f / Target: %s" % [lock_roll_realign_active,owner,rad_to_deg(facing_error()),lock_roll_realign_start_angle,lock_roll_realign_finish_angle,lock_roll_realign_speed,lock_roll_realign_elapsed,lock_roll_realign_delay,lock_roll_realign_max_duration,target.name if is_locked() else "None"]

func debug_text() -> String:
	var locked:=is_locked()
	var error:=0.0
	if locked: error=rad_to_deg(acos(clampf((-motor.visual.global_basis.z).dot(direction()),-1,1)))
	var gait: String="IDLE" if combat_input.length()<0.01 else ("RUN" if motor.animation_state.gait==1 else "WALK")
	return "LOCK-ON (F)\nMode: %s / Target: %s\nDistance: %.2fm / Target Angle: %.1f deg\nCombat Gait: %s / Input: %s\nFacing Error: %.1f deg / Sprint Allowed: %s" % ["LOCKED" if locked else "FREE",target.name if locked else "None",distance(),target_angle,gait,combat_input,error,not locked]
