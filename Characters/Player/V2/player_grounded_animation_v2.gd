extends Resource
## Grounded presentation and a shared animation-led turn coordinator.
@export var turn_180: Resource = preload("res://Characters/Player/V2/player_turn_180_v2.gd").new()
const ACTIONS := {
	"WalkBack": "LOC_WALKING_BACKWARDS", "WalkLeft": "LOC_LEFT_STRAFE_WALKING",
	"WalkRight": "LOC_RIGHT_STRAFE_WALKING", "RunLeft": "LOC_RUNNING_STRAFE_LEFT",
	"RunRight": "LOC_RUNNING_STRAFE_RIGHT", "RunStop": "LOC_RUN_TO_STOP",
	"WalkPivot": "LOC_WALKING_TURN_180", "RunPivot": "LOC_RUNNING_TURN_180",
	"TurnLeft": "LOC_LEFT_TURN_90", "TurnRight": "LOC_RIGHT_TURN_90"}
@export_category("Grounded Animation Transitions")
@export var locomotion_return_blend: float = 0.15
@export_range(0.0, 1.0) var run_stop_exit_progress: float = 0.90
@export var run_stop_blend: float = 0.15
@export_range(45.0, 90.0) var turn_in_place_min_angle: float = 60.0
@export var turn_blend: float = 0.15
@export var debug_grounded: bool = false
var transition: StringName = &"Loops"
var _tree: AnimationTree
var _player: AnimationPlayer
var _machine: AnimationNodeStateMachine
var _playback: AnimationNodeStateMachinePlayback
var _had_input: bool = false
var _last_gait: int = 0
var _active: bool = false
var _turn_start: float = 0.0
var _turn_angle: float = 0.0
var _turn_curves: Dictionary = {}
var playback_recoveries: int = 0

func prepare(player: AnimationPlayer) -> bool:
	_player = player
	var reference := Vector3.ZERO
	var idle := player.get_animation("IDL_IDLE_A")
	for t in idle.get_track_count():
		if idle.track_get_type(t) == Animation.TYPE_POSITION_3D and String(idle.track_get_path(t)).ends_with(":mixamorig_Hips"):
			reference = idle.track_get_key_value(t, 0)
	for key: String in ACTIONS:
		if not player.has_animation(ACTIONS[key]):
			push_error("V2 grounded missing action: " + ACTIONS[key])
			return false
		var clip := player.get_animation(ACTIONS[key])
		clip.loop_mode = Animation.LOOP_LINEAR if key in ["WalkBack", "WalkLeft", "WalkRight", "RunLeft", "RunRight"] else Animation.LOOP_NONE
		for t in clip.get_track_count():
			if not String(clip.track_get_path(t)).ends_with(":mixamorig_Hips"):
				continue
			if clip.track_get_type(t) == Animation.TYPE_POSITION_3D:
				for k in clip.track_get_key_count(t):
					var v: Vector3 = clip.track_get_key_value(t, k)
					v.x = reference.x
					v.y = reference.y
					clip.track_set_key_value(t, k, v)
			elif clip.track_get_type(t) == Animation.TYPE_ROTATION_3D and (key.begins_with("Turn") or key.ends_with("Pivot")):
				# Remove only authored yaw; preserve tilt. A normalized yaw curve
				# drives VisualRoot once, avoiding doubled skeletal/wrapper turns.
				var samples: Array[Vector2] = []
				var first: Quaternion = clip.track_get_key_value(t, 0)
				var previous_yaw: float = 0.0
				for k in clip.track_get_key_count(t):
					var q: Quaternion = clip.track_get_key_value(t, k)
					var relative := q * first.inverse()
					var yaw := 2.0 * atan2(relative.z, relative.w)
					# Unwrap the source across +/-180; Run overshoots that boundary.
					yaw = previous_yaw + wrapf(yaw - previous_yaw, -PI, PI)
					previous_yaw = yaw
					samples.append(Vector2(clip.track_get_key_time(t, k), yaw))
					clip.track_set_key_value(t, k, Quaternion(Vector3(0,0,1), -yaw) * q)
				_turn_curves[key] = samples
	return true

