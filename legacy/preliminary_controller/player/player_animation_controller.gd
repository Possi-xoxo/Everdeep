class_name PlayerAnimationController
extends Node

const IDLE_NAME := &"IDL_IDLE_A_RAW"
const WALK_NAME := &"LOC_WALKING"
const RUN_NAME := &"LOC_RUNNING_FOWARD_A"
const SPRINT_NAME := &"LOC_SPRINT_FORWARD"
const STANDING_JUMP_NAME := &"AIR_STANDING_JUMP_(2)"
const MOVING_JUMP_NAME := &"AIR_RUNNING_JUMP"
const FALL_NAME := &"AIR_FALLING_IDLE"
const LAND_NAME := &"AIR_FALLING_TO_LANDING"
const BLEND_PARAMETER := &"parameters/Locomotion/blend_position"
const PLAYBACK_PARAMETER := &"parameters/playback"

@export var actor: CharacterBody3D
@export var canonical_model: Node3D
@export var animation_player: AnimationPlayer
@export var animation_tree: AnimationTree
@export var landing_probe: ShapeCast3D
@export_category("Locomotion Blend Speeds")
@export var walk_blend_speed := 2.5
@export var run_blend_speed := 4.0
@export var sprint_blend_speed := 8.0
@export var gait_transition_blend_rate := 28.0
@export_category("Standing Jump")
@export_range(0.0, 1.0, 0.01) var standing_jump_speed_threshold := 0.30
@export_range(0.0, 1.0, 0.01) var jump_clip_start := 0.5
@export_range(0.0, 1.0, 0.01) var jump_min_animation_time := 0.28
@export_range(0.1, 2.0, 0.05) var jump_playback_speed := 1.0
@export_category("Moving Jump")
@export_range(0.0, 1.0, 0.01) var moving_jump_clip_start := 0.0
@export_range(0.0, 1.0, 0.01) var moving_jump_min_animation_time := 0.32
@export_range(0.1, 2.0, 0.05) var moving_jump_playback_speed := 1.0
@export_category("Airborne Shared")
@export_range(-5.0, 0.0, 0.1) var fall_transition_velocity := -0.5
@export_range(0.05, 1.0, 0.01) var trivial_drop_distance := 0.30
@export_range(0.0, 0.5, 0.01) var fall_animation_min_air_time := 0.12
@export_range(0.0, 5.0, 0.1) var fall_animation_min_downward_speed := 1.0
@export_range(0.0, 0.5, 0.01) var jump_blend_in := 0.10
@export_range(0.0, 0.5, 0.01) var jump_to_fall_blend := 0.5
@export_range(0.0, 1.0, 0.01) var land_clip_start := 0.5
@export_range(0.0, 1.0, 0.01) var land_clip_exit := 0.9
@export_range(0.1, 2.0, 0.05) var land_playback_speed := 1.10
@export_range(0.0, 0.25, 0.01) var land_min_impact_time := 0.08
@export_range(0.0, 0.25, 0.01) var minimum_land_air_time := 0.06
@export_range(0.0, 0.5, 0.01) var land_blend_in := 0.04
@export_range(0.0, 0.5, 0.01) var land_blend_out := 0.12
@export_category("Landing Anticipation")
@export_range(0.1, 1.0, 0.01) var landing_probe_distance := 1.40
@export_range(0.0, 1.0, 0.01) var land_prep_clip_start := 0.72
@export_range(0.0, 1.0, 0.01) var land_prep_clip_exit := 0.88
@export_range(0.1, 2.0, 0.05) var land_prep_playback_speed := 0.75
@export_range(0.0, 0.25, 0.01) var land_prep_blend := 0.06
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
enum JumpType { STANDING, MOVING }
var selected_jump_type: JumpType = JumpType.STANDING
var _land_visual_elapsed := 0.0
var _land_prep_visual_elapsed := 0.0
var _air_time := 0.0
var landing_imminent := false
var probe_ground_detected := false
var probe_ground_distance := INF
var trivial_drop := false
var jump_initiated := false
var fall_visual_committed := false
var landing_trigger_count := 0
var _previous_airborne := false
var _landing_armed := false
var _has_been_grounded := false
var _last_jump_sequence := 0
var _last_debug_physical_state := &""
var _last_debug_animation_state := &""

