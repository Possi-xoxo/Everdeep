extends CharacterBody3D
const State = preload("res://Characters/Player/V2/player_animation_state.gd")
const Dodge = preload("res://Characters/Player/V2/player_dodge_v2.gd")
@export_category("Dodge / Roll")
@export var dodge: Resource = Dodge.new()
@export_category("Gaits")
@export var walk_speed: float = 2.0
@export var run_start_speed: float = 4.0
@export var run_end_speed: float = 6.0
@export var sprint_speed: float = 8.0
@export_category("Lock-On Movement")
@export_range(0,12,0.1) var lock_walk_forward_speed: float = 2.0
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
@export_category("Free Walk")
@export_range(240,480,10) var walk_direction_turn_speed: float = 360.0
@export var debug_walk_direction: bool = false
var smoothed_walk_direction := Vector3.ZERO
var desired_move_direction := Vector3.ZERO
var walk_direction_smoothing_active: bool = false
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
@onready var roll_traversal = $RollTraversal
@onready var lock_on = $LockOnController
@onready var crouch = $CrouchController

func _ready() -> void:
	dodge=dodge.duplicate(true)
	dodge.initialize(true)

@onready var traversal = $TraversalController
@onready var ground_support = $GroundSupportProbe
@onready var context_interaction = $ContextInteraction

func physical_ground_contact() -> bool:
	return is_on_floor() or step_solver.active or roll_traversal.active

func _physics_process(delta: float) -> void:
	if traversal.hang.running:
		if Input.is_action_just_pressed("move_forward"): traversal.hang.request_up()
		elif Input.is_action_just_pressed("move_backward"): traversal.hang.request_release()
	context_interaction.tick(Input.is_action_just_pressed("interact"),Input.is_action_pressed("interact"))
	if not traversal.is_traversing or traversal.phase==traversal.Phase.EXIT:
		if Input.is_action_just_pressed("lock_on"): lock_on.toggle()
		if Input.is_action_just_pressed("crouch"): crouch.requested = not crouch.requested
	step_motor(delta, Input.get_vector("move_left", "move_right", "move_forward", "move_backward"), Input.is_action_pressed("sprint"), Input.is_action_just_pressed("jump"), Input.is_action_just_pressed("dodge"), crouch.requested)

