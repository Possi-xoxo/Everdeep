extends Node
const State = preload("res://Characters/Player/V2/player_animation_state.gd")
const Grounded = preload("res://Characters/Player/V2/player_grounded_animation_v2.gd")
@export var grounded: Resource = Grounded.new()
@export var debug_tree_playback: bool = false
@export_category("Lock-On Animation Blending")
@export_range(0,1,0.01) var lock_animation_enter_blend: float = 0.15
@export_range(0,1,0.01) var lock_animation_exit_blend: float = 0.15
@export_range(0,1,0.01) var lock_idle_to_move_blend: float = 0.15
@export_range(0,1,0.01) var lock_move_to_idle_blend: float = 0.15
@export_range(0,1,0.01) var lock_walk_to_run_blend: float = 0.20
@export_range(0,1,0.01) var lock_run_to_walk_blend: float = 0.20
@export_range(1,30,0.5) var lock_direction_blend_speed: float = 15.0
var playback_recoveries: int = 0
const CLIPS := {
	"Idle": &"IDL_IDLE_A_RAW", "Walk": &"LOC_WALKING",
	"Run": &"LOC_RUNNING_FOWARD_A", "Sprint": &"LOC_SPRINT_FORWARD",
	"JumpStanding": &"AIR_STANDING_JUMP_(2)", "JumpMoving": &"AIR_RUNNING_JUMP",
	"Fall": &"AIR_FALLING_IDLE", "Land": &"AIR_FALLING_TO_LANDING",
	"DodgeStand": &"DOD_STAND_TO_ROLL", "DodgeRun": &"DOD_RUN_TO_ROLL",
	"DodgeSprint": &"DOD_SPRINT_TO_ROLL",
	"DodgeBack": &"DPD_DODING_BACK",
}
@export_category("Gait Crossfades (seconds)")
@export var idle_to_walk_blend: float = 0.2
@export var walk_to_run_blend: float = 0.2
@export var run_to_sprint_blend: float = 0.20
@export var sprint_to_run_blend: float = 0.2
@export var run_to_walk_blend: float = 0.2
@export var walk_to_idle_blend: float = 0.2
@export_category("Airborne")
@export var standing_jump_speed_threshold: float = 0.30
@export var jump_blend_in: float = 0.08
@export var jump_to_fall_blend: float = 0.12
@export var apex_velocity_threshold: float = -0.5
@export_category("Passive Fall Presentation")
@export_range(0.0, 0.6, 0.01) var passive_fall_ground_grace_distance: float = 0.30
@export_range(0.0, 0.3, 0.01) var passive_fall_min_air_time: float = 0.12
@export var debug_facing_and_passive_fall: bool = false
## Compatibility for earlier tests/tools; a single authoritative timer setting.
var fall_min_air_time: float:
	get: return passive_fall_min_air_time
	set(value): passive_fall_min_air_time = value
