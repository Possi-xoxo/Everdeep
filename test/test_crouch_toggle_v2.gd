extends "res://test/test_crouch_v2.gd"

func input_tick(press: bool = false, release: bool = false) -> void:
	await physics_frame
	if press: Input.action_press("crouch")
	if release: Input.action_release("crouch")
	body._physics_process(DT)
	animation._physics_process(DT)
	tree.advance(DT)
	cam._process(DT)
	await process_frame

func run() -> void:
	lab=load("res://test/player_v2_lab.tscn").instantiate()
	root.add_child(lab)
	body=lab.get_node("PlayerV2")
	animation=body.get_node("AnimationController")
	tree=body.get_node("AnimationTree")
	lock=body.get_node("LockOnController")
	dummy=lab.get_node("LockOnTargetDummy")
	cam=body.get_node("CameraRig")
	dodge=body.dodge
	assist=body.roll_traversal
	crouch=body.get_node("CrouchController")
	body.set_physics_process(false)
	animation.set_physics_process(false)
	cam.set_process(false)
	tree.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	box(Vector3(200,-.25,0),Vector3(80,.5,80))
	await reset_at(Vector3(200,.1,10))
	await input_tick(true)
	for frame in 10: await input_tick()
	check(crouch.requested,"held press toggles only once")
	await input_tick(false,true)
	for frame in 80: await input_tick()
	check(crouch.requested and animation.current_state==&"CrouchIdle","release preserves crouch")
	await input_tick(true)
	await input_tick(false,true)
	for frame in 80: await input_tick()
	check(not crouch.requested and not crouch.active(),"second press stands")
	await input_tick(true)
	await input_tick(false,true)
	for frame in 80: await input_tick()
	var ceiling:=box(Vector3(200,1.45,10),Vector3(5,.3,8))
	for frame in 5: await input_tick()
	await input_tick(true)
	await input_tick(false,true)
	for frame in 80: await input_tick()
	check(not crouch.requested and crouch.active() and not crouch.can_stand,"off request waits under ceiling")
	ceiling.queue_free()
	for frame in 90: await input_tick()
	check(not crouch.active(),"stands once clearance returns")
	print("CROUCH TOGGLE PASS" if failures.is_empty() else str(failures))
	quit(0 if failures.is_empty() else 1)
