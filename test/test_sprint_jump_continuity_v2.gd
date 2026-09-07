extends "res://test/test_mantle_v2.gd"
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
	box(Vector3(200,-.25,-100),Vector3(80,.5,300))
	await reset_at(Vector3(200,.1,10))
	for frame in 144: await crouch_tick(false,Vector2(0,-1),true)
	check(absf(body._run_time-2.4)<.02,"60 percent buildup setup")
	for attempt in 4:
		var saved: float=0.0
		await crouch_tick(false,Vector2(0,-1),true,true)
		check(body.animation_state.jump_started,"ordinary jump starts")
		check(is_equal_approx(body._run_time,saved),"RUN takeoff resets buildup")
		var landed:=false
		for frame in 100:
			await crouch_tick(false,Vector2(0,-1),true)
			check(is_equal_approx(body._run_time,saved),"air holds progress without earning sprint")
			if body.animation_state.is_grounded:
				landed=true
				break
		check(landed,"ordinary jump lands")
		for frame in 30: await crouch_tick(false,Vector2(0,-1),true)
		check(body._run_time>=saved,"landing resumes from prior progress")
	check(body.animation_state.gait==1,"repeated RUN jumps cannot accumulate uninterrupted buildup")
	for frame in 245: await crouch_tick(false,Vector2(0,-1),true)
	check(body.animation_state.gait==2,"continuous ground running still reaches sprint")
	await crouch_tick(false,Vector2(0,-1),true,true)
	for frame in 15:
		await crouch_tick(false,Vector2(0,-1),true)
		check(body.animation_state.gait==2,"active sprint survives jump")
	await crouch_tick(false,Vector2(0,-1),false)
	check(body._run_time==0 and body.animation_state.gait==0,"release sprint airborne cancels")
	await crouch_tick(false,Vector2(0,-1),true)
	check(body._run_time==0 and body.animation_state.gait==1,"air repress does not resurrect sprint")
	for frame in 100: await crouch_tick(false)
	body._run_time=body.sprint_buildup_duration-DT*.5
	body.animation_state.gait=1
	await crouch_tick(false,Vector2(0,-1),true,true)
	check(body.animation_state.gait==1,"jump itself cannot complete almost-full buildup")
	check(body._run_time==0,"nearly full RUN buildup resets at takeoff")
	await crouch_tick(false,Vector2.ZERO,true)
	check(body._run_time==0,"stop intent airborne cancels")
	for frame in 100: await crouch_tick(false)
	for frame in 90: await crouch_tick(false,Vector2(0,-1),true)
	await crouch_tick(true,Vector2(0,-1),true)
	check(body._run_time==0,"crouch cancels")
	for frame in 100: await crouch_tick(false)
	for frame in 90: await crouch_tick(false,Vector2(0,-1),true)
	await crouch_tick(false,Vector2(0,-1),true,false,true)
	check(dodge.is_dodging and body._run_time==0,"running roll resets")
	for frame in 160: await crouch_tick(false)
	await ready_fixture()
	body._run_time=2.4
	body.context_interaction.scan()
	check(body.context_interaction.activate_selected(),"mantle activation")
	check(body._run_time==0,"mantle cancels buildup")
	for frame in 240:
		await crouch_tick(false)
		if not body.traversal.is_traversing: break
	check(body.traversal.last_end_reason=="COMPLETED","mantle remains functional")
	print("SPRINT_JUMP_CONTINUITY_V2: ","PASS" if failures.is_empty() else str(failures))
	quit(0 if failures.is_empty() else 1)