var ground_within_grace: bool = false
var passive_ground_distance: float = INF
var fall_visual_committed: bool = false
var _intentional_jump_episode: bool = false
@export_category("Contact Land")
@export_range(0.0, 1.0, 0.01) var land_clip_start: float = 0.50
@export_range(0.0, 1.0, 0.01) var land_exit_progress: float = 1
@export var land_blend_in: float = 0.1
@export var land_blend_out: float = 0.12
@export var land_min_impact_time: float = 0.08
@export_category("Landing Visual Compression")
@export_range(0.0, 0.08, 0.005) var land_visual_sink_amount: float = 0.25
@export_range(0.0, 1.0, 0.01) var land_sink_peak_progress: float = 0.20
@export_range(0.0, 1.0, 0.01) var land_sink_recover_progress: float = 0.75
@export_range(0.0, 1.0, 0.05) var land_sink_entry_fraction: float = 0.85
@export_range(0.0, 0.25, 0.005) var land_visual_recover_time: float = 0.12
@export var debug_land_visual_compression: bool = false
@export_category("Standing Jump Landing")
@export_range(0.0, 1.0, 0.01) var standing_land_clip_start: float = 0.40
@export_range(0.0, 1.0, 0.01) var standing_land_exit_progress: float = 0.8
@export_range(0.0, 0.2, 0.005) var standing_land_blend_in: float = 0.25
@export_range(0.0, 0.50, 0.005) var standing_land_sink_amount: float = 0.36
@export_range(0.0, 1.0, 0.01) var standing_land_sink_peak_progress: float = 0.13
@export_range(0.0, 1.0, 0.01) var standing_land_sink_recover_progress: float = 0.66
@export_range(0.0, 1.0, 0.05) var standing_land_sink_entry_fraction: float = 1.0
@export_range(0.0, 0.15, 0.005) var standing_land_sink_tail_amount: float = 0.05
var active_standing_landing: bool = false
var _standing_jump_episode: bool = false
var _land_profile: Dictionary = {}
var visual_root_base_position: Vector3 = Vector3.ZERO
var land_visual_offset: float = 0.0
var _sink_start_offset: float = 0.0
var _recover_start_offset: float = 0.0
var _recover_elapsed: float = 0.0
var land_source_progress: float = 0.0
var land_window_progress: float = 0.0
var land_contact_frame: int = -1
var land_contact_time: float = 0.0
var _pose_delta: float = 0.0
var land_debug_sample: Dictionary = {}
var _debug_entry_pending: bool = false
var _debug_peak_reported: bool = false
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
@onready var visual_root: Node3D = $"../VisualRoot"

func _ready() -> void:
	visual_root_base_position = visual_root.position
	grounded = grounded.duplicate(true)
	motor.turn_180 = grounded.turn_180
	_land_profile = _select_land_profile(false)
	# The published state and interruption clock both advance in physics ticks.
	tree.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_PHYSICS
	if not _prepare_library():
		set_physics_process(false)
		return
	_build_tree()
	tree.mixer_applied.connect(_on_pose_applied)

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
		clip.loop_mode = Animation.LOOP_NONE if state in ["JumpStanding", "JumpMoving", "Land", "DodgeStand", "DodgeRun", "DodgeSprint", "DodgeBack"] else Animation.LOOP_LINEAR
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
	_trim_backstep()
	return grounded.prepare(player)

func _trim_backstep() -> void:
	# Slice only this instance's duplicated action. Retain authored 30 fps
	# poses and 1x timing; shared GLB and its full action remain untouched.
	var clip := player.get_animation(CLIPS.DodgeBack)
	var start: float=motor.dodge.BACKSTEP_START_FRAME/motor.dodge.SOURCE_FPS
	var finish: float=motor.dodge.BACKSTEP_END_FRAME/motor.dodge.SOURCE_FPS
	for track in clip.get_track_count():
		var samples: Array=[]
		for frame in range(motor.dodge.BACKSTEP_START_FRAME,motor.dodge.BACKSTEP_END_FRAME+1):
			var time: float=frame/motor.dodge.SOURCE_FPS
			match clip.track_get_type(track):
				Animation.TYPE_POSITION_3D: samples.append(clip.position_track_interpolate(track,time))
				Animation.TYPE_ROTATION_3D: samples.append(clip.rotation_track_interpolate(track,time))
				Animation.TYPE_SCALE_3D: samples.append(clip.scale_track_interpolate(track,time))
				_: push_error("Unexpected track type in Backstep slice"); return
		for key in range(clip.track_get_key_count(track)-1,-1,-1): clip.track_remove_key(track,key)
		for frame in samples.size(): clip.track_insert_key(track,frame/motor.dodge.SOURCE_FPS,samples[frame])
	clip.length=finish-start

func _clip(state: String) -> AnimationNodeAnimation:
	var node := AnimationNodeAnimation.new()
	node.animation = CLIPS[state]
	if state == "Land":
		node.use_custom_timeline = true
		node.stretch_time_scale = false
		node.start_offset = player.get_animation(CLIPS.Land).length * land_clip_start
		node.timeline_length = maxf(player.get_animation(CLIPS.Land).length - node.start_offset, 0.001)
	return node

