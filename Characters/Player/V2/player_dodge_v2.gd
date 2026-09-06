extends Resource
## Single owner of roll configuration, captured intent, and evaluated timeline.
@export_category("Dodge / Roll")
@export_range(0.10,0.25,0.01) var dodge_movement_input_threshold: float = 0.15
@export_group("Backstep")
@export_range(0,10,0.1) var backstep_speed: float = 5.0
@export_range(0.85,1.15,0.01) var backstep_playback_speed: float = 1.0
@export var backstep_movement_curve: Curve = preload("res://Characters/Player/V2/Curves/dodge_backstep_curve.tres")
@export_range(0.80,1,0.01) var backstep_exit_progress: float = 1.0
## Import uses 30 fps. The runtime Backstep action is sliced, never sped up.
const BACKSTEP_START_FRAME: int = 15
const BACKSTEP_END_FRAME: int = 60
const SOURCE_FPS: float = 30.0
@export_group("Stand/Walk Roll")
@export_range(0,15,0.1) var stand_roll_speed: float = 6.0
@export_range(0.85,1.15,0.01) var stand_roll_playback_speed: float = 1.0
@export var stand_roll_movement_curve: Curve = preload("res://Characters/Player/V2/Curves/dodge_stand_roll_curve.tres")
@export_range(0.85,1,0.01) var stand_roll_exit_progress: float = 0.95
@export_group("Run/Sprint Roll")
@export_range(0,15,0.1) var run_roll_speed: float = 8.0
@export_range(0.85,1.15,0.01) var run_roll_playback_speed: float = 1.0
@export var run_roll_movement_curve: Curve = preload("res://Characters/Player/V2/Curves/dodge_run_roll_curve.tres")
@export_range(0.85,1,0.01) var run_roll_exit_progress: float = 0.95
## Presentation-only return to locomotion; does not change movement or cooldown.
@export_range(0,0.5,0.01) var run_roll_exit_blend: float = 0.20
@export_group("Shared Recovery / Debug")
@export_range(1,40,0.5) var dodge_rotation_speed: float = 20.0
@export_range(0,0.3,0.01) var dodge_recovery_time: float = 0.10
@export_range(0,0.3,0.01) var dodge_retrigger_delay: float = 0.05
@export var debug_dodge: bool = false
const STAND: StringName = &"DOD_STAND_TO_ROLL"
const RUN: StringName = &"DOD_RUN_TO_ROLL"
const BACK: StringName = &"DPD_DODING_BACK"
var input_magnitude: float = 0.0
var source_horizontal_speed: float = 0.0
var raw_combat_input := Vector2.ZERO
var target_forward := Vector3.ZERO
var target_right := Vector3.ZERO
var is_dodging: bool = false
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
var recovery_remaining: float = 0.0
var cooldown: float = 0.0
var starts: int = 0
var movement_curve: Curve
var movement_progress: float = 0.0
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

func begin(direction: Vector3, gait: int, locked: bool, player: AnimationPlayer, magnitude: float, horizontal_speed: float, combat_input: Vector2, forward: Vector3) -> bool:
	if is_dodging or cooldown>0: return false
	initialize()
	var backstep:=magnitude<dodge_movement_input_threshold
	var running:=gait>=1
	clip=BACK if backstep else (RUN if running else STAND)
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
	timeline_length=player.get_animation(clip).length/playback_speed
	dodge_elapsed=0
	dodge_progress=0
	movement_progress=0
	speed_multiplier=0
	recovery_remaining=0
	is_dodging=true
	starts+=1
	return true

func advance_timers(delta: float) -> void:
	cooldown=maxf(0,cooldown-delta)
	recovery_remaining=maxf(0,recovery_remaining-delta)
	if is_dodging and dodge_progress>=exit_progress-0.0001: finish()

func evaluate(position: float) -> void:
	if not is_dodging: return
	dodge_elapsed=position
	dodge_progress=clampf(position/maxf(timeline_length,0.001),0,1)

func motion() -> Vector3:
	# Domain is full source-clip progress, NOT progress / exit_progress.
	# Use the last evaluated AnimationTree pose; no independent movement clock.
	movement_progress=dodge_progress
	speed_multiplier=maxf(0.0,movement_curve.sample(movement_progress)) if movement_curve!=null else 0.0
	return dodge_direction*base_speed*speed_multiplier

func finish() -> void:
	if not is_dodging: return
	is_dodging=false
	recovery_remaining=dodge_recovery_time
	cooldown=maxf(dodge_retrigger_delay,dodge_recovery_time)
	speed_multiplier=0

func debug_text(horizontal_velocity: Vector3 = Vector3.ZERO) -> String:
	return "DODGE\nActive: %s / Type: %s\nSource Gait: %s / Mode: %s\nInput Magnitude: %.2f / Source Speed: %.2f\nRaw Combat Input: %s\nCaptured Dodge Direction: %s\nTarget Relative Forward: %s / Right: %s\nClip Progress: %.2f / Sampled Progress: %.2f / Elapsed: %.2f\nBase Speed: %.2f / Curve Value: %.2f\nEffective Dodge Speed: %.2f\nHorizontal Velocity (x,z): (%.2f, %.2f)" % [is_dodging,dodge_type,["IDLE","WALK","RUN","SPRINT"][dodge_source_gait+1],dodge_source_mode,input_magnitude,source_horizontal_speed,raw_combat_input,dodge_direction,target_forward,target_right,dodge_progress,movement_progress,dodge_elapsed,base_speed,speed_multiplier,base_speed*speed_multiplier,horizontal_velocity.x,horizontal_velocity.z]
