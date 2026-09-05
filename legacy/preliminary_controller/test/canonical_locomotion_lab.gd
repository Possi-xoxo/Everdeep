extends CharacterBody3D

const IDLE_ANIMATION := &"Idle"
const WALK_ANIMATION := &"Walk Forward"
const RUN_ANIMATION := &"Run Forward"
const JUMP_ANIMATION := &"Jump"
const LOCOMOTION_STATE := &"Locomotion"
const JUMP_STATE := &"Jump"
const BLEND_PARAMETER := &"parameters/Locomotion/blend_position"
const PLAYBACK_PARAMETER := &"parameters/playback"

@export_category("Movement")
@export_range(0.1, 10.0, 0.1) var walk_speed := 3.0
@export_range(0.1, 15.0, 0.1) var run_speed := 5.0
@export_range(0.1, 100.0, 0.1) var ground_acceleration := 22.0
@export_range(0.1, 100.0, 0.1) var ground_deceleration := 30.0
@export_range(0.1, 30.0, 0.1) var rotation_speed := 12.0
@export_range(0.1, 20.0, 0.1) var jump_velocity := 7.0
@export_range(0.1, 5.0, 0.1) var gravity_multiplier := 2.0
@export_range(0.0, 1.0, 0.05) var air_control := 0.35

@export_category("Camera")
@export_range(0.01, 0.02, 0.0005) var mouse_sensitivity := 0.003
@export_range(-89.0, 0.0, 1.0) var minimum_pitch_degrees := -55.0
@export_range(0.0, 89.0, 1.0) var maximum_pitch_degrees := 35.0

@onready var visual_root: Node3D = $VisualRoot
@onready var canonical_character: Node3D = $VisualRoot/CanonicalCharacter
@onready var animation_player: AnimationPlayer = $VisualRoot/CanonicalCharacter/AnimationPlayer
@onready var animation_tree: AnimationTree = $AnimationTree
@onready var yaw_pivot: Node3D = $CameraRig/YawPivot
@onready var pitch_pivot: Node3D = $CameraRig/YawPivot/PitchPivot
@onready var camera: Camera3D = $CameraRig/YawPivot/PitchPivot/SpringArm3D/Camera3D
@onready var debug_label: Label = $CanvasLayer/DebugPanel/MarginContainer/DebugLabel

var _gravity := float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))
var _state_machine_playback: AnimationNodeStateMachinePlayback
var _current_animation_state := LOCOMOTION_STATE
var _jump_requested := false
var _intentional_jump_active := false
var _current_input_mode := &"WALK"
var _blend_position := 0.0
var _dominant_clip := IDLE_ANIMATION


func _ready() -> void:
	floor_snap_length = 0.3
	floor_stop_on_slope = true
	_configure_animation_tree()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _exit_tree() -> void:
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		yaw_pivot.rotate_y(-event.relative.x * mouse_sensitivity)
		pitch_pivot.rotation.x = clampf(
			pitch_pivot.rotation.x - event.relative.y * mouse_sensitivity,
			deg_to_rad(minimum_pitch_degrees),
			deg_to_rad(maximum_pitch_degrees)
		)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		elif event.keycode == KEY_SPACE:
			_jump_requested = true


func _physics_process(delta: float) -> void:
	var input_direction := _get_camera_relative_input()
	var run_requested := Input.is_physical_key_pressed(KEY_SHIFT)
	_current_input_mode = &"RUN" if run_requested else &"WALK"
	var target_speed := run_speed if run_requested else walk_speed
	var horizontal_velocity := Vector3(velocity.x, 0.0, velocity.z)

	if is_on_floor():
		if _jump_requested:
			velocity.y = jump_velocity
			_intentional_jump_active = true
			_travel_to(JUMP_STATE)
		if input_direction.is_zero_approx():
			horizontal_velocity = horizontal_velocity.move_toward(Vector3.ZERO, ground_deceleration * delta)
		else:
			horizontal_velocity = horizontal_velocity.move_toward(
				input_direction * target_speed,
				ground_acceleration * delta
			)
	else:
		velocity.y -= _gravity * gravity_multiplier * delta
		if not input_direction.is_zero_approx():
			horizontal_velocity = horizontal_velocity.move_toward(
				input_direction * target_speed,
				ground_acceleration * air_control * delta
			)

	_jump_requested = false
	velocity.x = horizontal_velocity.x
	velocity.z = horizontal_velocity.z
	if not input_direction.is_zero_approx():
		_rotate_visual_toward(input_direction, delta)

	move_and_slide()
	if _intentional_jump_active and is_on_floor():
		_intentional_jump_active = false
		_travel_to(LOCOMOTION_STATE)

	_update_animation_blend()
	_update_debug_panel()


