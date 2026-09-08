extends "res://test/test_braced_hang_v2.gd"

func actual_input(action: String="", pressed: bool=false) -> void:
	if not action.is_empty():
		if pressed: Input.action_press(action)
		else: Input.action_release(action)
	await physics_frame
	body._physics_process(DT)
	animation._physics_process(DT)
	tree.advance(DT)
	cam._process(DT)
	await process_frame

func catch_fixture() -> void:
	await air_setup()
	await crouch_tick(false)
	check(hang.running,"automatic catch fixture")

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
	crouch=body.crouch
	hang=body.traversal.hang
	body.set_physics_process(false)
	animation.set_physics_process(false)
	cam.set_process(false)
	tree.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	var floor_box=box(Vector3(200,-.25,10),Vector3(20,.5,20))
	var wall=box(Vector3(200,1,8.35),Vector3(4,4,2))
	await physics_frame
	var release_clip: Animation=animation.player.get_animation(hang.RELEASE_CLIP)
	check(is_equal_approx(release_clip.length,.30) and release_clip.loop_mode==Animation.LOOP_NONE,"only .3s release segment, no baked landing")
	await catch_fixture()
	await actual_input("move_forward",true)
	check(hang.hang_phase==hang.HangPhase.SETTLE,"W cannot skip settle")
	await actual_input("move_forward",false)
	await actual_input("move_backward",true)
	check(hang.running and not hang.release_active,"S cannot skip settle")
	for frame in 25: await actual_input()
	check(hang.hang_phase==hang.HangPhase.IDLE,"holding S through settle does not release")
	await actual_input("move_backward",false)
	await actual_input("move_forward",true)
	check(hang.hang_phase==hang.HangPhase.TO_CROUCH and hang.climb_destination_valid,"real W begins validated climb up")
	await actual_input("move_forward",false)
	for frame in 110: await actual_input()
	check(body.ground_support.has_ground_support and not crouch.requested and crouch.phase==crouch.Phase.STANDING,"W returns to prior standing locomotion")
	for frame in 40: await actual_input()
	for frame in 90: await crouch_tick(false,Vector2(0,1))
	for frame in 45: await crouch_tick(false)
	check(body.ground_support.has_ground_support,"walk off top and land without reset")
	for frame in 50: await crouch_tick(false,Vector2(0,-1))
	for frame in 90:
		await crouch_tick(false,Vector2(0,-1),false,frame==0)
		if hang.running: break
	check(hang.running,"climb-crouch-return-jump-recatch without reset")
	await catch_fixture()
	for frame in 20: await actual_input()
	var blocker=box(Vector3(200,3.6,8.85),Vector3(3,1,1))
	await physics_frame
	await actual_input("move_forward",true)
	check(hang.hang_phase==hang.HangPhase.IDLE and not hang.climb_destination_valid,"blocked W stays hanging")
	await actual_input("move_forward",false)
	blocker.queue_free()
	var anchor: Vector3=body.position
	var land_count: int=animation.landing_count
	await actual_input("move_backward",true)
	check(not hang.running and not body.traversal.is_traversing and hang.release_active,"S detaches immediately")
	check(hang.hang_phase==hang.HangPhase.RELEASE and animation.current_state==&"HangRelease","release phase and clip")
	check(body.velocity.y<0 and body.position.y<anchor.y,"gravity resumes immediately")
	check(not body.animation_state.jump_started,"release press does not jump")
	check(hang.release_velocity.is_equal_approx(Vector3(0,-.2,.35)),"subtle impulse, no restored incoming momentum")
	for arm in body.get_node("MantleHandIK").arms: check(arm.weight>.5 and arm.weight<1,"release grip fades instead of instantly popping off")
	for frame in 70:
		if frame==10: Input.action_release("move_backward")
		await actual_input()
		check(not hang.running,"same ledge cannot recatch on release")
		check(not body.animation_state.jump_started,"held S does not retrigger jump")
	check(body.ground_support.has_ground_support and animation.landing_count==land_count+1,"normal landing after release")
	await actual_input("move_backward",false)
	check(not hang.release_suppression_active,"separation clears suppression")
	# Walk back toward the same wall and jump again, without fixture/reset.
	for frame in 24: await crouch_tick(false,Vector2(0,-1))
	for frame in 80:
		await crouch_tick(false,Vector2(0,-1),false,frame==0)
		if hang.running: break
	check(hang.running,"release-land-jump-recatch without reset")
	for frame in 20: await actual_input()
	await actual_input("move_backward",true)
	await actual_input("move_backward",false)
	# Other ledges remain eligible during suppression. Shift fixture laterally
	# for a deterministic candidate query without advancing separation timers.
	var other=box(Vector3(206,1,8.35),Vector3(4,4,2))
	await physics_frame
	body.position=Vector3(206,1.1,10)
	body.velocity=Vector3(0,-1,-2)
	check(hang.release_suppression_active and hang.detect().valid,"different ledge allowed during same-ledge suppression")
	check(hang.try_catch(DT),"different ledge automatically caught")
	check(hang.source==other and not hang.release_active,"new catch owns animation instead of release tail")
	for frame in 20: await actual_input()
	# New safety policy: S must not release when there is no safe floor.
	floor_box.queue_free()
	await physics_frame
	await actual_input("move_backward",true)
	await actual_input("move_backward",false)
	for frame in 30: await actual_input()
	check(hang.running and not hang.release_active and animation.current_state==&"HangIdle" and body.velocity.is_zero_approx(),"large drop S stays safely hanging")
	check(not body.ground_support.has_ground_support,"no authored phantom landing")
	print("HANG_EXITS_V2: ","PASS" if failures.is_empty() else str(failures))
	quit(0 if failures.is_empty() else 1)
