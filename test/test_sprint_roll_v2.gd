extends "res://test/test_dodge_v2.gd"

func run() -> void:
	var lab=load("res://test/player_v2_lab.tscn").instantiate()
	root.add_child(lab)
	body=lab.get_node("PlayerV2")
	animation=body.get_node("AnimationController")
	tree=body.get_node("AnimationTree")
	lock=body.get_node("LockOnController")
	dummy=lab.get_node("LockOnTargetDummy")
	cam=body.get_node("CameraRig")
	dodge=body.dodge
	body.set_physics_process(false)
	animation.set_physics_process(false)
	cam.set_process(false)
	tree.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	for gait in [2,1,0,2,1]:
		await reset_player()
		if gait==2: body._run_time=body.sprint_buildup_duration
		elif gait==1: body._run_time=body.sprint_buildup_duration-.5
		await roll_tick(Vector2(0,-1),gait>0)
		await roll_tick(Vector2(0,-1),gait>0,false,true)
		var expected: StringName=dodge.SPRINT if gait==2 else (dodge.RUN if gait==1 else dodge.STAND)
		check(dodge.clip==expected,"actual gait selects correct source")
		if gait==1: check(body._run_time==0.0,"running roll resets accumulated Sprint timer")
		if gait==2: check(body._run_time==body.sprint_buildup_duration,"Sprint roll preserves Sprint eligibility")
		check(tree.tree_root.get_node(animation.current_state).animation==expected,"tree plays selected clip, including Run after Sprint")
		if gait==2:
			check(dodge.exit_progress==1.0,"Sprint maintains motion through the complete clip")
			var saved_elapsed: float=dodge.dodge_elapsed
			for source_frame in [0.0,8.99,9.0,18.0,24.0,24.01,35.9,36.0]:
				dodge.evaluate(source_frame/30.0/dodge.playback_speed)
				check(dodge.motion().is_equal_approx(dodge.dodge_direction*dodge.base_speed),"constant Sprint motion throughout clip")
				check(body.roll_traversal.traversal_window_open()==(source_frame>=9.0 and source_frame<=24.0),"Sprint traversal restricted to 9-24 inclusive")
				dodge.evaluate(saved_elapsed)
			check(absf(dodge.timeline_length-1.2)<.00001,"Sprint keeps native duration")
			check(animation.player.get_animation(expected).loop_mode==Animation.LOOP_NONE,"Sprint is non-looping")
		await finish_roll(Vector2(0,-1),gait>0)
		check(animation.current_state==&"Locomotion","roll exits cleanly")
		if gait>0:
			var machine=tree.tree_root
			for index in machine.get_transition_count():
				if machine.get_transition_from(index)==&"DodgeRun" and machine.get_transition_to(index)==&"Locomotion":
					check(is_equal_approx(machine.get_transition(index).xfade_time,.3 if gait==2 else .2),"Sprint-only exit blend; Run restored independently")
		if gait==1: check(body._run_time<1.0 and body.animation_state.gait==1,"Run resumes with fresh buildup, not near Sprint")
	await reset_player()
	body._run_time=body.sprint_buildup_duration
	await roll_tick(Vector2(0,-1),true)
	lock.toggle()
	await roll_tick(Vector2(0,-1),true,false,true)
	check(dodge.clip==dodge.RUN,"Locked never selects Sprint")
	await finish_roll()
	await reset_player()
	body._run_time=body.sprint_buildup_duration
	await roll_tick(Vector2(0,-1),true)
	await roll_tick(Vector2.ZERO,true,false,true)
	check(dodge.clip==dodge.BACK,"no-input Backstep unchanged")
	print("SPRINT_ROLL_V2: ","PASS" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)