func _build_tree() -> void:
	var locomotion = grounded.build()
	var machine := AnimationNodeStateMachine.new()
	machine.add_node(&"Locomotion", locomotion)
	for state in ["JumpStanding", "JumpMoving", "Fall", "Land", "DodgeStand", "DodgeRun", "DodgeBack"]:
		machine.add_node(state, _clip(state))
	# Direct edges prevent travel() routing through unrelated one-shot states.
	for from in ["Locomotion", "JumpStanding", "JumpMoving", "Fall", "Land", "DodgeStand", "DodgeRun", "DodgeBack"]:
		for to in ["Locomotion", "JumpStanding", "JumpMoving", "Fall", "Land", "DodgeStand", "DodgeRun", "DodgeBack"]:
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
	_pose_delta = delta
	if _playback == null:
		return
	var s = motor.animation_state
	# Recovery pose continues independently of movement authority. Air/jump
	# still interrupts it, while grounded current-input motion can steer it.
	if s.is_airborne or s.jump_started:
		motor.dodge.run_roll_recovery_visible=false
	# Check evaluated playback before issuing this tick's normal transitions.
	# Never repair over Jump/Fall/Land or resend a pending travel request.
	if current_state == &"Locomotion" and not s.jump_started:
		_recover_locomotion_playback()
	_update_gait(s, delta)
	ground_within_grace = false
	passive_ground_distance = INF
	if motor.dodge.run_roll_recovery_visible or (motor.dodge.is_dodging and (s.is_grounded or motor.dodge.is_rolling())):
		_enter(&"DodgeBack" if motor.dodge.clip==motor.dodge.BACK else (&"DodgeRun" if motor.dodge.clip in [motor.dodge.RUN,motor.dodge.SPRINT] else &"DodgeStand"))
	elif current_state in [&"DodgeStand", &"DodgeRun", &"DodgeBack"]:
		if s.is_airborne:
			_episode_visible=true
			fall_visual_committed=true
			_enter(&"Fall")
		else:
			_enter(&"Locomotion")
	if motor.dodge.is_rolling() or motor.dodge.run_roll_recovery_visible:
		# A grounded-start roll owns presentation across drops and recontact.
		# Do not start an ordinary landing/sink episode inside the action.
		_episode_visible=false
		fall_visual_committed=false
		_intentional_jump_episode=false
		_standing_jump_episode=false
	elif s.jump_started:
		_intentional_jump_episode = true
		fall_visual_committed = false
		_episode_visible = true
		_standing_jump_episode = s.takeoff_speed < standing_jump_speed_threshold
		_enter(&"JumpStanding" if s.takeoff_speed < standing_jump_speed_threshold else &"JumpMoving")
	elif s.is_airborne:
		var intentional: bool = current_state in [&"JumpStanding", &"JumpMoving"]
		if not intentional and not fall_visual_committed:
			_sample_passive_ground()
		var clearly_far: bool = passive_ground_distance > maxf(0.6,passive_fall_ground_grace_distance*2.0)
		var passive_commit: bool = not ground_within_grace and (s.air_time >= passive_fall_min_air_time or clearly_far or s.vertical_velocity <= -3.0)
		if s.vertical_velocity <= apex_velocity_threshold and (intentional or fall_visual_committed or passive_commit):
			_episode_visible = true
			fall_visual_committed = true
			_enter(&"Fall")
	elif s.is_grounded and not s.was_grounded:
		if _has_ground_contact and _episode_visible:
			landing_count += 1
			_impact_time = 0.0
			_enter(&"Land")
		else:
			_enter(&"Locomotion")
		_episode_visible = false
		_intentional_jump_episode = false
		fall_visual_committed = false
		_standing_jump_episode = false
	if s.is_grounded:
		_has_ground_contact = true
	if current_state == &"Land":
		_impact_time += delta
		var progress := land_source_progress
		if _impact_time >= land_min_impact_time and (s.move_input_magnitude > 0.01 or progress >= float(_land_profile.exit)):
			_enter(&"Locomotion")
	grounded.configure_lock_blends(lock_animation_enter_blend,lock_animation_exit_blend)
	grounded.update(tree, s, gait_blend, current_state == &"Locomotion", visual_root,delta,self)
	motor.turn_arc_suppressed = current_state != &"Locomotion"

