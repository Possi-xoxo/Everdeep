class_name EverdeepPlayer
extends CharacterBody3D

enum LocomotionState {
	GROUNDED,
	AIRBORNE,
	DODGING,
}

@export_category("Ground Movement")
@export_range(0.1, 20.0, 0.1) var walk_speed: float = 5.0
@export_range(0.1, 30.0, 0.1) var sprint_speed: float = 8.0
@export_range(0.1, 100.0, 0.1) var ground_acceleration: float = 28.0
@export_range(0.1, 100.0, 0.1) var ground_deceleration: float = 42.0
@export_range(0.1, 150.0, 0.1) var turn_acceleration: float = 70.0
@export_range(0.1, 150.0, 0.1) var lateral_damping: float = 85.0
@export_range(0.0, 1.0, 0.05) var turn_alignment_threshold: float = 0.7
@export_range(0.1, 30.0, 0.1) var ground_rotation_speed: float = 16.0

@export_category("Air Movement")
@export_range(0.1, 100.0, 0.1) var acceleration: float = 22.0
@export_range(0.1, 30.0, 0.1) var rotation_speed: float = 12.0
@export_range(0.1, 5.0, 0.05) var gravity_multiplier: float = 1.5

@export_category("Jump")
@export_range(0.1, 20.0, 0.1) var jump_velocity: float = 7.0
@export_range(0.0, 1.0, 0.05) var air_control: float = 0.4

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

var _gravity: float = float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))
var _dodge_time_remaining: float = 0.0
var _dodge_cooldown_remaining: float = 0.0
var _dodge_direction: Vector3 = Vector3.ZERO
var locomotion_state: LocomotionState = LocomotionState.AIRBORNE


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
		_set_locomotion_state(LocomotionState.AIRBORNE)

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
		var attack_velocity := combat_controller.calculate_attack_velocity(input_direction, delta)
		velocity.x = attack_velocity.x
		velocity.z = attack_velocity.z
		var attack_facing := combat_controller.get_attack_facing_direction()
		if not attack_facing.is_zero_approx():
			_rotate_toward(attack_facing, delta, combat_controller.attack_rotation_multiplier)
		return

	var movement_direction := input_direction
	var is_sprinting := (
		Input.is_action_pressed("sprint")
		and not movement_direction.is_zero_approx()
	)
	var target_speed := sprint_speed if is_sprinting else walk_speed
	var horizontal_velocity := Vector3(velocity.x, 0.0, velocity.z)
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
		_update_grounded_movement(input_direction, delta)
		return

	# No-input air movement keeps takeoff momentum; input provides reduced steering.
	if not input_direction.is_zero_approx():
		var is_sprinting := Input.is_action_pressed("sprint")
		var target_speed := sprint_speed if is_sprinting else walk_speed
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
		velocity.y -= _gravity * gravity_multiplier * delta
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
	_set_locomotion_state(resolved_state)


func _set_locomotion_state(next_state: LocomotionState) -> void:
	if locomotion_state == next_state:
		return
	if debug_locomotion_transitions:
		print(
			"Locomotion: ",
			LocomotionState.keys()[locomotion_state],
			" -> ",
			LocomotionState.keys()[next_state]
		)
	locomotion_state = next_state
