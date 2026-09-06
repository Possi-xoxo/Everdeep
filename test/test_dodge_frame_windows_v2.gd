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
	var imported=load("res://Characters/Player/Models/Blender Master Rig.glb").instantiate()
	var original: Animation=imported.get_node("AnimationPlayer").get_animation(dodge.BACK)
	var trimmed: Animation=animation.player.get_animation(dodge.BACK)
	check(absf(original.length-2.7)<.001 and absf(trimmed.length-1.5)<.001,"full imported action retained; runtime slice is 1.5 seconds")
	for track in trimmed.get_track_count():
		check(trimmed.track_get_key_count(track)==46,"slice contains frames 15 through 60")
		for frame in 46:
			var t: float=frame/30.0
			match trimmed.track_get_type(track):
				Animation.TYPE_ROTATION_3D:
					check(absf(trimmed.rotation_track_interpolate(track,t).dot(original.rotation_track_interpolate(track,t+.5)))>.99999,"slice retains authored rotation at original speed")
				Animation.TYPE_SCALE_3D:
					check(trimmed.scale_track_interpolate(track,t).is_equal_approx(original.scale_track_interpolate(track,t+.5)),"slice retains scale")
				Animation.TYPE_POSITION_3D:
					check(absf(trimmed.position_track_interpolate(track,t).z-original.position_track_interpolate(track,t+.5).z)<.0001,"slice retains authored vertical motion")
	imported.free()
	await reset_player()
	await roll_tick(Vector2.ZERO,false,false,true)
	check(dodge.dodge_type=="BACKSTEP" and dodge.exit_progress==1 and absf(dodge.timeline_length-1.5)<.001,"backstep plays complete trimmed window")
	var initial:=body.position
	await finish_roll()
	print("TRIMMED_BACKSTEP distance=",initial.distance_to(body.position))
	for rate in [1.0,.9]:
		await reset_player()
		dodge.run_roll_playback_speed=rate
		await roll_tick(Vector2(0,-1),true,false,true)
		var checked:=0
		var resumed:=0
		while dodge.is_dodging:
			var source_frame: float=dodge.dodge_progress*animation.player.get_animation(dodge.RUN).length*30
			await roll_tick(Vector2(0,-1),true)
			if dodge.is_dodging and source_frame>=43.001 and source_frame<=65:
				checked+=1
				check(body.animation_state.horizontal_speed<.0001,"run momentum paused between frames 43 and 65")
			elif dodge.is_dodging and source_frame>65.1:
				resumed+=1
				check(body.animation_state.horizontal_speed>0.01,"forward dodge momentum resumes after frame 65")
				check(Vector3(body.velocity.x,0,body.velocity.z).normalized().dot(dodge.dodge_direction)>.999,"resumed movement retains captured direction")
		check(checked>30 and resumed>3,"pause and resumed travel both evaluated")
		await finish_roll()
	print("DODGE_FRAME_WINDOWS_V2: ","PASS" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)