func _get_camera_relative_input() -> Vector3:
	var input_2d := Vector2(
		float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)),
		float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W))
	).limit_length(1.0)
	if input_2d.is_zero_approx():
		return Vector3.ZERO
	var camera_forward := -camera.global_basis.z
	var camera_right := camera.global_basis.x
	camera_forward.y = 0.0
	camera_right.y = 0.0
	camera_forward = camera_forward.normalized()
	camera_right = camera_right.normalized()
	return (camera_right * input_2d.x + camera_forward * -input_2d.y).normalized()


func _rotate_visual_toward(direction: Vector3, delta: float) -> void:
	# The canonical Blender export faces +Z. Correct presentation in the wrapper;
	# movement math remains conventional camera-relative world movement.
	var target_yaw := atan2(direction.x, direction.z)
	visual_root.global_rotation.y = lerp_angle(
		visual_root.global_rotation.y,
		target_yaw,
		1.0 - exp(-rotation_speed * delta)
	)


func _configure_animation_tree() -> void:
	for loop_name in [IDLE_ANIMATION, WALK_ANIMATION, RUN_ANIMATION]:
		animation_player.get_animation(loop_name).loop_mode = Animation.LOOP_LINEAR
	animation_player.get_animation(JUMP_ANIMATION).loop_mode = Animation.LOOP_NONE

	var locomotion := AnimationNodeBlendSpace1D.new()
	locomotion.min_space = 0.0
	locomotion.max_space = run_speed
	locomotion.value_label = "Actual Horizontal Speed"
	locomotion.add_blend_point(_animation_node(IDLE_ANIMATION), 0.0, -1, IDLE_ANIMATION)
	locomotion.add_blend_point(_animation_node(WALK_ANIMATION), walk_speed, -1, WALK_ANIMATION)
	locomotion.add_blend_point(_animation_node(RUN_ANIMATION), run_speed, -1, RUN_ANIMATION)

	var state_machine := AnimationNodeStateMachine.new()
	state_machine.add_node(LOCOMOTION_STATE, locomotion, Vector2(120, 120))
	state_machine.add_node(JUMP_STATE, _animation_node(JUMP_ANIMATION), Vector2(420, 120))
	_add_transition(state_machine, LOCOMOTION_STATE, JUMP_STATE)
	_add_transition(state_machine, JUMP_STATE, LOCOMOTION_STATE)

	animation_tree.anim_player = animation_tree.get_path_to(animation_player)
	animation_tree.tree_root = state_machine
	animation_tree.active = true
	animation_tree.set(BLEND_PARAMETER, 0.0)
	_state_machine_playback = animation_tree.get(PLAYBACK_PARAMETER) as AnimationNodeStateMachinePlayback
	_state_machine_playback.start(LOCOMOTION_STATE)


func _animation_node(animation_name: StringName) -> AnimationNodeAnimation:
	var node := AnimationNodeAnimation.new()
	node.animation = animation_name
	return node


func _add_transition(machine: AnimationNodeStateMachine, from: StringName, to: StringName) -> void:
	var transition := AnimationNodeStateMachineTransition.new()
	transition.switch_mode = AnimationNodeStateMachineTransition.SWITCH_MODE_IMMEDIATE
	transition.xfade_time = 0.15
	machine.add_transition(from, to, transition)


func _travel_to(next_state: StringName) -> void:
	if _state_machine_playback == null or next_state == _current_animation_state:
		return
	_state_machine_playback.travel(next_state)
	_current_animation_state = next_state


func _update_animation_blend() -> void:
	_blend_position = clampf(Vector2(velocity.x, velocity.z).length(), 0.0, run_speed)
	animation_tree.set(BLEND_PARAMETER, _blend_position)
	if _blend_position < walk_speed * 0.5:
		_dominant_clip = IDLE_ANIMATION
	elif _blend_position < (walk_speed + run_speed) * 0.5:
		_dominant_clip = WALK_ANIMATION
	else:
		_dominant_clip = RUN_ANIMATION


func _update_debug_panel() -> void:
	debug_label.text = (
		"Canonical Locomotion Lab\n\n"
		+ "Animation State: %s\n" % _current_animation_state
		+ "Dominant Clip: %s\n" % (_dominant_clip if _current_animation_state == LOCOMOTION_STATE else JUMP_ANIMATION)
		+ "Horizontal Speed: %.2f m/s\n" % Vector2(velocity.x, velocity.z).length()
		+ "Blend Position: %.2f\n" % _blend_position
		+ "Grounded: %s\n" % ["TRUE" if is_on_floor() else "FALSE"]
		+ "Current Input Mode: %s\n\n" % _current_input_mode
		+ "WASD: Move   Shift: Run   Space: Jump\n"
		+ "Mouse: Camera   Esc: Release   Click: Capture"
	)
