extends "res://test/test_held_climb_v2.gd"
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
	detector=body.traversal.get_node("LedgeDetector")
	body.set_physics_process(false)
	animation.set_physics_process(false)
	cam.set_process(false)
	tree.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	box(Vector3(200,-.25,0),Vector3(80,.5,80))
	for mode in ["FAR_IDLE","FAR_MOVING","CLOSE","HELD"]:
		await ready_fixture()
		body.position.z=9.35+(.55 if mode=="CLOSE" else (3.2 if mode=="HELD" else 2.45))
		cam._process(DT)
		body.context_interaction.tick(false,false)
		if mode=="HELD":
			for tick in 150:
				await held_tick(Vector2(0,-1),true,false,true)
				if body.traversal.is_traversing: break
		else:
			body.velocity=Vector3(0,0,-3) if mode=="FAR_MOVING" else Vector3.ZERO
			body.context_interaction.scan()
			check(body.context_interaction.activate_selected(),"camera fixture accepts "+mode)
		var saw_entry:=false
		var saw_active:=false
		var previous: Vector3=cam.global_position
		var yaw: float=cam.yaw.rotation.y
		for tick in 300:
			await crouch_tick(false)
			if body.traversal.phase==body.traversal.Phase.ENTRY:
				saw_entry=true
				check(not cam.mantle_camera_active and not cam._mantle_tracking,"no early mantle camera "+mode)
				check(cam.global_position.distance_to(body.to_global(cam._base_position))<.001,"normal player-relative approach follow "+mode)
			if body.traversal.phase==body.traversal.Phase.ACTIVE:
				saw_active=true
				check(cam.mantle_camera_active and cam._mantle_tracking,"camera starts with ACTIVE "+mode)
				check(animation.current_state==&"Mantle","same authoritative phase starts animation")
			check(cam.global_position.distance_to(previous)<.2,"bounded camera transition")
			check(absf(cam.yaw.rotation.y-yaw)<.001,"camera yaw unchanged")
			previous=cam.global_position
			if not body.traversal.is_traversing: break
		check(saw_entry and saw_active,"observed approach and animation "+mode)
		check(body.traversal.last_end_reason=="COMPLETED","camera fixture completes")
		for tick in 120: await crouch_tick(false)
		check(not cam.mantle_camera_active,"existing return completes")
	for blocked in [false,true]:
		await ready_fixture()
		body.context_interaction.tick(false,false)
		body.position.z=11.8
		cam._process(DT)
		body.context_interaction.scan()
		check(body.context_interaction.activate_selected(),"pre-animation cancellation setup")
		var beam: StaticBody3D
		if blocked: beam=box(Vector3(200,1.65,10.7),Vector3(2,.2,.4))
		else: body.traversal.request_traversal_interrupt(body.traversal.Interrupt.DODGE)
		for tick in 90:
			await crouch_tick(false)
			check(not cam.mantle_camera_active,"cancelled approach never acquires climb camera")
			if not body.traversal.is_traversing: break
		check(not body.traversal.is_traversing,"approach cancelled safely")
		if is_instance_valid(beam): beam.queue_free()
	print("CLIMB_CAMERA_ENTRY_V2: ","PASS" if failures.is_empty() else str(failures))
	quit(0 if failures.is_empty() else 1)
