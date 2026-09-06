extends "res://test/test_roll_traversal_v2.gd"

func scenario(input: Vector2, held_shift: bool = true, sprinting: bool = false, locked: bool = false, rate: float = 1.0, rotate_camera: bool = false) -> void:
	await reset_at(Vector3(200,.1,16))
	dodge.run_roll_playback_speed=rate
	if locked:
		dummy.position=Vector3(200,0,8)
		lock.toggle()
	if sprinting:
		body._run_time=body.sprint_buildup_duration
		await roll_tick(Vector2(0,-1),true)
	await roll_tick(Vector2(0,-1),true,false,true)
	var captured: Vector3=dodge.dodge_direction
	if rotate_camera: cam.get_node("YawPivot").rotation.y=PI/2
	var source_length: float=animation.player.get_animation(dodge.RUN).length
	check(absf(source_length-2.46666669845581)<.000001,"full source clip retained")
	check(absf(dodge.run_roll_handoff_progress-(59.0/30.0)/source_length)<.000001,"actual duration determines marker")
	var events:=0
	var expected_direction:=Vector3.ZERO
	for frame in 200:
		var evaluated: float=dodge.dodge_elapsed*dodge.playback_speed*30
		var forward: Vector3=lock.direction() if locked else -body.camera.global_basis.z
		forward.y=0
		forward=forward.normalized()
		var right: Vector3=forward.cross(Vector3.UP)
		expected_direction=(right*input.x-forward*input.y).normalized()
		await roll_tick(input,held_shift)
		if dodge.handoff_this_tick: events+=1
		if not dodge.is_dodging:
			check(evaluated>=59-.0001 and evaluated<59+.51*rate,"handoff on first motor tick after evaluated frame 59")
			break
		check(dodge.dodge_direction.is_equal_approx(captured),"captured intent remains committed before marker")
	check(dodge.run_roll_control_returned and events==1,"control returned exactly once")
	check(animation.current_state==&"DodgeRun" and dodge.run_roll_recovery_visible,"grounded control handoff retains recovery animation")
	check(lock.is_locked()==locked,"lock preserved")
	var requested: Vector3=body.animation_state.move_direction_world
	var horizontal:=Vector3(body.velocity.x,0,body.velocity.z)
	if input.length()<dodge.dodge_movement_input_threshold:
		check(horizontal.length()<.001 and animation.gait_blend==0,"no-input handoff is Idle without drift")
	else:
		check(requested.dot(expected_direction)>.999,"current camera/target-relative input basis used")
		check(horizontal.length()>.01 and horizontal.normalized().dot(requested)>.999,"current direction accelerates in same handoff tick")
		check(body.animation_state.gait==(2 if sprinting and held_shift and not locked else (1 if held_shift else 0)),"current gait eligibility restored")
	for frame in 24:
		var pose_frame: float=dodge.dodge_elapsed*dodge.playback_speed*30
		await roll_tick(input,held_shift)
		if pose_frame<65-.0001:
			check(animation.current_state==&"DodgeRun","source recovery continues through frames 59-65")
		check(not dodge.handoff_this_tick,"handoff event does not repeat")
		check(not body.turn_180.active and not body.turn_arc_active,"no old-direction pivot/arc chain")
	check(animation.current_state==&"Locomotion" and not dodge.run_roll_recovery_visible,"recovery then blends into current locomotion")
	print("HANDOFF input=",input," shift=",held_shift," sprint=",sprinting," locked=",locked," rate=",rate," velocity=",horizontal)

func overlap() -> void:
	await reset_at()
	var ledge:=box(Vector3(200,.35,-13),Vector3(6,.7,30))
	await physics_frame
	await roll_tick(Vector2(0,-1),true,false,true)
	for frame in 90:
		await roll_tick(Vector2(0,-1),true)
		if assist.active: break
	check(assist.active,"overlap fixture starts real validated lift")
	# Force evaluated pose to frame 59 while a real lift is active.
	tree.advance((59.0/30.0)/dodge.playback_speed-animation._playback.get_current_play_position())
	await roll_tick(Vector2(1,0),true)
	check(dodge.is_dodging and dodge.handoff_pending,"lift defers handoff")
	check(Vector2(body.velocity.x,body.velocity.z).length()<.001,"pending handoff does not force recovery direction")
	for frame in 40:
		await roll_tick(Vector2(1,0),true)
		if not dodge.is_dodging: break
	check(not assist.active and dodge.run_roll_control_returned,"handoff follows completed correction")
	check(body.position.y>=.69,"completed lift leaves capsule above ledge")
	ledge.free()

func run() -> void:
	lab=load("res://test/player_v2_lab.tscn").instantiate()
	root.add_child(lab)
	body=lab.get_node("PlayerV2")
	animation=body.get_node("AnimationController")
	tree=body.get_node("AnimationTree")
	lock=body.get_node("LockOnController")
	dummy=lab.get_node("LockOnTargetDummy")
	ik=body.get_node("FootIKController")
	cam=body.get_node("CameraRig")
	dodge=body.dodge
	assist=body.roll_traversal
	body.set_physics_process(false)
	animation.set_physics_process(false)
	cam.set_process(false)
	tree.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	box(Vector3(200,-.25,0),Vector3(80,.5,80))
	for input in [Vector2.ZERO,Vector2(.1,0),Vector2(0,-1),Vector2(1,0),Vector2(0,1)]:
		await scenario(input)
	# Sprint now owns a different, shorter clip; covered by test_sprint_roll_v2.
	await scenario(Vector2(1,0),false)
	await scenario(Vector2(-1,0),true,false,true)
	await scenario(Vector2.ZERO,true,false,true)
	await scenario(Vector2(1,0),true,false,false,.9)
	await scenario(Vector2(1,0),true,false,false,1.15)
	await scenario(Vector2(0,-1),true,false,false,1.0,true)
	dodge.run_roll_playback_speed=1
	await drop(1.0,true)
	await drop(60.0,true)
	await overlap()
	print("RUN_ROLL_HANDOFF_V2: ","PASS" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)
