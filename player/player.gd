class_name EverdeepPlayer
extends CharacterBody3D

enum LocomotionState {
	GROUNDED,
	AIRBORNE,
	DODGING,
}

enum GroundMovementPhase {
	IDLE,
	STARTING,
	MOVING,
	STOPPING,
}

enum Gait {
	WALK,
	RUN,
	SPRINT,
}

signal movement_started
signal movement_stopping
signal movement_stopped
signal sprint_started
signal sprint_ended

@export_category("Gait")
@export_range(0.1, 20.0, 0.1) var walk_speed: float = 2.5
@export_range(0.1, 20.0, 0.1) var run_speed: float = 4.0
@export_range(0.1, 30.0, 0.1) var sprint_speed: float = 8.0
@export_range(3.0, 5.0, 0.1) var sprint_activation_delay: float = 4.0

@export_category("Movement Start")
@export_range(0.0, 1.0, 0.05) var walk_start_initial_movement_scale: float = 0.30
@export_range(0.0, 1.0, 0.05) var walk_start_full_movement_progress: float = 0.75
@export_range(0.0, 1.0, 0.05) var run_start_initial_movement_scale: float = 0.40
@export_range(0.0, 1.0, 0.05) var run_start_full_movement_progress: float = 0.65

@export_category("Movement Stop")
@export_range(0.0, 0.20, 0.01) var movement_stop_commitment: float = 0.12
@export_range(0.0, 0.5, 0.01) var true_idle_speed_threshold: float = 0.10
@export_range(0.0, 0.10, 0.01) var walk_stop_motion_carry_time: float = 0.06

@export_category("Ground Motor")
@export_range(0.1, 100.0, 0.1) var ground_acceleration: float = 28.0
@export_range(0.1, 100.0, 0.1) var ground_deceleration: float = 42.0
@export_range(0.1, 150.0, 0.1) var turn_acceleration: float = 70.0
@export_range(0.1, 150.0, 0.1) var lateral_damping: float = 85.0
@export_range(0.0, 1.0, 0.05) var turn_alignment_threshold: float = 0.7
@export_range(0.1, 30.0, 0.1) var ground_rotation_speed: float = 16.0

@export_category("Air Movement")
@export_range(0.1, 100.0, 0.1) var acceleration: float = 22.0
@export_range(0.1, 30.0, 0.1) var rotation_speed: float = 12.0

@export_category("Jump")
@export_range(0.1, 20.0, 0.1) var jump_velocity: float = 8.0
@export_range(0.0, 1.0, 0.05) var air_control: float = 0.4

@export_category("Gravity")
@export_range(0.1, 5.0, 0.05) var rise_gravity_multiplier: float = 2.0
@export_range(0.1, 6.0, 0.05) var fall_gravity_multiplier: float = 3.0
@export_range(1.0, 100.0, 0.5) var max_fall_speed: float = 35.0

@export_category("Dodge")
@export_range(0.1, 30.0, 0.1) var dodge_speed: float = 11.0
@export_range(0.05, 2.0, 0.01) var dodge_duration: float = 0.32
@export_range(0.0, 3.0, 0.05) var dodge_cooldown: float = 0.35

@export_category("References")
@export var camera_rig: Node3D
@export var movement_camera: Camera3D
@export var visual_root: Node3D
@export var combat_controller: PlayerCombatController

@export_category("Debug")
@export var debug_locomotion_transitions: bool = false
@export var debug_gait_phase_changes: bool = false

var _gravity: float = float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))
var _dodge_time_remaining: float = 0.0
var _dodge_cooldown_remaining: float = 0.0
var _dodge_direction: Vector3 = Vector3.ZERO
var locomotion_state: LocomotionState = LocomotionState.AIRBORNE
var ground_movement_phase: GroundMovementPhase = GroundMovementPhase.IDLE
var current_gait: Gait = Gait.WALK
var _movement_phase_elapsed := 0.0
var _sprint_hold_time := 0.0
var _start_direction := Vector3.ZERO
var _start_animation_ready := false
var _stop_animation_ready := false
var _start_transition_progress := 0.0


