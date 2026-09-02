class_name PlayerAnimationController
extends Node

const IDLE_SOURCE := "res://Characters/Player/Animations/Idle (6).fbx"
const WALK_SOURCE := "res://Characters/Player/Animations/Walking (9).fbx"
const RUN_SOURCE := "res://Characters/Player/Animations/Running (3).fbx"
const SPRINT_SOURCE := "res://Characters/Player/Animations/Fast Run.fbx"
const WALK_START_SOURCE := "res://Characters/Player/Animations/Start Walking.fbx"
const RUN_START_SOURCE := "res://Characters/Player/Animations/Idle To Sprint.fbx"
const WALK_STOP_SOURCE := "res://Characters/Player/Animations/Stop Walking.fbx"
const RUN_STOP_SOURCE := "res://Characters/Player/Animations/Run To Stop.fbx"
const JUMP_SOURCE := "res://Characters/Player/Animations/Jump (1).fbx"
const FALL_SOURCE := "res://Characters/Player/Animations/Falling Idle (1).fbx"
const SOURCE_CLIP := &"mixamo_com"
const LIBRARY_NAME := &"Locomotion"
const IDLE_NAME := &"Idle"
const WALK_NAME := &"Walk"
const RUN_NAME := &"Run"
const SPRINT_NAME := &"Sprint"
const WALK_START_NAME := &"WalkStart"
const RUN_START_NAME := &"RunStart"
const WALK_STOP_NAME := &"WalkStop"
const RUN_STOP_NAME := &"RunStop"
const JUMP_NAME := &"Jump"
const FALL_NAME := &"Fall"
const BLEND_PARAMETER := &"parameters/Locomotion/blend_position"
const PLAYBACK_PARAMETER := &"parameters/playback"
const BASE_HIPS_REST_POSITION := Vector3(0.0, 1.042749, 0.015543)

@export var actor: CharacterBody3D
@export var animation_player: AnimationPlayer
@export var animation_tree: AnimationTree
@export_category("Locomotion Blend Speeds")
@export var walk_blend_speed := 2.5
@export var run_blend_speed := 4.0
@export var sprint_blend_speed := 8.0

@export_category("Movement Start")
@export_range(0.0, 1.0, 0.01) var walk_start_clip_start := 0.12
@export_range(0.0, 1.0, 0.01) var walk_start_clip_exit := 0.32
@export_range(0.1, 3.0, 0.05) var walk_start_playback_speed := 1.15
@export_range(0.0, 0.3, 0.01) var walk_start_blend_in := 0.08
@export_range(0.0, 0.3, 0.01) var walk_start_blend_out := 0.10

@export_category("Run Start")
@export_range(0.0, 1.0, 0.01) var run_start_clip_start := 0.12
@export_range(0.0, 1.0, 0.01) var run_start_clip_exit := 0.70
@export_range(0.1, 3.0, 0.05) var run_start_playback_speed := 1.15
@export_range(0.0, 0.3, 0.01) var run_start_blend_in := 0.06
@export_range(0.0, 0.3, 0.01) var run_start_blend_out := 0.10

@export_category("Movement Stop")
@export_range(0.0, 1.0, 0.01) var walk_stop_clip_start := 0.55
@export_range(0.0, 1.0, 0.01) var walk_stop_clip_exit := 0.78
@export_range(0.1, 3.0, 0.05) var walk_stop_playback_speed := 1.10
@export_range(0.0, 0.3, 0.01) var walk_stop_blend_in := 0.06
@export_range(0.0, 0.3, 0.01) var walk_stop_blend_out := 0.08
# RunStop is the 0.04C reference behavior and intentionally remains unretimed.
@export_range(0.0, 1.0, 0.05) var run_stop_exit_progress := 0.75

@export_category("Airborne Animation")
@export_range(0.0, 1.0, 0.01) var jump_min_animation_time := 0.4
@export_range(-5.0, 0.0, 0.1) var fall_transition_velocity := -0.5
@export_range(0.0, 0.5, 0.01) var transition_blend_time := 0.15

@export_category("Debug")
@export var debug_locomotion_animation := false

var current_horizontal_speed := 0.0
var current_blend_value := 0.0
var dominant_animation := &"Idle"
var current_animation_state := &"Locomotion"
var current_start_progress := 0.0
var current_stop_progress := 0.0
var _last_dominant_animation := &""
var _state_machine_playback: AnimationNodeStateMachinePlayback
var _jump_visual_elapsed := 0.0
var _transition_visual_elapsed := 0.0

