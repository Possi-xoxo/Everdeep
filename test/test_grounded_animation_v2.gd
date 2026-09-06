extends "res://test/test_player_v2.gd"

func run() -> void:
	var lab := load("res://test/player_v2_lab.tscn").instantiate() as Node3D
	root.add_child(lab)
	body = lab.get_node("PlayerV2")
	animation = body.get_node("AnimationController")
	tree = body.get_node("AnimationTree")
	body.set_physics_process(false)
	animation.set_physics_process(false)
	tree.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	await settle(Vector3(0,0.1,20))
	var g = animation.grounded
	check(not g.debug_grounded, "grounded debug defaults off")
	var loops = tree.tree_root.get_node("Locomotion").get_node("Loops")
	check(not tree.tree_root.get_node("Locomotion").has_node("WalkStart"), "WalkStart removed from graph")
	check(not tree.tree_root.get_node("Locomotion").has_node("WalkStop"), "WalkStop removed from graph")
	check(loops.get_blend_point_node(1).get_blend_point_count() == 4, "Walk has four actual cardinal sources")
	check(loops.get_blend_point_node(2).get_blend_point_count() == 3, "Run has three actual cardinal sources")
	check(loops.get_blend_point_node(1).sync_mode == AnimationNodeBlendSpace2D.SYNC_MODE_CYCLIC_MUTABLE, "Walk uses cyclic phase sync")
	await tick(Vector2(0,-1))
	check(g.transition == &"Loops", "Walk starts directly in loops")
	check(body.velocity.length() > 0.1, "Walk responds immediately")
	await tick(Vector2(0,-1),false,true)
	check(animation.current_state == &"JumpMoving" and g.transition == &"Loops", "Jump immediately interrupts walking")
	for i in 90:
		await tick()
	await settle(Vector3(0,0.1,20))
	for i in 50:
		await tick(Vector2(0,-1))
	check(g.transition == &"Loops", "walking remains in loops")
	await tick()
	check(g.transition == &"Loops", "Walk release blends directly toward idle")
	await tick(Vector2(0,1))
	check(g.transition == &"WalkPivot", "moving reversal selects WalkPivot without WalkStart/Stop")
	for i in 3:
		await tick(Vector2(0,1))
	check(body.turn_180.active, "walking reversal remains in its moving pivot")
	for i in 75:
		await tick(Vector2(0,1))
	check(body.animation_state.move_local.y > 0.99, "free locomotion reorients toward travel")
	for i in 30:
		await tick(Vector2(0,1),true)
	await tick(Vector2.ZERO,true)
	check(g.transition == &"RunStop", "Run release enters RunStop")
	await tick(Vector2.ZERO,true,true)
	check(animation.current_state == &"JumpMoving", "Jump cancels RunStop")
	body.get_node("CameraRig/YawPivot").rotation.y = body.visual.rotation.y
	for i in 180:
		await tick()
	# Align visual with camera so tests can independently exercise thresholds.
	body.visual.rotation.y = 0
	body.get_node("CameraRig/YawPivot").rotation.y = deg_to_rad(45)
	for i in 5:
		await tick()
	check(g.transition == &"Loops", "45 degrees below 60-degree threshold")
	body.get_node("CameraRig/YawPivot").rotation.y = PI/2
	await tick()
	check(g.transition == &"TurnLeft", "90-degree left camera orbit enters stationary turn")
	var pos := body.position
	for i in 90:
		await tick()
	check(absf(wrapf(body.visual.rotation.y - PI/2,-PI,PI)) < 0.03, "stationary turn finishes with matching visual facing")
	check(body.position.distance_to(pos) < 0.005, "turn does not translate physical body")
	body.get_node("CameraRig/YawPivot").rotation.y = 0
	await tick()
	check(g.transition == &"TurnRight", "right orbit selects right turn")
	await tick(Vector2(0,-1))
	check(g.transition == &"Loops", "movement cancels stationary turn")
	for i in 20:
		await tick(Vector2(0,-1))
	await tick()
	check(g.transition == &"Loops", "second Walk release stays in loops")
	for i in 65:
		await tick()
	check(g.transition == &"Loops" and is_zero_approx(animation.gait_blend), "Walk settles directly to idle")
	# Camera-relative cardinal/diagonal travel remains a transient local blend.
	for stick in [Vector2(-1,0),Vector2(1,0),Vector2(1,-1).normalized(),Vector2(-1,1).normalized()]:
		await tick(stick)
		check(body.animation_state.move_local.is_finite(), "direction remains finite")
		var expected: Vector2 = body.animation_state.move_local if body.animation_state.horizontal_speed > 0.1 else Vector2(0,1)
		check(tree.get("parameters/Locomotion/Loops/Walk/blend_position").is_equal_approx(expected), "Walk consumes published direction or its stopped fallback")
		# A sufficiently opposite request now commits to a full-source Walk180.
		for i in 90:
			await tick(stick)
		check(body.animation_state.move_local.y > 0.98, "diagonal/cardinal free movement rotates forward")
	for i in 260:
		await tick(Vector2(0,-1),true)
	check(body.animation_state.gait == 2 and is_equal_approx(animation.gait_blend,3), "Sprint remains forward-only gait")
	check(loops.get_blend_point_node(3) is AnimationNodeAnimation, "Sprint is not a directional space")
	await tick(Vector2.ZERO,true)
	check(g.transition == &"RunStop", "Sprint uses RunStop")
	await tick(Vector2(0,-1),true)
	check(g.transition == &"Loops", "movement cancels RunStop")
	body.get_node("CameraRig/YawPivot").rotation.y = body.visual.rotation.y
	for i in 100:
		await tick()
	body.get_node("CameraRig/YawPivot").rotation.y = body.visual.rotation.y + PI
	await tick()
	check(g.transition in [&"TurnLeft", &"TurnRight"], "180-degree stationary change uses bounded turns")
	await tick(Vector2.ZERO,false,true)
	check(animation.current_state == &"JumpStanding" and g.transition == &"Loops", "Jump immediately cancels Turn")
	check(is_equal_approx(animation.standing_land_clip_start,0.4), "standing Land source start preserved")
	print("GROUNDED_V2: ", "PASS" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)
