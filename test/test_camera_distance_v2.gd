extends "res://test/test_lock_tuning_v2.gd"

func wheel(up: bool) -> void:
	var event:=InputEventMouseButton.new()
	event.button_index=MOUSE_BUTTON_WHEEL_UP if up else MOUSE_BUTTON_WHEEL_DOWN
	event.pressed=true
	cam._unhandled_input(event)

func run() -> void:
	root.size=Vector2i(1280,720)
	var lab=load("res://test/player_v2_lab.tscn").instantiate()
	root.add_child(lab)
	body=lab.get_node("PlayerV2")
	animation=body.get_node("AnimationController")
	tree=body.get_node("AnimationTree")
	lock=body.get_node("LockOnController")
	dummy=lab.get_node("LockOnTargetDummy")
	cam=body.get_node("CameraRig")
	body.set_physics_process(false)
	animation.set_physics_process(false)
	cam.set_process(false)
	tree.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	await settle(Vector3(0,0.1,18))
	var display: Label=body.get_node("UI/CameraDistanceDisplay")
	check(cam.camera_distance_level==5 and is_equal_approx(cam.selected_distance(),4.0),"default level five maps to four meters")
	check(not display.visible,"notification hidden at spawn")
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	var cursor_mode:=Input.mouse_mode
	# Real viewport dispatch, not just the helper boundary.
	var event:=InputEventMouseButton.new()
	event.button_index=MOUSE_BUTTON_WHEEL_DOWN
	event.pressed=true
	Input.parse_input_event(event)
	await process_frame
	check(cam.camera_distance_level==6,"real wheel down dispatched")
	check(Input.mouse_mode==cursor_mode,"wheel does not capture cursor")
	check(display.visible and display.text=="Camera Distance: 6","notification shows latest level")
	check(is_equal_approx(cam.arm.spring_length,4.0),"wheel never snaps SpringArm immediately")
	cam._process(DT)
	check(cam.arm.spring_length>4 and cam.arm.spring_length<4.5,"smooth distance step")
	cam._process(4.0)
	wheel(false)
	check(display.text=="Camera Distance: 7" and is_equal_approx(cam._display_remaining,5.0),"second change restarts timer")
	cam._process(4.9)
	check(display.visible,"display remains before five seconds")
	cam._process(0.11)
	check(not display.visible,"display hides after five seconds")
	for i in 20: wheel(true)
	check(cam.camera_distance_level==1 and is_equal_approx(cam.selected_distance(),2.0),"closest clamped endpoint")
	for i in 90: await tick()
	check(absf(cam.arm.spring_length-2.0)<0.001,"minimum free camera distance")
	check(body.camera.global_position.distance_to(body.global_position)>1.5,"close level stays outside player origin")
	cam.apply_mouse_motion(Vector2(40,0))
	var orbit_yaw: float=cam.yaw.rotation.y
	for i in 30: wheel(false)
	check(cam.camera_distance_level==10 and is_equal_approx(cam.selected_distance(),6.5),"maximum clamped endpoint")
	check(cam.yaw.rotation.y==orbit_yaw,"zoom does not change free orbit")
	cam._process(1.0)
	var remaining: float=cam._display_remaining
	wheel(false)
	check(is_equal_approx(remaining,cam._display_remaining),"clamped input is not a level change")
	for i in 90: await tick()
	check(absf(cam.arm.spring_length-6.5)<0.001,"maximum free camera distance")
	for resolution in [Vector2i(1280,720),Vector2i(1920,1080),Vector2i(800,600)]:
		root.size=resolution
		await process_frame
		var rect:=display.get_global_rect()
		var viewport_size:=root.get_visible_rect().size
		print("CAMERA_TOAST window=",resolution," canvas=",viewport_size," rect=",rect)
		check(absf(rect.end.x-(viewport_size.x-24))<1.0 and absf(rect.position.y-20)<1.0,"notification anchors top right")
	root.size=Vector2i(1280,720)
	# Same selected level in Locked and Free; lock framing survives zoom.
	cam.yaw.rotation.y=0
	dummy.position=Vector3(0,0,8)
	lock.toggle()
	check(lock.is_locked(),"lock for zoom test")
	for level in [1,10,3,8]:
		cam.camera_distance_level=level
		for i in 90: await tick()
		check(absf(cam.arm.spring_length-cam.selected_distance())<0.001,"shared locked distance level")
		check((body.camera.global_position-body.position).dot(lock.direction())< -1.5,"zoom keeps camera behind player")
		check(not body.camera.is_position_behind(lock.point()),"zoom keeps target ahead")
		check(Rect2(Vector2.ZERO,root.size).has_point(body.camera.unproject_position(lock.point())),"target framed at zoom levels")
	cam.lock_camera_distance_multiplier=1.1
	for i in 90: await tick()
	check(absf(cam.arm.spring_length-cam.selected_distance()*1.1)<0.001,"optional lock multiplier honors selected distance")
	cam.lock_camera_distance_multiplier=1.0
	cam.camera_distance_level=10
	var wall:=StaticBody3D.new()
	var collision:=CollisionShape3D.new()
	var shape:=BoxShape3D.new()
	shape.size=Vector3(8,6,0.4)
	collision.shape=shape
	wall.add_child(collision)
	lab.add_child(wall)
	wall.position=body.position+Vector3(0,2,2)
	for i in 90: await tick()
	check(cam.arm.get_hit_length()<2 and cam.camera_distance_level==10,"collision retracts without changing preference")
	check(absf(cam.arm.spring_length-6.5)<0.001,"collision leaves requested arm length intact")
	wall.free()
	for i in 90: await tick()
	check(cam.arm.get_hit_length()>6.4 and cam.camera_distance_level==10,"obstruction removal restores selected distance")
	lock.clear()
	for i in 90: await tick()
	check(cam.camera_distance_level==10 and absf(cam.arm.spring_length-6.5)<0.001,"unlock preserves zoom preference")
	cam.camera_distance_min=2.5
	cam.camera_distance_max=7.0
	cam.camera_distance_level=1
	check(is_equal_approx(cam.selected_distance(),2.5),"Inspector minimum")
	cam.camera_distance_level=10
	check(is_equal_approx(cam.selected_distance(),7.0),"Inspector maximum")
	print("CAMERA_DISTANCE_V2: ","PASS" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)
