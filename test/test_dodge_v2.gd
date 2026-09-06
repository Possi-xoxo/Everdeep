extends "res://test/test_lock_on_v2.gd"
var dodge: Resource
var cam: Node

func roll_tick(stick:=Vector2.ZERO,shift:=false,jump:=false,pressed:=false) -> void:
	await physics_frame
	body.step_motor(DT,stick,shift,jump,pressed)
	animation._physics_process(DT)
	tree.advance(DT)
	cam._process(DT)

func finish_roll(stick:=Vector2.ZERO,shift:=false) -> void:
	for frame in 240:
		await roll_tick(stick,shift)
		if not dodge.is_dodging and not dodge.run_roll_recovery_visible: break
	check(not dodge.is_dodging,"roll completes from evaluated animation progress")
	for frame in 12: await roll_tick(stick,shift)

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
	body.set_physics_process(false)
	animation.set_physics_process(false)
	cam.set_process(false)
	tree.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	check(InputMap.has_action("dodge"),"existing dodge action")
	check(InputMap.action_get_events("dodge")[0].physical_keycode==KEY_ALT,"ALT binding")
	for name in [dodge.STAND,dodge.RUN,dodge.SPRINT,dodge.BACK]:
		check(animation.player.has_animation(name),"canonical roll exists")
		check(animation.player.get_animation(name).loop_mode==Animation.LOOP_NONE,"roll does not loop")
	await reset_player()
	var landing_before: int=animation.landing_count
	var start:=body.position
	# Use real InputMap dispatch for the first trigger and held-key check.
	await process_frame
	var key:=InputEventKey.new()
	key.physical_keycode=KEY_ALT
	key.location=KEY_LOCATION_LEFT
	key.pressed=true
	Input.parse_input_event(key)
	await physics_frame
	body._physics_process(DT)
	animation._physics_process(DT)
	tree.advance(DT)
	check(dodge.is_dodging and dodge.clip==dodge.BACK,"ALT Idle starts backstep")
	check(dodge.dodge_direction.dot(Vector3.BACK)>0.99,"Free Idle retreats without turning")
	var starts: int=dodge.starts
	for frame in 40:
		await roll_tick(Vector2(1,0),false,true,true)
		check(dodge.starts==starts and not body.animation_state.jump_started,"spam and jump cannot interrupt roll")
		check(dodge.dodge_direction.dot(Vector3.BACK)>0.99,"direction captured once")
		check((-body.visual.global_basis.z).dot(Vector3.FORWARD)>0.99,"Free backstep does not rotate toward new input")
	key.pressed=false
	Input.parse_input_event(key)
	for leg in ik.legs: check(leg.weight<0.01 and not leg.plant.locked,"IK and planting release")
	check(absf(ik.pelvis.applied_offset)<0.01,"pelvis releases")
	await finish_roll()
	print("BACKSTEP distance=",start.distance_to(body.position)," timeline=",dodge.timeline_length)
	check(body.position.distance_to(start)>1,"physics displaces dodge")
	check(animation.current_state==&"Locomotion" and animation.landing_count==landing_before,"roll exit is not Land")
	# A user-selected playback rate changes the evaluated clip duration, not
	# an independent motor timer. Exit remains a source-normalized boundary.
	for rate in [0.85,1.15]:
		await reset_player()
		dodge.backstep_playback_speed=rate
		await roll_tick(Vector2.ZERO,false,false,true)
		var frames:=0
		while dodge.is_dodging and frames<240:
			await roll_tick()
			frames+=1
		check(absf(frames*DT-dodge.timeline_length*dodge.exit_progress)<0.06,"manual playback speed sets animation-driven duration")
		await finish_roll()
	dodge.backstep_playback_speed=1.0
	for gait in [0,1,2]:
		await reset_player()
		body._run_time=body.sprint_buildup_duration if gait==2 else 0
		for frame in 15: await roll_tick(Vector2(0,-1),gait>0)
		await roll_tick(Vector2(0,1),gait>0,false,true)
		check(dodge.clip==(dodge.STAND if gait==0 else (dodge.SPRINT if gait==2 else dodge.RUN)),"gait chooses correct fixed clip")
		check(not body.turn_180.active,"dodge priority over reversal")
		check(dodge.dodge_direction.dot(Vector3.BACK)>0.99,"Free requested back dodge")
		await finish_roll(Vector2(0,1),gait>0)
		check(body.animation_state.gait==gait,"return preserves gait/buildup")
	# All target-relative axes including no-input defensive default.
	for stick in [Vector2.ZERO,Vector2(1,0),Vector2(-1,0),Vector2(0,-1),Vector2(0,1),Vector2(1,-1)]:
		await reset_player()
		lock.toggle()
		var forward: Vector3=lock.direction()
		var expected: Vector3=-forward if stick.is_zero_approx() else (forward.cross(Vector3.UP)*stick.x-forward*stick.y).normalized()
		await roll_tick(stick,true,false,true)
		check(dodge.dodge_direction.dot(expected)>0.99,"Locked target-relative direction")
		await finish_roll(stick,true)
		check(lock.is_locked() and body.animation_state.gait<2,"lock persists without Sprint")
		# Recovery now permits extra target-relative travel. Stop near the target
		# and let the existing smooth facing catch up before testing alignment.
		for frame in 24: await roll_tick(Vector2.ZERO,true)
		check((-body.visual.global_basis.z).dot(lock.direction())>0.95,"target facing preserved")
		check(tree.get("parameters/Locomotion/playback").get_current_node()==&"Locked","Locked branch restored")
	# Changes in mode/input during a committed action affect the destination,
	# never its captured direction or clip.
	await reset_player()
	lock.toggle()
	await roll_tick(Vector2(1,0),false,false,true)
	var captured: Vector3=dodge.dodge_direction
	lock.clear()
	await finish_roll(Vector2.ZERO,false)
	check(dodge.dodge_direction==captured and not lock.is_locked(),"unlock during roll preserves captured action")
	check(tree.get("parameters/Locomotion/playback").get_current_node()==&"Loops","unlock during roll returns Free")
	await reset_player()
	await roll_tick(Vector2.ZERO,false,true)
	await roll_tick(Vector2.ZERO,false,false,true)
	check(not dodge.is_dodging,"airborne ALT rejected")
	for frame in 130: await roll_tick()
	await roll_tick(Vector2.ZERO,false,false,true)
	await finish_roll()
	await roll_tick(Vector2.ZERO,false,true)
	check(body.animation_state.jump_started,"jump available after roll")
	for frame in 130: await roll_tick()
	# A dedicated wall tests body collision without relying on lab wall positions.
	await reset_player()
	var wall:=StaticBody3D.new()
	var shape:=CollisionShape3D.new()
	var box:=BoxShape3D.new()
	box.size=Vector3(10,4,0.3)
	shape.shape=box
	wall.add_child(shape)
	lab.add_child(wall)
	wall.position=Vector3(0,1,13)
	await physics_frame
	await roll_tick(Vector2(0,-1),false,false,true)
	await finish_roll()
	check(body.position.z>13.4,"roll cannot pass through wall")
	wall.free()
	await reset_player()
	await settle(Vector3(62,0.1,-18))
	await roll_tick(Vector2(0,-1),false,false,true)
	for frame in 150:
		await roll_tick(Vector2(0,-1))
		if not dodge.is_dodging: break
		check(not body.step_solver.active and body.velocity.y<=0.1,"roll suppresses stair step-up without launch")
		for leg in ik.legs: check(leg.solved.is_finite(),"roll IK finite")
	# Ledge handoff uses explicit removal of support: no ground roll in the air.
	await reset_player()
	await roll_tick(Vector2.ZERO,false,false,true)
	body.position.y+=3
	await roll_tick()
	check(not dodge.is_dodging and animation.current_state==&"Fall","support loss hands roll to Fall")
	print("DODGE_V2: ","PASS" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)
