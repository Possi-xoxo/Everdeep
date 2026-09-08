extends "res://test/test_braced_hang_v2.gd"

func launch(point: Vector3,yaw: float=PI) -> void:
	if body.traversal.is_traversing: body.traversal.finish("TEST_RESET")
	body.position=point+Vector3.UP*.02
	body.visual.rotation.y=yaw
	body.velocity=Vector3.DOWN
	body.move_and_slide()
	body.apply_floor_snap()
	body.ground_support.refresh(0)
	body.animation_state.is_airborne=false
	body.animation_state.is_grounded=true
	body.animation_state.jump_started=false
	animation._enter(&"Locomotion")
	await physics_frame

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
	var wall=box(Vector3(200,1.5,8),Vector3(8,3,4))
	await physics_frame
	var entry=hang.top_entry
	check(is_equal_approx(animation.player.get_animation(entry.SOURCE).length,.2),"airborne catch remains trimmed")
	check(animation.player.get_animation(entry.ACTION).length>1.5,"full private top-entry clip")
	for index in tree.tree_root.get_transition_count():
		if tree.tree_root.get_transition_to(index)==&"HangTopEntry" and tree.tree_root.get_transition_from(index)!=&"Start":
			check(is_equal_approx(tree.tree_root.get_transition(index).xfade_time,.30),"top entry uses .30 second blend")
	for angle in [0.0,.25,-.25]:
		await launch(Vector3(200,3,9.5),PI+angle)
		entry.refresh()
		print("TOP QUERY ",entry.result.get("reason"))
		check(entry.result.valid,"valid top-down query "+str(angle))
		if not entry.result.valid: continue
		var previous: Vector3=entry.result.start
		for frame_index in range(1,33):
			var point: Vector3=entry.position_at(entry.result,frame_index*.5)
			check(point.y<=previous.y+.0001,"compact entry never rises")
			check(point.distance_to(entry.result.anchor)<=previous.distance_to(entry.result.anchor)+.0001,"compact entry has no return loop")
			previous=point
		for frame_index in range(10):
			var expected: Vector3=Vector3(entry.result.start).lerp(entry.result.anchor,float(frame_index)/9.0)
			check(entry.visual_position_at(entry.result,frame_index).distance_to(expected)<.0001,"model takes linear frame0-9 trajectory")
		check(entry.begin_interaction(body),"E entry commits")
		check(not hang.navigation.resolve(hang,"UP"),"W locked during entry")
		check(not hang.navigation.resolve(hang,"DOWN"),"S locked during entry")
		await crouch_tick(false,Vector2(1,-1),true,true,true)
		check(entry.active and body.velocity==Vector3.ZERO and not body.dodge.is_dodging,"jump/dodge/sprint cannot take ownership")
		for tick in 110:
			await crouch_tick(false)
			cam._process(DT)
			if entry.active and entry.frame()>=9 and entry.frame()<10:
				check(body.position.distance_to(hang.alignment)<.001,"capsule at anchor by frame9")
				check(entry.visual_offset().length()<.001,"model offset reunited by frame9")
				check((-body.visual.global_basis.z).dot(hang.facing)>.99,"twist completed by frame9")
			if entry.active and entry.frame()>=16 and entry.frame()<17:
				check(body.position.distance_to(hang.alignment)<.01,"contact anchor at frame16")
				check((-body.visual.global_basis.z).dot(hang.facing)>.99,"contact facing")
				for arm in body.get_node("MantleHandIK").arms: check(arm.weight>.99 and arm.error<.005,"frame16 hand contact")
			if entry.active and entry.frame()>16:
				check((-body.visual.global_basis.z).dot(hang.facing)>.99,"wall facing retained through tail")
		check(hang.running and hang.hang_phase==hang.HangPhase.IDLE,"entry reaches normal hang idle")
		check(body.position.distance_to(hang.alignment)<.005,"anchor stable")
		check(absf(hang.idle_pose.offset-hang.braced_hang_visual_vertical_offset)<.001,"shared visual baseline does not accumulate")
		print("TOP END ",hang.exit_reason," ",entry.frame())
	await launch(Vector3(200,3,8.8))
	entry.refresh()
	check(not entry.result.valid,"far from edge no prompt")
	await launch(Vector3(200,3,9.5))
	var blocker=box(Vector3(200,2,10.55),Vector3(1,.4,.5))
	await physics_frame
	entry.refresh()
	check(not entry.result.valid,"blocked anchor no prompt")
	blocker.queue_free()
	await physics_frame
	entry.refresh()
	check(entry.begin_interaction(body),"retry after blocker removed")
	wall.queue_free()
	await physics_frame
	await crouch_tick(false)
	check(not hang.running and not entry.active and not body.traversal.is_traversing,"source loss detaches cleanly")
	for tick in 100: await crouch_tick(false)
	check(not cam.mantle_camera_active,"camera rejoins after abort")
	check(absf(hang.idle_pose.offset)<.001,"visual baseline cleared after abort")
	for arm in body.get_node("MantleHandIK").arms: check(arm.weight==0,"hand IK cleared after abort")
	print("HANG_TOP_ENTRY_V2: ","PASS" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)