func _ready() -> void:
	if camera_rig == null:
		camera_rig = get_node_or_null("CameraRig") as Node3D
	if movement_camera == null:
		movement_camera = get_node_or_null("CameraRig/YawPivot/PitchPivot/SpringArm3D/Camera3D") as Camera3D
	if visual_root == null:
		visual_root = get_node_or_null("VisualRoot") as Node3D
	if combat_controller == null:
		combat_controller = get_node_or_null("CombatController") as PlayerCombatController


func _physics_process(delta: float) -> void:
	_dodge_cooldown_remaining = maxf(_dodge_cooldown_remaining - delta, 0.0)
	_sync_surface_state()
	var input_direction := _get_camera_relative_input()

	if Input.is_action_just_pressed("dodge") and _can_dodge():
		_start_dodge(input_direction)
	elif Input.is_action_just_pressed("jump") and _can_jump():
		velocity.y = jump_velocity
		_interrupt_ground_movement(false)
		_set_locomotion_state(LocomotionState.AIRBORNE)

	if locomotion_state != LocomotionState.DODGING and not _is_attacking():
		_update_gait_intent(input_direction, delta)

	match locomotion_state:
		LocomotionState.GROUNDED:
			_update_grounded_movement(input_direction, delta)
		LocomotionState.AIRBORNE:
			_update_airborne_movement(input_direction, delta)
		LocomotionState.DODGING:
			_update_dodge(delta)

	_apply_gravity(delta)
	move_and_slide()
	_resolve_post_move_state()


func _get_camera_relative_input() -> Vector3:
	var input_vector := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	if input_vector.is_zero_approx():
		return Vector3.ZERO

	var camera_forward := Vector3.FORWARD
	var camera_right := Vector3.RIGHT
	if movement_camera != null:
		camera_forward = -movement_camera.global_basis.z
		camera_right = movement_camera.global_basis.x

	# Pitch must not affect horizontal speed or introduce vertical movement.
	camera_forward.y = 0.0
	camera_right.y = 0.0
	camera_forward = camera_forward.normalized()
	camera_right = camera_right.normalized()

	var world_direction := camera_right * input_vector.x + camera_forward * -input_vector.y
	return world_direction.normalized()


