extends "res://test/test_braced_hang_v2.gd"

func run() -> void:
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
	box(Vector3(200,-.25,10),Vector3(30,.5,30))
	box(Vector3(200,1,8.35),Vector3(4,4,2))
	for scenario in ["COMPLETE","REPEAT","BLOCKED","RELEASE","ABORT"]:
		await air_setup()
		check(hang.try_catch(DT),"camera fixture catch")
		for frame in 30: await crouch_tick(false)
		check(not cam.mantle_camera_active,"idle keeps normal camera")
		if scenario=="BLOCKED":
			var beam=box(Vector3(200,3.6,9.1),Vector3(2,1,1))
			await physics_frame
			check(not hang.request_up(),"blocked destination rejects")
			cam._process(DT)
			check(not cam.mantle_camera_active,"blocked attempt never holds camera")
			beam.queue_free()
			hang.request_release()
		elif scenario=="RELEASE":
			check(hang.request_release(),"release accepted")
			cam._process(DT)
			check(not cam.mantle_camera_active,"release never holds camera")
		else:
			check(hang.request_up(),"pull-up commits")
			cam._process(DT)
			check(cam.traversal_camera_mode=="HANG_PULLUP_HOLD","committed pull-up owns camera")
			var position_before: Vector3=body.position
			var anchor_before: Vector3=cam.global_position
			var target_before: Vector3=cam.mantle_camera_target
			body.position+=Vector3(.05,.05,.05)
			cam._process(0)
			check(cam.global_position.distance_to(anchor_before)<.00001,"body correction cannot shift held anchor")
			check(cam.mantle_camera_target.distance_to(target_before)<.00001,"target independent of body correction")
			body.position=position_before
			var yaw_before: float=cam.yaw.rotation.y
			cam.apply_mouse_motion(Vector2(10,0))
			check(absf(cam.yaw.rotation.y-yaw_before)>.001,"orbit remains available")
			if scenario=="ABORT":
				for frame in 30: await crouch_tick(crouch.requested)
				body.traversal.finish("CAMERA_TEST_ABORT")
			else:
				for frame in 130:
					await crouch_tick(crouch.requested)
					if body.traversal.phase==body.traversal.Phase.EXIT: break
				check(body.ground_support.has_ground_support,"reunion begins at supported destination")
			cam._process(DT)
			check(cam.traversal_camera_mode=="REJOIN","completion or interruption releases hold")
		for frame in 180: await crouch_tick(crouch.requested)
		check(not cam.mantle_camera_active,"reunion cleans up")
		check(cam.global_position.distance_to(body.to_global(cam._base_position))<.002,"no residual camera offset")
	print("HANG_CAMERA_V2: ","PASS" if failures.is_empty() else str(failures))
	quit(0 if failures.is_empty() else 1)
