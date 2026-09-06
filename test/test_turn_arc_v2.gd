extends "res://test/test_player_v2.gd"

func reset_case() -> void:
	body.turn_180.cancel()
	body.get_node("CameraRig/YawPivot").rotation.y = 0
	body.visual.rotation.y = 0
	body.turn_arc_active = false
	body.last_large_turn_sign = 1
	await settle(Vector3(0,0.1,20))
	body.visual.rotation.y = 0

func run() -> void:
	var lab = load("res://test/player_v2_lab.tscn").instantiate()
	root.add_child(lab)
	body = lab.get_node("PlayerV2")
	animation = body.get_node("AnimationController")
	tree = body.get_node("AnimationTree")
	body.set_physics_process(false)
	animation.set_physics_process(false)
	tree.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	for degrees in [45.0,90.0,120.0,135.0,-135.0]:
		await reset_case()
		var yaw := deg_to_rad(degrees)
		var desired := Vector3.FORWARD.rotated(Vector3.UP,yaw)
		var stick := Vector2(desired.x,desired.z)
		await tick(stick)
		var s = body.animation_state
		check(s.turn_arc_active == (absf(degrees)>90), "activation threshold %s" % degrees)
		check(s.horizontal_speed > 0.1, "immediate movement %s" % degrees)
		check(s.move_direction_world.is_equal_approx(desired), "original intent retained")
		if absf(degrees)>90:
			check(absf(s.allowed_move_delta) <= deg_to_rad(60.01), "movement target constrained to 60 degrees")
			check(absf(body.visual.rotation.y) <= deg_to_rad(6.01), "rotation bounded to 360 degrees/sec")
			check(animation.grounded.transition == &"Loops", "arc does not invoke stationary turn")
			var first_direction: Vector3 = s.allowed_move_direction_world
			for i in 35:
				await tick(stick)
			check(not s.turn_arc_active, "arc converges and releases")
			check(s.allowed_move_direction_world.dot(first_direction) < 0.8, "acceleration direction curves")
			check(s.allowed_move_direction_world.dot(desired)>0.999, "release restores desired direction")
			check(absf(s.facing_delta)<0.05, "faces original target")
	# Dedicated animation-led turns now supersede arcs for idle opposites.
	await reset_case()
	body.last_large_turn_sign = -1
	await tick(Vector2(0,1))
	check(not body.turn_180.active and body.turn_arc_active, "idle 180 uses arc")
	await tick()
	check(not body.turn_arc_active, "input release cancels arc")
	await reset_case()
	body.get_node("CameraRig/YawPivot").rotation.y = PI
	await tick(Vector2(0,-1))
	check(body.turn_arc_active and body.animation_state.move_direction_world.z>0.99, "camera-relative backward W activates arc")
	await tick(Vector2(0,-1),false,true)
	check(not body.turn_arc_active and not body.turn_180.active and animation.current_state == &"JumpMoving", "jump cancels idle arc immediately")
	for i in 120:
		await tick()
	await reset_case()
	body.turn_arc_suppressed = true
	await tick(Vector2(0,1))
	check(not body.turn_arc_active, "non-locomotion gate suppresses arc")
	await reset_case()
	for i in 30:
		await tick(Vector2(0,-1),true)
	await tick(Vector2(0,1),true)
	check(not body.turn_arc_active, "already moving Run retains responsive steering")
	await reset_case()
	for i in 260:
		await tick(Vector2(0,-1),true)
	await tick(Vector2(0,1),true)
	check(body.turn_180.active and not body.turn_arc_active and body.animation_state.gait == 2, "Sprint 180 pivot supersedes arc without dropping gait")
	check(body.velocity.z < 0, "Sprint carries forward momentum into Run180 before pausing")
	print("TURN_ARC_V2: ", "PASS" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)
