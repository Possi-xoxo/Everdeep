extends RefCounted
## Written once after move_and_slide by the motor; read-only to presentation.
enum Gait { WALK, RUN, SPRINT }
var horizontal_speed: float = 0.0
var vertical_velocity: float = 0.0
var is_grounded: bool = false
var was_grounded: bool = false
var is_airborne: bool = true
var is_falling: bool = false
var jump_started: bool = false
var takeoff_speed: float = 0.0
var move_input_magnitude: float = 0.0
var gait: Gait = Gait.WALK
var run_buildup_ratio: float = 0.0
var air_time: float = 0.0
var move_direction_world: Vector3 = Vector3.ZERO
## Actual travel relative to visual facing: +Y forward, +X right.
var move_local: Vector2 = Vector2.ZERO
var facing_delta: float = 0.0
var allowed_move_direction_world: Vector3 = Vector3.ZERO
var turn_arc_active: bool = false
## Pre-turn angles for the current acceleration target, in radians.
var desired_turn_angle: float = 0.0
var allowed_move_delta: float = 0.0
