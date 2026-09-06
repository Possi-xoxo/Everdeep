extends "res://test/test_player_v2.gd"

func run() -> void:
	var lab = load("res://test/player_v2_lab.tscn").instantiate()
	root.add_child(lab)
	body=lab.get_node("PlayerV2")
	animation=body.get_node("AnimationController")
	tree=body.get_node("AnimationTree")
	body.set_physics_process(false)
	animation.set_physics_process(false)
	tree.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	await settle(Vector3(0,0.05,20))
	var yaw = body.get_node("CameraRig/YawPivot")
	var facing: float = body.visual.rotation.y
	var clock = tree.get("parameters/Locomotion/playback")
	var first_clock: float = clock.get_current_play_position()
	for frame in 120:
		yaw.rotation.y=TAU*frame/119.0
		await tick()
		check(absf(wrapf(body.visual.rotation.y-facing,-PI,PI))<0.0001,"idle orbit preserves facing")
		check(animation.grounded.transition==&"Loops","orbit never triggers turn")
	check(clock.get_current_play_position()!=first_clock,"idle animation clock keeps advancing")
	yaw.rotation.y=PI
	await tick(Vector2(0,-1))
	check(body.animation_state.move_direction_world.z>0.99 and body.turn_arc_active,"opposite camera-forward input starts normal arc")
	for gait in 3:
		body.step_solver.cancel()
		await settle(Vector3(62,1.25,-30))
		body.visual.rotation.y=PI
		yaw.rotation.y=PI
		body._run_time=4.0 if gait==2 else 0.0
		var landings: int = animation.landing_count
		var air_frames := 0
		var near_frames := 0
		for frame in 195:
			await tick(Vector2(0,-1),gait>0)
			if body.animation_state.is_airborne: air_frames+=1
			if animation.ground_within_grace: near_frames+=1
			check(animation.current_state==&"Locomotion","20 cm descent keeps locomotion")
			check(not animation.fall_visual_committed,"20 cm descent never commits Fall")
			check(body.animation_state.gait==gait,"descent preserves gait")
			if body.position.z> -19: break
		check(body.position.z> -19,"stair descent completed")
		check(animation.landing_count==landings,"no stair landing events")
		print("PASSIVE_STAIRS gait=",gait," air_frames=",air_frames," near_frames=",near_frames," end=",body.position)
	# Meaningful drop: once committed, nearby ground may not undo Fall.
	yaw.rotation.y=0
	await settle(Vector3(9,3.05,-23))
	body.visual.rotation.y=0
	var saw_fall := false
	var landings: int = animation.landing_count
	for frame in 160:
		await tick(Vector2(0,-1),true)
		if animation.current_state==&"Fall": saw_fall=true
		if saw_fall and body.animation_state.is_airborne:
			check(animation.current_state==&"Fall" and animation.fall_visual_committed,"Fall stays committed until contact")
	check(saw_fall and animation.landing_count==landings+1,"large ledge produces Fall and one Land")
	# Grounded stair jump is immediate and bypasses near-ground suppression.
	await settle(Vector3(62,1.25,-30))
	yaw.rotation.y=PI
	body.visual.rotation.y=PI
	for frame in 150:
		await tick(Vector2(0,-1),true)
		if body.position.z> -24.8 and body.is_on_floor(): break
	check(body.is_on_floor() and body.position.z> -24.8,"jump test reaches actual floor contact on descent")
	await tick(Vector2(0,-1),true,true)
	check(body.animation_state.jump_started and animation.current_state==&"JumpMoving","stair jump is immediate")
	check(body.velocity.y>7.0,"original jump impulse retained")
	print("IDLE_PASSIVE_FALL_V2: ","PASS" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)
