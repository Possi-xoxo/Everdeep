extends CharacterBody3D
const State = preload("res://Characters/Player/V2/player_animation_state.gd")
const Dodge = preload("res://Characters/Player/V2/player_dodge_v2.gd")
@export_category("Dodge / Roll")
@export var dodge: Resource = Dodge.new()
@export_category("Gaits")
@export var walk_speed: float = 4.0
@export var run_start_speed: float = 4.0
@export var run_end_speed: float = 6.0
@export var sprint_speed: float = 8.0
@export_category("Lock-On Movement")
@export_range(0,12,0.1) var lock_walk_forward_speed: float = 4.0
@export_range(0,12,0.1) var lock_walk_backward_speed: float = 3.0
@export_range(0,12,0.1) var lock_walk_strafe_speed: float = 3.5
@export_range(0,12,0.1) var lock_run_forward_speed: float = 6.0
@export_range(0,12,0.1) var lock_run_backward_speed: float = 4.5
@export_range(0,12,0.1) var lock_run_strafe_speed: float = 6.0
## Zero inherits existing motor acceleration/turn response or deceleration.
@export_range(0,100,1) var lock_acceleration: float = 0.0
@export_range(0,100,1) var lock_deceleration: float = 0.0
@export_category("Gaits")
@export_range(0.1, 10.0, 0.1) var sprint_buildup_duration: float = 4.0
@export_category("Ground Motor")
@export var acceleration: float = 28.0
@export var deceleration: float = 36.0
@export var turn_acceleration: float = 65.0
@export var lateral_damping: float = 80.0
@export var turn_rate: float = 16.0
@export_category("Directional Turn Arc")
@export_range(0.0, 180.0) var large_turn_threshold_degrees: float = 90.0
@export_range(1.0, 90.0) var max_move_angle_from_forward: float = 60.0
@export_range(1.0, 720.0) var large_turn_rotation_speed: float = 360.0
@export_range(0.0, 90.0) var turn_arc_release_angle: float = 35.0
@export_range(0.0, 0.5) var large_turn_activation_speed: float = 0.3
@export var debug_turn_arc: bool = false
@export_category("Air Motor")
@export var jump_velocity: float = 8.0
@export var rise_gravity: float = 19.6
@export var fall_gravity: float = 29.4
@export_range(0.0, 1.0, 0.05) var air_control: float = 0.4
@export var max_fall_speed: float = 35.0
var animation_state = State.new()
var target_speed: float = 0.0
var _run_time: float = 0.0
## Presentation/action boundary: suppress during Land or other non-locomotion.
## Physical airborne/jump gating is always enforced by the motor as well.
var turn_arc_suppressed: bool = false
var turn_arc_active: bool = false
var last_large_turn_sign: float = 1.0
var _movement_input_was_active: bool = false
## Assigned by AnimationController; shared coordination, no clip timers here.
var turn_180: Resource
@onready var camera: Camera3D = $CameraRig/YawPivot/PitchPivot/SpringArm3D/Camera3D
@onready var visual: Node3D = $VisualRoot
@onready var step_solver = $StepSolver
@onready var lock_on = $LockOnController

func _ready() -> void:
	dodge=dodge.duplicate(true)
	dodge.initialize(true)

func _physics_process(delta: float) -> void:
	if Input.is_action_just_pressed("lock_on"): lock_on.toggle()
	step_motor(delta, Input.get_vector("move_left", "move_right", "move_forward", "move_backward"), Input.is_action_pressed("sprint"), Input.is_action_just_pressed("jump"), Input.is_action_just_pressed("dodge"))

