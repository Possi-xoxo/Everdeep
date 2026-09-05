extends Node3D
@export var sensitivity: float = 0.12
@export var minimum_pitch: float = -55.0
@export var maximum_pitch: float = 65.0
@export var distance: float = 4.5
@onready var yaw: Node3D = $YawPivot
@onready var pitch: Node3D = $YawPivot/PitchPivot
@onready var arm: SpringArm3D = $YawPivot/PitchPivot/SpringArm3D

func _ready() -> void:
	arm.add_excluded_object(get_parent().get_rid())
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _process(_delta: float) -> void:
	arm.spring_length = distance

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseButton and event.pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		yaw.rotate_y(deg_to_rad(-event.relative.x * sensitivity))
		pitch.rotation.x = clampf(pitch.rotation.x - deg_to_rad(event.relative.y * sensitivity), deg_to_rad(minimum_pitch), deg_to_rad(maximum_pitch))