## Input boundary also supports deterministic play tests without emulating OS keys.
func step_motor(delta: float, stick: Vector2, shift: bool, jump: bool, dodge_pressed: bool = false, crouch_requested: bool = false) -> void:
	if not ground_support.initialized: ground_support.refresh(0)
	var hang_intent: Vector3=traversal.hang.acquisition.prepare_tick(traversal.hang,delta,stick)
	if traversal.hang.running:
		if traversal.hang.step(delta): return
		crouch_requested=crouch.requested
	elif traversal.hang.try_catch(delta,hang_intent):
		traversal.hang.step(delta)
		return
	var was_mantling: bool=traversal.mantle.running
	if was_mantling and traversal.mantle.step(delta,stick,jump,dodge_pressed): return
	traversal.advance(delta)
	if traversal.is_traversing and not ((traversal.mantle.running or traversal.hang.running) and traversal.phase==traversal.Phase.EXIT):
		# Phase 0 yields input authority only; braking, gravity and collisions
		# still run through the normal motor. No traversal pose/translation yet.
		stick=Vector2.ZERO
		shift=false
		jump=false
		dodge_pressed=false
		crouch_requested=crouch.requested
	var dodge_was_active: bool=dodge.is_dodging
	dodge.advance_timers(delta,roll_traversal.active,stick)
	var was_crouched: bool=crouch.active()
	crouch.update(crouch_requested,delta,stick,shift)
	crouch.motion_request(stick,shift,delta)
	if crouch.active() or was_crouched:
		# Locked may resume Run immediately after the physical exit completes;
		# Free keeps its first standing tick at Walk before normal promotion.
		if crouch.active() or not lock_on.is_locked(): shift=false
		jump=false
		_run_time=0
		animation_state.gait=State.Gait.WALK
	dodge.handoff_input=stick
	if dodge.handoff_waiting_for_input:
		if stick.length()<dodge.dodge_movement_input_threshold:
			stick=Vector2.ZERO
		else:
			dodge.handoff_waiting_for_input=false
	lock_on.update_target()
	var locked: bool=lock_on.is_locked()
	var s = animation_state
	s.locked_on=locked
	s.combat_input=Vector2(stick.x,-stick.y).limit_length(1.0) if locked else Vector2.ZERO
	lock_on.combat_input=s.combat_input
	var source_gait: int = s.gait
	var grounded_before: bool = ground_support.has_ground_support or step_solver.active or roll_traversal.active
	s.was_grounded = s.is_grounded
	s.jump_started = jump and (grounded_before or ground_support.coyote_remaining>0)
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
	desired_move_direction=direction
	if dodge.handoff_reorienting:
		var facing: Vector3=-visual.global_basis.z
		if not dodge.handoff_this_tick and (locked or direction.is_zero_approx() or rad_to_deg(facing.angle_to(direction))<=turn_arc_release_angle):
			dodge.handoff_reorienting=false
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
			crouch.clear_handoff()
			if crouch.active():
				crouch.phase=crouch.Phase.CROUCHED
				crouch.resize(crouch.crouch_capsule_height)
			# A running roll starts a fresh Sprint buildup at control return.
			if dodge.clip==dodge.RUN: _run_time=0.0
			turn_arc_active=false
			if turn_180!=null: turn_180.cancel()
	if dodge.is_dodging: s.jump_started=false
	# Only a real RUN -> jump spends grounded buildup. Sprint/edge loss do not.
	if s.jump_started and source_gait==State.Gait.RUN:
		_run_time=0.0
		if turn_180!=null: turn_180.entry_buildup=0.0
	if not locked or s.jump_started or dodge.is_dodging:
		lock_on.cancel_roll_realign()
	elif dodge_was_active:
		lock_on.begin_roll_realign()
	_update_sprint_buildup(delta,shift,locked,grounded_before and not s.jump_started)
	if not locked and turn_180 != null and turn_180.active and turn_180.running and shift and s.move_input_magnitude>.01:
		_run_time = turn_180.entry_buildup
		s.gait = turn_180.source_gait
	s.run_buildup_ratio = clampf(_run_time / maxf(sprint_buildup_duration, 0.001), 0.0, 1.0)
	target_speed = walk_speed
	if s.gait == State.Gait.RUN:
		target_speed = lerpf(run_start_speed, run_end_speed, s.run_buildup_ratio)
	elif s.gait == State.Gait.SPRINT:
		target_speed = sprint_speed
	if locked: target_speed=locked_speed(s.combat_input,shift)
	if crouch.active(): target_speed=crouch.speed()
	var horizontal := Vector3(velocity.x, 0.0, velocity.z)
	if dodge.handoff_this_tick:
		if grounded_before and direction.is_zero_approx(): horizontal=Vector3.ZERO
		dodge.handoff_target_mode="LOCKED" if locked else "FREE"
		dodge.handoff_target_gait="FALL" if not grounded_before else ("IDLE" if direction.is_zero_approx() else ["WALK","RUN","SPRINT"][s.gait])
		dodge.handoff_target_direction=direction
	if s.jump_started and turn_180 != null and turn_180.active and turn_180.running:
		# A planted runner still has moving-jump intent and stored momentum.
		horizontal = Vector3.FORWARD.rotated(Vector3.UP, visual.global_rotation.y) * turn_180.entry_speed
		s.takeoff_speed = turn_180.entry_speed
	if turn_180 != null:
		turn_180.begin_motor_tick(direction, horizontal, grounded_before and not s.jump_started and not crouch.active() and not turn_arc_suppressed and not turn_arc_active and not locked and not dodge.is_dodging and not dodge.handoff_reorienting, source_gait, s.gait, visual)
		if turn_180.started:
			turn_180.entry_buildup = _run_time
	var turning: bool = turn_180 != null and turn_180.active
	var allowed_direction := direction
	if dodge.is_dodging:
		turn_arc_active=false
		allowed_direction=dodge.dodge_direction
	elif locked or dodge.handoff_reorienting:
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
	# Decisions above consume RAW camera-relative intent, especially Walk180.
	# Only ordinary standing Free Walk feeds a smoothed target to the motor.
	var free_walk_presentation: bool=(anim.current_state==&"Locomotion" and anim.grounded.transition==&"Loops") or (crouch.active() and String(anim.current_state).begins_with("Crouch"))
	walk_direction_smoothing_active=not locked and s.gait==State.Gait.WALK and grounded_before and not s.jump_started and not dodge.is_dodging and not dodge.run_roll_recovery_visible and not dodge.handoff_reorienting and not turning and not turn_arc_active and not (turn_180!=null and turn_180.resume_pending) and free_walk_presentation
	if walk_direction_smoothing_active and not direction.is_zero_approx():
		allowed_direction=_smooth_walk_direction(allowed_direction,delta)
	else:
		smoothed_walk_direction=-visual.global_basis.z.normalized()
	if s.jump_started:
		ground_support.consume_jump()
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
	elif walk_direction_smoothing_active and not direction.is_zero_approx():
		visual.rotation.y=rotate_toward(visual.rotation.y,atan2(-smoothed_walk_direction.x,-smoothed_walk_direction.z),deg_to_rad(walk_direction_turn_speed)*delta)
	elif not dodge.is_dodging and s.move_input_magnitude > 0.01 and horizontal.length() > 0.1 and not turn_arc_active and not turning:
		visual.rotation.y = lerp_angle(visual.rotation.y, atan2(-horizontal.x, -horizontal.z), 1.0 - exp(-turn_rate * delta))
	if not grounded_before or s.jump_started:
		velocity.y = maxf(velocity.y - (rise_gravity if velocity.y > 0.0 else fall_gravity) * delta, -max_fall_speed)
	else:
		velocity.y = -0.5
	var step_allowed: bool = grounded_before and not s.jump_started and not turn_arc_suppressed and not turning and not dodge.is_dodging and not roll_traversal.active
	var stepping: bool = step_solver.prepare(delta,horizontal,direction,step_allowed)
	var roll_stepping: bool=roll_traversal.prepare_roll(delta,horizontal)
	var saved_snap := floor_snap_length
	var saved_stop := floor_stop_on_slope
	if not grounded_before:
		floor_snap_length=0
		floor_stop_on_slope=false
	if stepping:
		step_solver.lift(delta)
		floor_snap_length = 0.0
		velocity.y = 0.0
	elif roll_stepping:
		roll_traversal.lift(delta)
		floor_snap_length=0.0
		# Bounded collision-swept correction owns vertical movement only while
		# traversing verified support. Free airborne rolls retain normal gravity.
		if roll_traversal.active: velocity.y=0.0
	move_and_slide()
	floor_snap_length = saved_snap
	floor_stop_on_slope = saved_stop
	step_solver.finish()
	roll_traversal.finish()
	s.is_stepping_up = step_solver.active
	s.step_height = step_solver.step_height
	s.step_target_y = step_solver.step_target_y
	ground_support.refresh(delta,step_solver.active or roll_traversal.active)
	s.is_grounded = ground_support.has_ground_support or step_solver.active or roll_traversal.active
	s.is_airborne = not s.is_grounded
	dodge.dodge_airborne=dodge.is_rolling() and s.is_airborne
	if s.is_airborne:
		if not dodge.is_rolling(): dodge.finish()
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

