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
	for rate in [.85,1.0,1.15]:
		for marker in [0,50,55,-1]:
			await reset_at(Vector3(200,.1,10))
			dodge.backstep_playback_speed=rate
			await roll_tick(Vector2.ZERO,false,false,true)
			check(dodge.clip==dodge.BACK,"correct imported backstep selected")
			check(is_equal_approx(animation.player.get_animation(dodge.BACK).length,1.5),"15–60 runtime slice unchanged")
			var saw_tail:=false
			var last_frame:=15.0
			for frame in 180:
				last_frame=dodge.source_frame()
				var motion: Vector3=dodge.motion()
				if last_frame<=36:
					check(is_equal_approx(motion.length(),dodge.backstep_movement_curve.sample(dodge.dodge_progress)*dodge.backstep_speed),"initial push unchanged")
				if last_frame>=47 and last_frame<50:
					saw_tail=true
					check(motion.length()>.1,"authored momentum continues beyond 47")
				if motion.length()>.001: check(motion.normalized().dot(dodge.dodge_direction)>.999,"motion stays in captured backstep direction")
				var input:=Vector2.RIGHT if marker>=0 and last_frame>=marker else Vector2.ZERO
				await roll_tick(input)
				if not dodge.is_dodging: break
			check(saw_tail,"late motion exercised")
			if marker<0:
				check(last_frame>=59.99,"no-input backstep completes to source 60")
				dodge.dodge_elapsed=dodge.timeline_length
				dodge.dodge_progress=1.0
				check(dodge.motion().length()<.001,"tail settles to zero by completion")
			else:
				check(last_frame>=maxi(50,marker)-.001 and last_frame<maxi(50,marker)+rate*.51,"first current-input tick at/after marker exits")
				check(animation.current_state==&"Locomotion" and dodge.handoff_this_tick,"input starts locomotion blend")
				check(body.velocity.x>0,"current directional input takes control")
				for edge in tree.tree_root.get_transition_count():
					if tree.tree_root.get_transition_from(edge)==&"DodgeBack" and tree.tree_root.get_transition_to(edge)==&"Locomotion":
						check(is_equal_approx(tree.tree_root.get_transition(edge).xfade_time,.3),"backstep exit blend .3 seconds")
			print("BACKSTEP rate=",rate," input=",marker," exit_frame=",last_frame)
	print("BACKSTEP_RECOVERY_V2: ","PASS" if failures.is_empty() else str(failures))
	quit(0 if failures.is_empty() else 1)
