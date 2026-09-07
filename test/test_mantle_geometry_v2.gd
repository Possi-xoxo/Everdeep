extends "res://test/test_crouch_v2.gd"
var detector: Node
var test_obstacle: StaticBody3D

func fixture(height: float,depth: float=2.0) -> void:
	if is_instance_valid(test_obstacle): test_obstacle.queue_free()
	await crouch_tick(false)
	await reset_at(Vector3(200,.1,10))
	body.visual.rotation=Vector3.ZERO
	test_obstacle=box(Vector3(200,height*.5,9.35-depth*.5),Vector3(3,height,depth))
	await crouch_tick(false)

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
	# Preserve the original detector boundary regression independently of the
	# Phase 1B production defaults, covered by test_mantle_v2.
	detector.mantle_min_height=.7
	detector.mantle_max_height=1.4
	body.set_physics_process(false)
	animation.set_physics_process(false)
	cam.set_process(false)
	tree.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	box(Vector3(200,-.25,0),Vector3(80,.5,80))
	for height in [.4,.6,.7,.8,.9,1.0,1.1,1.2,1.3,1.4,1.5,1.7,6.0]:
		await fixture(height)
		detector.refresh_contextual_candidate()
		var r: Dictionary=detector.result
		var expected: bool=height>=.7 and height<=1.4
		print("HEIGHT ",height," valid=",r.valid," reject=",r.reject_reason)
		check(r.valid==expected,"height classification "+str(height))
		if not expected: check(r.reject_reason==("TOO_LOW" if height<.7 else "TOO_HIGH"),"height reject reason")
		else:
			check(r.landing_position.y>height and r.player_alignment_facing.dot(Vector3.FORWARD)>.99,"landing/alignment data")
			check(detector.volume_queries==1,"one staged volume query")
	await fixture(1.0,.2)
	detector.refresh_contextual_candidate()
	check(detector.result.reject_reason=="TOP_TOO_SHALLOW","thin shelf rejected")
	await fixture(1.0)
	var roof:=box(Vector3(200,2.15,8.3),Vector3(3,.3,2))
	await crouch_tick(false)
	detector.refresh_contextual_candidate()
	print("CEILING ",detector.result.reject_reason)
	check(detector.result.reject_reason=="DESTINATION_BLOCKED","standing volume rejects ceiling")
	roof.queue_free()
	await crouch_tick(false)
	# Vertical front and a genuinely steep top, rather than a tilted wall face.
	test_obstacle.queue_free()
	await crouch_tick(false)
	test_obstacle=StaticBody3D.new()
	lab.add_child(test_obstacle)
	var shape:=CollisionShape3D.new()
	var hull:=ConvexPolygonShape3D.new()
	hull.points=PackedVector3Array([Vector3(-1.5,0,0),Vector3(1.5,0,0),Vector3(-1.5,.9,0),Vector3(1.5,.9,0),Vector3(-1.5,0,-1),Vector3(1.5,0,-1),Vector3(-1.5,2.328,-1),Vector3(1.5,2.328,-1)])
	shape.shape=hull
	test_obstacle.add_child(shape)
	test_obstacle.position=Vector3(200,0,9.35)
	await crouch_tick(false)
	detector.refresh_contextual_candidate()
	check(detector.result.reject_reason=="TOP_TOO_STEEP","steep top rejected")
	await fixture(1.1)
	body.position.x=201.48
	for i in 6:
		body.position.x=201.48+float(i%2)*.002
		detector.refresh_contextual_candidate()
		check(not detector.result.valid and detector.result.reject_reason=="TOP_TOO_SHALLOW","corner rejects consistently")
	await fixture(1.1)
	detector.mantle_debug=true
	detector.refresh_contextual_candidate()
	await process_frame
	check(detector.debug_mesh.visible and detector.debug_mesh.mesh!=null and detector.debug_label.visible,"debug probes and standing volume generated")
	detector.mantle_debug=false
	for frame in 65: await crouch_tick(true)
	body.context_interaction.scan()
	check(body.context_interaction.selected==detector.candidate and body.context_interaction.prompt.text=="E to Climb","crouched systemic candidate uses Phase 0 UI")
	dummy.position=Vector3(200,0,0)
	lock.toggle()
	check(lock.is_locked(),"lock setup")
	var before: Vector3=body.position
	check(body.context_interaction.activate_selected(),"geometry revalidated and request accepted")
	check(body.traversal.active_data.target_position==body.traversal.active_data.landing_position and body.traversal.active_data.target_normal==body.traversal.active_data.top_normal,"validated geometry survives generic adapter")
	check(not lock.is_locked() and body.traversal.is_traversing,"mantle test clears lock")
	check(body.position==before,"request does not reposition")
	check(body.traversal.request_traversal_interrupt(body.traversal.Interrupt.DAMAGE),"entry releases ownership")
	await crouch_tick(true,Vector2.ZERO,false,false,true)
	body.context_interaction.scan()
	check(not detector.result.valid and detector.volume_queries==0,"Dodge skips contextual volume queries")
	for frame in 170: await crouch_tick(true)
	await fixture(1.1)
	body.animation_state.is_airborne=true
	body.context_interaction.scan()
	check(not detector.result.valid and detector.volume_queries==0,"airborne skips contextual volume queries")
	body.animation_state.is_airborne=false
	body.context_interaction.scan()
	test_obstacle.queue_free()
	check(not body.context_interaction.activate_selected(),"freed geometry rejects stale activation")
	await fixture(1.0)
	body.position.z+=3
	body.context_interaction.scan()
	check(not detector.result.valid and not body.context_interaction.prompt.visible,"walk away clears candidate")
	detector.mantle_enabled=false
	detector.refresh_contextual_candidate()
	check(detector.volume_queries==0,"disabled detector skips volume work")
	print("MANTLE_GEOMETRY_V2: ","PASS" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)