## One authoritative timer: ground locomotion earns progress; air only holds it.
## Existing action-entry resets (run roll, crouch, lock-on, mantle) remain owners.
func _update_sprint_buildup(delta: float, shift: bool, locked: bool, can_accumulate: bool) -> void:
	var s=animation_state
	if locked or not shift or s.move_input_magnitude<=.01:
		_run_time=0.0
		if turn_180!=null and turn_180.active and turn_180.running:
			# The committed turn keeps its animation/momentum, not cancelled intent.
			turn_180.entry_buildup=0.0
			turn_180.source_gait=State.Gait.RUN
	elif can_accumulate and not dodge.is_dodging:
		_run_time=minf(_run_time+delta,sprint_buildup_duration)
	# Ordinary jump/fall cannot earn sprint or resurrect a cancelled intent.
	# Sprint rolls retain their existing gait ownership; running rolls reset on entry.
	if not dodge.is_dodging:
		s.gait=State.Gait.WALK if not shift else (State.Gait.SPRINT if not locked and _run_time>=sprint_buildup_duration else State.Gait.RUN)

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

func _smooth_walk_direction(desired: Vector3, delta: float) -> Vector3:
	if smoothed_walk_direction.is_zero_approx(): smoothed_walk_direction=-visual.global_basis.z.normalized()
	var current:=atan2(-smoothed_walk_direction.x,-smoothed_walk_direction.z)
	var target:=atan2(-desired.x,-desired.z)
	var next:=rotate_toward(current,target,deg_to_rad(walk_direction_turn_speed)*delta)
	smoothed_walk_direction=Vector3.FORWARD.rotated(Vector3.UP,next)
	return smoothed_walk_direction

func walk_direction_debug_text() -> String:
	return "FREE WALK TURN\nDesired: %s\nSmoothed: %s\nFacing Error: %.1f degrees / Turn Speed: %.0f deg/s\nSmoothing: %s / Walk180 Active: %s" % [desired_move_direction,smoothed_walk_direction,rad_to_deg((-visual.global_basis.z).angle_to(desired_move_direction)) if not desired_move_direction.is_zero_approx() else 0.0,walk_direction_turn_speed,walk_direction_smoothing_active,turn_180!=null and turn_180.active and not turn_180.running]

func locked_speed(input: Vector2, run: bool) -> float:
	var longitudinal: float=(lock_run_forward_speed if run else lock_walk_forward_speed) if input.y>=0 else (lock_run_backward_speed if run else lock_walk_backward_speed)
	var strafe: float=lock_run_strafe_speed if run else lock_walk_strafe_speed
	var total:=absf(input.x)+absf(input.y)
	return lerpf(longitudinal,strafe,absf(input.x)/total) if total>0.001 else longitudinal
