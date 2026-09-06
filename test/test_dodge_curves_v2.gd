extends "res://test/test_dodge_v2.gd"

func run() -> void:
	var lab=load("res://test/player_v2_lab.tscn").instantiate()
	root.add_child(lab)
	body=lab.get_node("PlayerV2")
	animation=body.get_node("AnimationController")
	tree=body.get_node("AnimationTree")
	lock=body.get_node("LockOnController")
	dummy=lab.get_node("LockOnTargetDummy")
	ik=body.get_node("FootIKController")
	cam=body.get_node("CameraRig")
	dodge=body.dodge
	# Profile tests include the preserved tail using the safety exit.
	dodge.run_roll_input_handoff_frame=300
	body.set_physics_process(false)
	animation.set_physics_process(false)
	cam.set_process(false)
	tree.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	var paths: Array[String]=["dodge_backstep_curve","dodge_stand_roll_curve","dodge_run_roll_curve"]
	var points: Array=[
		[Vector2(0,0),Vector2(.1,.2),Vector2(.2,.75),Vector2(.3,1),Vector2(.42,.65),Vector2(.52,.2),Vector2(.6,0),Vector2(1,0)],
		[Vector2(0,0),Vector2(.08,.45),Vector2(.18,.9),Vector2(.3,1),Vector2(.6,1),Vector2(.75,.55),Vector2(.85,.1),Vector2(.9,0),Vector2(1,0)],
		[Vector2(0,.25),Vector2(4.0/74,.75),Vector2(9.0/74,1),Vector2(30.0/74,1),Vector2(36.0/74,.7),Vector2(40.0/74,.25),Vector2(43.0/74,0),Vector2(59.0/74,0),Vector2(65.0/74,1),Vector2(1,1)]]
	var defaults: Array[Curve]=[dodge.backstep_movement_curve,dodge.stand_roll_movement_curve,dodge.run_roll_movement_curve]
	for i in 3:
		var saved: Curve=load("res://Characters/Player/V2/Curves/"+paths[i]+".tres")
		check(saved.point_count==points[i].size(),"saved curve point count")
		check(defaults[i]!=saved,"instance-local curves preserve reusable assets")
		for point: Vector2 in points[i]: check(absf(saved.sample(point.x)-point.y)<0.0001,"default curve points")
	# Empty slots get type-specific defaults without replacing assigned profiles.
	dodge.backstep_movement_curve=null
	dodge.stand_roll_movement_curve=null
	dodge.run_roll_movement_curve=null
	dodge.initialize()
	check(dodge.backstep_movement_curve!=null and dodge.stand_roll_movement_curve!=null and dodge.run_roll_movement_curve!=null,"null-safe curve defaults")
	for rate in [1.0,0.9]:
		# Sprint bypasses curves; its constant profile is tested separately.
		for kind in ["BACKSTEP","STAND_ROLL","RUN_ROLL"]:
			await reset_player()
			dodge.backstep_playback_speed=rate
			dodge.stand_roll_playback_speed=rate
			dodge.run_roll_playback_speed=rate
			var stick:=Vector2.ZERO if kind=="BACKSTEP" else Vector2(0,-1)
			var running: bool=kind in ["RUN_ROLL","SPRINT"]
			if kind=="SPRINT":
				body._run_time=body.sprint_buildup_duration
				await roll_tick(stick,true)
			var initial:=body.position
			await roll_tick(stick,running,false,true)
			var expected_curve: Curve=dodge.backstep_movement_curve if kind=="BACKSTEP" else (dodge.run_roll_movement_curve if running else dodge.stand_roll_movement_curve)
			check(dodge.movement_curve==expected_curve,"type selects dedicated curve")
			var stop_progress: float=.6 if kind=="BACKSTEP" else (43.0/74.0 if running else .9)
			var recovery_frames:=0
			var frames:=0
			var stop_time: float=-1
			var final_position:=initial
			while dodge.is_dodging and frames<300:
				var progress: float=dodge.dodge_progress
				var before:=body.position
				# Keep contradictory input held through zero-speed recovery.
				await roll_tick(Vector2(1,0),running)
				frames+=1
				if not dodge.is_dodging: break
				final_position=body.position
				check(absf(dodge.speed_multiplier-(1.0 if kind=="SPRINT" else expected_curve.sample(progress)))<0.0001,"Sprint stays constant; other rolls sample full clip progress")
				if progress>=stop_progress and (not running or progress<=59.0/74.0):
					if stop_time<0: stop_time=frames*DT
					recovery_frames+=1
					check(body.animation_state.horizontal_speed<0.0001,"zero curve explicitly clears horizontal velocity")
					check(Vector2(body.position.x-before.x,body.position.z-before.z).length()<0.0001,"recovery has no physical drift despite input")
					check(animation.current_state in [&"DodgeStand",&"DodgeRun",&"DodgeBack"],"animation retains recovery authority")
			check(recovery_frames>=5,"default profile leaves stationary recovery")
			check(absf(stop_time-stop_progress*dodge.timeline_length)<0.06,"playback rate stretches movement timing")
			print("DODGE_CURVE kind=",kind," rate=",rate," distance=",initial.distance_to(final_position)," stop_time=",stop_time," recovery_frames=",recovery_frames)
			await finish_roll()
	# Inspector-style replacement: short profile, overshoot, and early exit.
	await reset_player()
	var custom:=Curve.new()
	custom.max_value=1.5
	custom.add_point(Vector2(0,1.25),0,0,Curve.TANGENT_LINEAR,Curve.TANGENT_LINEAR)
	custom.add_point(Vector2(.3,0),0,0,Curve.TANGENT_LINEAR,Curve.TANGENT_LINEAR)
	custom.add_point(Vector2(1,0),0,0,Curve.TANGENT_LINEAR,Curve.TANGENT_LINEAR)
	dodge.stand_roll_movement_curve=custom
	dodge.stand_roll_exit_progress=.85
	await roll_tick(Vector2(0,-1),false,false,true)
	check(absf(dodge.speed_multiplier-1.25)<0.001,"multipliers above one are supported")
	var held_frames:=0
	while dodge.is_dodging and held_frames<300:
		var progress: float=dodge.dodge_progress
		await roll_tick(Vector2(0,-1))
		held_frames+=1
		if dodge.is_dodging and progress>=.3: check(body.animation_state.horizontal_speed<0.0001,"edited curve stops early without animation exit")
	await finish_roll()
	dodge.stand_roll_movement_curve=null
	dodge.initialize()
	# Wall blocks travel while profile continues; no stored launch after removal.
	await reset_player()
	var wall:=StaticBody3D.new()
	var collision:=CollisionShape3D.new()
	var box:=BoxShape3D.new()
	box.size=Vector3(10,4,.3)
	collision.shape=box
	wall.add_child(collision)
	lab.add_child(wall)
	wall.position=Vector3(0,1,13)
	await physics_frame
	await roll_tick(Vector2(0,-1),true,false,true)
	for frame in 200:
		await roll_tick()
		if dodge.dodge_progress>=.7: break
	check(dodge.is_dodging and body.position.z>13.4,"wall blocks roll while animation progresses")
	wall.free()
	var stopped:=body.position
	while dodge.dodge_progress<.79:
		await roll_tick()
		check(Vector2(body.position.x-stopped.x,body.position.z-stopped.z).length()<.001,"no stored wall velocity during pause")
	await finish_roll()
	print("DODGE_CURVES_V2: ","PASS" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)
