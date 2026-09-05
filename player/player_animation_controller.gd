class_name PlayerAnimationController
extends Node

const IDLE_NAME := &"IDL_IDLE_A"
const WALK_NAME := &"LOC_WALKING"
const RUN_NAME := &"LOC_RUNNING_FOWARD_A"
const SPRINT_NAME := &"LOC_SPRINT_FORWARD"
const JUMP_NAME := &"AIR_STANDING_JUMP_(2)"
const FALL_NAME := &"AIR_FALLING_IDLE"
const LAND_NAME := &"AIR_FALLING_TO_LANDING"
const BLEND_PARAMETER := &"parameters/Locomotion/blend_position"
const PLAYBACK_PARAMETER := &"parameters/playback"

@export var actor: CharacterBody3D
@export var canonical_model: Node3D
@export var animation_player: AnimationPlayer
@export var animation_tree: AnimationTree
@export_category("Locomotion Blend Speeds")
@export var walk_blend_speed := 2.5
@export var run_blend_speed := 4.0
@export var sprint_blend_speed := 8.0
@export var gait_transition_blend_rate := 28.0
@export_category("Airborne Animation")
@export_range(0.0, 1.0, 0.01) var jump_clip_start := 0.12
@export_range(0.0, 1.0, 0.01) var jump_min_animation_time := 0.28
@export_range(0.1, 2.0, 0.05) var jump_playback_speed := 1.0
@export_range(-5.0, 0.0, 0.1) var fall_transition_velocity := -0.5
@export_range(0.0, 0.5, 0.01) var jump_blend_in := 0.10
@export_range(0.0, 0.5, 0.01) var jump_to_fall_blend := 0.12
@export_range(0.0, 1.0, 0.01) var land_clip_start := 0.9
@export_range(0.0, 1.0, 0.01) var land_exit_progress := 1
@export_range(0.1, 2.0, 0.05) var land_playback_speed := 1.50
@export_range(0.0, 0.5, 0.01) var land_blend_in := 0.08
@export_range(0.0, 0.5, 0.01) var land_blend_out := 0.5
@export_category("Debug")
@export var debug_locomotion_animation := false
@export var debug_airborne_animation := false

var current_horizontal_speed := 0.0
var current_blend_value := 0.0
var dominant_animation := IDLE_NAME
var current_animation_state := &"Locomotion"
var _last_dominant_animation := &""
var _state_machine_playback: AnimationNodeStateMachinePlayback
var _jump_visual_elapsed := 0.0
var _land_visual_elapsed := 0.0
var landing_trigger_count := 0
var _previous_airborne := false
var _landing_armed := false
var _has_been_grounded := false
var _last_debug_physical_state := &""
var _last_debug_animation_state := &""

func _ready() -> void:
	if actor == null or canonical_model == null or animation_player == null or animation_tree == null:
		push_error("PlayerAnimationController is missing a required canonical-rig node reference.")
		set_physics_process(false)
		return
	if not _prepare_master_actions():
		set_physics_process(false)
		return
	_configure_animation_tree()

func _physics_process(delta: float) -> void:
	current_horizontal_speed = Vector2(actor.velocity.x, actor.velocity.z).length()
	var target_blend := _get_gait_blend_target()
	current_blend_value = move_toward(
		current_blend_value,
		target_blend,
		gait_transition_blend_rate * delta
	)
	animation_tree.set(BLEND_PARAMETER, current_blend_value)
	_update_dominant_animation()
	_fulfill_legacy_movement_phase_contract()
	_update_airborne_animation_state(delta)

func _prepare_master_actions() -> bool:
	var required := [IDLE_NAME, WALK_NAME, RUN_NAME, SPRINT_NAME, JUMP_NAME, FALL_NAME, LAND_NAME]
	for animation_name: StringName in required:
		if not animation_player.has_animation(animation_name):
			push_error("Canonical master rig is missing required action: %s" % animation_name)
			return false
	var idle_reference := _get_first_hips_position(animation_player.get_animation(IDLE_NAME))
	for animation_name: StringName in required:
		var source := animation_player.get_animation(animation_name)
		var animation := source.duplicate(true) as Animation
		animation.loop_mode = (
			Animation.LOOP_NONE
			if animation_name == JUMP_NAME or animation_name == LAND_NAME
			else Animation.LOOP_LINEAR
		)
		_normalize_hips_translation(
			animation,
			idle_reference,
			animation_name == JUMP_NAME or animation_name == FALL_NAME or animation_name == LAND_NAME
		)
		_replace_animation(animation_name, animation)
	return true

func _replace_animation(animation_name: StringName, animation: Animation) -> void:
	for library_name: StringName in animation_player.get_animation_library_list():
		var library := animation_player.get_animation_library(library_name)
		if library.has_animation(animation_name):
			library.remove_animation(animation_name)
			library.add_animation(animation_name, animation)
			return

