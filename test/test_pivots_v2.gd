extends "res://test/test_player_v2.gd"
func reset_case() -> void:
	body.turn_180.cancel()
	body.get_node("CameraRig/YawPivot").rotation.y = 0
	body.visual.rotation.y = 0
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
	var turn = body.turn_180
	for gait in 3:
		await reset_case()
		for i in (260 if gait==2 else 40):
			await tick(Vector2(0,-1),gait>0)
		var entry: float = body.animation_state.horizontal_speed
		await tick(Vector2(0,1),gait>0)
		check(turn.active and turn.started,"moving reversal triggers")
		check(turn.source_gait==gait,"source gait captured")
		check(is_equal_approx(turn.entry_speed,entry),"entry speed captured once")
		var saved_buildup: float = turn.entry_buildup
		var node = tree.tree_root.get_node("Locomotion").get_node(animation.grounded.transition)
		check(not node.use_custom_timeline,"default playback uses uncompressed source")
		var length: float = animation.player.get_animation(node.animation).length
		if gait>0:
			check(node.animation == &"LOC_RUNNING_TURN_180","Run/Sprint use the correct non-RAW running turn")
			check(absf(length-0.7)<0.001,"correct running source is 0.70 seconds at 1.0x")
		var ticks := 1
		var position_at_start := body.position
		var saw_carry := false
		var saw_pause := false
		while turn.active and ticks<180:
			var previous_progress: float = turn.progress
			var previous_position := body.position
			await tick(Vector2(0,1),gait>0)
			ticks+=1
			check(not turn.started,"held input cannot restart")
			if turn.active and gait>0:
				if previous_progress < turn.run_180_carry_end_progress:
					saw_carry = true
					check(absf(body.velocity.z + entry)<0.001,"Run/Sprint carry original forward speed, not reversed input")
				else:
					saw_pause = true
					check(body.animation_state.horizontal_speed==0,"Run/Sprint pause after carry-through")
					check(body.position.distance_to(previous_position)<0.005,"planted position remains fixed")
				check(is_equal_approx(body._run_time,saved_buildup),"buildup stays captured throughout turn")
			elif turn.active and turn.progress>0.38 and turn.progress<0.5:
				check(body.animation_state.horizontal_speed<0.08,"Walk profile retained")
		check(not turn.active,"turn completes")
		check(absf(ticks*DT-length)<0.07,"natural full source duration")
		if gait>0:
			check(saw_carry and saw_pause,"carry-through precedes pause")
			check(body.position.z < position_at_start.z,"initial momentum advances forward before reversal")
			check(absf(body.animation_state.horizontal_speed-entry)<0.001,"completion restores exact entry speed")
			check(body.animation_state.gait==gait,"completion preserves Run or Sprint")
		check(body.velocity.z>3,"exit direction restored")
	# Idle opposite requests must stay arcs, even after acceleration begins.
	for shift in [false,true]:
		await reset_case()
		for i in 45:
			await tick(Vector2(0,1),shift)
			check(not turn.active,"idle opposite never escalates into dedicated turn")
	# Release input: finish visually, but never restore speed.
	await reset_case()
	for i in 40:
		await tick(Vector2(0,-1),true)
	await tick(Vector2(0,1),true)
	for i in 150:
		await tick(Vector2.ZERO,true)
	check(not turn.active and body.animation_state.horizontal_speed==0,"released turn exits idle without momentum")
	# Incompatible input remains locked during playback; Jump is immediate.
	await reset_case()
	for i in 40:
		await tick(Vector2(0,-1),true)
	await tick(Vector2(0,1),true)
	var target: Vector3 = turn.target_direction
	for i in 15:
		await tick(Vector2(1,0),true)
	check(turn.active and turn.target_direction.is_equal_approx(target),"changed input does not retarget/cancel Run180")
	await tick(Vector2(1,0),true,true)
	check(not turn.active and animation.current_state==&"JumpMoving","Jump cancels as MovingJump")
	check(body.animation_state.horizontal_speed>1,"Jump restores horizontal control/momentum")
	for i in 130:
		await tick()
	for angle in [120.0,170.0]:
		await reset_case()
		for i in 40:
			await tick(Vector2(0,-1),true)
		var desired := Vector3.FORWARD.rotated(Vector3.UP,deg_to_rad(angle))
		await tick(Vector2(desired.x,desired.z),true)
		check(turn.active == (angle>=150),"Run trigger angle")
	print("PIVOTS_V2: ","PASS" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)
