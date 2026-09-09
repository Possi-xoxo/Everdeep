extends "res://test/test_hang_transfer_v2.gd"
func run() -> void:
	await setup_transfer()
	var course=load("res://test/traversal_playground/hang_transfer_course.tscn").instantiate()
	root.add_child(course)
	course.position=Vector3(400,0,0)
	await physics_frame
	for fixture in [[0,true],[18,true],[36,true],[54,true],[74,false],[94,false],[112,false],[130,true],[182,true]]:
		await catch_at(Vector3(401.5+fixture[0],1.1,.65))
		var result: Dictionary=hang.transfer.query(hang,1)
		print("TRANSFER STATION ",fixture[0]," ",result.reason," ",result.get("distance",0))
		check(result.valid==fixture[1],"fixture validity "+str(fixture[0]))
		if not result.valid or not fixture[1]:
			check(not hang.navigation.resolve(hang,"LATERAL",1,true) and hang.running,"invalid fixture stays hanging")
			continue
		if fixture[0]==54: check(result.distance>4.3 and result.distance<=4.501,"max range target")
		if fixture[0]==130:
			check(result.distance<3,"nearest ledge priority")
			var other: bool=false
			for candidate in hang.transfer.candidates:
				if candidate.valid and candidate.source!=result.source: other=true
			check(other,"priority fixture contains two compatible in-range targets")
		await run_transfer(1)
		if fixture[0]==182:
			check(hang.navigation.resolve(hang,"UP"),"transfer then vertical hop")
			for tick in 140: await crouch_tick(false)
			check(hang.running and absf(hang.top.y-4)<.03,"upper shelf reached after transfer")
	await catch_at(Vector3(608,1.1,.65))
	var continuous: Dictionary=hang.lateral.preview(hang,1,true)
	check(continuous.valid,"tiny seam remains compatible continuous hop")
	check(hang.navigation.resolve(hang,"LATERAL",1,true) and not hang.transfer.active,"continuous hop takes priority")
	for tick in 140: await crouch_tick(false)
	# Three separate targets, requiring fresh input and repositioning each time.
	await catch_at(Vector3(553.5,1.1,.65))
	for x in [557,562,567]:
		await run_transfer(1)
		check(hang.ledge_edge.x>x-2 and hang.ledge_edge.x<x+2,"chain destination")
		if x<567:
			for shimmy in 4:
				check(hang.navigation.resolve(hang,"LATERAL",1,false),"shimmy toward next gap")
				for tick in 120: await crouch_tick(false)
	print("HANG_TRANSFER_COURSE_V2: ","PASS" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)