func _get_first_hips_position(animation: Animation) -> Vector3:
	for track_index in animation.get_track_count():
		if (
			animation.track_get_type(track_index) == Animation.TYPE_POSITION_3D
			and String(animation.track_get_path(track_index)).ends_with(":mixamorig_Hips")
			and animation.track_get_key_count(track_index) > 0
		):
			return animation.track_get_key_value(track_index, 0) as Vector3
	return Vector3.ZERO

func _normalize_hips_translation(animation: Animation, reference: Vector3, lock_vertical: bool) -> void:
	for track_index in animation.get_track_count():
		if animation.track_get_type(track_index) != Animation.TYPE_POSITION_3D:
			continue
		if not String(animation.track_get_path(track_index)).ends_with(":mixamorig_Hips"):
			continue
		if animation.track_get_key_count(track_index) == 0:
			continue
		var first := animation.track_get_key_value(track_index, 0) as Vector3
		for key_index in animation.track_get_key_count(track_index):
			var value := animation.track_get_key_value(track_index, key_index) as Vector3
			value.x = reference.x
			value.y = reference.y
			value.z = reference.z if lock_vertical else reference.z + (value.z - first.z)
			animation.track_set_key_value(track_index, key_index, value)

func _configure_animation_tree() -> void:
	animation_tree.root_node = animation_tree.get_path_to(canonical_model)
	animation_tree.anim_player = animation_tree.get_path_to(animation_player)
	var blend_space := AnimationNodeBlendSpace1D.new()
	blend_space.min_space = 0.0
	blend_space.max_space = sprint_blend_speed
	blend_space.value_label = "Selected Gait"
	blend_space.add_blend_point(_animation_node(IDLE_NAME), 0.0, -1, &"Idle")
	blend_space.add_blend_point(_animation_node(WALK_NAME), walk_blend_speed, -1, &"Walk")
	blend_space.add_blend_point(_animation_node(RUN_NAME), run_blend_speed, -1, &"Run")
	blend_space.add_blend_point(_animation_node(SPRINT_NAME), sprint_blend_speed, -1, &"Sprint")
	var state_machine := AnimationNodeStateMachine.new()
	state_machine.add_node("Locomotion", blend_space, Vector2(100, 120))
	state_machine.add_node("Jump", _windowed_animation_node(JUMP_NAME, jump_clip_start, jump_playback_speed), Vector2(340, 20))
	state_machine.add_node("Fall", _animation_node(FALL_NAME), Vector2(580, 80))
	state_machine.add_node("Land", _windowed_animation_node(LAND_NAME, land_clip_start, land_playback_speed), Vector2(820, 120))
	_add_transition(state_machine, &"Locomotion", &"Jump", jump_blend_in)
	_add_transition(state_machine, &"Locomotion", &"Fall", jump_to_fall_blend)
	_add_transition(state_machine, &"Jump", &"Fall", jump_to_fall_blend)
	_add_transition(state_machine, &"Jump", &"Land", land_blend_in)
	_add_transition(state_machine, &"Fall", &"Land", land_blend_in)
	_add_transition(state_machine, &"Land", &"Locomotion", land_blend_out)
	_add_transition(state_machine, &"Land", &"Jump", jump_blend_in)
	_add_transition(state_machine, &"Land", &"Fall", jump_to_fall_blend)
	animation_tree.tree_root = state_machine
	animation_tree.active = true
	animation_tree.set(BLEND_PARAMETER, 0.0)
	animation_tree.set(&"parameters/Jump/TimeScale/scale", jump_playback_speed)
	animation_tree.set(&"parameters/Land/TimeScale/scale", land_playback_speed)
	_state_machine_playback = animation_tree.get(PLAYBACK_PARAMETER) as AnimationNodeStateMachinePlayback
	_state_machine_playback.start(&"Locomotion")
	current_animation_state = &"Locomotion"

func _add_transition(machine: AnimationNodeStateMachine, from: StringName, to: StringName, blend_time: float) -> void:
	var transition := AnimationNodeStateMachineTransition.new()
	transition.switch_mode = AnimationNodeStateMachineTransition.SWITCH_MODE_IMMEDIATE
	transition.xfade_time = blend_time
	machine.add_transition(from, to, transition)

func _animation_node(animation_name: StringName) -> AnimationNodeAnimation:
	var node := AnimationNodeAnimation.new()
	node.resource_name = animation_name
	node.animation = animation_name
	return node

func _windowed_animation_node(
	animation_name: StringName,
	clip_start: float,
	_playback_speed: float
) -> AnimationNodeBlendTree:
	var tree := AnimationNodeBlendTree.new()
	var animation_node := _animation_node(animation_name)
	animation_node.start_offset = animation_player.get_animation(animation_name).length * clip_start
	var time_scale := AnimationNodeTimeScale.new()
	tree.add_node("Animation", animation_node, Vector2(0, 0))
	tree.add_node("TimeScale", time_scale, Vector2(220, 0))
	tree.connect_node("TimeScale", 0, "Animation")
	tree.connect_node("output", 0, "TimeScale")
	return tree

