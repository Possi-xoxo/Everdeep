extends "res://test/test_hang_navigation_course_v2.gd"

func setup_transfer() -> void:
	lab=load("res://test/player_v2_lab.tscn").instantiate()
	root.add_child(lab)
	body=lab.get_node("PlayerV2")
	animation=body.get_node("AnimationController")
	tree=body.get_node("AnimationTree")
	cam=body.get_node("CameraRig")
	crouch=body.crouch
	hang=body.traversal.hang
	body.set_physics_process(false)
	animation.set_physics_process(false)
	cam.set_process(false)
	tree.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL

func run_transfer(side: int) -> Vector3:
	# A useful continuous remainder now takes priority. Consume it before
	# testing the unchanged remote-transfer path from the actual edge.
	for attempt in 2:
		if not hang.lateral.preview(hang,side,true).valid: break
		check(hang.lateral.request(hang,side,true),"continuous remainder before gap")
		for tick in 160:
			await crouch_tick(false)
			if not hang.lateral.active: break
	check(hang.navigation.resolve(hang,"LATERAL",side,true),"gap input accepted")
	check(hang.transfer.active and hang.lateral.active,"transfer uses lateral state")
	if not hang.transfer.active: return body.position
	var target: Vector3=hang.transfer.destination.anchor
	var source_id: int=hang.transfer.destination.source.get_instance_id()
	var saw_flight: bool=false
	for tick in 150:
		await crouch_tick(false,Vector2(side,0),true)
		if hang.transfer.active:
			check(body.position.distance_to(hang.lateral.expected_position)<.005,"authored trajectory followed")
			check(body.velocity==Vector3.ZERO,"no ordinary airborne physics")
			for arm in body.get_node("MantleHandIK").arms: check(arm.length_error<.005,"transfer preserves arm lengths")
			if hang.lateral.progress>.30 and hang.lateral.progress<.65:
				saw_flight=true
				for arm in body.get_node("MantleHandIK").arms: check(arm.weight<.001,"no mid-gap source hand pin")
				check(hang.transfer.contact_weight(hang,true)==0,"no mid-gap foot pin")
	check(saw_flight,"sampled authored flight phase")
	check(hang.running and not hang.transfer.active and hang.hang_phase==hang.HangPhase.IDLE,"stable arrival")
	check(body.position.distance_to(target)<.005 and hang.alignment.distance_to(target)<.005,"exact destination no held auto-chain")
	check(hang.source.get_instance_id()==source_id,"destination source ownership")
	check(hang.transfer.input_latched,"held transfer requires rearm")
	await crouch_tick(false)
	check(not hang.transfer.input_latched,"release rearms input")
	return target

func run() -> void:
	await setup_transfer()
	# Isolate the legacy straight-gap suite: A/D at this box end may now
	# legitimately turn its own outside corner, but never crosses the gap.
	hang.braced_hang_corners_enabled=false
	var source_wall=box(Vector3(200,1.5,-2),Vector3(4,3,4))
	var target_wall=box(Vector3(205,1.5,-2),Vector3(4,3,4))
	await physics_frame
	await catch_at(Vector3(201.5,1.1,.65))
	check(not hang.lateral.preview(hang,1,true).valid,"continuous hop fails at separate gap")
	print("TRANSFER QUERY ",hang.transfer.query(hang,1).reason)
	var original: Vector3=body.position
	check(not hang.navigation.resolve(hang,"LATERAL",1,false),"A/D cannot transfer")
	check(body.position.distance_to(original)<.001,"failed shimmy stays hanging")
	await run_transfer(1)
	check(hang.navigation.resolve(hang,"LATERAL",1,false),"transfer to shimmy")
	for tick in 130: await crouch_tick(false)
	await run_transfer(-1)
	# Elevated/lowered targets retain the same arc with middle/arrival bias.
	for height in [.25,-.25]:
		if hang.running: body.traversal.finish("FIXTURE_RESET")
		target_wall.position.y=1.5+height
		await physics_frame
		await catch_at(Vector3(201.5,1.1,.65))
		await run_transfer(1)
		check(absf(hang.top.y-(3+height))<.005,"vertical endpoint bias")
	if hang.running: body.traversal.finish("FIXTURE_RESET")
	target_wall.position.y=1.5
	await physics_frame
	await catch_at(Vector3(201.5,1.1,.65))
	hang.braced_hang_transfer_max_horizontal_distance=1.5
	check(not hang.navigation.resolve(hang,"LATERAL",1,true) and hang.running,"out of range safely rejected")
	hang.braced_hang_transfer_max_horizontal_distance=4.5
	check(not hang.navigation.resolve(hang,"LATERAL",1,true),"failed held input does not retry")
	await crouch_tick(false)
	hang.braced_hang_transfer_max_motion_scale=.5
	check(not hang.transfer.query(hang,1).valid,"excessive trajectory stretch rejected")
	hang.braced_hang_transfer_max_motion_scale=1.5
	target_wall.position.z=-2.6
	await physics_frame
	check(not hang.transfer.query(hang,1).valid,"outward wall transfer excluded")
	target_wall.position.z=-2
	target_wall.position.y=2
	await physics_frame
	check(not hang.transfer.query(hang,1).valid,"large vertical difference excluded")
	target_wall.position.y=1.5
	target_wall.rotation.y=deg_to_rad(25)
	await physics_frame
	check(not hang.transfer.query(hang,1).valid,"sharp rotated destination excluded")
	target_wall.rotation.y=0
	await physics_frame
	hang.braced_hang_transfer_min_gap=1.1
	check(not hang.transfer.query(hang,1).valid,"minimum real gap threshold enforced")
	hang.braced_hang_transfer_min_gap=.15
	var blocker=box(Vector3(202.5,2,.6),Vector3(.25,3,1.5))
	await physics_frame
	check(not hang.navigation.resolve(hang,"LATERAL",1,true) and hang.running,"blocked corridor rejected")
	blocker.queue_free()
	await physics_frame
	await crouch_tick(false)
	check(hang.navigation.resolve(hang,"LATERAL",1,true),"moving target test commits")
	target_wall.position.x+=.1
	await physics_frame
	await crouch_tick(false)
	check(not hang.running and not hang.transfer.active,"moved committed target aborts safely")
	target_wall.position.x-=.1
	await physics_frame
	await catch_at(Vector3(201.5,1.1,.65))
	check(hang.navigation.resolve(hang,"LATERAL",1,true),"retry commits")
	target_wall.queue_free()
	await physics_frame
	await crouch_tick(false)
	check(not hang.running and not hang.transfer.active and not hang.lateral.active,"target deletion abort clears ownership")
	source_wall.queue_free()
	print("HANG_TRANSFER_V2: ","PASS" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)
