extends "res://test/test_dodge_v2.gd"

func blend(from: StringName,to: StringName) -> float:
	var machine=tree.tree_root
	for i in machine.get_transition_count():
		if machine.get_transition_from(i)==from and machine.get_transition_to(i)==to: return machine.get_transition(i).xfade_time
	return -1

func run() -> void:
	var lab=load("res://test/player_v2_lab.tscn").instantiate()
	root.add_child(lab)
	body=lab.get_node("PlayerV2")
	animation=body.get_node("AnimationController")
	tree=body.get_node("AnimationTree")
	lock=body.get_node("LockOnController")
	dummy=lab.get_node("LockOnTargetDummy")
	cam=body.get_node("CameraRig")
	dodge=body.dodge
	body.set_physics_process(false)
	animation.set_physics_process(false)
	cam.set_process(false)
	tree.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	for locked in [false,true]:
		await reset_player()
		if locked: lock.toggle()
		await roll_tick(Vector2(0,-1),true,false,true)
		await finish_roll(Vector2(0,-1),true)
		check(is_equal_approx(blend(&"DodgeRun",&"Locomotion"),.2),"run roll uses 0.2 second exit blend")
		check(animation.current_state==&"Locomotion","clean return to locomotion")
		check(lock.is_locked()==locked,"mode preserved")
	await reset_player()
	await roll_tick(Vector2.ZERO,false,false,true)
	await finish_roll()
	check(is_equal_approx(blend(&"DodgeBack",&"Locomotion"),.1),"backstep blend unchanged")
	await reset_player()
	await roll_tick(Vector2(0,-1),false,false,true)
	await finish_roll()
	check(is_equal_approx(blend(&"DodgeStand",&"Locomotion"),.1),"walk roll blend unchanged")
	await reset_player()
	await roll_tick(Vector2(0,-1),true,false,true)
	body.position.y+=3
	await roll_tick()
	check(animation.current_state==&"Fall" and is_equal_approx(blend(&"DodgeRun",&"Fall"),.1),"airborne handoff unchanged")
	print("RUN_ROLL_EXIT_BLEND_V2: ","PASS" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)
