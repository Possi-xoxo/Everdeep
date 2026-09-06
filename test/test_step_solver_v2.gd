extends "res://test/test_player_v2.gd"
var simulation_dt: float = DT

func tick(stick := Vector2.ZERO, shift := false, jump := false) -> void:
	await physics_frame
	body.step_motor(simulation_dt,stick,shift,jump)
	animation._physics_process(simulation_dt)
	tree.advance(simulation_dt)

func run() -> void:
	var lab = load("res://test/player_v2_lab.tscn").instantiate()
	root.add_child(lab)
	body = lab.get_node("PlayerV2")
	animation = body.get_node("AnimationController")
	tree = body.get_node("AnimationTree")
	body.set_physics_process(false)
	animation.set_physics_process(false)
	tree.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	print("STEP_BODY radius=",body.get_node("CollisionShape3D").shape.radius," height=",body.get_node("CollisionShape3D").shape.height," angle=",rad_to_deg(body.floor_max_angle)," margin=",body.safe_margin)
	for gait in 3:
		for i in 10:
			body.step_solver.cancel()
			await settle(Vector3(38+i*6,0.05,7))
			body.visual.rotation.y=0
			body._run_time=4.0 if gait==2 else 0.0
			var count: int = body.step_solver.steps_started
			var minimum := 100.0
			var max_rise := 0.0
			var air := 0
			for frame in 100:
				var old_y: float = body.position.y
				await tick(Vector2(0,-1),gait>0)
				max_rise=maxf(max_rise,body.position.y-old_y)
				if body.step_solver.active:
					check(body.velocity.y<=0.001,"lift never stores upward launch velocity")
					check(body.animation_state.gait==gait,"step preserves gait")
					check(body.animation_state.horizontal_speed<=body.target_speed+0.01,"no horizontal boost")
				if body.position.z<5.0 and body.position.z>3.0:
					minimum=minf(minimum,body.animation_state.horizontal_speed)
					if body.animation_state.is_airborne: air+=1
				if body.position.z<2.0: break
			var traversed: bool = body.position.z<2.0
			print("STEP_CURB gait=",gait," cm=",(i+1)*5," crossed=",traversed," min_speed=",minimum," rise=",max_rise," air=",air," lifts=",body.step_solver.steps_started-count," reason=",body.step_solver.reason)
			check(traversed==(i<7),"curb threshold gait %d height %d" % [gait,(i+1)*5])
			if i<7:
				check(air==0,"curb has continuous supported locomotion")
				check(minimum>3.0,"curb does not stop horizontal motion")
				check(max_rise<=body.step_solver.step_up_speed*DT+0.012,"bounded vertical rise")
	for gait in 3:
		for i in 3:
			body.step_solver.cancel()
			await settle(Vector3(42+i*10,0.05,-18))
			body.visual.rotation.y=0
			body._run_time=4.0 if gait==2 else 0.0
			var air := 0
			var slowest := 100.0
			var landings: int = animation.landing_count
			var largest_rise := 0.0
			var largest_descent := 0.0
			for frame in 200:
				var before_y: float = body.position.y
				await tick(Vector2(0,-1),gait>0)
				if body.position.z< -20.5:
					largest_rise=maxf(largest_rise,body.position.y-before_y)
					largest_descent=maxf(largest_descent,before_y-body.position.y)
					check(animation.current_state==&"Locomotion","no stair Fall/Land flicker")
					var playback = tree.get("parameters/Locomotion/playback")
					check(playback.is_playing() and playback.get_current_node()==&"Loops","stairs keep actual locomotion pose source")
					if body.animation_state.is_airborne: air+=1
					slowest=minf(slowest,body.animation_state.horizontal_speed)
				if body.position.z< -30: break
			print("STEP_STAIRS gait=",gait," riser=",0.1+i*0.05," end=",body.position," air=",air," min_speed=",slowest," reason=",body.step_solver.reason)
			check(body.position.z< -30,"staircase traversed")
			check(air==0,"stairs maintain supported locomotion")
			check(slowest>3.0,"stairs preserve motion")
			check(animation.landing_count==landings,"stairs generate no landing events")
			check(largest_rise<=body.step_solver.step_up_speed*DT+0.012,"stair vertical rise bounded")
			check(largest_descent<0.012,"stair down-correction stays under 12mm")
			print("STEP_STAIR_VERTICAL rise=",largest_rise," down=",largest_descent)
	for location in [Vector3(78,0.05,-20),Vector3(88,0.05,-19),Vector3(115,0.05,5),Vector3(120,0.05,-21)]:
		body.step_solver.cancel()
		await settle(location)
		body.visual.rotation.y=0
		var count: int = body.step_solver.steps_started
		var why: String = ""
		for frame in 100:
			await tick(Vector2(0,-1),true)
			if body.step_solver.reason not in ["NO_LOW_HIT","NOT_MOVING"]: why=body.step_solver.reason
		print("STEP_REJECT at=",location," lifts=",body.step_solver.steps_started-count," reason=",why," end=",body.position)
		check(body.step_solver.steps_started==count,"unsafe obstacle not stepped")
	# Diagonal approach to the ordinary 20 cm curb, without a facing-only probe.
	body.step_solver.cancel()
	await settle(Vector3(55,0.05,6))
	body.visual.rotation.y= -PI/4
	var count: int = body.step_solver.steps_started
	for frame in 70:
		await tick(Vector2(0.5,-1).normalized(),false)
	print("STEP_DIAGONAL end=",body.position," lifts=",body.step_solver.steps_started-count)
	check(body.step_solver.steps_started>count,"diagonal curb detected")
	# Jump and released input must break support immediately, never retain lift velocity.
	for do_jump in [true,false]:
		body.step_solver.cancel()
		await settle(Vector3(50,0.05,6))
		body.visual.rotation.y=0
		for frame in 60:
			await tick(Vector2(0,-1),false)
			if body.step_solver.active: break
		check(body.step_solver.active,"interrupt setup finds a step")
		await tick(Vector2(0,-1) if do_jump else Vector2.ZERO,false,do_jump)
		check(not body.step_solver.active,"jump or input release cancels step")
		if do_jump: check(body.animation_state.jump_started and body.velocity.y>7.0,"jump retains existing impulse")
	# Disabled component retains the known 15 cm blocking baseline.
	body.step_solver.cancel()
	body.step_solver.enabled=false
	await settle(Vector3(50,0.05,6))
	body.visual.rotation.y=0
	for frame in 90: await tick(Vector2(0,-1),false)
	check(body.position.z>4.0,"disabled solver restores ordinary capsule blocking")
	body.step_solver.enabled=true
	# A gentle comparison ramp remains owned by ordinary floor/slope movement.
	body.step_solver.cancel()
	await settle(Vector3(100,0.05,-19))
	body.visual.rotation.y=0
	count=body.step_solver.steps_started
	for frame in 120: await tick(Vector2(0,-1),false)
	check(body.position.y>0.2 and body.step_solver.steps_started==count,"ramp does not need automatic lifts")
	for hz in [30,120]:
		Engine.physics_ticks_per_second=hz
		simulation_dt=1.0/hz
		body.step_solver.cancel()
		await settle(Vector3(50,0.05,7))
		body.visual.rotation.y=0
		body._run_time=4.0
		for frame in hz:
			await tick(Vector2(0,-1),true)
		check(body.position.z<2.0 and body.position.y>0.14,"15 cm sprint curb at %d Hz" % hz)
		print("STEP_RATE ",hz," end=",body.position)
	print("STEP_SOLVER_V2: ","PASS" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)
