class_name EverdeepPlayerCamera
extends Node3D

@export_category("Camera")
@export_range(0.01, 1.0, 0.01) var mouse_sensitivity: float = 0.12
@export_range(-89.0, 0.0, 1.0) var minimum_pitch_degrees: float = -55.0
@export_range(0.0, 89.0, 1.0) var maximum_pitch_degrees: float = 65.0
@export_range(1.0, 12.0, 0.1) var camera_distance: float = 4.5
@export_range(0.5, 4.0, 0.1) var pivot_height: float = 1.55

@onready var yaw_pivot: Node3D = $YawPivot
@onready var pitch_pivot: Node3D = $YawPivot/PitchPivot
@onready var spring_arm: SpringArm3D = $YawPivot/PitchPivot/SpringArm3D

var _pitch_radians: float = deg_to_rad(-12.0)


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	position.y = pivot_height
	spring_arm.spring_length = camera_distance
	_pitch_radians = clampf(pitch_pivot.rotation.x, _minimum_pitch(), _maximum_pitch())
	pitch_pivot.rotation.x = _pitch_radians


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		get_viewport().set_input_as_handled()
		return

	if event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		get_viewport().set_input_as_handled()
		return

	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		yaw_pivot.rotate_y(deg_to_rad(-event.relative.x * mouse_sensitivity))
		_pitch_radians = clampf(
			_pitch_radians + deg_to_rad(-event.relative.y * mouse_sensitivity),
			_minimum_pitch(),
			_maximum_pitch()
		)
		pitch_pivot.rotation.x = _pitch_radians
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	# Inspector changes remain live while testing in the editor.
	position.y = pivot_height
	spring_arm.spring_length = camera_distance


func _minimum_pitch() -> float:
	return deg_to_rad(minf(minimum_pitch_degrees, maximum_pitch_degrees))


func _maximum_pitch() -> float:
	return deg_to_rad(maxf(minimum_pitch_degrees, maximum_pitch_degrees))