func animation(action: String) -> AnimationNodeAnimation:
	var node := AnimationNodeAnimation.new()
	node.animation = action
	return node

func directional(run: bool) -> AnimationNodeBlendSpace2D:
	var space := AnimationNodeBlendSpace2D.new()
	# Cardinal clips have different lengths. Normalize phase within each gait;
	# a solo clip keeps authored speed, with no input-dependent seek/restart.
	space.sync_mode = AnimationNodeBlendSpace2D.SYNC_MODE_CYCLIC_MUTABLE
	var forward := "LOC_RUNNING_FOWARD_A" if run else "LOC_WALKING"
	space.add_blend_point(animation(forward), Vector2(0,1), -1, &"Forward")
	space.add_blend_point(animation(ACTIONS.RunLeft if run else ACTIONS.WalkLeft), Vector2(-1,0), -1, &"Left")
	space.add_blend_point(animation(ACTIONS.RunRight if run else ACTIONS.WalkRight), Vector2(1,0), -1, &"Right")
	if not run:
		space.add_blend_point(animation(ACTIONS.WalkBack), Vector2(0,-1), -1, &"Back")
	return space

func build() -> AnimationNodeStateMachine:
	_machine = AnimationNodeStateMachine.new()
	var loops := AnimationNodeBlendSpace1D.new()
	loops.min_space = 0
	loops.max_space = 3
	# Gait children include nested spaces, not finite AnimationNodeAnimation
	# leaves: cyclic sync is inappropriate here. Preserve Phase 1 gait clocks.
	loops.sync_mode = AnimationNodeBlendSpace1D.SYNC_MODE_INDEPENDENT
	loops.add_blend_point(animation("IDL_IDLE_A"), 0, -1, &"Idle")
	loops.add_blend_point(directional(false), 1, -1, &"Walk")
	loops.add_blend_point(directional(true), 2, -1, &"Run")
	loops.add_blend_point(animation("LOC_SPRINT_FORWARD"), 3, -1, &"Sprint")
	_machine.add_node(&"Loops", loops)
	# Parent state re-entry resets this nested machine to Start. Start must
	# resolve to a pose in the same evaluation, not depend on a queued start()
	# that the parent reset can overwrite.
	var entry := AnimationNodeStateMachineTransition.new()
	entry.advance_mode = AnimationNodeStateMachineTransition.ADVANCE_MODE_AUTO
	_machine.add_transition(&"Start", &"Loops", entry)
	for key in ["RunStop", "TurnLeft", "TurnRight", "WalkPivot", "RunPivot"]:
		_machine.add_node(key, animation(ACTIONS[key]))
	# Optional constant manual rate only; never fit playback to a pause timer.
	var run_node := _machine.get_node(&"RunPivot") as AnimationNodeAnimation
	if not is_equal_approx(turn_180.run_180_playback_speed, 1.0):
		run_node.use_custom_timeline = true
		run_node.stretch_time_scale = true
		run_node.timeline_length = _player.get_animation(ACTIONS.RunPivot).length / clampf(turn_180.run_180_playback_speed,0.9,1.1)
	for from in ["Loops", "RunStop", "TurnLeft", "TurnRight", "WalkPivot", "RunPivot"]:
		for to in ["Loops", "RunStop", "TurnLeft", "TurnRight", "WalkPivot", "RunPivot"]:
			if from == to:
				continue
			var edge := AnimationNodeStateMachineTransition.new()
			edge.xfade_time = locomotion_return_blend if to == "Loops" else (run_stop_blend if to == "RunStop" else turn_blend)
			_machine.add_transition(from,to,edge)
	return _machine