func _ready() -> void:
	if actor == null or animation_player == null or animation_tree == null:
		push_error("PlayerAnimationController is missing a required node reference.")
		set_physics_process(false)
		return
	if not _install_locomotion_library():
		set_physics_process(false)
		return
	_configure_animation_tree()

func _physics_process(delta: float) -> void:
	current_horizontal_speed = Vector2(actor.velocity.x, actor.velocity.z).length()
	current_blend_value = clampf(current_horizontal_speed, 0.0, sprint_blend_speed)
	animation_tree.set(BLEND_PARAMETER, current_blend_value)
	_update_dominant_animation()
	_update_airborne_animation_state(delta)

func _install_locomotion_library() -> bool:
	var library := AnimationLibrary.new()
	var sources := {
		IDLE_NAME: IDLE_SOURCE,
		WALK_NAME: WALK_SOURCE,
		RUN_NAME: RUN_SOURCE,
		SPRINT_NAME: SPRINT_SOURCE,
		WALK_START_NAME: WALK_START_SOURCE,
		RUN_START_NAME: RUN_START_SOURCE,
		WALK_STOP_NAME: WALK_STOP_SOURCE,
		RUN_STOP_NAME: RUN_STOP_SOURCE,
		JUMP_NAME: JUMP_SOURCE,
		FALL_NAME: FALL_SOURCE,
	}
	for animation_name: StringName in sources:
		var animation := _load_source_animation(sources[animation_name])
		if animation == null:
			push_error("Could not load locomotion animation %s from %s." % [animation_name, sources[animation_name]])
			return false
		animation.loop_mode = (
			Animation.LOOP_NONE
			if (
				animation_name == JUMP_NAME
				or animation_name == WALK_START_NAME
				or animation_name == RUN_START_NAME
				or animation_name == WALK_STOP_NAME
				or animation_name == RUN_STOP_NAME
			)
			else Animation.LOOP_LINEAR
		)
		_neutralize_root_translation(
			animation,
			animation_name == JUMP_NAME or animation_name == FALL_NAME
		)
		library.add_animation(animation_name, animation)
	if animation_player.has_animation_library(LIBRARY_NAME):
		animation_player.remove_animation_library(LIBRARY_NAME)
	animation_player.add_animation_library(LIBRARY_NAME, library)
	return true

func _load_source_animation(source_path: String) -> Animation:
	var packed := load(source_path) as PackedScene
	if packed == null:
		return null
	var source_root := packed.instantiate()
	var source_player := source_root.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if source_player == null or not source_player.has_animation(SOURCE_CLIP):
		source_root.free()
		return null
	var animation := source_player.get_animation(SOURCE_CLIP).duplicate(true) as Animation
	source_root.free()
	return animation

func _neutralize_root_translation(animation: Animation, lock_vertical: bool) -> void:
	for track_index in animation.get_track_count():
		if animation.track_get_type(track_index) != Animation.TYPE_POSITION_3D:
			continue
		if not String(animation.track_get_path(track_index)).ends_with(":mixamorig_Hips"):
			continue
		if animation.track_get_key_count(track_index) == 0:
			continue
		var reference := animation.track_get_key_value(track_index, 0) as Vector3
		for key_index in animation.track_get_key_count(track_index):
			var value := animation.track_get_key_value(track_index, key_index) as Vector3
			if lock_vertical:
				# Airborne world height belongs entirely to CharacterBody3D. Mixamo's
				# Jump/Fall clips use different absolute hip heights; blending
				# those values makes the visible body bounce above the real floor.
				value = BASE_HIPS_REST_POSITION
			else:
				value.x = reference.x
				value.z = reference.z
			animation.track_set_key_value(track_index, key_index, value)

