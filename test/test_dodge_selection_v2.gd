extends "res://test/test_dodge_v2.gd"

func run() -> void:
	var lab=load("res://test/player_v2_lab.tscn").instantiate()
	root.add_child(lab)
	root.size=Vector2i(1280,720)
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
	# Released input wins over residual running velocity and source gait.
	for locked in [false,true]:
		await reset_player()
		if locked: lock.toggle()
		for frame in 20: await roll_tick(Vector2(0,-1),true)
		check(body.animation_state.horizontal_speed>2,"release fixture has momentum")
		await roll_tick(Vector2.ZERO,true,false,true)
		check(dodge.dodge_type=="BACKSTEP" and dodge.clip==&"DPD_DODING_BACK","released running input selects neutral backstep")
		var facing: Vector3=-body.visual.global_basis.z
		await finish_roll()
		check((-body.visual.global_basis.z).dot(facing)>0.98,"backstep retains facing")
	# Deadzone boundary is based on intent, not the always-normalized direction.
	for magnitude in [0.10,0.149,0.15,0.20]:
		await reset_player()
		await roll_tick(Vector2(magnitude,0),false,false,true)
		check((dodge.dodge_type=="BACKSTEP")== (magnitude<0.15),"threshold separates backstep and roll")
		await finish_roll()
	# Test every cardinal/diagonal for both combat gaits, measured displacement
	# and visual orientation rather than only the captured direction variable.
	for running in [false,true]:
		for stick in [Vector2(0,-1),Vector2(0,1),Vector2(-1,0),Vector2(1,0),Vector2(-1,-1),Vector2(1,-1),Vector2(-1,1),Vector2(1,1)]:
			await reset_player()
			lock.toggle()
			for frame in 25: await roll_tick(stick,running)
			var forward: Vector3=lock.direction()
			var right:=forward.cross(Vector3.UP)
			var expected: Vector3=(right*stick.x-forward*stick.y).normalized()
			var initial:=body.position
			await roll_tick(stick,running,false,true)
			check(dodge.clip==(dodge.RUN if running else dodge.STAND),"moving combat gait clip")
			check(dodge.raw_combat_input.is_equal_approx(Vector2(stick.x,-stick.y).limit_length(1)),"debug captures raw combat input")
			for frame in 40:
				await roll_tick(-stick,not running)
				check(dodge.dodge_direction.dot(expected)>0.999,"input changes cannot retarget")
				check(lock.is_locked(),"target persists during moving roll")
			var displacement:=body.position-initial
			displacement.y=0
			check(displacement.normalized().dot(expected)>0.999,"physical roll follows combat input without target bias")
			check((-body.visual.global_basis.z).dot(expected)>0.99,"locked visual aligns with roll travel")
			check(absf(body.animation_state.horizontal_speed-dodge.base_speed*dodge.speed_multiplier)<0.02,"diagonal speed not inflated")
			var point: Vector3=dummy.get_node("LockOnPoint").global_position
			check(not body.camera.is_position_behind(point),"locked camera keeps target ahead during roll")
			var screen: Vector2=body.camera.unproject_position(point)
			check(Rect2(Vector2.ZERO,Vector2(root.size)).has_point(screen),"locked camera frames target during lateral roll")
			while dodge.is_dodging:
				var before: float=body.visual.rotation.y
				await roll_tick()
				if not dodge.is_dodging:
					check(absf(wrapf(body.visual.rotation.y-before,-PI,PI))<0.65,"exit restores facing without snap")
			await finish_roll()
			for frame in 30: await roll_tick()
			check((-body.visual.global_basis.z).dot(lock.direction())>0.99,"target facing smoothly restored")
	print("DODGE_SELECTION_V2: ","PASS" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)
