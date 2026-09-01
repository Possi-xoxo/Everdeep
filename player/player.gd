class_name EverdeepPlayer
extends CharacterBody3D

enum LocomotionState {
	GROUNDED,
	AIRBORNE,
	DODGING,
}

@export_category("Movement")
@export_range(0.1, 20.0, 0.1) var walk_speed: float = 5.0
@export_range(0.1, 30.0, 0.1) var sprint_speed: float = 8.0
@export_range(0.1, 100.0, 0.1) var acceleration: float = 22.0
@export_range(0.1, 100.0, 0.1) var deceleration: float = 28.0
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
	var movement_direction := input_direction
	var movement_multiplier := 1.0
	if is_attacking and combat_controller != null:
		movement_direction = combat_controller.get_committed_move_direction()
		movement_multiplier = combat_controller.get_movement_multiplier()
	var is_sprinting := (
		Input.is_action_pressed("sprint")
		and not movement_direction.is_zero_approx()
		and not is_attacking
	)
	var target_speed := sprint_speed if is_sprinting else walk_speed
	var target_velocity := movement_direction * target_speed * movement_multiplier
	var horizontal_velocity := Vector3(velocity.x, 0.0, velocity.z)
	var rate := acceleration if not movement_direction.is_zero_approx() else deceleration
	if is_attacking:
		rate *= maxf(movement_multiplier, 0.1)
	horizontal_velocity = horizontal_velocity.move_toward(target_velocity, rate * delta)
	velocity.x = horizontal_velocity.x
	velocity.z = horizontal_velocity.z

	if not movement_direction.is_zero_approx() and not is_attacking:
		_rotate_toward(movement_direction, delta)


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


func _rotate_toward(direction: Vector3, delta: float) -> void:
	var target_yaw := atan2(-direction.x, -direction.z)
	if visual_root != null:
		visual_root.rotation.y = lerp_angle(
			visual_root.rotation.y,
			target_yaw - global_rotation.y,
			1.0 - exp(-rotation_speed * delta)
		)
	else:
		rotation.y = lerp_angle(rotation.y, target_yaw, 1.0 - exp(-rotation_speed * delta))


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
