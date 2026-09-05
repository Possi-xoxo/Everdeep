extends Node
const State = preload("res://Characters/Player/V2/player_animation_state.gd")
const CLIPS := {
	"Idle": &"IDL_IDLE_B", "Walk": &"LOC_WALKING",
	"Run": &"LOC_RUNNING_FOWARD_A", "Sprint": &"LOC_SPRINT_FORWARD",
	"JumpStanding": &"AIR_STANDING_JUMP_(2)", "JumpMoving": &"AIR_RUNNING_JUMP",
	"Fall": &"AIR_FALLING_IDLE", "Land": &"AIR_FALLING_TO_LANDING",
}
@export_category("Gait Crossfades (seconds)")
@export var idle_to_walk_blend: float = 0.15
@export var walk_to_run_blend: float = 0.18
@export var run_to_sprint_blend: float = 0.20
@export var sprint_to_run_blend: float = 0.18
@export var run_to_walk_blend: float = 0.18
@export var walk_to_idle_blend: float = 0.20
@export_category("Airborne")
@export var standing_jump_speed_threshold: float = 0.30
@export var jump_blend_in: float = 0.08
@export var jump_to_fall_blend: float = 0.12
@export var apex_velocity_threshold: float = -0.5
@export var fall_min_air_time: float = 0.12
@export_category("Contact Land")
@export_range(0.0, 1.0, 0.01) var land_clip_start: float = 0.7
@export_range(0.0, 1.0, 0.01) var land_exit_progress: float = 0.90
@export var land_blend_in: float = 0.1
@export var land_blend_out: float = 0.12
@export var land_min_impact_time: float = 0.08
var current_state: StringName = &"Locomotion"
var landing_count: int = 0
var gait_blend: float = 0.0
var _impact_time: float = 0.0
var _has_ground_contact: bool = false
var _episode_visible: bool = false
var _playback: AnimationNodeStateMachinePlayback
@onready var motor = get_parent()
@onready var rig: Node3D = $"../VisualRoot/MasterRig"
@onready var player: AnimationPlayer = $"../VisualRoot/MasterRig/AnimationPlayer"
@onready var tree: AnimationTree = $"../AnimationTree"

func _ready() -> void:
	if not _prepare_library():
		set_physics_process(false)
		return
	_build_tree()

func _prepare_library() -> bool:
	for clip: StringName in CLIPS.values():
		if not player.has_animation(clip):
			push_error("V2 missing canonical action: " + clip)
			return false
	# Each V2 instance owns its runtime library; never edit imported shared data.
	for library_name in player.get_animation_library_list():
		var library := player.get_animation_library(library_name).duplicate(true) as AnimationLibrary
		player.remove_animation_library(library_name)
		player.add_animation_library(library_name, library)
	var idle := player.get_animation(CLIPS.Idle)
	var reference := Vector3.ZERO
	for track in idle.get_track_count():
		if idle.track_get_type(track) == Animation.TYPE_POSITION_3D and String(idle.track_get_path(track)).ends_with(":mixamorig_Hips"):
			reference = idle.track_get_key_value(track, 0)
	for state: String in CLIPS:
		var clip := player.get_animation(CLIPS[state])
		var airborne := state in ["JumpStanding", "JumpMoving", "Fall", "Land"]
		clip.loop_mode = Animation.LOOP_NONE if state in ["JumpStanding", "JumpMoving", "Land"] else Animation.LOOP_LINEAR
		# This Blender rig uses local Z for vertical; local X/Y are horizontal.
		for track in clip.get_track_count():
			if clip.track_get_type(track) != Animation.TYPE_POSITION_3D or not String(clip.track_get_path(track)).ends_with(":mixamorig_Hips"):
				continue
			for key in clip.track_get_key_count(track):
				var value: Vector3 = clip.track_get_key_value(track, key)
				value.x = reference.x
				value.y = reference.y
				if airborne:
					value.z = reference.z
				clip.track_set_key_value(track, key, value)
	return true