func _sample_passive_ground() -> void:
	# Presentation sensor only: never snaps, alters velocity, or claims ground.
	# A small five-ray footprint covers tread edges without the capsule's wide
	# sidewall footprint treating a nearby vertical face as support.
	var origin: Vector3 = motor.global_position
	var extent := maxf(0.65,passive_fall_ground_grace_distance*2.0+0.05)
	for offset in [Vector3.ZERO,Vector3(0.20,0,0),Vector3(-0.20,0,0),Vector3(0,0,0.20),Vector3(0,0,-0.20)]:
		var q := PhysicsRayQueryParameters3D.create(origin+offset+Vector3.UP*0.02,origin+offset-Vector3.UP*extent,motor.collision_mask,[motor.get_rid()])
		var hit: Dictionary = motor.get_world_3d().direct_space_state.intersect_ray(q)
		if hit.is_empty() or hit.normal.dot(Vector3.UP)<cos(motor.floor_max_angle):
			continue
		var distance: float = origin.y-hit.position.y
		if distance >= -0.002:
			passive_ground_distance = minf(passive_ground_distance,maxf(distance,0.0))
	ground_within_grace = passive_ground_distance <= passive_fall_ground_grace_distance

func facing_and_fall_debug_text() -> String:
	var s = motor.animation_state
	var moving: bool = s.move_input_magnitude>0.01
	var explicit_turn: bool = motor.turn_180 != null and motor.turn_180.active
	return "Move Input: %.2f\nIdle Facing Locked: %s\nDesired Facing Updated: %s\nPhysical Grounded: %s\nPassive Air Time: %.3f\nGround Within Grace: %s\nGround Distance: %.3f m\nFall Visual Committed: %s\nAnimation State: %s" % [s.move_input_magnitude,not moving and not explicit_turn,moving,motor.is_on_floor(),s.air_time if not _intentional_jump_episode else 0.0,ground_within_grace,passive_ground_distance,fall_visual_committed,presentation_label()]

func _recover_locomotion_playback() -> void:
	if not tree.active:
		tree.active = true
		playback_recoveries += 1
	var actual := _playback.get_current_node()
	if not _playback.is_playing() or actual in [&"", &"Start", &"End"]:
		_playback.start(&"Locomotion")
		playback_recoveries += 1
	elif actual != &"Locomotion":
		if not _playback.get_travel_path().has(&"Locomotion"):
			_playback.travel(&"Locomotion")
			playback_recoveries += 1
	if actual == &"Locomotion":
		grounded.recover_playback()

func playback_debug_text() -> String:
	var child: AnimationNodeStateMachinePlayback = tree.get("parameters/Locomotion/playback")
	return "Logical: %s\nActual Tree Node: %s (%s)\nActual Locomotion Node: %s (%s)\nAnimationTree Active: %s\nGait Blend: %.2f [Idle / Walk / Run / Sprint]\nAir Episode Visible: %s\nPlayback Recoveries: %d" % [presentation_label(), _playback.get_current_node(), _playback.is_playing(), child.get_current_node(), child.is_playing(), tree.active, gait_blend, _episode_visible, playback_recoveries + grounded.playback_recoveries]

func _on_pose_applied() -> void:
	grounded.on_pose_applied(visual_root)
	if current_state in [&"DodgeStand", &"DodgeRun", &"DodgeBack"] and _playback.get_current_node()==current_state:
		motor.dodge.evaluate(_playback.get_current_play_position())
	# Read the evaluated AnimationTree timeline, not a guessed source timer.
	if current_state == &"Land" and _playback.get_current_node() == &"Land":
		var land_node := tree.tree_root.get_node(&"Land") as AnimationNodeAnimation
		var length := player.get_animation(CLIPS.Land).length
		land_source_progress = clampf((land_node.start_offset + _playback.get_current_play_position()) / length, 0.0, 1.0)
		var start := land_node.start_offset / length
		# 0..1 describes the remaining source clip, independent of early exit.
		land_window_progress = clampf((land_source_progress - start) / maxf(1.0 - start, 0.001), 0.0, 1.0)
	_update_land_visual_compression(_pose_delta)
	if debug_land_visual_compression and current_state == &"Land":
		_sample_land_feet()
		if _debug_entry_pending or (not _debug_peak_reported and land_window_progress >= float(_land_profile.peak)):
			print("V2 Land feet: ", land_debug_sample)
			if not _debug_entry_pending:
				_debug_peak_reported = true
			_debug_entry_pending = false

