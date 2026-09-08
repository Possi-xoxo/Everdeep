extends "res://test/test_hang_vertical_v2.gd"

func catch_at(point: Vector3) -> void:
	if hang.running: body.traversal.finish("TEST_RESET")
	hang.cooldown=0
	hang.release_suppression_active=false
	hang.navigation.jump_visual=false
	hang.acquisition.reset_history()
	body.position=point
	body.ground_support.last_supported_height=0
	body.visual.rotation.y=0
	body.velocity=Vector3(0,0,-2)
	body.ground_support.refresh(0)
	animation._enter(&"Fall")
	await physics_frame
	check(hang.try_catch(DT),"catch navigation fixture "+str(point))
	for frame in 25: await crouch_tick(false)

func run() -> void:
	lab=load("res://test/player_v2_lab.tscn").instantiate()
	root.add_child(lab)
	body=lab.get_node("PlayerV2")
	animation=body.get_node("AnimationController")
	tree=body.get_node("AnimationTree")
	cam=body.get_node("CameraRig")
	crouch=body.crouch
	hang=body.traversal.hang
	body.set_physics_process(false)
	animation.set_physics_process(false)
	cam.set_process(false)
	tree.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	var course=load("res://test/traversal_playground/hang_navigation_course.tscn").instantiate()
	root.add_child(course)
	course.position=Vector3(200,0,20)
	await physics_frame
	await catch_at(Vector3(200,.55,20.65))
	check(hang.navigation.release_query(hang).valid,"safe support below low wall")
	check(hang.navigation.resolve(hang,"DOWN") and hang.release_active,"safe S releases")
	await catch_at(Vector3(212,3.25,20.65))
	check(not hang.navigation.resolve(hang,"DOWN") and hang.running,"high unsafe S does nothing")
	await catch_at(Vector3(224,.55,20.65))
	check(not hang.navigation.resolve(hang,"UP") and hang.running,"blocked W does nothing")
	await catch_at(Vector3(236,.55,20.65))
	hang.navigation.scan_interaction(hang)
	print("INTERACTION ",hang.navigation.selected)
	check(is_instance_valid(hang.navigation.selected),"reachable interaction selected")
	if is_instance_valid(hang.navigation.selected):
		var selected: Node3D=hang.navigation.selected
		var anchor: Vector3=body.position
		check(hang.navigation.resolve(hang,"INTERACT"),"hang interact commits")
		check(not hang.navigation.resolve(hang,"LATERAL",1),"interaction protects support")
		for frame in 50: await crouch_tick(false)
		check(selected.activation_count==1,"existing interaction activates once")
		check(hang.running and body.position.distance_to(anchor)<.001 and not hang.navigation.interacting,"interaction stays attached and returns idle")
		selected.available=false
		hang.navigation.scan_interaction(hang)
		var other: Node3D=hang.navigation.selected
		check(is_instance_valid(other) and other!=selected,"opposite-hand target available")
		if is_instance_valid(other):
			check(hang.navigation.resolve(hang,"INTERACT"),"opposite-hand interaction")
			for frame in 50:
				await crouch_tick(false)
				for arm in body.get_node("MantleHandIK").arms:
					check(arm.length_error<.005,"interaction preserves arm length")
					if arm.side!=hang.navigation.hand_side: check(arm.weight>.99,"other hand stays anchored")
			check(other.activation_count==1,"opposite-hand target fires once")
	for child in course.get_children():
		if child.is_in_group("context_interactable") and str(child.name) in ["Hang_Interact_Left","Hang_Interact_Right"]: child.available=false
	hang.navigation.scan_interaction(hang)
	check(hang.navigation.selected==null,"blocked and remote interaction rejected")
	await catch_at(Vector3(270,1.25,22.65))
	var before: Vector3=hang.wall_normal
	for hop in [false,true]:
		check(hang.navigation.resolve(hang,"LATERAL",1,hop),"curved traversal accepted")
		print("CURVE QUERY ",hang.lateral.last_query.get("reason")," angle ",hang.lateral.last_query.get("curve_delta"))
		for frame in 160:
			var prior: Vector3=hang.wall_normal
			await crouch_tick(false)
			check(rad_to_deg(acos(clampf(prior.dot(hang.wall_normal),-1,1)))<3.1,"no frame orientation snap")
			if not hang.lateral.active: break
		check(hang.running and hang.hang_phase==hang.HangPhase.IDLE,"curve stays attached")
	check(rad_to_deg(acos(clampf(before.dot(hang.wall_normal),-1,1)))>10,"local facing follows curve")
	await catch_at(Vector3(203.4,.55,20.65))
	check(not hang.navigation.resolve(hang,"LATERAL",1,true),"sharp box corner unsupported")
	hang.hang_debug=true
	hang.navigation.refresh(hang,0,true)
	hang.detection_visual._process(.016)
	check(hang.detection_visual.mesh.get_surface_count()>0,"navigation debug draws")
	print("HANG_NAVIGATION_COURSE_V2: ","PASS" if failures.is_empty() else str(failures))
	quit(0 if failures.is_empty() else 1)
