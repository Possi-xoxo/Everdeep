extends "res://test/test_hang_exits_v2.gd"
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
	hang=body.traversal.hang
	body.set_physics_process(false)
	animation.set_physics_process(false)
	cam.set_process(false)
	tree.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	box(Vector3(200,-.25,10),Vector3(30,.5,30))
	box(Vector3(200,1,5.35),Vector3(6,4,8))
	await physics_frame
	for gait in [0,1,2,3,4,5]: # walk/run/sprint/idle/blocked standing/prior crouch
		await air_setup()
		body.animation_state.gait=mini(gait,2)
		body._run_time=2.0 if gait==1 else (4.0 if gait==2 else 0.0)
		if gait==5:
			crouch.requested=true
			crouch.phase=crouch.Phase.CROUCHED
			crouch.resize(crouch.crouch_capsule_height)
		var roof: Node3D
		if gait==4:
			roof=box(Vector3(200,4.5,8.2),Vector3(4,.2,2))
			await physics_frame
		check(hang.try_catch(DT),"gait fixture caught")
		for frame in 20: await actual_input()
		await actual_input("move_forward",true)
		await actual_input("move_forward",false)
		check(hang.hang_phase==hang.HangPhase.TO_CROUCH,"W top out")
		var stick:=Vector2(0,-1) if gait<3 or gait==5 else Vector2.ZERO
		var saw_exit: bool=false
		var exit_start:=Vector3.ZERO
		for frame in 140:
			await crouch_tick(crouch.requested,stick,gait in [1,2,5])
			if hang.running and body.traversal.phase==body.traversal.Phase.EXIT:
				if not saw_exit:
					saw_exit=true
					exit_start=body.position
					check(body.ground_support.has_ground_support,"safe supported handoff")
					check(not hang.is_attached(),"hang IK yields at handoff")
					check(crouch.active()==(gait>=4),"prior crouch or obstruction respected")
					if gait<3: check(body.animation_state.gait==gait,"previous gait restored")
					if gait==1: check(body._run_time>=2,"run buildup restored")
					var destination: StringName=animation.current_state
					check(destination==(&"CrouchRun" if gait==5 else (&"CrouchIdle" if gait==4 else &"Locomotion")),"direct locomotion exit, no forced crouch idle")
					for index in tree.tree_root.get_transition_count():
						if tree.tree_root.get_transition_from(index)==&"HangUp" and tree.tree_root.get_transition_to(index)==destination:
							check(is_equal_approx(tree.tree_root.get_transition(index).xfade_time,body.traversal.mantle.mantle_exit_blend_time),"same .30s mantle blend")
			if not hang.running: break
		check(saw_exit and hang.exit_reason=="HANG_TO_CROUCH_COMPLETED","clean exit lifecycle")
		if gait<3: check(body.position.distance_to(exit_start)>.05 and body.velocity.length()>.1,"movement continues through blend and completion")
		if is_instance_valid(roof): roof.queue_free()
	print("HANG_GAIT_EXIT_V2: ","PASS" if failures.is_empty() else str(failures))
	quit(0 if failures.is_empty() else 1)
