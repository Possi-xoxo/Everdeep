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
	await reset_at(Vector3(200,.1,10))
	for frame in 30: await roll_tick(Vector2(0,-1))
	var peak:=0.0
	for repeat in 3:
		for stick in [Vector2(1,0),Vector2(0,1),Vector2(-1,0),Vector2(0,-1)]:
			for frame in 20:
				var before: float=body.visual.rotation.y
				await roll_tick(stick)
				var change: float=absf(wrapf(body.visual.rotation.y-before,-PI,PI))
				peak=maxf(peak,rad_to_deg(change))
				check(change<=deg_to_rad(body.walk_direction_turn_speed)*DT+.0001,"circle yaw bounded by Walk turn rate")
				check(body.desired_move_direction.dot(Vector3(stick.x,0,stick.y))>.999,"raw input updates immediately")
				check(not body.turn_180.active,"90-degree circle does not restart reversal clips")
				check(body.smoothed_walk_direction.is_finite() and absf(body.smoothed_walk_direction.length()-1)<.001,"angle smoothing remains normalized")
	for stick in [Vector2(0,-1),Vector2(1,-1).normalized(),Vector2(1,0)]:
		for frame in 20: await roll_tick(stick)
		check(body.smoothed_walk_direction.dot(Vector3(stick.x,0,stick.y))>.99,"diagonal converges")
	await reset_at(Vector3(200,.1,10))
	for frame in 30: await roll_tick(Vector2(0,-1))
	await roll_tick(Vector2(0,1))
	check(body.turn_180.active and not body.turn_180.running,"raw true reversal still triggers Walk180")
	for frame in 120: await roll_tick()
	var facing: float=body.visual.rotation.y
	cam.get_node("YawPivot").rotation.y+=1.2
	for frame in 30: await roll_tick()
	check(absf(wrapf(body.visual.rotation.y-facing,-PI,PI))<.0001,"Idle camera does not change facing")
	await reset_at(Vector3(200,.1,10))
	for frame in 30: await roll_tick(Vector2(0,-1),true)
	await roll_tick(Vector2(1,0),true)
	check(not body.walk_direction_smoothing_active,"Run bypasses smoothing")
	body._run_time=body.sprint_buildup_duration+1
	await roll_tick(Vector2(0,-1),true)
	check(not body.walk_direction_smoothing_active,"Sprint bypasses smoothing")
	await reset_at(Vector3(200,.1,10))
	dummy.position=Vector3(200,0,0)
	lock.toggle()
	await roll_tick(Vector2(1,0))
	check(lock.is_locked() and not body.walk_direction_smoothing_active,"locked Walk bypasses smoothing")
	# Angle integration itself is independent of frame rate.
	for rate in [30,60,120]:
		body.smoothed_walk_direction=Vector3.FORWARD
		for frame in int(rate*.25): body._smooth_walk_direction(Vector3.RIGHT,1.0/rate)
		check(body.smoothed_walk_direction.dot(Vector3.RIGHT)>.99,"quarter-second 90-degree turn at "+str(rate))
	print("WALK_DIRECTION_V2 peak_yaw_degrees=",peak," ","PASS" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)
