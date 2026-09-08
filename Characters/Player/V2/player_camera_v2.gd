extends Node3D
@export var sensitivity: float = 0.12
@export var minimum_pitch: float = -55.0
@export var maximum_pitch: float = 65.0
@export_category("Camera Distance Levels")
@export_range(1,10,1) var camera_distance_level: int = 5:
	set(value):
		var level:=clampi(value,1,10)
		if camera_distance_level==level: return
		camera_distance_level=level
		if is_node_ready(): _show_distance_level()
@export_range(0.5,20,0.1) var camera_distance_min: float = 2.0
@export_range(0.5,20,0.1) var camera_distance_max: float = 6.5
@export_range(1,30,0.5) var camera_distance_smoothing: float = 12.0
@export_range(0.1,20,0.1) var camera_distance_display_duration: float = 5.0
var distance_target: float = 4.0
var _display_remaining: float = 0.0
@export_category("Lock-On Camera")
@export_range(0.5,1.5,0.05) var lock_camera_distance_multiplier: float = 1.0
@export_range(0.5,3,0.05) var lock_camera_height: float = 2.0
@export_range(-2,2,0.05) var lock_camera_target_height_bias: float = 0.0
@export_range(1,30,0.5) var lock_camera_position_smoothing: float = 8.0
@export_range(1,30,0.5) var lock_camera_rotation_smoothing: float = 12.0
@export_range(0,1,0.01) var lock_camera_enter_blend_time: float = 0.25
@export_range(0,1,0.01) var lock_camera_exit_blend_time: float = 0.25
@export_range(0.0,1.0,0.01) var lock_camera_target_weight: float = 0.65
@export_range(5,75,1) var lock_camera_max_pitch_up: float = 40.0
@export_range(5,75,1) var lock_camera_max_pitch_down: float = 45.0
var _base_position := Vector3.ZERO
var _smooth_origin := Vector3.ZERO
var _lock_weight: float = 0.0
var _was_locked: bool = false
var mantle_camera_active: bool = false
var mantle_camera_target := Vector3.ZERO
var _mantle_origin := Vector3.ZERO
var _mantle_start := Vector3.ZERO
var _mantle_tracking: bool = false
var traversal_camera_mode: String = "NORMAL"
var _hang_camera_top := Vector3.ZERO
var _free_shape: Shape3D
var _lock_shape := SphereShape3D.new()
@onready var yaw: Node3D = $YawPivot
@onready var pitch: Node3D = $YawPivot/PitchPivot
@onready var arm: SpringArm3D = $YawPivot/PitchPivot/SpringArm3D
@onready var distance_display: Label = $"../UI/CameraDistanceDisplay"

