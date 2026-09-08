extends "res://test/test_hang_top_entry_v2.gd"
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
	var course=load("res://test/traversal_playground/hang_top_entry_course.tscn").instantiate()
	root.add_child(course)
	course.position=Vector3(200,0,0)
	await physics_frame
	for fixture in [[0,3,true],[10,3,true],[20,2.5,true],[28,3.5,true],[38,4,true],[48,3,false],[58,3,false],[68,3,false],[83,3,true]]:
		await launch(Vector3(200+fixture[0],fixture[1],-.5))
		hang.top_entry.refresh()
		print("TOP STATION ",fixture[0]," ",hang.top_entry.result.get("reason"))
		check(hang.top_entry.result.valid==fixture[2],"station "+str(fixture[0]))
		if not fixture[2] or not hang.top_entry.result.valid: continue
		body.context_interaction.scan()
		check(body.context_interaction.selected==hang.top_entry,"existing E prompt selects top entry")
		check(body.context_interaction.activate_selected(),"prompt accepts entry")
		for tick in 110: await crouch_tick(false)
		check(hang.running and hang.hang_phase==hang.HangPhase.IDLE,"station enters hang idle")
		if fixture[0]==10:
			check(hang.navigation.resolve(hang,"LATERAL",1,false),"shimmy available after top entry")
			for tick in 130: await crouch_tick(false)
	for distance in [.35,.69,.76]:
		await launch(Vector3(200,3,-distance))
		hang.top_entry.refresh()
		check(hang.top_entry.result.valid==(distance<.7),"prompt distance "+str(distance))
	# Shared Vertical/Mixed wall: top-down entry followed by lower-target S.
	var vertical_course=load("res://test/traversal_playground/hang_vertical_course.tscn").instantiate()
	vertical_course.compact=true
	root.add_child(vertical_course)
	vertical_course.position=Vector3(400,0,0)
	await physics_frame
	await launch(Vector3(400,5.3,-.5))
	hang.top_entry.refresh()
	check(hang.top_entry.begin_interaction(body),"vertical top entry")
	for tick in 110: await crouch_tick(false)
	check(hang.navigation.resolve(hang,"DOWN"),"hop down after top entry")
	for tick in 150: await crouch_tick(false)
	check(hang.running and absf(hang.top.y-4.3)<.03,"lower shelf reached")
	print("HANG_TOP_ENTRY_COURSE_V2: ","PASS" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)
