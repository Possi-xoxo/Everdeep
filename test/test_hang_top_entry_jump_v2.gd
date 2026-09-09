extends "res://test/test_hang_top_entry_v2.gd"
func run() -> void:
	lab=load("res://test/player_v2_lab.tscn").instantiate()
	root.add_child(lab)
	body=lab.get_node("PlayerV2")
	animation=body.get_node("AnimationController"); tree=body.get_node("AnimationTree")
	cam=body.get_node("CameraRig"); crouch=body.crouch; hang=body.traversal.hang
	body.set_physics_process(false); animation.set_physics_process(false); cam.set_process(false)
	tree.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	box(Vector3(200,1.5,8),Vector3(8,3,4))
	await physics_frame
	for attempt in 2:
		await launch(Vector3(200,3,9.5))
		check(body.ground_support.has_ground_support,"starts on supported top")
		hang.top_entry.refresh()
		check(hang.top_entry.begin_interaction(body),"prompt top-down entry")
		for tick in 160: await crouch_tick(false)
		check(hang.running and hang.hang_phase==hang.HangPhase.IDLE,"settled top-entry hang")
		var outward: Vector3=hang.wall_normal
		await crouch_tick(false,Vector2.ZERO,false,true)
		check(hang.navigation.jumping and not hang.release_active,"Space selects jump, not release")
		for tick in 150:
			await crouch_tick(false)
			if not hang.navigation.jumping: break
		check(not hang.running and hang.exit_reason=="HANG_JUMP_OFF","authored departure launches")
		var launch_y: float=body.velocity.y
		var takeoff: Vector3=body.position
		await crouch_tick(false)
		print("TOP JUMP first air velocity ",body.velocity," support ",body.ground_support.has_ground_support)
		check(body.velocity.y>0 and body.velocity.y<launch_y,"first airborne tick retains upward impulse")
		check(body.velocity.dot(outward)>0,"outward impulse retained")
		check(hang.navigation.jump_visual,"jump animation remains active")
		for tick in 8: await crouch_tick(false)
		check(body.position.y>takeoff.y+.1,"jump rises instead of dropping")
	print("HANG_TOP_ENTRY_JUMP_V2: ","PASS" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)