func _clip(state: String) -> AnimationNodeAnimation:
	var node := AnimationNodeAnimation.new()
	node.animation = CLIPS[state]
	if state == "Land":
		node.start_offset = player.get_animation(CLIPS.Land).length * land_clip_start
	return node

func _build_tree() -> void:
	var locomotion := AnimationNodeBlendSpace1D.new()
	locomotion.min_space = 0.0
	locomotion.max_space = 3.0
	locomotion.sync = true
	for index in 4:
		var gait_name: String = ["Idle", "Walk", "Run", "Sprint"][index]
		locomotion.add_blend_point(_clip(gait_name), float(index), -1, StringName(gait_name))
	var machine := AnimationNodeStateMachine.new()
	machine.add_node(&"Locomotion", locomotion)
	for state in ["JumpStanding", "JumpMoving", "Fall", "Land"]:
		machine.add_node(state, _clip(state))
	# Direct edges prevent travel() routing through unrelated one-shot states.
	for from in ["Locomotion", "JumpStanding", "JumpMoving", "Fall", "Land"]:
		for to in ["Locomotion", "JumpStanding", "JumpMoving", "Fall", "Land"]:
			if from == to:
				continue
			var transition := AnimationNodeStateMachineTransition.new()
			transition.xfade_time = land_blend_out if to == "Locomotion" else (land_blend_in if to == "Land" else (jump_to_fall_blend if to == "Fall" else jump_blend_in))
			machine.add_transition(from, to, transition)
	tree.root_node = tree.get_path_to(rig)
	tree.anim_player = tree.get_path_to(player)
	tree.tree_root = machine
	tree.active = true
	_playback = tree.get("parameters/playback")
	_playback.start(&"Locomotion")

func _physics_process(delta: float) -> void:
	if _playback == null:
		return
	var s = motor.animation_state
	_update_gait(s, delta)
	if s.jump_started:
		_episode_visible = true
		_enter(&"JumpStanding" if s.takeoff_speed < standing_jump_speed_threshold else &"JumpMoving")
	elif s.is_airborne:
		if s.vertical_velocity <= apex_velocity_threshold and (current_state in [&"JumpStanding", &"JumpMoving"] or s.air_time >= fall_min_air_time):
			_episode_visible = true
			_enter(&"Fall")
	elif s.is_grounded and not s.was_grounded:
		if _has_ground_contact and _episode_visible:
			landing_count += 1
			_impact_time = 0.0
			_enter(&"Land")
		else:
			_enter(&"Locomotion")
		_episode_visible = false
	if s.is_grounded:
		_has_ground_contact = true
	if current_state == &"Land":
		_impact_time += delta
		var progress := land_clip_start + _impact_time / player.get_animation(CLIPS.Land).length
		if _impact_time >= land_min_impact_time and (s.move_input_magnitude > 0.01 or progress >= land_exit_progress):
			_enter(&"Locomotion")

func _update_gait(s, delta: float) -> void:
	var target: float = float(s.gait + 1) if s.horizontal_speed > 0.10 or s.move_input_magnitude > 0.01 else 0.0
	var duration: float
	if target > gait_blend:
		duration = idle_to_walk_blend if gait_blend < 1.0 else (walk_to_run_blend if gait_blend < 2.0 else run_to_sprint_blend)
	else:
		duration = sprint_to_run_blend if gait_blend > 2.0 else (run_to_walk_blend if gait_blend > 1.0 else walk_to_idle_blend)
	gait_blend = move_toward(gait_blend, target, delta / maxf(duration, 0.001))
	tree.set("parameters/Locomotion/blend_position", gait_blend)

func _enter(next: StringName) -> void:
	if current_state == next:
		return
	current_state = next
	_playback.travel(next)

func presentation_label() -> String:
	if current_state == &"Locomotion":
		return ["IDLE", "WALK", "RUN", "SPRINT"][clampi(roundi(gait_blend), 0, 3)]
	return {&"JumpStanding": "JUMP_STANDING", &"JumpMoving": "JUMP_MOVING", &"Fall": "FALL", &"Land": "LAND"}.get(current_state, String(current_state))
