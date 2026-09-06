extends "res://test/test_roll_traversal_v2.gd"

func prepare_locked() -> void:
	await reset_at(Vector3(200,.1,16))
	dummy.position=Vector3(200,0,0)
	lock.toggle()
	check(lock.is_locked(),"fixture locks target")

func scenario(input: Vector2, running: bool, current_input: Vector2) -> void:
	await prepare_locked()
	await roll_tick(input,running,false,true)
	var saw_realign:=false
	var ended:=false
	for frame in 240:
		var was_dodge: bool=dodge.is_dodging
		var was_realign: bool=lock.lock_roll_realign_active
		var before: float=body.visual.global_rotation.y
		var source_frame: float=dodge.dodge_elapsed*dodge.playback_speed*30
		await roll_tick(current_input,running)
		if was_dodge and not dodge.is_dodging:
			ended=true
			if running: check(source_frame>=59-.001 and source_frame<59.51,"Run hands control back at frame 59")
			if input.x!=0 or input.y>0:
				check(lock.lock_roll_realign_active,"directional exit begins facing recovery")
		if lock.lock_roll_realign_active or was_realign:
			saw_realign=true
			check(absf(wrapf(body.visual.global_rotation.y-before,-PI,PI))<=deg_to_rad(450)*DT+.00001,"single bounded yaw owner, no snap")
			check(body.animation_state.combat_input.is_equal_approx(Vector2(current_input.x,-current_input.y)),"combat input remains target-relative")
			var expected: Vector3=(lock.direction().cross(Vector3.UP)*current_input.x-lock.direction()*current_input.y).normalized()
			check(body.animation_state.move_direction_world.dot(expected)>.98,"body yaw cannot twist movement basis")
			check(body.animation_state.horizontal_speed>.01,"movement continues during realignment")
			check(not body.turn_180.active and not body.turn_arc_active,"no procedural pivot chain")
		if ended and not lock.lock_roll_realign_active: break
	check(ended and lock.is_locked(),"action completes without losing lock")
	if input.x!=0 or input.y>0: check(saw_realign,"recovery observed")
	await finish_roll(Vector2.ZERO,running)
	for frame in 30: await roll_tick()
	check(absf(rad_to_deg(lock.facing_error()))<4,"normal facing smoothly finishes residual error")

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
	for running in [false,true]:
		for input in [Vector2(-1,0),Vector2(1,0),Vector2(0,-1),Vector2(0,1),Vector2(-1,-1).normalized(),Vector2(1,1).normalized()]:
			await scenario(input,running,input)
		await scenario(Vector2(1,0),running,Vector2(0,-1))
	await prepare_locked()
	await roll_tick(Vector2.ZERO,false,false,true)
	for frame in 140:
		await roll_tick()
		check(not lock.lock_roll_realign_active,"aligned Backstep does not wobble")
	# Current target position is authoritative, not the position at recovery start.
	body.visual.rotation.y=PI/2
	lock.begin_roll_realign()
	dummy.position.x+=8
	var yaw: float=body.visual.global_rotation.y
	var error: float=lock.facing_error()
	lock.face_target(DT)
	check(is_equal_approx(wrapf(body.visual.global_rotation.y-yaw,-PI,PI),clampf(error,-deg_to_rad(450)*DT,deg_to_rad(450)*DT)),"recovery tracks moved target")
	lock.clear()
	check(not lock.lock_roll_realign_active,"manual unlock cancels immediately")
	await prepare_locked()
	body.visual.rotation.y=PI
	lock.begin_roll_realign()
	await roll_tick(Vector2.ZERO,false,true)
	check(body.animation_state.jump_started and not lock.lock_roll_realign_active,"Jump cancels recovery")
	await prepare_locked()
	body.visual.rotation.y=PI/2
	lock.begin_roll_realign()
	dodge.cooldown=0
	await roll_tick(Vector2(1,0),false,false,true)
	check(dodge.is_dodging and not lock.lock_roll_realign_active,"new dodge owns yaw")
	await finish_roll()
	await prepare_locked()
	body.visual.rotation.y=PI/2
	lock.begin_roll_realign()
	dummy.remove_from_group("lock_on_target")
	await roll_tick()
	check(not lock.is_locked() and not lock.lock_roll_realign_active,"invalid target cancels recovery")
	dummy.add_to_group("lock_on_target")
	await prepare_locked()
	lock.lock_roll_realign_speed=90
	body.visual.rotation.y=deg_to_rad(5)
	lock.begin_roll_realign()
	check(not lock.lock_roll_realign_active,"tiny facing error skips recovery")
	body.visual.rotation.y=PI/2
	lock.lock_roll_realign_delay=.08
	lock.begin_roll_realign()
	yaw=body.visual.rotation.y
	for frame in 4: lock.face_target(DT)
	check(is_equal_approx(body.visual.rotation.y,yaw),"optional delay holds yaw without affecting motor")
	lock.lock_roll_realign_delay=0
	body.visual.rotation.y=PI
	lock.begin_roll_realign()
	for frame in 20: lock.face_target(DT)
	check(not lock.lock_roll_realign_active,"timeout releases yaw ownership")
	yaw=body.visual.rotation.y
	error=lock.facing_error()
	lock.face_target(DT)
	check(absf(wrapf(body.visual.rotation.y-yaw,-PI,PI))<absf(error)*.3,"timeout resumes smooth normal facing, not snap")
	print("LOCK_ROLL_REALIGN_V2: ","PASS" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)