func _get_gait_blend_target() -> float:
	if current_horizontal_speed <= 0.1:
		return 0.0
	match int(actor.get("current_gait")):
		EverdeepPlayer.Gait.WALK:
			return walk_blend_speed
		EverdeepPlayer.Gait.SPRINT:
			return sprint_blend_speed
		_:
			return run_blend_speed

func _update_dominant_animation() -> void:
	if current_blend_value < walk_blend_speed * 0.5:
		dominant_animation = IDLE_NAME
	elif current_blend_value < (walk_blend_speed + run_blend_speed) * 0.5:
		dominant_animation = WALK_NAME
	elif current_blend_value < (run_blend_speed + sprint_blend_speed) * 0.5:
		dominant_animation = RUN_NAME
	else:
		dominant_animation = SPRINT_NAME
	if debug_locomotion_animation and dominant_animation != _last_dominant_animation:
		print("Master locomotion: speed=%.2f blend=%.2f action=%s" % [current_horizontal_speed, current_blend_value, dominant_animation])
	_last_dominant_animation = dominant_animation

func _fulfill_legacy_movement_phase_contract() -> void:
	var phase := int(actor.get("ground_movement_phase"))
	if phase == EverdeepPlayer.GroundMovementPhase.STARTING:
		actor.call("update_start_transition_progress", 1.0)
		actor.call("complete_movement_start")
	elif phase == EverdeepPlayer.GroundMovementPhase.STOPPING:
		actor.call("complete_movement_stop")

func _update_airborne_animation_state(delta: float) -> void:
	if _state_machine_playback == null:
		return
	var state := int(actor.get("locomotion_state"))
	var airborne := state == EverdeepPlayer.LocomotionState.AIRBORNE
	_debug_airborne_state(airborne)
	if state == EverdeepPlayer.LocomotionState.DODGING:
		_previous_airborne = false
		_landing_armed = false
		_travel_to(&"Locomotion")
		return
	if airborne:
		if not _previous_airborne:
			_landing_armed = _has_been_grounded
		_previous_airborne = true
		if current_animation_state == &"Jump":
			_jump_visual_elapsed += delta
			if _jump_visual_elapsed >= jump_min_animation_time and actor.velocity.y <= fall_transition_velocity:
				_travel_to(&"Fall")
		elif actor.velocity.y > 0.0:
			_jump_visual_elapsed = 0.0
			_travel_to(&"Jump")
		elif actor.velocity.y <= fall_transition_velocity:
			_travel_to(&"Fall")
		return
	if not _has_been_grounded:
		_has_been_grounded = true
		_previous_airborne = false
		_landing_armed = false
		_travel_to(&"Locomotion")
		return
	if _previous_airborne and _landing_armed:
		_landing_armed = false
		landing_trigger_count += 1
		_land_visual_elapsed = 0.0
		_travel_to(&"Land")
	_previous_airborne = false
	if current_animation_state == &"Land":
		_land_visual_elapsed += delta
		if _get_source_progress(LAND_NAME, land_clip_start, _land_visual_elapsed, land_playback_speed) >= land_exit_progress:
			_travel_to(&"Locomotion")
	else:
		_travel_to(&"Locomotion")

func _get_source_progress(
	animation_name: StringName,
	clip_start: float,
	elapsed: float,
	playback_speed: float
) -> float:
	var length := animation_player.get_animation(animation_name).length
	if length <= 0.0:
		return 1.0
	return clip_start + elapsed * playback_speed / length

func _debug_airborne_state(airborne: bool) -> void:
	if not debug_airborne_animation:
		return
	var physical_state := &"Airborne" if airborne else &"Grounded"
	if physical_state == _last_debug_physical_state and current_animation_state == _last_debug_animation_state:
		return
	print(
		"Airborne debug: physical=%s animation=%s velocity_y=%.2f jump_elapsed=%.2f land_count=%d"
		% [physical_state, current_animation_state, actor.velocity.y, _jump_visual_elapsed, landing_trigger_count]
	)
	_last_debug_physical_state = physical_state
	_last_debug_animation_state = current_animation_state

func _travel_to(next_state: StringName) -> void:
	if next_state == current_animation_state:
		return
	if debug_locomotion_animation:
		print("Master animation: %s -> %s" % [current_animation_state, next_state])
	_state_machine_playback.travel(next_state)
	current_animation_state = next_state
	if debug_airborne_animation:
		print(
			"Airborne animation: state=%s velocity_y=%.2f jump_elapsed=%.2f land_count=%d"
			% [current_animation_state, actor.velocity.y, _jump_visual_elapsed, landing_trigger_count]
		)
