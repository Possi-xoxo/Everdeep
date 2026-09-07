extends "res://test/test_mantle_geometry_v2.gd"
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
	var support=body.ground_support
	box(Vector3(200,-.25,0),Vector3(80,.5,80))
	var platform:=box(Vector3(200,1,0),Vector3(4,2,4))
	await reset_at(Vector3(200,2.05,0))
	for frame in 30: await crouch_tick(false)
	check(support.support_hits==5 and support.has_ground_support,"flat full support")
	body.position.x=201.9
	await crouch_tick(false)
	check(support.support_hits==3 and support.has_ground_support,"3/5 edge support")
	body.position.x=202.05
	await crouch_tick(false)
	check(body.is_on_floor() and not support.has_ground_support,"footprint loses support before capsule")
	check(support.support_just_lost and support.coyote_remaining>0,"explicit support loss and coyote")
	await crouch_tick(false,Vector2.ZERO,false,true)
	check(body.animation_state.jump_started and body.velocity.y>0,"coyote jump succeeds")
	await crouch_tick(false,Vector2.ZERO,false,true)
	check(not body.animation_state.jump_started and support.coyote_remaining==0,"one jump per loss")
	await reset_at(Vector3(200,2.05,0))
	for frame in 50: await crouch_tick(false)
	body.position.x=202.05
	for frame in 10: await crouch_tick(false)
	await crouch_tick(false,Vector2.ZERO,false,true)
	check(not body.animation_state.jump_started,"expired coyote rejects jump")
	for frame in 110: await crouch_tick(false)
	check(body.position.y<1.5,"unsupported capsule falls naturally without correction")
	# Probe geometry can classify a platform narrower than the body.
	var beam:=box(Vector3(210,1,0),Vector3(.5,2,4))
	await reset_at(Vector3(210,2.05,0))
	for frame in 50: await crouch_tick(false)
	check(support.has_ground_support and support.support_hits==5,"half-meter beam supports broad .9m body")
	for frame in 65: await crouch_tick(true)
	check(support.has_ground_support and is_equal_approx(support.ground_support_radius,.22),"same crouch support footprint")
	beam.get_child(0).shape.size.x=.15
	await crouch_tick(true)
	check(not support.has_ground_support,"too narrow support rejects")
	beam.queue_free()
	platform.queue_free()
	for angle in [15.0,30.0,40.0]:
		var slope:=box(Vector3(220,2,0),Vector3(8,.5,8))
		slope.rotation.x=deg_to_rad(angle)
		await reset_at(Vector3(220,2.6,0))
		for frame in 100: await crouch_tick(false)
		check(support.has_ground_support,"slope support "+str(angle))
		slope.queue_free()
	for h in [.10,.15,.20]:
		await fixture(h)
		for frame in 90: await crouch_tick(false)
		var flicker:=false
		for frame in 100:
			await crouch_tick(false,Vector2(0,-1))
			flicker=flicker or body.animation_state.is_airborne
			if body.position.z<8.5: break
		check(body.position.y>h-.02 and not flicker,"confirmed step retains support "+str(h))
	await fixture(3.0)
	for frame in 120: await crouch_tick(false,Vector2(0,-1))
	check(body.position.z>=9.79 and is_equal_approx(body.crouch.standing_capsule_radius,.45),"broad wall collision unchanged")
	for width in [.5,.15]:
		await fixture(1.75)
		test_obstacle.get_child(0).shape.size.x=width
		for frame in 90: await crouch_tick(false)
		body.context_interaction.scan()
		check(detector.result.valid==(width>.2),"narrow mantle footprint classification "+str(width))
		if width>.2:
			check(body.context_interaction.activate_selected(),"narrow mantle activation")
			for frame in 240:
				await crouch_tick(false)
				if not body.traversal.is_traversing: break
			check(body.traversal.last_end_reason=="COMPLETED" and support.has_ground_support,"narrow supported mantle completes")
	print("GROUND_SUPPORT_V2: ","PASS" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)
