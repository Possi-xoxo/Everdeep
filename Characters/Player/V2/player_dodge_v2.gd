extends Resource
## Single owner of roll configuration, captured intent, and evaluated timeline.
@export_category("Dodge / Roll")
@export_range(0.10,0.25,0.01) var dodge_movement_input_threshold: float = 0.15
@export_group("Backstep")
@export_range(15,60,1) var backstep_input_exit_frame: int = 50
@export_range(0,.5,.01) var backstep_exit_blend: float = .30
@export_range(15,60,1) var backstep_recovery_motion_start_frame: int = 36
@export_range(15,60,1) var backstep_recovery_motion_full_frame: int = 42
@export_range(15,60,1) var backstep_settle_start_frame: int = 57
@export_range(0,2,.05) var backstep_recovery_motion_strength: float = 1.0
@export_range(0,10,0.1) var backstep_speed: float = 5.0
@export_range(0.85,1.15,0.01) var backstep_playback_speed: float = 1.0
@export var backstep_movement_curve: Curve = preload("res://Characters/Player/V2/Curves/dodge_backstep_curve.tres")
@export_range(0.80,1,0.01) var backstep_exit_progress: float = 1.0
## Import uses 30 fps. The runtime Backstep action is sliced, never sped up.
const BACKSTEP_START_FRAME: int = 15
const BACKSTEP_END_FRAME: int = 60
const SOURCE_FPS: float = 30.0
@export_group("Stand/Walk Roll")
@export_range(0,60,1) var stand_roll_start_frame: int = 10
@export_range(0,90,1) var stand_roll_momentum_start_frame: int = 21
## Authored forward hip speed, scaled down during the anticipation/reach.
@export_range(0,1,.05) var stand_roll_leadin_strength: float = .65
@export_range(0,5,1) var stand_roll_leadin_blend_frames: float = 2.0
@export_range(0,120,1) var stand_roll_input_exit_frame: int = 55
@export_range(0,.5,.01) var stand_roll_exit_blend: float = .30
@export_range(0,15,0.1) var stand_roll_speed: float = 6.0
@export_range(0.85,1.15,0.01) var stand_roll_playback_speed: float = 1.0
@export var stand_roll_movement_curve: Curve = preload("res://Characters/Player/V2/Curves/dodge_stand_roll_curve.tres")
@export_range(0.85,1,0.01) var stand_roll_exit_progress: float = 1.0
@export_group("Run/Sprint Roll")
@export_range(0,15,0.1) var run_roll_speed: float = 8.0
@export_range(0.85,1.15,0.01) var run_roll_playback_speed: float = 1.0
@export var run_roll_movement_curve: Curve = preload("res://Characters/Player/V2/Curves/dodge_run_roll_curve.tres")
@export_range(0,300,1) var run_roll_input_handoff_frame: int = 59
@export_range(0,300,1) var run_roll_animation_exit_frame: int = 65
## Legacy early-cut setting retained for serialized compatibility, not used.
var run_roll_handoff_blend_time: float = 0.08
## Safety maximum if the handoff marker is configured beyond the normal exit.
@export_range(0.85,1,0.01) var run_roll_exit_progress: float = 0.95
## Presentation-only return to locomotion; does not change movement or cooldown.
@export_range(0,0.5,0.01) var run_roll_exit_blend: float = 0.20
@export_group("Sprint Roll")
## Presentation only: full roll velocity and source duration stay unchanged.
@export_range(0,0.5,0.01) var sprint_roll_exit_blend: float = 0.30
@export_group("Shared Recovery / Debug")
@export_range(1,40,0.5) var dodge_rotation_speed: float = 20.0
@export_range(0,0.3,0.01) var dodge_recovery_time: float = 0.10
@export_range(0,0.3,0.01) var dodge_retrigger_delay: float = 0.05
@export var debug_dodge: bool = false
const STAND: StringName = &"DOD_STAND_TO_ROLL"
const RUN: StringName = &"DOD_RUN_TO_ROLL"
const SPRINT: StringName = &"DOD_SPRINT_TO_ROLL"
const BACK: StringName = &"DPD_DODING_BACK"
var input_magnitude: float = 0.0
var source_horizontal_speed: float = 0.0
var raw_combat_input := Vector2.ZERO
var target_forward := Vector3.ZERO
var target_right := Vector3.ZERO
var is_dodging: bool = false
var dodge_airborne: bool = false
var dodge_type: String = "STAND_ROLL"
var dodge_direction := Vector3.FORWARD
var dodge_elapsed: float = 0.0
var dodge_progress: float = 0.0
var dodge_source_gait: int = -1
var dodge_source_mode: String = "FREE"
var clip: StringName = STAND
var base_speed: float = 0.0
var speed_multiplier: float = 0.0
var playback_speed: float = 1.0
var exit_progress: float = 0.95
var timeline_length: float = 1.0
var timeline_start_offset: float = 0.0
## Storage lets the motor's per-instance Resource duplication retain this cache.
@export_storage var stand_roll_authored_speed: Curve
@export_storage var backstep_authored_speed: Curve
var recovery_remaining: float = 0.0
var cooldown: float = 0.0
var starts: int = 0
var movement_curve: Curve
var movement_progress: float = 0.0
var run_roll_handoff_progress: float = 0.0
var run_roll_control_returned: bool = false
var run_roll_recovery_visible: bool = false
var run_roll_animation_exit_progress: float = 0.0
var handoff_this_tick: bool = false
var handoff_pending: bool = false
var handoff_reorienting: bool = false
var handoff_waiting_for_input: bool = false
var handoff_input := Vector2.ZERO
var handoff_target_mode: String = ""
var handoff_target_gait: String = ""
var handoff_target_direction := Vector3.ZERO
## Inert integration hooks: no stamina, damage immunity, or cancellation logic.
var dodge_invulnerable: bool = false
var dodge_stamina_cost: float = 0.0
var can_cancel_attack_into_dodge: bool = false

