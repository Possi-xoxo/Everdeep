extends "res://test/test_hang_vertical_v2.gd"
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
	var wall:=StaticBody3D.new()
	root.add_child(wall)
	add_shape(wall,Vector3(200,3,8.27),Vector3(18,6,2))
	add_shape(wall,Vector3(200,1.5,8.35),Vector3(18,3,2))
	for height in [3.0,4.0,5.0,6.0]: add_shape(wall,Vector3(200,height-.09,8.35),Vector3(18,.18,2))
	await air_setup()
	check(hang.try_catch(DT),"catch")
	for frame in 30: await crouch_tick(false)
	for tier in [1,1,1,-1,-1,-1]:
		check(hang.navigation.resolve(hang,"UP" if tier>0 else "DOWN"),"vertical hop")
		for frame in 140:
			await crouch_tick(false)
			if not hang.vertical.active: break
		for hop in [false,true]:
			for side in [-1,1]:
				check(hang.navigation.resolve(hang,"LATERAL",side,hop),"lateral after vertical tier "+str(tier))
				for frame in 140:
					await crouch_tick(false)
					if not hang.lateral.active: break
		check(hang.running,"still attached")
	# High wall without a reachable lower ledge must not release.
	hang.vertical_down_range=.5
	check(not hang.navigation.resolve(hang,"DOWN") and hang.running,"S high no-op")
	check(not hang.navigation.safe_ground.valid,"no support below")
	print("JUMP ROOT ",hang.navigation.jump_root_delta)
	check(hang.navigation.resolve(hang,"JUMP",1),"jump accepted")
	for frame in 40:
		await crouch_tick(false)
		if not hang.running: break
	check(not hang.running and hang.navigation.jump_visual,"jump exits to airborne")
	check(body.velocity.y>8 and body.velocity.z>4 and body.velocity.x>1,"wall-relative launch impulse")
	check(hang.release_suppression_active and hang.cooldown==0,"local regrab suppression")
	check(animation.current_state==&"HangJumpOff","correct jump animation")
	for frame in 100: await crouch_tick(false)
	check(not hang.navigation.jump_visual,"normal aerial animation resumes")
	print("HANG_NAVIGATION_V2: ","PASS" if failures.is_empty() else str(failures))
	quit(0 if failures.is_empty() else 1)