## Input boundary also supports deterministic play tests without emulating OS keys.
func step_motor(delta: float, stick: Vector2, shift: bool, jump: bool, dodge_pressed: bool = false) -> void:
	dodge.advance_timers(delta)
	lock_on.update_target()
	var locked: bool=lock_on.is_locked()
	var s = animation_state
	s.locked_on=locked
	s.combat_input=Vector2(stick.x,-stick.y).limit_length(1.0) if locked else Vector2.ZERO
	lock_on.combat_input=s.combat_input
	var source_gait: int = s.gait
	var grounded_before: bool = is_on_floor() or step_solver.active
	s.was_grounded = s.is_grounded
	s.jump_started = jump and grounded_before
	s.takeoff_speed = Vector2(velocity.x, velocity.z).length() if s.jump_started else s.takeoff_speed
	s.move_input_magnitude = minf(stick.length(), 1.0)
	var forward := -camera.global_basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var right := camera.global_basis.x
	right.y = 0.0
	var direction := (right.normalized() * stick.x - forward * stick.y).normalized()
	if locked:
		forward=lock_on.direction()
		right=forward.cross(Vector3.UP)
		direction=(right*stick.x-forward*stick.y).normalized()
	s.move_direction_world = direction
	var anim=get_node("AnimationController")
	if dodge_pressed and grounded_before and not s.is_airborne and not s.jump_started and anim.current_state not in [&"JumpStanding", &"JumpMoving", &"Fall"]:
		var roll_direction: Vector3=direction
		if s.move_input_magnitude<dodge.dodge_movement_input_threshold:
			roll_direction=-lock_on.direction() if locked else visual.global_basis.z
		roll_direction.y=0
		var roll_gait: int=(min(source_gait,1) if locked else source_gait) if s.horizontal_speed>0.1 else (-1 if s.move_input_magnitude<dodge.dodge_movement_input_threshold else (1 if shift else 0))
		if s.move_input_magnitude>=dodge.dodge_movement_input_threshold:
			roll_gait=(maxi(roll_gait,1) if shift else 0)
		if dodge.begin(roll_direction,roll_gait,locked,anim.player,s.move_input_magnitude,s.horizontal_speed,s.combat_input,forward):
			turn_arc_active=false
			if turn_180!=null: turn_180.cancel()
	if dodge.is_dodging: s.jump_started=false
	if dodge.is_dodging:
		# Freeze existing Free buildup while eligible; releasing input resets it.
		if locked or not shift or stick.is_zero_approx(): _run_time=0
	elif locked:
		_run_time=0.0
		s.gait=State.Gait.RUN if shift else State.Gait.WALK
	elif not shift:
		_run_time = 0.0
		s.gait = State.Gait.WALK
	elif grounded_before and s.move_input_magnitude <= 0.01 and Vector2(velocity.x, velocity.z).length() < 0.1:
		_run_time = 0.0
		s.gait = State.Gait.RUN
	elif s.move_input_magnitude > 0.01:
		_run_time = minf(_run_time + delta, sprint_buildup_duration)
		s.gait = State.Gait.SPRINT if _run_time >= sprint_buildup_duration else State.Gait.RUN
	if not locked and turn_180 != null and turn_180.active and turn_180.running and shift:
		_run_time = turn_180.entry_buildup
		s.gait = turn_180.source_gait
	s.run_buildup_ratio = clampf(_run_time / maxf(sprint_buildup_duration, 0.001), 0.0, 1.0)
	target_speed = walk_speed
	if s.gait == State.Gait.RUN:
		target_speed = lerpf(run_start_speed, run_end_speed, s.run_buildup_ratio)
	elif s.gait == State.Gait.SPRINT:
		target_speed = sprint_speed
	if locked: target_speed=locked_speed(s.combat_input,shift)
	var horizontal := Vector3(velocity.x, 0.0, velocity.z)
	if s.jump_started and turn_180 != null and turn_180.active and turn_180.running:
		# A planted runner still has moving-jump intent and stored momentum.
		horizontal = Vector3.FORWARD.rotated(Vector3.UP, visual.global_rotation.y) * turn_180.entry_speed
		s.takeoff_speed = turn_180.entry_speed
	if turn_180 != null:
		turn_180.begin_motor_tick(direction, horizontal, grounded_before and not s.jump_started and not turn_arc_suppressed and not turn_arc_active and not locked and not dodge.is_dodging, source_gait, s.gait, visual)
		if turn_180.started:
			turn_180.entry_buildup = _run_time
	var turning: bool = turn_180 != null and turn_180.active
	var allowed_direction := direction
	if dodge.is_dodging:
		turn_arc_active=false
		allowed_direction=dodge.dodge_direction
	elif locked:
		turn_arc_active=false
		_movement_input_was_active=s.move_input_magnitude>0.01
		s.desired_turn_angle=0.0
		s.allowed_move_delta=0.0
	elif turning:
		turn_arc_active = false
		_movement_input_was_active = true
		allowed_direction = turn_180.target_direction
	elif turn_180 != null and turn_180.resume_pending:
		turn_arc_active = false
		allowed_direction = turn_180.target_direction
	else:
		allowed_direction = _turn_arc_direction(direction, horizontal.length(), grounded_before and not s.jump_started, delta)
	if s.jump_started:
		velocity.y = jump_velocity
	if dodge.is_dodging:
		horizontal=dodge.motion()
		target_speed=horizontal.length()
	elif grounded_before and not s.jump_started:
		if turn_180 != null and turn_180.resume_pending:
			var restored_speed: float = turn_180.entry_speed if shift else minf(turn_180.entry_speed, walk_speed)
			horizontal = turn_180.target_direction * restored_speed
		elif turning and turn_180.running:
			horizontal = turn_180.motion_target(target_speed)
		elif turning:
			var motion_target: Vector3 = turn_180.motion_target(target_speed * s.move_input_magnitude)
			var response := deceleration if motion_target.length() < horizontal.length() else acceleration
			horizontal = horizontal.move_toward(motion_target, response * delta)
		elif direction.is_zero_approx():
			var brake: float=lock_deceleration if locked and lock_deceleration>0 else deceleration
			horizontal = horizontal.move_toward(Vector3.ZERO, brake * delta)
		else:
			var parallel := horizontal.dot(allowed_direction)
			var lateral := horizontal - allowed_direction * parallel
			var alignment := horizontal.normalized().dot(allowed_direction) if horizontal.length() > 0.1 else 1.0
			var rate := lerpf(turn_acceleration, acceleration, clampf(alignment, 0.0, 1.0))
			if locked:
				if lock_acceleration>0: rate=lock_acceleration
				if parallel>target_speed*s.move_input_magnitude and lock_deceleration>0: rate=lock_deceleration
			parallel = move_toward(parallel, target_speed * s.move_input_magnitude, rate * delta)
			horizontal = allowed_direction * parallel + lateral.move_toward(Vector3.ZERO, lateral_damping * delta)
	elif not direction.is_zero_approx() and not s.jump_started:
		horizontal = horizontal.move_toward(direction * target_speed * s.move_input_magnitude, acceleration * air_control * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	if dodge.is_dodging and dodge.dodge_type!="BACKSTEP":
		visual.rotation.y=lerp_angle(visual.rotation.y,atan2(-dodge.dodge_direction.x,-dodge.dodge_direction.z),1-exp(-dodge.dodge_rotation_speed*delta))
	elif locked:
		lock_on.face_target(delta)
	elif not dodge.is_dodging and s.move_input_magnitude > 0.01 and horizontal.length() > 0.1 and not turn_arc_active and not turning:
		visual.rotation.y = lerp_angle(visual.rotation.y, atan2(-horizontal.x, -horizontal.z), 1.0 - exp(-turn_rate * delta))
	if not grounded_before or s.jump_started:
		velocity.y = maxf(velocity.y - (rise_gravity if velocity.y > 0.0 else fall_gravity) * delta, -max_fall_speed)
	else:
		velocity.y = -0.5
	var step_allowed: bool = grounded_before and not s.jump_started and not turn_arc_suppressed and not turning and not dodge.is_dodging
	var stepping: bool = step_solver.prepare(delta,horizontal,direction,step_allowed)
	var saved_snap := floor_snap_length
	if stepping:
		step_solver.lift(delta)
		floor_snap_length = 0.0
		velocity.y = 0.0
	move_and_slide()
	floor_snap_length = saved_snap
	step_solver.finish()
	s.is_stepping_up = step_solver.active
	s.step_height = step_solver.step_height
	s.step_target_y = step_solver.step_target_y
	s.is_grounded = is_on_floor() or step_solver.active
	s.is_airborne = not s.is_grounded
	if s.is_airborne:
		dodge.finish()
		turn_arc_active = false
		if turn_180 != null:
			turn_180.cancel()
	s.turn_arc_active = turn_arc_active
	s.allowed_move_direction_world = allowed_direction
	s.horizontal_speed = Vector2(velocity.x, velocity.z).length()
	s.vertical_velocity = velocity.y
	s.is_falling = s.is_airborne and velocity.y < 0.0
	s.air_time = s.air_time + delta if s.is_airborne else 0.0
	var local_velocity := visual.global_basis.inverse() * Vector3(velocity.x, 0.0, velocity.z)
	s.move_local = Vector2(local_velocity.x, -local_velocity.z).normalized() if s.horizontal_speed > 0.1 else Vector2.ZERO
	# Idle camera orbit is not a facing request. Explicit pivot ownership remains
	# separate; returning input still uses the current camera-relative direction.
	s.facing_delta = wrapf(atan2(-direction.x, -direction.z) - visual.global_rotation.y, -PI, PI) if s.move_input_magnitude > 0.01 else 0.0

func _turn_arc_direction(desired: Vector3, speed: float, grounded: bool, delta: float) -> Vector3:
	var s = animation_state
	var starting_from_rest := not _movement_input_was_active and speed <= large_turn_activation_speed
	_movement_input_was_active = not desired.is_zero_approx()
	s.desired_turn_angle = 0.0
	s.allowed_move_delta = 0.0
	if desired.is_zero_approx() or not grounded or turn_arc_suppressed:
		turn_arc_active = false
		return desired
	var angle := wrapf(atan2(-desired.x, -desired.z) - visual.global_rotation.y, -PI, PI)
	# Within one degree of directly behind, retain a deterministic turn side.
	if absf(angle) >= deg_to_rad(179.0):
		angle = absf(angle) * last_large_turn_sign
	s.desired_turn_angle = angle
	var release := deg_to_rad(minf(turn_arc_release_angle, large_turn_threshold_degrees))
	if turn_arc_active and absf(angle) <= release:
		turn_arc_active = false
	elif not turn_arc_active and absf(angle) > deg_to_rad(large_turn_threshold_degrees + 0.001) and (starting_from_rest or s.gait == State.Gait.SPRINT):
		turn_arc_active = true
	if not turn_arc_active:
		s.allowed_move_delta = angle
		return desired
	last_large_turn_sign = signf(angle)
	var limit := deg_to_rad(max_move_angle_from_forward)
	var allowed_angle := clampf(angle, -limit, limit)
	var allowed := Vector3.FORWARD.rotated(Vector3.UP, visual.global_rotation.y + allowed_angle)
	s.allowed_move_delta = allowed_angle
	# Face the original intent, not the clamped acceleration target. Moving
	# animation cancels any stationary turn before it can overwrite this yaw.
	visual.rotation.y += clampf(angle, -deg_to_rad(large_turn_rotation_speed) * delta, deg_to_rad(large_turn_rotation_speed) * delta)
	return allowed

func locked_speed(input: Vector2, run: bool) -> float:
	var longitudinal: float=(lock_run_forward_speed if run else lock_walk_forward_speed) if input.y>=0 else (lock_run_backward_speed if run else lock_walk_backward_speed)
	var strafe: float=lock_run_strafe_speed if run else lock_walk_strafe_speed
	var total:=absf(input.x)+absf(input.y)
	return lerpf(longitudinal,strafe,absf(input.x)/total) if total>0.001 else longitudinal