func _update_grounded_movement(input_direction: Vector3, delta: float) -> void:
	var is_attacking := _is_attacking()
	if is_attacking and combat_controller != null:
		_interrupt_ground_movement(true)
		var attack_velocity := combat_controller.calculate_attack_velocity(input_direction, delta)
		velocity.x = attack_velocity.x
		velocity.z = attack_velocity.z
		var attack_facing := combat_controller.get_attack_facing_direction()
		if not attack_facing.is_zero_approx():
			_rotate_toward(attack_facing, delta, combat_controller.attack_rotation_multiplier)
		return

	var movement_direction := input_direction
	var horizontal_velocity := Vector3(velocity.x, 0.0, velocity.z)
	var horizontal_speed := horizontal_velocity.length()

	if movement_direction.is_zero_approx():
		if ground_movement_phase == GroundMovementPhase.STARTING:
			_set_ground_movement_phase(GroundMovementPhase.IDLE)
		elif ground_movement_phase == GroundMovementPhase.MOVING:
			_set_ground_movement_phase(GroundMovementPhase.STOPPING)
		_movement_phase_elapsed += delta
		var preserve_walk_momentum := (
			ground_movement_phase == GroundMovementPhase.STOPPING
			and current_gait == Gait.WALK
			and _movement_phase_elapsed <= walk_stop_motion_carry_time
		)
		if not preserve_walk_momentum:
			horizontal_velocity = _resolve_grounded_velocity(
				horizontal_velocity,
				Vector3.ZERO,
				run_speed,
				delta
			)
		velocity.x = horizontal_velocity.x
		velocity.z = horizontal_velocity.z
		if (
			ground_movement_phase == GroundMovementPhase.STOPPING
			and _movement_phase_elapsed >= movement_stop_commitment
			and horizontal_velocity.length() <= true_idle_speed_threshold
			and _stop_animation_ready
		):
			_set_ground_movement_phase(GroundMovementPhase.IDLE)
			_reset_sprint_to_walk()
		return

	if ground_movement_phase == GroundMovementPhase.STOPPING:
		_set_ground_movement_phase(GroundMovementPhase.MOVING)
	elif (
		ground_movement_phase == GroundMovementPhase.IDLE
		and horizontal_speed <= true_idle_speed_threshold
	):
		_start_direction = movement_direction
		_set_ground_movement_phase(GroundMovementPhase.STARTING)

	if ground_movement_phase == GroundMovementPhase.STARTING:
		# Keep the latest intent so a quick direction correction never launches
		# the character along a stale captured direction.
		_start_direction = movement_direction
		_rotate_toward(_start_direction, delta, 1.0, ground_rotation_speed)
		var start_target_speed := _get_current_gait_speed() * _get_start_movement_scale()
		horizontal_velocity = _resolve_grounded_velocity(
			horizontal_velocity,
			movement_direction,
			start_target_speed,
			delta
		)
		velocity.x = horizontal_velocity.x
		velocity.z = horizontal_velocity.z
		if not _start_animation_ready:
			return
		_set_ground_movement_phase(GroundMovementPhase.MOVING)
	elif ground_movement_phase == GroundMovementPhase.IDLE:
		# Meaningful retained velocity (for example after landing) bypasses STARTING.
		_set_ground_movement_phase(GroundMovementPhase.MOVING)

	var target_speed := _get_current_gait_speed()
	horizontal_velocity = _resolve_grounded_velocity(
		horizontal_velocity,
		movement_direction,
		target_speed,
		delta
	)
	velocity.x = horizontal_velocity.x
	velocity.z = horizontal_velocity.z

	if not movement_direction.is_zero_approx():
		_rotate_toward(movement_direction, delta, 1.0, ground_rotation_speed)


func _resolve_grounded_velocity(
	current_velocity: Vector3,
	desired_direction: Vector3,
	target_speed: float,
	delta: float
) -> Vector3:
	current_velocity.y = 0.0
	if desired_direction.is_zero_approx():
		return current_velocity.move_toward(Vector3.ZERO, ground_deceleration * delta)

	desired_direction.y = 0.0
	desired_direction = desired_direction.normalized()
	var current_speed := current_velocity.length()
	if current_speed <= 0.001:
		return current_velocity.move_toward(
			desired_direction * target_speed,
			ground_acceleration * delta
		)

	var current_direction := current_velocity / current_speed
	var alignment := clampf(current_direction.dot(desired_direction), -1.0, 1.0)
	var turn_weight := clampf(
		(turn_alignment_threshold - alignment) / maxf(turn_alignment_threshold, 0.001),
		0.0,
		1.0
	)
	var response_rate := lerpf(ground_acceleration, turn_acceleration, turn_weight)

	# Resolve intended travel separately from obsolete sideways momentum. This
	# preserves some weight during a turn without making the player skate along
	# the old direction.
	var parallel_speed := current_velocity.dot(desired_direction)
	var parallel_velocity := desired_direction * parallel_speed
	var lateral_velocity := current_velocity - parallel_velocity
	parallel_velocity = parallel_velocity.move_toward(
		desired_direction * target_speed,
		response_rate * delta
	)
	lateral_velocity = lateral_velocity.move_toward(Vector3.ZERO, lateral_damping * delta)
	return parallel_velocity + lateral_velocity


func _update_airborne_movement(input_direction: Vector3, delta: float) -> void:
	# Preserve the pre-refactor takeoff frame: floor contact is still valid until
	# move_and_slide() processes the newly applied upward velocity.
	if is_on_floor():
		# An intentional upward impulse already owns this frame. Do not let the
		# grounded braking motor shave horizontal momentum before floor contact
		# clears in move_and_slide().
		if velocity.y > 0.0:
			return
		_update_grounded_movement(input_direction, delta)
		return

	# No-input air movement keeps takeoff momentum; input provides reduced steering.
	if not input_direction.is_zero_approx():
		var target_speed := _get_current_gait_speed()
		var target_velocity := input_direction * target_speed
		var horizontal_velocity := Vector3(velocity.x, 0.0, velocity.z)
		horizontal_velocity = horizontal_velocity.move_toward(
			target_velocity,
			acceleration * air_control * delta
		)
		velocity.x = horizontal_velocity.x
		velocity.z = horizontal_velocity.z
		_rotate_toward(input_direction, delta)


