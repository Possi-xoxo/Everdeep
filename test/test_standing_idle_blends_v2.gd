extends "res://test/test_crouch_v2.gd"
func run() -> void:
	lab=load("res://test/player_v2_lab.tscn").instantiate()
	root.add_child(lab)
	body=lab.get_node("PlayerV2")
	animation=body.get_node("AnimationController")
	tree=body.get_node("AnimationTree")
	body.set_physics_process(false)
	animation.set_physics_process(false)
	tree.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	var s=body.animation_state
	s.is_grounded=true
	s.is_airborne=false
	for source in [&"Land",&"Fall",&"JumpStanding",&"JumpMoving",&"DodgeStand",&"DodgeRun",&"DodgeBack",&"CrouchEnter",&"CrouchExit",&"CrouchIdle",&"CrouchWalk",&"CrouchRun",&"CrouchLocked",&"CrouchLockedRun",&"Mantle"]:
		s.move_input_magnitude=0
		s.horizontal_speed=0
		animation.current_state=source
		animation._playback.start(source)
		tree.advance(.01)
		animation._enter(&"Locomotion")
		check(edge_time(tree.tree_root,source,&"Locomotion")>=.30-.0001,"idle return "+str(source))
		tree.advance(.10)
		check(animation._playback.get_fading_from_node()==source,"actual outgoing blend "+str(source))
		s.move_input_magnitude=1
		s.horizontal_speed=2
		animation.current_state=source
		animation._enter(&"Locomotion")
		if source in [&"Land",&"Fall",&"JumpStanding",&"JumpMoving"]:
			check(is_equal_approx(edge_time(tree.tree_root,source,&"Locomotion"),animation.land_blend_out),"moving return restored "+str(source))
	s.move_input_magnitude=0
	s.horizontal_speed=0
	animation.grounded.update(tree,s,0,true,body.visual,DT,animation)
	var nested: AnimationNodeStateMachine=tree.tree_root.get_node("Locomotion")
	for source in [&"RunStop",&"TurnLeft",&"TurnRight",&"WalkPivot",&"RunPivot",&"Locked"]:
		check(edge_time(nested,source,&"Loops")>=.30-.0001,"nested idle return "+str(source))
	animation.gait_blend=1
	for i in 9: animation._update_gait(s,DT)
	check(animation.gait_blend>.4 and animation.gait_blend<.6,"walk idle halfway at .15 seconds")
	for i in 10: animation._update_gait(s,DT)
	check(animation.gait_blend<.001,"walk idle finishes at .30 seconds")
	check(is_equal_approx(animation.lock_move_to_idle_blend,.30),"locked idle smoothstep timing")
	print("STANDING_IDLE_BLENDS_V2: ","PASS" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)

func edge_time(machine: AnimationNodeStateMachine,from: StringName,to: StringName) -> float:
	for index in machine.get_transition_count():
		if machine.get_transition_from(index)==from and machine.get_transition_to(index)==to: return machine.get_transition(index).xfade_time
	return -1
