extends Resource
## Shared animation/motor coordination. Only evaluated animation advances progress.
@export_category("Animation-led 180 Turns")
@export_range(120.0, 180.0) var turn_180_trigger_angle: float = 150.0
@export_range(0.1, 2.0) var moving_turn_min_speed: float = 0.3
@export_range(0.0, 1.0) var walk_180_stop_progress: float = 0.30
@export_range(0.0, 1.0) var walk_180_resume_progress: float = 0.55
@export_range(120.0, 180.0) var run_180_trigger_angle: float = 150.0
@export_range(0.9, 1.1, 0.01) var run_180_playback_speed: float = 1.0
@export_range(0.0, 0.4, 0.01) var run_180_carry_end_progress: float = 0.20
@export_range(0.0, 1.0) var run_180_rotation_start_progress: float = 0.15
@export_range(0.0, 1.0) var run_180_rotation_end_progress: float = 0.90
@export var debug_180: bool = false
var active: bool = false
var started: bool = false
var running: bool = false
var progress: float = 0.0
var target_direction: Vector3 = Vector3.ZERO
var source_gait: int = 0
var target_gait: int = 0
var movement_multiplier: float = 1.0
var target_angle: float = 0.0
var _start_yaw: float = 0.0
var _entry_velocity: Vector3 = Vector3.ZERO
var _finished: bool = false
var _stop: float = 0.0
var _resume: float = 0.0
var entry_speed: float = 0.0
var entry_buildup: float = 0.0
var resume_pending: bool = false

func begin_motor_tick(desired: Vector3, horizontal: Vector3, allowed: bool, from_gait: int, to_gait: int, visual: Node3D) -> void:
	started = false
	resume_pending = false
	target_gait = to_gait
	if _finished:
		resume_pending = running and allowed and not desired.is_zero_approx()
		cancel()
		return
	var valid := allowed and not desired.is_zero_approx()
	if active:
		if running:
			# Run commits to the captured destination, even if input is released
			# or changed. Only physical/high-priority suppression cancels it.
			if not allowed:
				cancel()
			return
		# Lock the destination through compatible jitter; a clear new request
		# or released input cancels without forcing a meaningless reversal.
		if not valid or desired.dot(target_direction) < cos(deg_to_rad(60.0)):
			cancel()
		return
	if not valid or horizontal.length() <= moving_turn_min_speed:
		return
	var angle := wrapf(atan2(-desired.x,-desired.z) - visual.global_rotation.y,-PI,PI)
	var threshold := run_180_trigger_angle if to_gait != 0 else turn_180_trigger_angle
	if absf(angle) + 0.00001 < deg_to_rad(threshold):
		return
	active = true
	started = true
	running = to_gait != 0
	progress = 0.0
	source_gait = to_gait if running else from_gait
	_entry_velocity = horizontal
	entry_speed = horizontal.length()
	target_direction = desired
	_start_yaw = visual.rotation.y
	target_angle = angle
	if absf(angle) >= deg_to_rad(179.0):
		target_angle = PI * (-1.0 if running else 1.0)
	_stop = clampf(walk_180_stop_progress,0.0,1.0)
	_resume = clampf(walk_180_resume_progress,_stop,1.0)
	movement_multiplier = 1.0

func motion_target(requested_speed: float) -> Vector3:
	if running:
		# Carry the captured incoming momentum for the source's entry step,
		# then plant. Never steer this entry movement toward reverse input.
		return _entry_velocity if progress < run_180_carry_end_progress else Vector3.ZERO
	if progress < _stop:
		movement_multiplier = 1.0 - smoothstep(0.0,1.0,progress / maxf(_stop,0.0001))
		return _entry_velocity * movement_multiplier
	if progress <= _resume:
		movement_multiplier = 0.0
		return Vector3.ZERO
	movement_multiplier = smoothstep(0.0,1.0,(progress-_resume)/maxf(1.0-_resume,0.0001))
	return target_direction * requested_speed * movement_multiplier

func apply_evaluated_pose(normalized_progress: float, rotation_weight: float, visual: Node3D) -> void:
	if not active:
		return
	progress = clampf(normalized_progress,0.0,1.0)
	if running:
		var start := clampf(run_180_rotation_start_progress,0,1)
		var end := clampf(run_180_rotation_end_progress,start+0.0001,1.0001)
		rotation_weight = smoothstep(0.0,1.0,clampf((progress-start)/(end-start),0,1))
	visual.rotation.y = _start_yaw + target_angle * rotation_weight
	if progress >= 0.99999:
		visual.rotation.y = _start_yaw + target_angle
		_finished = true

func cancel() -> void:
	active = false
	_finished = false
	movement_multiplier = 1.0