func _sample_land_feet() -> void:
	# Diagnostic only: bone origins are ankles, not mesh soles or IK targets.
	var skeleton := rig.get_node("Base Armature and Mesh/Skeleton3D") as Skeleton3D
	var left := skeleton.find_bone("mixamorig_LeftFoot")
	var right := skeleton.find_bone("mixamorig_RightFoot")
	var left_y := (skeleton.global_transform * skeleton.get_bone_global_pose(left).origin).y
	var right_y := (skeleton.global_transform * skeleton.get_bone_global_pose(right).origin).y
	var origin: Vector3 = motor.global_position
	var query := PhysicsRayQueryParameters3D.create(origin + Vector3.UP * 0.5, origin + Vector3.DOWN, motor.collision_mask, [motor.get_rid()])
	var hit: Dictionary = motor.get_world_3d().direct_space_state.intersect_ray(query)
	var ground_y: float = hit.position.y if not hit.is_empty() else NAN
	land_debug_sample = {"standing_profile": active_standing_landing, "contact_frame": land_contact_frame, "contact_time": land_contact_time,
		"pose_frame": Engine.get_physics_frames(), "source_progress": land_source_progress,
		"window_progress": land_window_progress, "offset": land_visual_offset,
		"left_foot_y": left_y, "right_foot_y": right_y,
		"left_ankle_gap": left_y - ground_y, "right_ankle_gap": right_y - ground_y}

func _update_land_visual_compression(delta: float) -> void:
	if current_state == &"Land":
		var amount: float = _land_profile.amount
		var peak := clampf(float(_land_profile.peak), 0.0, 1.0)
		var recover := clampf(float(_land_profile.recover), peak, 1.0)
		if land_window_progress <= peak:
			var entry := minf(_sink_start_offset, -amount * float(_land_profile.entry))
			land_visual_offset = lerpf(entry, -amount, _compression_weight(land_window_progress, peak))
		else:
			# The fixed-height hips leave a small sole gap at source 0.80.
			# Carry that standing-only correction into the existing exit blend.
			var tail := minf(amount, maxf(float(_land_profile.tail), 0.0))
			land_visual_offset = lerpf(-amount, -tail, _compression_weight(land_window_progress - peak, recover - peak))
	else:
		_recover_elapsed += delta
		land_visual_offset = lerpf(_recover_start_offset, 0.0, _compression_weight(_recover_elapsed, land_visual_recover_time))
	# Absolute offset from the captured base prevents accumulation. Rotation,
	# scale, bones, collision, and the CharacterBody are never written here.
	visual_root.position = visual_root_base_position + Vector3(0.0, land_visual_offset, 0.0)

func _compression_weight(elapsed: float, duration: float) -> float:
	if duration <= 0.0:
		return 1.0
	return smoothstep(0.0, 1.0, clampf(elapsed / duration, 0.0, 1.0))

func _exit_tree() -> void:
	if is_instance_valid(visual_root):
		visual_root.position = visual_root_base_position

func _update_gait(s, delta: float) -> void:
	if s.locked_on: gait_blend=minf(gait_blend,2.0)
	var target: float = float(s.gait + 1) if s.horizontal_speed > 0.10 or s.move_input_magnitude > 0.01 else 0.0
	# The outgoing roll supplies the handoff blend, so its destination should
	# already represent current intent, not a second old-gait recovery blend.
	if motor.dodge.handoff_this_tick:
		gait_blend=target
		return
	var duration: float
	if target > gait_blend:
		duration = idle_to_walk_blend if gait_blend < 1.0 else (walk_to_run_blend if gait_blend < 2.0 else run_to_sprint_blend)
	else:
		duration = sprint_to_run_blend if gait_blend > 2.0 else (run_to_walk_blend if gait_blend > 1.0 else walk_to_idle_blend)
	gait_blend = move_toward(gait_blend, target, delta / maxf(duration, 0.001))