func _ready() -> void:
	if actor == null or canonical_model == null or animation_player == null or animation_tree == null or landing_probe == null:
		push_error("PlayerAnimationController is missing a required canonical-rig node reference.")
		set_physics_process(false)
		return
	landing_probe.target_position = Vector3.DOWN * landing_probe_distance
	_last_jump_sequence = int(actor.get("jump_sequence"))
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
	var required := [IDLE_NAME, WALK_NAME, RUN_NAME, SPRINT_NAME, STANDING_JUMP_NAME, MOVING_JUMP_NAME, FALL_NAME, LAND_NAME]
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
			if animation_name == STANDING_JUMP_NAME or animation_name == MOVING_JUMP_NAME or animation_name == LAND_NAME
			else Animation.LOOP_LINEAR
		)
		_normalize_hips_translation(
			animation,
			idle_reference,
			animation_name == STANDING_JUMP_NAME or animation_name == MOVING_JUMP_NAME or animation_name == FALL_NAME or animation_name == LAND_NAME
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
	state_machine.add_node("StandingJump", _windowed_animation_node(STANDING_JUMP_NAME, jump_clip_start, jump_playback_speed), Vector2(320, 0))
	state_machine.add_node("MovingJump", _windowed_animation_node(MOVING_JUMP_NAME, moving_jump_clip_start, moving_jump_playback_speed), Vector2(320, 100))
	state_machine.add_node("Fall", _animation_node(FALL_NAME), Vector2(580, 80))
	state_machine.add_node("LandPrep", _windowed_animation_node(LAND_NAME, land_prep_clip_start, land_prep_playback_speed), Vector2(700, 20))
	state_machine.add_node("Land", _windowed_animation_node(LAND_NAME, land_clip_start, land_playback_speed), Vector2(820, 120))
	_add_transition(state_machine, &"Locomotion", &"StandingJump", jump_blend_in)
	_add_transition(state_machine, &"Locomotion", &"MovingJump", jump_blend_in)
	_add_transition(state_machine, &"Locomotion", &"Fall", jump_to_fall_blend)
	_add_transition(state_machine, &"StandingJump", &"Fall", jump_to_fall_blend)
	_add_transition(state_machine, &"MovingJump", &"Fall", jump_to_fall_blend)
	_add_transition(state_machine, &"Fall", &"LandPrep", land_prep_blend)
	_add_transition(state_machine, &"LandPrep", &"Fall", land_prep_blend)
	_add_transition(state_machine, &"LandPrep", &"Land", land_blend_in)
	_add_transition(state_machine, &"StandingJump", &"Land", land_blend_in)
	_add_transition(state_machine, &"MovingJump", &"Land", land_blend_in)
	_add_transition(state_machine, &"Fall", &"Land", land_blend_in)
	_add_transition(state_machine, &"Land", &"Locomotion", land_blend_out)
	_add_transition(state_machine, &"Land", &"StandingJump", jump_blend_in)
	_add_transition(state_machine, &"Land", &"MovingJump", jump_blend_in)
	_add_transition(state_machine, &"Land", &"Fall", jump_to_fall_blend)
	animation_tree.tree_root = state_machine
	animation_tree.active = true
	animation_tree.set(BLEND_PARAMETER, 0.0)
	animation_tree.set(&"parameters/StandingJump/TimeScale/scale", jump_playback_speed)
	animation_tree.set(&"parameters/MovingJump/TimeScale/scale", moving_jump_playback_speed)
	animation_tree.set(&"parameters/LandPrep/TimeScale/scale", land_prep_playback_speed)
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
		landing_imminent = false
		probe_ground_detected = false
		probe_ground_distance = INF
		trivial_drop = false
		jump_initiated = false
		fall_visual_committed = false
		_previous_airborne = false
		_landing_armed = false
		_air_time = 0.0
		_travel_to(&"Locomotion")
		return
	if airborne:
		if not _previous_airborne:
			_landing_armed = _has_been_grounded
			_air_time = 0.0
			jump_initiated = (
				int(actor.get("jump_sequence")) != _last_jump_sequence
				or actor.velocity.y > 0.0
			)
			_last_jump_sequence = int(actor.get("jump_sequence"))
			fall_visual_committed = false
			if jump_initiated:
				_begin_jump_visual()
		_previous_airborne = true
		_air_time += delta
		_update_ground_probe()
		if current_animation_state == &"StandingJump" or current_animation_state == &"MovingJump":
			_jump_visual_elapsed += delta
			if _jump_visual_elapsed >= _get_selected_jump_min_time() and actor.velocity.y <= fall_transition_velocity:
				_commit_fall_visual()
		else:
			if not jump_initiated and not fall_visual_committed and _should_commit_passive_fall():
				_commit_fall_visual()
			if current_animation_state == &"Fall" or current_animation_state == &"LandPrep":
				_update_landing_anticipation(delta)
		return
	landing_imminent = false
	probe_ground_detected = false
	probe_ground_distance = INF
	trivial_drop = false
	if not _has_been_grounded:
		_has_been_grounded = true
		_previous_airborne = false
		_landing_armed = false
		_air_time = 0.0
		_travel_to(&"Locomotion")
		return
	var ground_contact_event := _previous_airborne
	var visible_airborne_event := jump_initiated or fall_visual_committed
	if ground_contact_event and _landing_armed and visible_airborne_event and _air_time >= minimum_land_air_time:
		_landing_armed = false
		landing_trigger_count += 1
		_land_visual_elapsed = 0.0
		_travel_to(&"Land")
		_debug_ground_contact(true)
	elif ground_contact_event:
		_landing_armed = false
		_travel_to(&"Locomotion")
		_debug_ground_contact(false)
	_previous_airborne = false
	jump_initiated = false
	fall_visual_committed = false
	_land_prep_visual_elapsed = 0.0
	if current_animation_state == &"Land":
		_land_visual_elapsed += delta
		var impact_read := _land_visual_elapsed >= land_min_impact_time
		var moving_exit := impact_read and _has_movement_intent()
		var idle_exit := (
			impact_read
			and _get_source_progress(LAND_NAME, land_clip_start, _land_visual_elapsed, land_playback_speed) >= land_clip_exit
		)
		if moving_exit or idle_exit:
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

func _begin_jump_visual() -> void:
	_jump_visual_elapsed = 0.0
	selected_jump_type = (
		JumpType.STANDING
		if current_horizontal_speed <= standing_jump_speed_threshold
		else JumpType.MOVING
	)
	_travel_to(&"StandingJump" if selected_jump_type == JumpType.STANDING else &"MovingJump")

func _get_selected_jump_min_time() -> float:
	return (
		jump_min_animation_time
		if selected_jump_type == JumpType.STANDING
		else moving_jump_min_animation_time
	)

func _has_movement_intent() -> bool:
	return not Input.get_vector("move_left", "move_right", "move_forward", "move_backward").is_zero_approx()

func _update_ground_probe() -> void:
	landing_probe.target_position = Vector3.DOWN * landing_probe_distance
	landing_probe.force_shapecast_update()
	probe_ground_detected = landing_probe.is_colliding()
	probe_ground_distance = INF
	if probe_ground_detected:
		for collision_index in landing_probe.get_collision_count():
			var collision_point := landing_probe.get_collision_point(collision_index)
			probe_ground_distance = minf(
				probe_ground_distance,
				maxf(actor.global_position.y - collision_point.y, 0.0)
			)
	trivial_drop = probe_ground_detected and probe_ground_distance <= trivial_drop_distance

func _should_commit_passive_fall() -> bool:
	if trivial_drop:
		return false
	var time_ready := _air_time >= fall_animation_min_air_time
	var speed_ready := -actor.velocity.y >= fall_animation_min_downward_speed
	return time_ready or speed_ready

func _commit_fall_visual() -> void:
	fall_visual_committed = true
	_travel_to(&"Fall")

func _update_landing_anticipation(delta: float) -> void:
	var descending := actor.velocity.y < 0.0
	var probe_hit := descending and probe_ground_detected
	landing_imminent = probe_hit
	if landing_imminent:
		if current_animation_state != &"LandPrep":
			_land_prep_visual_elapsed = 0.0
			animation_tree.set(&"parameters/LandPrep/TimeScale/scale", land_prep_playback_speed)
			_travel_to(&"LandPrep")
		else:
			_land_prep_visual_elapsed += delta
			if _get_source_progress(LAND_NAME, land_prep_clip_start, _land_prep_visual_elapsed, land_prep_playback_speed) >= land_prep_clip_exit:
				animation_tree.set(&"parameters/LandPrep/TimeScale/scale", 0.0)
	elif current_animation_state == &"LandPrep":
		_land_prep_visual_elapsed = 0.0
		animation_tree.set(&"parameters/LandPrep/TimeScale/scale", land_prep_playback_speed)
		if actor.velocity.y > 0.0:
			_travel_to(&"StandingJump" if selected_jump_type == JumpType.STANDING else &"MovingJump")
		else:
			_commit_fall_visual()

func _debug_ground_contact(visible_land: bool) -> void:
	if not debug_airborne_animation:
		return
	print(
		"Ground contact: visible_land=%s air_time=%.3f land_count=%d gait=%s"
		% [visible_land, _air_time, landing_trigger_count, EverdeepPlayer.Gait.keys()[int(actor.get("current_gait"))]]
	)

func _debug_airborne_state(airborne: bool) -> void:
	if not debug_airborne_animation:
		return
	var physical_state := &"Airborne" if airborne else &"Grounded"
	if physical_state == _last_debug_physical_state and current_animation_state == _last_debug_animation_state:
		return
	print(
		"Airborne debug: grounded=%s jump_initiated=%s air_time=%.2f probe_ground_distance=%s trivial_drop=%s fall_committed=%s landing_imminent=%s animation=%s velocity_y=%.2f gait=%s"
		% [not airborne, jump_initiated, _air_time, "%.2f" % probe_ground_distance if is_finite(probe_ground_distance) else "none", trivial_drop, fall_visual_committed, landing_imminent, current_animation_state, actor.velocity.y, EverdeepPlayer.Gait.keys()[int(actor.get("current_gait"))]]
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