func _can_dodge() -> bool:
	return (
		locomotion_state == LocomotionState.GROUNDED
		and _dodge_time_remaining <= 0.0
		and _dodge_cooldown_remaining <= 0.0
		and is_on_floor()
		and not _is_attacking()
	)


func _can_jump() -> bool:
	return (
		locomotion_state == LocomotionState.GROUNDED
		and _dodge_time_remaining <= 0.0
		and is_on_floor()
		and not _is_attacking()
	)


func can_begin_light_attack() -> bool:
	return locomotion_state == LocomotionState.GROUNDED and is_on_floor()


func _is_attacking() -> bool:
	return combat_controller != null and combat_controller.is_attacking()


func _start_dodge(input_direction: Vector3) -> void:
	_interrupt_ground_movement(true)
	_dodge_direction = input_direction
	if _dodge_direction.is_zero_approx():
		_dodge_direction = -visual_root.global_basis.z if visual_root != null else -global_basis.z
		_dodge_direction.y = 0.0
		_dodge_direction = _dodge_direction.normalized()
	_dodge_time_remaining = dodge_duration
	_dodge_cooldown_remaining = dodge_duration + dodge_cooldown
	_set_locomotion_state(LocomotionState.DODGING)


func _update_dodge(delta: float) -> void:
	_dodge_time_remaining = maxf(_dodge_time_remaining - delta, 0.0)
	velocity.x = _dodge_direction.x * dodge_speed
	velocity.z = _dodge_direction.z * dodge_speed
	_rotate_toward(_dodge_direction, delta)


func _rotate_toward(
	direction: Vector3,
	delta: float,
	speed_multiplier: float = 1.0,
	base_rotation_speed: float = -1.0
) -> void:
	var target_yaw := atan2(-direction.x, -direction.z)
	var selected_rotation_speed := (
		base_rotation_speed
		if base_rotation_speed >= 0.0
		else rotation_speed
	)
	var effective_rotation_speed := selected_rotation_speed * maxf(speed_multiplier, 0.0)
	if visual_root != null:
		visual_root.rotation.y = lerp_angle(
			visual_root.rotation.y,
			target_yaw - global_rotation.y,
			1.0 - exp(-effective_rotation_speed * delta)
		)
	else:
		rotation.y = lerp_angle(rotation.y, target_yaw, 1.0 - exp(-effective_rotation_speed * delta))


func get_facing_direction() -> Vector3:
	var facing := -visual_root.global_basis.z if visual_root != null else -global_basis.z
	facing.y = 0.0
	return facing.normalized()


func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		var gravity_multiplier := (
			rise_gravity_multiplier
			if velocity.y > 0.0
			else fall_gravity_multiplier
		)
		velocity.y = maxf(
			velocity.y - _gravity * gravity_multiplier * delta,
			-max_fall_speed
		)
	elif velocity.y <= 0.0:
		velocity.y = -0.5


func _sync_surface_state() -> void:
	if locomotion_state == LocomotionState.DODGING:
		return
	var surface_state := LocomotionState.GROUNDED if is_on_floor() else LocomotionState.AIRBORNE
	_set_locomotion_state(surface_state)


func _resolve_post_move_state() -> void:
	if locomotion_state == LocomotionState.DODGING and _dodge_time_remaining > 0.0:
		return
	var resolved_state := LocomotionState.GROUNDED if is_on_floor() else LocomotionState.AIRBORNE
	if resolved_state == LocomotionState.AIRBORNE:
		_interrupt_ground_movement(false)
	_set_locomotion_state(resolved_state)