func _enter(next: StringName) -> void:
	if current_state == next:
		return
	if next in [&"DodgeStand", &"DodgeRun", &"DodgeBack"]:
		var roll_node := tree.tree_root.get_node(next) as AnimationNodeAnimation
		# Run and Sprint share action plumbing, but select distinct source clips.
		roll_node.animation=motor.dodge.clip
		roll_node.use_custom_timeline=true
		roll_node.stretch_time_scale=true
		roll_node.timeline_length=motor.dodge.timeline_length
		roll_node.start_offset=0
		land_visual_offset=0
		_recover_start_offset=0
		_episode_visible=false
		visual_root.position=visual_root_base_position
	if current_state in [&"DodgeStand", &"DodgeRun", &"DodgeBack"]:
		var machine := tree.tree_root as AnimationNodeStateMachine
		for index in machine.get_transition_count():
			if machine.get_transition_from(index)==current_state and machine.get_transition_to(index)==next:
				var roll_blend: float=motor.dodge.sprint_roll_exit_blend if motor.dodge.clip==motor.dodge.SPRINT else motor.dodge.run_roll_exit_blend
				machine.get_transition(index).xfade_time=roll_blend if current_state==&"DodgeRun" and next==&"Locomotion" else motor.dodge.dodge_recovery_time
	if next == &"Land":
		var s = motor.animation_state
		# Select once at contact. A standing takeoff that moves in the air uses
		# the existing moving landing; new movement can still interrupt normally.
		active_standing_landing = _standing_jump_episode and s.horizontal_speed < standing_jump_speed_threshold and s.move_input_magnitude <= 0.01
		_land_profile = _select_land_profile(active_standing_landing)
		var node := tree.tree_root.get_node(&"Land") as AnimationNodeAnimation
		node.start_offset = player.get_animation(CLIPS.Land).length * float(_land_profile.start)
		node.timeline_length = maxf(player.get_animation(CLIPS.Land).length - node.start_offset, 0.001)
		var machine := tree.tree_root as AnimationNodeStateMachine
		for index in machine.get_transition_count():
			if machine.get_transition_to(index) == &"Land":
				machine.get_transition(index).xfade_time = float(_land_profile.blend)
		_sink_start_offset = land_visual_offset
		land_source_progress = float(_land_profile.start)
		land_window_progress = 0.0
		land_contact_frame = Engine.get_physics_frames()
		land_contact_time = Time.get_ticks_msec() / 1000.0
		_debug_entry_pending = true
		_debug_peak_reported = false
	elif next in [&"JumpStanding", &"JumpMoving", &"Fall"]:
		# A fresh airborne presentation must not retain a compressed takeoff.
		land_visual_offset = 0.0
		_recover_start_offset = 0.0
		visual_root.position = visual_root_base_position
	elif current_state == &"Land":
		# Locomotion/future action interruptions recover from the current depth.
		_recover_start_offset = land_visual_offset
		_recover_elapsed = 0.0
	current_state = next
	_playback.travel(next)

func _select_land_profile(standing: bool) -> Dictionary:
	if standing:
		return {"start": standing_land_clip_start, "exit": standing_land_exit_progress,
			"blend": standing_land_blend_in, "amount": standing_land_sink_amount,
			"peak": standing_land_sink_peak_progress, "recover": standing_land_sink_recover_progress,
			"entry": standing_land_sink_entry_fraction, "tail": standing_land_sink_tail_amount}
	return {"start": land_clip_start, "exit": land_exit_progress,
		"blend": land_blend_in, "amount": land_visual_sink_amount,
		"peak": land_sink_peak_progress, "recover": land_sink_recover_progress,
		"entry": land_sink_entry_fraction, "tail": 0.0}

func presentation_label() -> String:
	if current_state == &"Locomotion":
		if motor.animation_state.locked_on: return "LOCKED / "+grounded.combat.label(motor.animation_state)
		return String(grounded.transition) if grounded.transition != &"Loops" else ["IDLE", "WALK", "RUN", "SPRINT"][clampi(roundi(gait_blend), 0, 3)]
	return {&"JumpStanding": "JUMP_STANDING", &"JumpMoving": "JUMP_MOVING", &"Fall": "FALL", &"Land": "LAND"}.get(current_state, String(current_state))