func initialize(unique_curves: bool = false) -> void:
	# Null Inspector slots fall back independently; never replace a tuned curve.
	if backstep_movement_curve==null:
		backstep_movement_curve=preload("res://Characters/Player/V2/Curves/dodge_backstep_curve.tres").duplicate()
	if stand_roll_movement_curve==null:
		stand_roll_movement_curve=preload("res://Characters/Player/V2/Curves/dodge_stand_roll_curve.tres").duplicate()
	if run_roll_movement_curve==null:
		run_roll_movement_curve=preload("res://Characters/Player/V2/Curves/dodge_run_roll_curve.tres").duplicate()
	if unique_curves:
		# Resource.duplicate(true) may retain externally saved resources.
		backstep_movement_curve=backstep_movement_curve.duplicate()
		stand_roll_movement_curve=stand_roll_movement_curve.duplicate()
		run_roll_movement_curve=run_roll_movement_curve.duplicate()

func prepare_stand_leadin(source: Animation) -> void:
	# Read BEFORE horizontal normalization; retain a speed profile, not root
	# motion authority. This rig's local +Y is forward, in centimeters.
	stand_roll_authored_speed=Curve.new()
	stand_roll_authored_speed.max_value=30.0
	for track in source.get_track_count():
		if source.track_get_type(track)!=Animation.TYPE_POSITION_3D or not str(source.track_get_path(track)).ends_with(":mixamorig_Hips"): continue
		var frames:=ceili(source.length*SOURCE_FPS)
		for frame in range(frames+1):
			var time:=minf(float(frame)/SOURCE_FPS,source.length)
			var before:=maxf(0,time-.5/SOURCE_FPS)
			var after:=minf(source.length,time+.5/SOURCE_FPS)
			var a: Vector3=source.position_track_interpolate(track,before)
			var b: Vector3=source.position_track_interpolate(track,after)
			var speed:=maxf(0,(b.y-a.y)*.01/maxf(after-before,.001))
			stand_roll_authored_speed.add_point(Vector2(time/source.length,minf(speed,30)))
		return

func prepare_backstep_recovery(source: Animation) -> void:
	# Preserve the tuned initial push, but recover the source's late backward
	# travel before the runtime clip is normalized and sliced to frames 15–60.
	backstep_authored_speed=Curve.new()
	backstep_authored_speed.max_value=30.0
	for track in source.get_track_count():
		if source.track_get_type(track)!=Animation.TYPE_POSITION_3D or not str(source.track_get_path(track)).ends_with(":mixamorig_Hips"): continue
		for frame in range(BACKSTEP_START_FRAME,BACKSTEP_END_FRAME+1):
			var time:=float(frame)/SOURCE_FPS
			var before:=maxf(0,time-.5/SOURCE_FPS)
			var after:=minf(source.length,time+.5/SOURCE_FPS)
			var a: Vector3=source.position_track_interpolate(track,before)
			var b: Vector3=source.position_track_interpolate(track,after)
			var speed:=maxf(0,(a.y-b.y)*.01/maxf(after-before,.001))
			backstep_authored_speed.add_point(Vector2(float(frame-BACKSTEP_START_FRAME)/(BACKSTEP_END_FRAME-BACKSTEP_START_FRAME),minf(speed,30)))
		return