func _configure_animation_tree() -> void:
	var blend_space := AnimationNodeBlendSpace1D.new()
	blend_space.min_space = 0.0
	blend_space.max_space = sprint_blend_speed
	blend_space.value_label = "Horizontal Speed"
	blend_space.add_blend_point(_animation_node(IDLE_NAME), 0.0, -1, IDLE_NAME)
	blend_space.add_blend_point(_animation_node(WALK_NAME), walk_blend_speed, -1, WALK_NAME)
	blend_space.add_blend_point(_animation_node(RUN_NAME), run_blend_speed, -1, RUN_NAME)
	blend_space.add_blend_point(
		_animation_node(SPRINT_NAME),
		sprint_blend_speed,
		-1,
		SPRINT_NAME
	)
	var state_machine := AnimationNodeStateMachine.new()
	state_machine.add_node("Locomotion", blend_space, Vector2(120, 120))
	state_machine.add_node("Jump", _animation_node(JUMP_NAME), Vector2(380, 40))
	state_machine.add_node("Fall", _animation_node(FALL_NAME), Vector2(640, 120))
	state_machine.add_node("WalkStart", _transition_node(WALK_START_NAME, walk_start_clip_start, walk_start_playback_speed), Vector2(100, 300))
	state_machine.add_node("RunStart", _transition_node(RUN_START_NAME, run_start_clip_start, run_start_playback_speed), Vector2(260, 300))
	state_machine.add_node("WalkStop", _transition_node(WALK_STOP_NAME, walk_stop_clip_start, walk_stop_playback_speed), Vector2(420, 300))
	state_machine.add_node("RunStop", _animation_node(RUN_STOP_NAME), Vector2(580, 300))
	_add_state_transition(state_machine, "Locomotion", "Jump")
	_add_state_transition(state_machine, "Locomotion", "Fall")
	_add_transition_state_edges(state_machine, WALK_START_NAME, walk_start_blend_in, walk_start_blend_out)
	_add_transition_state_edges(state_machine, RUN_START_NAME, run_start_blend_in, run_start_blend_out)
	_add_transition_state_edges(state_machine, WALK_STOP_NAME, walk_stop_blend_in, walk_stop_blend_out)
	_add_transition_state_edges(state_machine, RUN_STOP_NAME, transition_blend_time, transition_blend_time)
	_add_state_transition(state_machine, "Jump", "Fall")
	_add_state_transition(state_machine, "Jump", "Locomotion")
	_add_state_transition(state_machine, "Fall", "Locomotion")
	animation_tree.tree_root = state_machine
	animation_tree.active = true
	animation_tree.set(BLEND_PARAMETER, 0.0)
	animation_tree.set(&"parameters/WalkStart/TimeScale/scale", walk_start_playback_speed)
	animation_tree.set(&"parameters/RunStart/TimeScale/scale", run_start_playback_speed)
	animation_tree.set(&"parameters/WalkStop/TimeScale/scale", walk_stop_playback_speed)
	_state_machine_playback = animation_tree.get(PLAYBACK_PARAMETER) as AnimationNodeStateMachinePlayback
	_state_machine_playback.start("Locomotion")
	current_animation_state = &"Locomotion"

func _add_state_transition(
	state_machine: AnimationNodeStateMachine,
	from_state: StringName,
	to_state: StringName,
	xfade_time: float = -1.0
) -> void:
	var transition := AnimationNodeStateMachineTransition.new()
	transition.switch_mode = AnimationNodeStateMachineTransition.SWITCH_MODE_IMMEDIATE
	transition.xfade_time = transition_blend_time if xfade_time < 0.0 else xfade_time
	state_machine.add_transition(from_state, to_state, transition)

func _add_transition_state_edges(
	state_machine: AnimationNodeStateMachine,
	state_name: StringName,
	blend_in: float,
	blend_out: float
) -> void:
	_add_state_transition(state_machine, "Locomotion", state_name, blend_in)
	_add_state_transition(state_machine, state_name, "Locomotion", blend_out)
	_add_state_transition(state_machine, state_name, "Jump", blend_out)
	_add_state_transition(state_machine, state_name, "Fall", blend_out)

func _animation_node(animation_name: StringName) -> AnimationNodeAnimation:
	var node := AnimationNodeAnimation.new()
	node.resource_name = animation_name
	node.animation = StringName("%s/%s" % [LIBRARY_NAME, animation_name])
	return node

func _transition_node(
	animation_name: StringName,
	clip_start: float,
	playback_speed: float
) -> AnimationNodeBlendTree:
	var tree := AnimationNodeBlendTree.new()
	var animation_node := _animation_node(animation_name)
	var source_animation := animation_player.get_animation(
		StringName("%s/%s" % [LIBRARY_NAME, animation_name])
	)
	animation_node.start_offset = source_animation.length * clip_start
	var time_scale := AnimationNodeTimeScale.new()
	tree.add_node("Animation", animation_node, Vector2(0, 0))
	tree.add_node("TimeScale", time_scale, Vector2(220, 0))
	tree.connect_node("TimeScale", 0, "Animation")
	tree.connect_node("output", 0, "TimeScale")
	return tree

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
		print("Locomotion animation: speed=%.2f blend=%.2f dominant=%s" % [current_horizontal_speed, current_blend_value, dominant_animation])
	_last_dominant_animation = dominant_animation

