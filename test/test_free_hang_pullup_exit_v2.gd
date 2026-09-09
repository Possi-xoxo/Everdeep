extends "res://test/test_free_hang_moves_v2.gd"

func run() -> void:
	await setup_transfer()
	var f=body.traversal.free_hang
	box(Vector3(200,2.875,-2),Vector3(8,.25,4))
	box(Vector3(200,-.1,1),Vector3(16,.2,12))
	await physics_frame
	for scenario in ["STANDING","CROUCH","LOW_CEILING","MOVING","ABORT"]:
		body.crouch.requested=scenario=="CROUCH"
		await free_catch(Vector3(200,1.1,.65),Vector3(0,-2,-2))
		for i in 100: await crouch_tick(body.crouch.requested)
		var ceiling: Node3D
		if scenario=="LOW_CEILING":
			ceiling=box(Vector3(200,4.5,-2),Vector3(8,.2,4))
			await physics_frame
		await crouch_tick(body.crouch.requested,Vector2.UP)
		check(f.actions.active,"pull-up begins "+scenario)
		if not f.actions.active: continue
		check(cam.traversal_camera_mode=="FREE_HANG_PULLUP_HOLD","Free pull-up owns camera")
		var expected: float=maxf(hang.landing_setback,body.ground_support.minimum_landing_setback())
		check(absf(f.actions.destination.anchor.z+expected)<.001,"same near-edge setback as Braced")
		print("FREE PULLUP SETBACK ",expected)
		var anchor: Vector3=cam.global_position
		var target: Vector3=cam.mantle_camera_target
		var saved: Vector3=body.position
		body.position+=Vector3(.04,.06,.02)
		cam._process(0)
		check(cam.global_position.distance_to(anchor)<.0001,"camera independent of capsule correction")
		check(cam.mantle_camera_target.distance_to(target)<.0001,"camera target stays fixed to clip/landing")
		body.position=saved
		var yaw_before: float=cam.yaw.rotation.y
		cam.apply_mouse_motion(Vector2(10,0))
		check(absf(cam.yaw.rotation.y-yaw_before)>.001,"orbit preserved")
		if scenario=="ABORT":
			for i in 30: await crouch_tick(body.crouch.requested)
			body.traversal.finish("TEST_ABORT")
		else:
			for i in 240:
				await crouch_tick(body.crouch.requested,Vector2.UP if scenario=="MOVING" else Vector2.ZERO)
				if not f.running: break
			check(not f.running and body.ground_support.has_ground_support,"supported completion "+scenario)
			check(body.crouch.requested==(scenario in ["CROUCH","LOW_CEILING"]),"restore posture / low-ceiling safety "+scenario)
			var wanted: StringName=&"Locomotion" if scenario in ["STANDING","MOVING"] else &"CrouchIdle"
			if scenario=="MOVING": check(body.animation_state.move_input_magnitude>.01,"moving input resumes on completion tick")
			check(animation.current_state==wanted,"direct restored exit state "+scenario)
			for index in tree.tree_root.get_transition_count():
				if tree.tree_root.get_transition_from(index)==&"FreeHangClimb" and tree.tree_root.get_transition_to(index)==wanted:
					check(is_equal_approx(tree.tree_root.get_transition(index).xfade_time,body.traversal.mantle.mantle_exit_blend_time),"shared pull-up exit blend")
		cam._process(DT)
		check(cam.traversal_camera_mode=="REJOIN","completion/abort releases camera hold")
		for i in 180: await crouch_tick(body.crouch.requested)
		check(not cam.mantle_camera_active,"camera fully reconnects")
		check(cam.global_position.distance_to(body.to_global(cam._base_position))<.002,"no residual camera offset")
		if is_instance_valid(ceiling):
			ceiling.queue_free()
			await physics_frame
	print("FREE PULLUP EXIT ","PASS" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)
