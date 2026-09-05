extends CharacterBody3D
const State = preload("res://Characters/Player/V2/player_animation_state.gd")
@export_category("Gaits")
@export var walk_speed: float = 4.0
@export var run_start_speed: float = 4.0
@export var run_end_speed: float = 6.0
@export var sprint_speed: float = 8.0
@export_range(0.1, 10.0, 0.1) var sprint_buildup_duration: float = 4.0
@export_category("Ground Motor")
@export var acceleration: float = 28.0
@export var deceleration: float = 36.0
@export var turn_acceleration: float = 65.0
@export var lateral_damping: float = 80.0
@export var turn_rate: float = 16.0
@export_category("Air Motor")
@export var jump_velocity: float = 8.0
@export var rise_gravity: float = 19.6
@export var fall_gravity: float = 29.4
@export_range(0.0, 1.0, 0.05) var air_control: float = 0.4
@export var max_fall_speed: float = 35.0
var animation_state = State.new()
var target_speed: float = 0.0
var _run_time: float = 0.0
@onready var camera: Camera3D = $CameraRig/YawPivot/PitchPivot/SpringArm3D/Camera3D
@onready var visual: Node3D = $VisualRoot

func _physics_process(delta: float) -> void:
	step_motor(delta, Input.get_vector("move_left", "move_right", "move_forward", "move_backward"), Input.is_action_pressed("sprint"), Input.is_action_just_pressed("jump"))

## Input boundary also supports deterministic play tests without emulating OS keys.
func step_motor(delta: float, stick: Vector2, shift: bool, jump: bool) -> void:
	var s = animation_state
	var grounded_before := is_on_floor()
	s.was_grounded = s.is_grounded
	s.jump_started = jump and grounded_before
	s.takeoff_speed = Vector2(velocity.x, velocity.z).length() if s.jump_started else s.takeoff_speed
	s.move_input_magnitude = minf(stick.length(), 1.0)
	var forward := -camera.global_basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var right := camera.global_basis.x
	right.y = 0.0
	var direction := (right.normalized() * stick.x - forward * stick.y).normalized()
	s.move_direction_world = direction
	if not shift:
		_run_time = 0.0
		s.gait = State.Gait.WALK
	elif grounded_before and s.move_input_magnitude <= 0.01 and Vector2(velocity.x, velocity.z).length() < 0.1:
		_run_time = 0.0
		s.gait = State.Gait.RUN
	elif s.move_input_magnitude > 0.01:
		_run_time = minf(_run_time + delta, sprint_buildup_duration)
		s.gait = State.Gait.SPRINT if _run_time >= sprint_buildup_duration else State.Gait.RUN
	s.run_buildup_ratio = clampf(_run_time / maxf(sprint_buildup_duration, 0.001), 0.0, 1.0)
	target_speed = walk_speed
	if s.gait == State.Gait.RUN:
		target_speed = lerpf(run_start_speed, run_end_speed, s.run_buildup_ratio)
	elif s.gait == State.Gait.SPRINT:
		target_speed = sprint_speed
	var horizontal := Vector3(velocity.x, 0.0, velocity.z)
	if s.jump_started:
		velocity.y = jump_velocity
	if grounded_before and not s.jump_started:
		if direction.is_zero_approx():
			horizontal = horizontal.move_toward(Vector3.ZERO, deceleration * delta)
		else:
			var parallel := horizontal.dot(direction)
			var lateral := horizontal - direction * parallel
			var alignment := horizontal.normalized().dot(direction) if horizontal.length() > 0.1 else 1.0
			var rate := lerpf(turn_acceleration, acceleration, clampf(alignment, 0.0, 1.0))
			parallel = move_toward(parallel, target_speed * s.move_input_magnitude, rate * delta)
			horizontal = direction * parallel + lateral.move_toward(Vector3.ZERO, lateral_damping * delta)
	elif not direction.is_zero_approx() and not s.jump_started:
		horizontal = horizontal.move_toward(direction * target_speed * s.move_input_magnitude, acceleration * air_control * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	if horizontal.length() > 0.1:
		visual.rotation.y = lerp_angle(visual.rotation.y, atan2(-horizontal.x, -horizontal.z), 1.0 - exp(-turn_rate * delta))
	if not grounded_before or s.jump_started:
		velocity.y = maxf(velocity.y - (rise_gravity if velocity.y > 0.0 else fall_gravity) * delta, -max_fall_speed)
	else:
		velocity.y = -0.5
	move_and_slide()
	s.is_grounded = is_on_floor()
	s.is_airborne = not s.is_grounded
	s.horizontal_speed = Vector2(velocity.x, velocity.z).length()
	s.vertical_velocity = velocity.y
	s.is_falling = s.is_airborne and velocity.y < 0.0
	s.air_time = s.air_time + delta if s.is_airborne else 0.0

