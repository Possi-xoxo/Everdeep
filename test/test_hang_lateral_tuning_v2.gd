extends "res://test/test_braced_hang_v2.gd"
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
	box(Vector3(200,1,8.35),Vector3(18,4,2))
	await air_setup()
	check(hang.try_catch(DT),"catch")
	for frame in 30: await crouch_tick(false)
	var original: Vector3=hang.alignment
	if hang.braced_hang_right_hop_mirror_left_curve:
		var curves=hang.lateral.motion
		var difference: float=0
		for i in range(curves.SAMPLE_COUNT+1):
			check(Vector3(curves.profiles[&"HangHopRight"][i]).distance_to(curves.profiles[&"HangHopLeft"][i])<.000001,"right uses direction-mirrored left profile")
			difference=maxf(difference,Vector3(curves.original_right_profile[i]).distance_to(curves.profiles[&"HangHopRight"][i]))
		check(difference>.01,"replacement differs from original right curve")
		curves.configure_right_hop(false)
		check(curves.profiles[&"HangHopRight"]==curves.original_right_profile,"original right curve can be restored")
		curves.configure_right_hop(true)
		print("RIGHT_HOP_MIRROR maximum normalized/profile difference=",difference)
	for hop in [false,true]:
		for side in [-1,1]:
			var start: Vector3=hang.alignment
			check(hang.lateral.request(hang,side,hop),"action accepted")
			var state: StringName=hang.lateral.state
			var clip: Animation=animation.player.get_animation(hang.lateral.CLIPS[state])
			var expected_duration: float=clip.length/1.1
			check(absf(hang.lateral.lengths[state]-expected_duration)<.0001,"controller timeline is 1.1x")
			var node: AnimationNodeAnimation=tree.tree_root.get_node(state)
			check(node.stretch_time_scale and absf(node.timeline_length-expected_duration)<.0001,"animation timeline is 1.1x")
			var ticks: int=0
			var playback_ticks: int=0
			for frame in 160:
				await crouch_tick(false)
				ticks+=1
				if animation._playback.get_current_node()==state: playback_ticks+=1
				if not hang.lateral.active: break
				check(body.position.distance_to(hang.lateral.expected_position)<.001,"body stays synchronized")
			check(absf(playback_ticks*DT-expected_duration)<.07,"actual playback duration excludes entry transition wait")
			var distance: float=3.0 if hop else .7
			if state==&"HangHopRight":
				var motion=hang.lateral.motion
				check(absf(clip.length-float(motion.measurements[state].duration))<.0001,"right hop retains full source duration")
				check(motion.sample(state,1).distance_to(Vector3(1,0,0))<.0001,"full path settles at anchor")
			check(hang.alignment.distance_to(start+hang.facing.cross(Vector3.UP)*side*distance)<.001,"requested exact endpoint")
			print(state," duration=",ticks*DT," distance=",hang.alignment.distance_to(start))
	check(hang.alignment.distance_to(original)<.001,"equal left/right distances return to start")
	for i in tree.tree_root.get_transition_count():
		if tree.tree_root.get_transition_to(i)==&"HangIdle":
			var from: StringName=tree.tree_root.get_transition_from(i)
			if from in [&"HangShimmyLeft",&"HangShimmyRight"]:
				check(absf(tree.tree_root.get_transition(i).xfade_time-.30)<.0001,"shimmy idle blend is .30 seconds")
			if from in [&"HangHopLeft",&"HangHopRight"]:
				check(absf(tree.tree_root.get_transition(i).xfade_time-.12)<.0001,"hop idle blend unchanged")
	print("HANG_LATERAL_TUNING_V2: ","PASS" if failures.is_empty() else str(failures))
	quit(0 if failures.is_empty() else 1)