func source_frame() -> float:
	return dodge_elapsed*playback_speed*SOURCE_FPS+(BACKSTEP_START_FRAME if clip==BACK else 0)

func begin(direction: Vector3, gait: int, locked: bool, player: AnimationPlayer, magnitude: float, horizontal_speed: float, combat_input: Vector2, forward: Vector3) -> bool:
	if is_dodging or run_roll_recovery_visible or cooldown>0: return false
	initialize()
	var backstep:=magnitude<dodge_movement_input_threshold
	var running:=gait>=1
	clip=BACK if backstep else (SPRINT if gait==2 and not locked else (RUN if running else STAND))
	if not player.has_animation(clip): return false
	dodge_type="BACKSTEP" if backstep else ("RUN_ROLL" if running else "STAND_ROLL")
	movement_curve=backstep_movement_curve if backstep else (run_roll_movement_curve if running else stand_roll_movement_curve)
	input_magnitude=magnitude
	source_horizontal_speed=horizontal_speed
	raw_combat_input=combat_input
	target_forward=forward if locked else Vector3.ZERO
	target_right=forward.cross(Vector3.UP) if locked else Vector3.ZERO
	dodge_source_gait=gait
	dodge_source_mode="LOCKED" if locked else "FREE"
	dodge_direction=direction.normalized()
	base_speed=backstep_speed if backstep else (run_roll_speed if running else stand_roll_speed)
	playback_speed=maxf(0.01,backstep_playback_speed if backstep else (run_roll_playback_speed if running else stand_roll_playback_speed))
	exit_progress=clampf(backstep_exit_progress if backstep else (run_roll_exit_progress if running else stand_roll_exit_progress),0.01,1.0)
	if clip==SPRINT: exit_progress=1.0
	timeline_length=player.get_animation(clip).length/playback_speed
	timeline_start_offset=float(stand_roll_start_frame)/SOURCE_FPS/playback_speed if clip==STAND else 0.0
	# Zero-based source timestamps at the verified 30 Hz import rate.
	run_roll_handoff_progress=(float(run_roll_input_handoff_frame)/SOURCE_FPS)/maxf(player.get_animation(clip).length,0.001)
	run_roll_control_returned=false
	run_roll_recovery_visible=false
	run_roll_animation_exit_progress=(float(maxi(run_roll_animation_exit_frame,run_roll_input_handoff_frame))/SOURCE_FPS)/maxf(player.get_animation(clip).length,0.001)
	handoff_this_tick=false
	handoff_pending=false
	handoff_reorienting=false
	handoff_waiting_for_input=false
	handoff_target_mode=""
	handoff_target_gait=""
	handoff_target_direction=Vector3.ZERO
	dodge_elapsed=timeline_start_offset
	dodge_progress=clampf(dodge_elapsed/maxf(timeline_length,.001),0,1)
	movement_progress=0
	speed_multiplier=0
	recovery_remaining=0
	is_dodging=true
	dodge_airborne=false
	starts+=1
	return true

func advance_timers(delta: float, traversal_active: bool = false, current_input: Vector2 = Vector2.ZERO) -> void:
	handoff_this_tick=false
	cooldown=maxf(0,cooldown-delta)
	recovery_remaining=maxf(0,recovery_remaining-delta)
	var input_exit_due: bool=(clip==STAND and source_frame()>=stand_roll_input_exit_frame-.0001) or (clip==BACK and source_frame()>=backstep_input_exit_frame-.0001)
	if is_dodging and input_exit_due and current_input.length()>.01:
		# Current input, not captured roll intent. Do not interrupt an accepted lift.
		if not traversal_active:
			handoff_this_tick=true
			handoff_reorienting=true
			finish()
	if run_roll_recovery_visible and dodge_progress>=minf(run_roll_animation_exit_progress,exit_progress)-0.000001:
		run_roll_recovery_visible=false
	if is_dodging and dodge_type=="RUN_ROLL":
		var marker_due: bool=clip==RUN and run_roll_handoff_progress<=exit_progress and dodge_progress>=run_roll_handoff_progress-0.000001
		if marker_due or dodge_progress>=exit_progress-0.0001:
			# Finish a validated capsule lift before returning control.
			handoff_pending=traversal_active
			if traversal_active: return
			if marker_due:
				run_roll_control_returned=true
				run_roll_recovery_visible=true
				handoff_this_tick=true
				handoff_waiting_for_input=true
				handoff_reorienting=true
			finish()
	if is_dodging and dodge_progress>=exit_progress-0.0001: finish()

