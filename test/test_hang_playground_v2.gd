extends "res://test/test_traversal_playground_v2.gd"
func run() -> void:
	playground=load("res://test/traversal_playground/traversal_playground.tscn").instantiate()
	root.add_child(playground)
	playground.set_physics_process(false)
	await reset_course(&"Hang")
	check(body.ground_support.has_ground_support,"Hang key-4 spawn is supported")
	var course=playground.get_node("Courses/Hang")
	for name in ["Hang_Basic","Hang_Apex","Hang_Falling","Hang_Diagonal","Hang_ConeEdge","Hang_Invalid_Backside","Hang_Invalid_NoBrace","Hang_Low","Hang_Medium","Hang_High","Hang_ToCrouch","Hang_Rising","Hang_Chain"]:
		check(course.has_node(name),"permanent labeled fixture "+name)
	for route in ["Vertical","Mixed"]:
		check(playground.has_node("Courses/"+route+"/BracedHangDetour/HangWall"),"optional route hang "+route)
	for name in ["Hang_Basic","Hang_Medium","Hang_High","Hang_Invalid_NoBrace"]:
		await reset_course(&"Hang")
		var wall=course.get_node(name)
		var size: Vector3=wall.get_node("Collision").shape.size
		body.global_position=course.to_global(Vector3(wall.position.x,.02,wall.position.z+size.z*.5+.70))
		for frame in 30: await crouch_tick(false)
		check(body.ground_support.has_ground_support,"grounded launch "+name)
		for frame in 90:
			await crouch_tick(false,Vector2(0,-1),false,frame==0)
			if body.traversal.hang.running: break
		var expected: bool=name!="Hang_Invalid_NoBrace"
		print("PLAYGROUND HANG ",name," caught=",body.traversal.hang.running," result=",body.traversal.hang.result)
		check(body.traversal.hang.running==expected,"real jump catches only braced wall "+name)
		if expected and body.traversal.hang.running:
			for frame in 20: await crouch_tick(false)
			check(body.traversal.hang.request_release(),"release authored playground ledge")
			await crouch_tick(false)
			for frame in 90:
				await crouch_tick(false)
				if body.ground_support.has_ground_support: break
			check(body.ground_support.has_ground_support,"safe existing floor below release")
			for frame in 2: await crouch_tick(false)
			check(not body.traversal.hang.release_suppression_active,"landing allows immediate new attempt")
			for frame in 90:
				await crouch_tick(false,Vector2(0,-1),false,frame==0)
				if body.traversal.hang.running: break
			check(body.traversal.hang.running,"authored release-land-jump-catch without reset")
			for frame in 20: await crouch_tick(false)
			check(body.traversal.hang.request_up(),"authored playground top-out")
			for frame in 120: await crouch_tick(crouch.requested)
			check(body.traversal.last_end_reason=="HANG_TO_CROUCH_COMPLETED" and not crouch.requested,"authored ledge locomotion completion")
	print("HANG_PLAYGROUND_V2: ","PASS" if failures.is_empty() else str(failures))
	quit(0 if failures.is_empty() else 1)
