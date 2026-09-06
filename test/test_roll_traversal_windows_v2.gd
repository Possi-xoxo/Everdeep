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
	box(Vector3(200,.35,-13),Vector3(6,.7,30))
	for rate in [.9,1.0,1.15]:
		for running in [false,true]:
			var window:=Vector2(15,30) if running else Vector2(20,40)
			for frame in [window.x-.1,window.x,(window.x+window.y)/2,window.y,window.y+.1,65.0]:
				await reset_at(Vector3(200,.1,2.7))
				dodge.run_roll_playback_speed=rate
				dodge.stand_roll_playback_speed=rate
				await roll_tick(Vector2(0,-1),running,false,true)
				# Feed the same evaluated-time input used by mixer_applied.
				dodge.evaluate(frame/(30*rate))
				var horizontal: Vector3=dodge.motion()
				var expected: bool=frame>=window.x and frame<=window.y
				check(assist.traversal_window_open()==expected,"exact source-frame window at varied playback rate")
				check(assist.prepare_roll(DT,horizontal)==expected,"valid ledge accepted only inside action window")
				if expected:
					dodge.evaluate((window.y+1)/(30*rate))
					check(assist.prepare_roll(DT,Vector3.ZERO),"accepted bounded lift may finish outside initiation window")
	# Exercise actual playback rather than only boundary input samples.
	for running in [false,true]:
		await reset_at(Vector3(200,.1,2.7))
		dodge.run_roll_playback_speed=1
		dodge.stand_roll_playback_speed=1
		await roll_tick(Vector2(0,-1),running,false,true)
		var began:=false
		for i in 100:
			var prior_frame: float=assist.source_frame()
			var count: int=assist.steps_started
			await roll_tick()
			if assist.steps_started>count:
				var window:=Vector2(15,30) if running else Vector2(20,40)
				check(prior_frame>=window.x-.001 and prior_frame<=window.y+.001,"real playback starts traversal in permitted window")
				began=true
		check(began,"in-window roll still clears ledge")
	print("ROLL_TRAVERSAL_WINDOWS_V2: ","PASS" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)