func evaluate(position: float) -> void:
	if not is_dodging and not run_roll_recovery_visible: return
	dodge_elapsed=position+timeline_start_offset
	dodge_progress=clampf(dodge_elapsed/maxf(timeline_length,0.001),0,1)

func motion() -> Vector3:
	if clip==BACK and backstep_authored_speed!=null:
		movement_progress=dodge_progress
		var frame:=source_frame()
		var original: float=maxf(0,movement_curve.sample(movement_progress)) if movement_curve!=null else 0.0
		# Keep existing speed tuning as a multiplier relative to its 5m/s default.
		var authored: float=backstep_authored_speed.sample(movement_progress)*backstep_recovery_motion_strength*playback_speed/5.0
		var blend:=smoothstep(backstep_recovery_motion_start_frame,maxi(backstep_recovery_motion_full_frame,backstep_recovery_motion_start_frame+1),frame)
		var settle:=1.0-smoothstep(mini(backstep_settle_start_frame,BACKSTEP_END_FRAME-1),BACKSTEP_END_FRAME,frame)
		speed_multiplier=lerpf(original,authored,blend)*settle
		return dodge_direction*base_speed*speed_multiplier
	if clip==STAND and dodge_elapsed*playback_speed*SOURCE_FPS<stand_roll_momentum_start_frame-.0001:
		movement_progress=dodge_progress
		var frame:=dodge_elapsed*playback_speed*SOURCE_FPS
		var full: float=maxf(0,movement_curve.sample(movement_progress)) if movement_curve!=null else 0.0
		var authored: float=stand_roll_authored_speed.sample(movement_progress)*stand_roll_leadin_strength*playback_speed/maxf(base_speed,.001) if stand_roll_authored_speed!=null else 0.0
		var blend:=smoothstep(stand_roll_momentum_start_frame-stand_roll_leadin_blend_frames,stand_roll_momentum_start_frame,frame) if stand_roll_leadin_blend_frames>0 else 0.0
		speed_multiplier=lerpf(minf(authored,full),full,blend)
		return dodge_direction*base_speed*speed_multiplier
	if clip==SPRINT:
		# Sprint carries full roll speed throughout its complete source clip.
		movement_progress=dodge_progress
		speed_multiplier=1.0
		return dodge_direction*base_speed
	if handoff_pending:
		speed_multiplier=0.0
		return Vector3.ZERO
	# Domain is full source-clip progress, NOT progress / exit_progress.
	# Use the last evaluated AnimationTree pose; no independent movement clock.
	movement_progress=dodge_progress
	speed_multiplier=maxf(0.0,movement_curve.sample(movement_progress)) if movement_curve!=null else 0.0
	return dodge_direction*base_speed*speed_multiplier

func finish() -> void:
	if not is_dodging: return
	is_dodging=false
	dodge_airborne=false
	recovery_remaining=dodge_recovery_time
	cooldown=maxf(dodge_retrigger_delay,dodge_recovery_time)
	speed_multiplier=0

func is_rolling() -> bool:
	return is_dodging and dodge_type!="BACKSTEP"

func handoff_debug_text() -> String:
	return "RUN ROLL HANDOFF\nCurrent Frame: %.2f / Handoff Frame: %d (%.6f)\nControl Returned: %s / Lift Pending: %s\nCurrent Input: %s\nAt Handoff: %s / %s / Direction: %s\n" % [dodge_elapsed*playback_speed*SOURCE_FPS,run_roll_input_handoff_frame,run_roll_handoff_progress,run_roll_control_returned,handoff_pending,handoff_input,handoff_target_mode,handoff_target_gait,handoff_target_direction]

func debug_text(horizontal_velocity: Vector3 = Vector3.ZERO) -> String:
	return "DODGE\nActive: %s / Type: %s\nSource Gait: %s / Mode: %s\nInput Magnitude: %.2f / Source Speed: %.2f\nRaw Combat Input: %s\nCaptured Dodge Direction: %s\nTarget Relative Forward: %s / Right: %s\nClip Progress: %.2f / Sampled Progress: %.2f / Elapsed: %.2f\nBase Speed: %.2f / Curve Value: %.2f\nEffective Dodge Speed: %.2f\nHorizontal Velocity (x,z): (%.2f, %.2f)" % [is_dodging,dodge_type,["IDLE","WALK","RUN","SPRINT"][dodge_source_gait+1],dodge_source_mode,input_magnitude,source_horizontal_speed,raw_combat_input,dodge_direction,target_forward,target_right,dodge_progress,movement_progress,dodge_elapsed,base_speed,speed_multiplier,base_speed*speed_multiplier,horizontal_velocity.x,horizontal_velocity.z]
