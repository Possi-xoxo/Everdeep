extends Node3D
## Scene-local development reset, not a gameplay checkpoint system.
const PLAYER = preload("res://Characters/Player/V2/player_v2.tscn")
@export var fall_reset_y: float = -6.0
var player: CharacterBody3D
var current_course: StringName = &"Hub"
var _reset_pending: bool = false

func _ready() -> void:
	restart_attempt()

func request_reset(course: StringName = current_course) -> void:
	if _reset_pending: return
	if course!=&"Hub" and not has_node("Courses/"+String(course)): return
	current_course=course
	_reset_pending=true
	call_deferred("restart_attempt")

func restart_attempt() -> void:
	# Fresh instance reliably clears traversal ownership, animation, IK targets,
	# coyote state and all action timers, including resets during a committed climb.
	if is_instance_valid(player):
		remove_child(player)
		player.queue_free()
	var marker: Marker3D=$HubStart if current_course==&"Hub" else get_node("Courses/"+String(current_course)+"/Start")
	player=PLAYER.instantiate()
	player.name="PlayerV2"
	player.position=to_local(marker.global_position)
	add_child(player)
	var yaw: float=marker.global_rotation.y-global_rotation.y
	player.visual.rotation.y=yaw
	player.get_node("CameraRig/YawPivot").rotation.y=yaw
	_reset_pending=false

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo: return
	match event.physical_keycode:
		KEY_R: request_reset()
		KEY_HOME: request_reset(&"Hub")
		KEY_1: request_reset(&"Vertical")
		KEY_2: request_reset(&"Speed")
		KEY_3: request_reset(&"Mixed")
		KEY_4: request_reset(&"Hang")
		_: return
	get_viewport().set_input_as_handled()

func _physics_process(_delta: float) -> void:
	if not is_instance_valid(player) or _reset_pending: return
	if player.global_position.y<fall_reset_y:
		request_reset()
		return
	# Walking into a branch selects its start without teleporting the player.
	for course in $Courses.get_children():
		var local: Vector3=course.to_local(player.global_position)
		if absf(local.x)<2.9 and local.z<-.2 and local.z>-5.5 and local.y>-.1 and local.y<1:
			current_course=course.name