func update(tree: AnimationTree, s, gait_blend: float, active: bool, visual: Node3D) -> void:
	_tree = tree
	_playback = tree.get("parameters/Locomotion/playback")
	var moving: bool = s.move_input_magnitude > 0.01
	var direction: Vector2 = s.move_local if s.horizontal_speed > 0.1 else Vector2(0,1)
	tree.set("parameters/Locomotion/Loops/blend_position", gait_blend)
	tree.set("parameters/Locomotion/Loops/Walk/blend_position", direction)
	# No neutral backward Run source: use forward while the motor reorients.
	tree.set("parameters/Locomotion/Loops/Run/blend_position", Vector2(direction.x, maxf(direction.y, 0.01)).normalized())
	if not active or s.jump_started:
		turn_180.cancel()
		_active = false
		transition = &"Loops"
		_had_input = moving
		_last_gait = s.gait
		return
	if not _active:
		transition = &"Loops"
		_active = true
		_had_input = moving
	if not s.is_grounded:
		# Passive floor loss does not relinquish the locomotion pose. Only
		# physical-only transitions are cancelled; a running loop keeps phase.
		turn_180.cancel()
		enter(&"Loops")
		_had_input = moving
		_last_gait = s.gait
		return
	if turn_180.active:
		var pivot: StringName = &"RunPivot" if turn_180.running else &"WalkPivot"
		# Full source at 1.0x. There is no controller-duration timeline scaling.
		enter(pivot)
		_had_input = moving
		_last_gait = s.gait
		return
	elif transition in [&"WalkPivot", &"RunPivot"]:
		enter(&"Loops")
		_had_input = moving
		return
	if transition != &"Loops":
		var progress := source_progress()
		if transition.begins_with("Turn"):
			if moving or s.horizontal_speed > 0.1:
				enter(&"Loops")
			else:
				visual.rotation.y = _turn_start + _turn_angle * turn_weight()
				if progress >= 0.99:
					visual.rotation.y = _turn_start + _turn_angle
					enter(&"Loops")
		elif moving or progress >= run_stop_exit_progress:
			enter(&"Loops")
	# Walking stays in Loops and uses the existing Idle/Walk gait crossfade.
	elif not moving and _had_input and _last_gait != 0 and s.horizontal_speed > 0.1:
		enter(&"RunStop")
	elif not moving and s.horizontal_speed < 0.1 and absf(s.facing_delta) >= deg_to_rad(turn_in_place_min_angle):
		_turn_start = visual.rotation.y
		_turn_angle = clampf(s.facing_delta, -PI/2, PI/2)
		enter(&"TurnLeft" if _turn_angle > 0 else &"TurnRight")
	_had_input = moving
	if moving:
		_last_gait = s.gait

func enter(next: StringName) -> void:
	if next != transition:
		transition = next
		_playback.travel(next)

func recover_playback() -> void:
	if _playback == null or not _active:
		return
	var actual := _playback.get_current_node()
	if not _playback.is_playing() or actual in [&"", &"Start", &"End"]:
		_playback.start(transition)
		playback_recoveries += 1
	elif actual != transition and not _playback.get_travel_path().has(transition):
		_playback.travel(transition)
		playback_recoveries += 1

func on_pose_applied(visual: Node3D) -> void:
	if not turn_180.active or _playback == null or transition not in [&"WalkPivot", &"RunPivot"]:
		return
	if _playback.get_current_node() != transition:
		return
	turn_180.apply_evaluated_pose(source_progress(), turn_weight(), visual)

func source_progress() -> float:
	if _playback.get_current_node() != transition:
		return 0.0
	var node := _machine.get_node(transition) as AnimationNodeAnimation
	if transition == &"RunPivot" and node.use_custom_timeline:
		return _playback.get_current_play_position() / node.timeline_length
	return (_playback.get_current_play_position() + node.start_offset) / _player.get_animation(node.animation).length

func turn_weight() -> float:
	if _playback.get_current_node() != transition:
		return 0.0
	var samples: Array = _turn_curves[transition]
	var end: float = samples[-1].y
	var time := _playback.get_current_play_position()
	for i in range(1, samples.size()):
		if time <= samples[i].x:
			var a: Vector2 = samples[i-1]
			var b: Vector2 = samples[i]
			return clampf(lerpf(a.y,b.y,inverse_lerp(a.x,b.x,time)) / end, 0, 1)
	return 1.0

func direction_label(s) -> String:
	if s.horizontal_speed <= 0.1:
		return "None"
	if absf(s.move_local.x) > absf(s.move_local.y):
		return "Right" if s.move_local.x > 0 else "Left"
	return "Forward" if s.move_local.y >= 0 else "Back"