func _ready() -> void:
	distance_target=selected_distance()
	arm.spring_length=distance_target
	_base_position=position
	_free_shape=arm.shape
	_lock_shape.radius=0.12
	_smooth_origin=global_position
	arm.add_excluded_object(get_parent().get_rid())
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _process(delta: float) -> void:
	var motor=get_parent()
	var lock=motor.get_node("LockOnController")
	var locked: bool=lock.is_locked()
	if locked and not _was_locked: _smooth_origin=global_position
	var duration:=lock_camera_enter_blend_time if locked else lock_camera_exit_blend_time
	_lock_weight=move_toward(_lock_weight,1.0 if locked else 0.0,delta/maxf(duration,0.001))
	var weight:=smoothstep(0,1,_lock_weight)
	var free_origin: Vector3=motor.to_global(_base_position)
	var mantle=motor.traversal.mantle
	var hang=motor.traversal.hang
	# Commitment owns the motor during ENTRY, but the animation controller
	# starts Mantle only in ACTIVE. Keep ordinary follow through alignment.
	var climb_tracking: bool=mantle.running and motor.traversal.phase==motor.traversal.Phase.ACTIVE
	var hang_tracking: bool=hang.running and hang.hang_phase==hang.HangPhase.TO_CROUCH and motor.traversal.phase==motor.traversal.Phase.ACTIVE
	var tracking: bool=climb_tracking or hang_tracking
	if tracking and not _mantle_tracking:
		_mantle_start=free_origin
		_mantle_origin=global_position
		if hang_tracking: _hang_camera_top=hang.landing+Vector3.UP*(_base_position.y+mantle.mantle_camera_top_offset)
		mantle_camera_active=true
	if mantle_camera_active:
		if tracking:
			var weight_top:=smoothstep(12,50,mantle.current_frame())
			# World-space anchor independent of instantaneous capsule lift.
			var top_anchor: Vector3=mantle.landing+Vector3.UP*(_base_position.y+mantle.mantle_camera_top_offset)
			if hang_tracking:
				# Validated destination + animation clock only, never capsule/IK
				# corrections. Reuse climb's easing, response and reunion below.
				top_anchor=_hang_camera_top
				weight_top=smoothstep(0,1,hang.progress)
			mantle_camera_target=_mantle_start.lerp(top_anchor,weight_top)
		else:
			mantle_camera_target=free_origin
		var speed: float=mantle.mantle_camera_follow_speed if tracking else mantle.mantle_camera_return_speed
		_mantle_origin=_mantle_origin.lerp(mantle_camera_target,1-exp(-speed*delta))
		if not tracking and _mantle_origin.distance_to(free_origin)<.002:
			mantle_camera_active=false
		else:
			free_origin=_mantle_origin
	_mantle_tracking=tracking
	traversal_camera_mode="HANG_PULLUP_HOLD" if hang_tracking else ("CLIMB" if climb_tracking else ("REJOIN" if mantle_camera_active else ("HANG" if hang.is_attached() else "NORMAL")))
	var locked_origin: Vector3=motor.global_position+Vector3.UP*lock_camera_height
	_smooth_origin=_smooth_origin.lerp(locked_origin,1-exp(-lock_camera_position_smoothing*delta))
	global_position=free_origin.lerp(_smooth_origin,weight)
	distance_target=selected_distance()*lerpf(1.0,lock_camera_distance_multiplier,weight)
	arm.spring_length=lerpf(arm.spring_length,distance_target,1-exp(-maxf(camera_distance_smoothing,0.01)*delta))
	_display_remaining=maxf(0.0,_display_remaining-delta)
	distance_display.visible=_display_remaining>0.0
	# Keep the same SpringArm sweep. A small locked-camera volume protects
	# its origin as well as the near plane; restore Free's original shape.
	arm.shape=_lock_shape if _lock_weight>0 else _free_shape
	if locked:
		var look_target: Vector3=(motor.global_position+Vector3.UP*1.55).lerp(lock.point()+Vector3.UP*lock_camera_target_height_bias,lock_camera_target_weight)
		var offset: Vector3=look_target-global_position
		var horizontal:=Vector2(offset.x,offset.z).length()
		var direction: Vector3=lock.direction()
		var wanted_yaw:=atan2(-direction.x,-direction.z)
		var wanted_pitch:=clampf(atan2(offset.y,maxf(horizontal,0.1)),-deg_to_rad(lock_camera_max_pitch_down),deg_to_rad(lock_camera_max_pitch_up))
		var response: float=(1-exp(-lock_camera_rotation_smoothing*delta))*weight
		yaw.global_rotation.y=lerp_angle(yaw.global_rotation.y,wanted_yaw,response)
		pitch.rotation.x=lerp_angle(pitch.rotation.x,wanted_pitch,response)
	# On unlock keep the current view angles; mouse resumes from this view,
	# while anchor/distance blend back. Never restore a stale pre-lock yaw.
	_was_locked=locked

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
		camera_distance_level+=-1 if event.button_index==MOUSE_BUTTON_WHEEL_UP else 1
		get_viewport().set_input_as_handled()
		return # Scrolling never captures a released mouse cursor.
	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseButton and event.pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		apply_mouse_motion(event.relative)

func apply_mouse_motion(relative: Vector2) -> void:
	if get_parent().get_node("LockOnController").is_locked(): return
	yaw.rotate_y(deg_to_rad(-relative.x * sensitivity))
	pitch.rotation.x = clampf(pitch.rotation.x - deg_to_rad(relative.y * sensitivity), deg_to_rad(minimum_pitch), deg_to_rad(maximum_pitch))

func debug_text() -> String:
	return "LOCK CAMERA\nMode: %s / Blend: %.2f\nLevel: %d / Target Distance: %.2f\nSpringArm: %.2f / Collision Length: %.2f\nAnchor Height: %.2f / Target Weight: %.2f\nTraversal: %s / Anchor %s / Target %s" % ["LOCKED" if _was_locked else "FREE",_lock_weight,camera_distance_level,distance_target,arm.spring_length,arm.get_hit_length(),lock_camera_height,lock_camera_target_weight,traversal_camera_mode,_mantle_origin,mantle_camera_target]

func selected_distance() -> float:
	var minimum:=maxf(0.1,camera_distance_min)
	var maximum:=maxf(minimum,camera_distance_max)
	return lerpf(minimum,maximum,float(camera_distance_level-1)/9.0)

func _show_distance_level() -> void:
	distance_display.text="Camera Distance: %d" % camera_distance_level
	_display_remaining=maxf(camera_distance_display_duration,0.0)
	distance_display.visible=_display_remaining>0.0
