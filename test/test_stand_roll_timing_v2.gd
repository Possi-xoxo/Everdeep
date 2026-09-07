extends "res://test/test_roll_traversal_v2.gd"
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
	body.set_physics_process(false)
	animation.set_physics_process(false)
	cam.set_process(false)
	tree.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	box(Vector3(200,-.25,0),Vector3(80,.5,80))
	var source: Animation=animation.player.get_animation(dodge.STAND)
	var source_length: float=source.length
	print("STAND_SOURCE_FRAMES ",source_length*30)
	for rate in [.85,1.0,1.15]:
		for input_frame in [0,55,60,-1]:
			await reset_at(Vector3(200,.1,15))
			dodge.stand_roll_playback_speed=rate
			await roll_tick(Vector2(0,-1),false,false,true)
			check(dodge.clip==dodge.STAND and animation.current_state==&"DodgeStand","stand clip selected")
			var node: AnimationNodeAnimation=tree.tree_root.get_node("DodgeStand")
			check(is_equal_approx(node.start_offset*rate*30,10),"runtime clip starts on source frame 10")
			check(is_equal_approx(source.length,source_length),"source animation unmodified")
			var last_frame:=0.0
			var saw_momentum:=false
			for tick_index in 300:
				last_frame=assist.source_frame()
				var input:=Vector2.RIGHT if input_frame>=0 and last_frame>=input_frame else Vector2.ZERO
				if last_frame<21:
					var early: float=dodge.motion().length()
					var full: float=dodge.stand_roll_movement_curve.sample(dodge.dodge_progress)*dodge.stand_roll_speed
					check(early>0 and early<=full+.001,"authored lead-in is positive and bounded by normal momentum")
					if last_frame<19:
						var expected: float=dodge.stand_roll_authored_speed.sample(dodge.dodge_progress)*dodge.stand_roll_leadin_strength*rate
						check(absf(early-minf(expected,full))<.001,"early motion follows authored speed")
				else:
					var expected: float=dodge.stand_roll_movement_curve.sample(dodge.dodge_progress)*dodge.stand_roll_speed
					check(is_equal_approx(dodge.motion().length(),expected),"original post-onset curve preserved")
					saw_momentum=saw_momentum or expected>.1
				await roll_tick(input)
				if not dodge.is_dodging: break
				if last_frame<55: check(animation.current_state==&"DodgeStand","input cannot cut before 55")
			check(saw_momentum,"roll moves after onset")
			if input_frame<0:
				check(last_frame>=source_length*30-.02,"no-input roll reaches source completion")
			else:
				check(last_frame>=maxi(55,input_frame)-.001 and last_frame<maxi(55,input_frame)+rate*.51,"first eligible input tick exits")
				check(dodge.handoff_this_tick and animation.current_state==&"Locomotion","input-driven handoff begins blend")
				check(body.velocity.x>0,"current requested direction receives control")
				var found:=false
				for edge in tree.tree_root.get_transition_count():
					if tree.tree_root.get_transition_from(edge)==&"DodgeStand" and tree.tree_root.get_transition_to(edge)==&"Locomotion":
						found=true
						check(is_equal_approx(tree.tree_root.get_transition(edge).xfade_time,.3),"stand-specific exit blend")
				check(found,"exit route exists")
			print("STAND_EXIT rate=",rate," input=",input_frame," source_frame=",last_frame)
	print("STAND_ROLL_TIMING_V2: ","PASS" if failures.is_empty() else str(failures))
	quit(0 if failures.is_empty() else 1)
