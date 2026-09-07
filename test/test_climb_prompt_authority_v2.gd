extends "res://test/test_mantle_v2.gd"
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
	crouch=body.crouch
	detector=body.traversal.get_node("LedgeDetector")
	var mantle=body.traversal.mantle
	body.set_physics_process(false)
	animation.set_physics_process(false)
	cam.set_process(false)
	tree.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	box(Vector3(200,-.25,0),Vector3(80,.5,80))
	for distance in [.55,.95,1.5,2.45,2.49]:
		await ready_fixture()
		body.position.z=9.35+distance
		for frame in 4: await crouch_tick(false)
		body.context_interaction.scan()
		check(body.context_interaction.prompt.visible,"executable prompt at "+str(distance))
		var origin: Vector3=body.position
		check(body.context_interaction.activate_selected(),"visible prompt accepts at "+str(distance))
		check(body.position.is_equal_approx(origin),"commit itself never teleports")
		var previous: Vector3=origin
		var saw_run:=false
		var saw_animation:=false
		for frame in 300:
			var entry: bool=body.traversal.phase==body.traversal.Phase.ENTRY
			# Steering away cannot redirect the committed approach.
			await crouch_tick(false,Vector2(1,0) if entry else Vector2.ZERO)
			if entry:
				check(body.position.distance_to(previous)<=mantle.mantle_approach_speed*DT+.012,"bounded pull-in displacement")
				check(absf(body.position.x-origin.x)<.001,"entry ignores steering input")
				if animation.current_state==&"Locomotion" and animation.gait_blend>1: saw_run=true
			if animation.current_state==&"Mantle": saw_animation=true
			previous=body.position
			if not body.traversal.is_traversing: break
		check(body.traversal.last_end_reason=="COMPLETED" and saw_animation,"far/near mantle completes")
		if distance>1.1: check(saw_run,"long pull-in has moving locomotion pose")
	# No prompt/no interaction outside the single acquisition range.
	await ready_fixture()
	body.position.z=12
	body.context_interaction.scan()
	check(not body.context_interaction.prompt.visible and not body.context_interaction.activate_selected(),"out of prompt range does not start")
	# Wall/ledge geometry is valid, but a low beam blocks the swept approach.
	body.position.z=11.8
	var beam:=box(Vector3(200,1.65,10.7),Vector3(2,.2,.4))
	await crouch_tick(false)
	check(detector.detect_ledge_geometry().valid,"beam fixture has valid wall geometry")
	body.context_interaction.scan()
	check(not body.context_interaction.prompt.visible and detector.result.reject_reason=="ALIGNMENT_BLOCKED","approach preflight hides obstructed prompt")
	check(not body.context_interaction.activate_selected(),"blocked approach cannot start")
	beam.queue_free()
	await crouch_tick(false)
	body.context_interaction.scan()
	check(body.context_interaction.prompt.visible,"prompt returns after obstruction removed")
	body.visual.rotation.y=PI
	body.context_interaction.scan()
	check(not body.context_interaction.prompt.visible,"invalid angle hides prompt")
	body.visual.rotation.y=0
	body.context_interaction.scan()
	check(body.context_interaction.activate_selected(),"dynamic collision setup")
	beam=box(Vector3(200,1.65,10.7),Vector3(2,.2,.4))
	for frame in 120:
		await crouch_tick(false)
		if not mantle.running: break
	check(body.traversal.last_end_reason=="ALIGNMENT_BLOCKED","new real obstruction safely interrupts")
	check(body.position.z>10.9,"pull-in did not pass through blocker")
	beam.queue_free()
	# Supported start and destination, but a gap in between must not permit a glide.
	await ready_fixture()
	body.position.z=11.8
	body.context_interaction.scan()
	check(body.context_interaction.activate_selected(),"destination-loss setup")
	test_obstacle.get_child(0).set_deferred("disabled",true)
	for frame in 20:
		await crouch_tick(false)
		if not mantle.running: break
	check(body.traversal.last_end_reason=="NO_LANDING_SUPPORT","lost destination support aborts committed approach")
	# Separate supported islands must not be bridged by the assisted approach.
	var start_pad:=box(Vector3(300,-.25,3),Vector3(3,.5,2))
	var wall:=box(Vector3(300,1.2,0),Vector3(3,2.4,2))
	await reset_at(Vector3(300,.02,3.4))
	for frame in 90: await crouch_tick(false)
	body.context_interaction.scan()
	check(not body.context_interaction.prompt.visible and detector.result.reject_reason=="APPROACH_UNSUPPORTED","unsupported pull-in path rejected before prompt")
	start_pad.queue_free()
	wall.queue_free()
	print("CLIMB_PROMPT_AUTHORITY_V2: ","PASS" if failures.is_empty() else str(failures))
	quit(0 if failures.is_empty() else 1)