func _update_gait_intent(movement_direction: Vector3, delta: float) -> void:
	if not Input.is_action_pressed("sprint"):
		_reset_sprint_to_walk()
		return
	if movement_direction.is_zero_approx():
		# A brief stop or airborne no-input interval preserves eligibility. The
		# grounded STOPPING path resets only after the character genuinely idles.
		return
	if current_gait == Gait.WALK:
		_set_gait(Gait.RUN)
	if current_gait == Gait.RUN:
		_sprint_hold_time += delta
		if _sprint_hold_time >= sprint_activation_delay:
			if debug_gait_phase_changes:
				print("Sprint timer: eligible")
			_set_gait(Gait.SPRINT)


func _get_current_gait_speed() -> float:
	match current_gait:
		Gait.WALK:
			return walk_speed
		Gait.SPRINT:
			return sprint_speed
		_:
			return run_speed


func _interrupt_ground_movement(reset_gait: bool) -> void:
	if reset_gait:
		_reset_sprint_to_walk()
	_set_ground_movement_phase(GroundMovementPhase.IDLE)


func _reset_sprint_to_walk() -> void:
	_sprint_hold_time = 0.0
	_set_gait(Gait.WALK)


func _set_gait(next_gait: Gait) -> void:
	if current_gait == next_gait:
		return
	var previous_gait := current_gait
	current_gait = next_gait
	if debug_gait_phase_changes:
		print("Gait: %s -> %s" % [Gait.keys()[previous_gait], Gait.keys()[next_gait]])
	if next_gait == Gait.SPRINT:
		sprint_started.emit()
	elif previous_gait == Gait.SPRINT:
		sprint_ended.emit()


func _set_ground_movement_phase(next_phase: GroundMovementPhase) -> void:
	if ground_movement_phase == next_phase:
		return
	var previous_phase := ground_movement_phase
	ground_movement_phase = next_phase
	_movement_phase_elapsed = 0.0
	if next_phase == GroundMovementPhase.STARTING:
		_start_animation_ready = false
		_start_transition_progress = 0.0
	elif next_phase == GroundMovementPhase.STOPPING:
		_stop_animation_ready = false
	if debug_gait_phase_changes:
		print("Phase: %s -> %s" % [GroundMovementPhase.keys()[previous_phase], GroundMovementPhase.keys()[next_phase]])
	match next_phase:
		GroundMovementPhase.MOVING:
			movement_started.emit()
		GroundMovementPhase.STOPPING:
			movement_stopping.emit()
		GroundMovementPhase.IDLE:
			movement_stopped.emit()


func complete_movement_start() -> void:
	if ground_movement_phase == GroundMovementPhase.STARTING:
		_start_animation_ready = true


func update_start_transition_progress(progress: float) -> void:
	if ground_movement_phase == GroundMovementPhase.STARTING:
		_start_transition_progress = clampf(progress, 0.0, 1.0)


func _get_start_movement_scale() -> float:
	var initial_scale := (
		walk_start_initial_movement_scale
		if current_gait == Gait.WALK
		else run_start_initial_movement_scale
	)
	var full_progress := (
		walk_start_full_movement_progress
		if current_gait == Gait.WALK
		else run_start_full_movement_progress
	)
	var ramp_weight := clampf(
		_start_transition_progress / maxf(full_progress, 0.001),
		0.0,
		1.0
	)
	return lerpf(initial_scale, 1.0, ramp_weight)


func complete_movement_stop() -> void:
	if ground_movement_phase == GroundMovementPhase.STOPPING:
		_stop_animation_ready = true


func _set_locomotion_state(next_state: LocomotionState) -> void:
	if locomotion_state == next_state:
		return
	var previous_state := locomotion_state
	if debug_locomotion_transitions:
		print(
			"Locomotion: ",
			LocomotionState.keys()[locomotion_state],
			" -> ",
			LocomotionState.keys()[next_state]
		)
	locomotion_state = next_state
	if debug_gait_phase_changes:
		print(
			"Physical: %s -> %s; gait remains %s"
			% [LocomotionState.keys()[previous_state], LocomotionState.keys()[next_state], Gait.keys()[current_gait]]
		)