func _update_airborne_animation_state(delta: float) -> void:
	if _state_machine_playback == null:
		return
	var locomotion_state: int = int(actor.get("locomotion_state"))
	if locomotion_state == EverdeepPlayer.LocomotionState.DODGING:
		# No dodge visual is wired yet; preserve the existing locomotion presentation.
		_travel_to(&"Locomotion")
		return

	if locomotion_state == EverdeepPlayer.LocomotionState.AIRBORNE:
		if current_animation_state == JUMP_NAME:
			_jump_visual_elapsed += delta
			if (
				_jump_visual_elapsed >= jump_min_animation_time
				and actor.velocity.y <= fall_transition_velocity
			):
				_travel_to(FALL_NAME)
			return
		if actor.velocity.y > 0.0:
			_begin_jump_visual()
		elif actor.velocity.y <= fall_transition_velocity:
			_travel_to(FALL_NAME)
		return

	var movement_phase: int = int(actor.get("ground_movement_phase"))
	if movement_phase == EverdeepPlayer.GroundMovementPhase.STARTING:
		var requested_start := (
			WALK_START_NAME
			if int(actor.get("current_gait")) == EverdeepPlayer.Gait.WALK
			else RUN_START_NAME
		)
		if current_animation_state != WALK_START_NAME and current_animation_state != RUN_START_NAME:
			current_start_progress = 0.0
			_travel_to(requested_start)
			return
		_transition_visual_elapsed += delta
		var start_clip_start := (
			walk_start_clip_start
			if current_animation_state == WALK_START_NAME
			else run_start_clip_start
		)
		var start_clip_exit := (
			walk_start_clip_exit
			if current_animation_state == WALK_START_NAME
			else run_start_clip_exit
		)
		var start_speed := (
			walk_start_playback_speed
			if current_animation_state == WALK_START_NAME
			else run_start_playback_speed
		)
		current_start_progress = _get_source_progress(start_clip_start, start_speed)
		actor.call(
			"update_start_transition_progress",
			inverse_lerp(start_clip_start, start_clip_exit, current_start_progress)
		)
		if current_start_progress >= start_clip_exit:
			actor.call("complete_movement_start")
		return
	if movement_phase == EverdeepPlayer.GroundMovementPhase.STOPPING:
		var requested_stop := (
			WALK_STOP_NAME
			if int(actor.get("current_gait")) == EverdeepPlayer.Gait.WALK
			else RUN_STOP_NAME
		)
		if current_animation_state != WALK_STOP_NAME and current_animation_state != RUN_STOP_NAME:
			current_stop_progress = 0.0
			_travel_to(requested_stop)
			return
		_transition_visual_elapsed += delta
		current_stop_progress = (
			_get_source_progress(walk_stop_clip_start, walk_stop_playback_speed)
			if current_animation_state == WALK_STOP_NAME
			else _get_current_normalized_progress()
		)
		var stop_exit_progress := walk_stop_clip_exit if current_animation_state == WALK_STOP_NAME else run_stop_exit_progress
		if current_stop_progress >= stop_exit_progress:
			actor.call("complete_movement_stop")
		return

	# Landing presentation is intentionally disabled. Ground contact returns
	# directly to the actual-speed locomotion blend without playing a recovery clip.
	_travel_to(&"Locomotion")

func _get_current_normalized_progress() -> float:
	var animation_length := _state_machine_playback.get_current_length()
	if animation_length <= 0.0:
		return 1.0
	return _state_machine_playback.get_current_play_position() / animation_length

func _get_source_progress(clip_start: float, playback_speed: float) -> float:
	var source_length := _get_transition_source_length(current_animation_state)
	if source_length <= 0.0:
		return 1.0
	return clip_start + (_transition_visual_elapsed * playback_speed / source_length)

func _get_transition_source_length(state_name: StringName) -> float:
	var animation_name := state_name
	return animation_player.get_animation(
		StringName("%s/%s" % [LIBRARY_NAME, animation_name])
	).length

func _begin_jump_visual() -> void:
	_jump_visual_elapsed = 0.0
	_travel_to(JUMP_NAME)

func _travel_to(next_state: StringName) -> void:
	if next_state == current_animation_state:
		return
	if debug_locomotion_animation:
		print(
			"Animation: %s -> %s velocity_y=%.2f jump_time=%.2f speed=%.2f"
			% [current_animation_state, next_state, actor.velocity.y, _jump_visual_elapsed, current_horizontal_speed]
		)
	_state_machine_playback.travel(next_state)
	current_animation_state = next_state
	_transition_visual_elapsed = 0.0
