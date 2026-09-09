extends "res://test/test_hang_outward_v2.gd"
func run() -> void:
	await setup_transfer()
	hang.automatic_ledge_to_ledge_jump_enabled=true # Explicitly test the opt-in feature.
	var course=load("res://test/traversal_playground/hang_outward_course.tscn").instantiate()
	root.add_child(course)
	course.position=Vector3(400,0,0)
	await physics_frame
	for fixture in [[0,true,0],[18,true,0],[36,true,0],[54,true,-1],[72,true,1],[90,true,0],[108,false,0],[126,false,0],[144,false,0],[180,false,0]]:
		await catch_at(Vector3(400+fixture[0],1.1,.65))
		var r: Dictionary=hang.outward.query(hang,fixture[2])
		print("OUTWARD STATION ",fixture[0]," ",r.reason," ",r.get("distance",0))
		check(r.valid==fixture[1],"outward fixture "+str(fixture[0]))
		if fixture[1] and r.valid:
			await run_outward(fixture[2])
			if fixture[0]==0:
				check(hang.navigation.resolve(hang,"LATERAL",1,false),"outward then shimmy")
				for tick in 120: await crouch_tick(false)
		elif not fixture[1]:
			check(hang.navigation.resolve(hang,"JUMP",fixture[2]) and hang.navigation.jumping and not hang.outward.active,"invalid remote uses jump-off")
			for tick in 40: await crouch_tick(false)
	for side in [-1,1]:
		await catch_at(Vector3(562,1.1,.65))
		var r: Dictionary=hang.outward.query(hang,side)
		check(r.valid,"biased target available")
		if r.valid:
			check((r.anchor.x-562)*side>.5,"intent selects correct side")
			var again: Dictionary=hang.outward.query(hang,side)
			check(r.anchor==again.anchor,"deterministic target selection")
			await run_outward(side)
	# Source hop up -> transfer -> destination hop up/down -> transfer back.
	await catch_at(Vector3(598,.4,.65))
	check(hang.navigation.resolve(hang,"UP"),"source vertical hop")
	for tick in 140: await crouch_tick(false)
	await run_outward()
	check(hang.navigation.resolve(hang,"UP"),"outward then hop up")
	for tick in 140: await crouch_tick(false)
	check(absf(hang.top.y-4.3)<.01,"destination upper shelf")
	check(hang.navigation.resolve(hang,"DOWN"),"outward then hop down")
	for tick in 140: await crouch_tick(false)
	await run_outward()
	await catch_at(Vector3(617.5,1.1,.65))
	await run_transfer(1)
	await run_outward()
	# Committed target cannot move or disappear; a new obstruction aborts safely.
	await catch_at(Vector3(400,1.1,.65))
	check(hang.navigation.resolve(hang,"JUMP"),"safety fixture commits")
	var target=hang.outward.destination.source
	target.position.x+=.1
	await physics_frame
	await crouch_tick(false)
	check(not hang.running and not hang.outward.active,"moving destination abort")
	target.position.x-=.1
	await physics_frame
	await catch_at(Vector3(400,1.1,.65))
	check(hang.navigation.resolve(hang,"JUMP"),"second safety fixture commits")
	target.queue_free()
	await physics_frame
	await crouch_tick(false)
	check(not hang.running and not hang.outward.active,"deleted destination abort")
	await catch_at(Vector3(418,1.1,.65))
	hang.braced_hang_outward_transfer_max_motion_scale=1.1
	check(not hang.outward.query(hang,0).valid,"extreme motion scale rejected")
	hang.braced_hang_outward_transfer_max_motion_scale=1.8
	check(hang.navigation.resolve(hang,"JUMP") and hang.outward.active,"live obstruction fixture commits")
	var obstacle_point: Vector3=hang.outward.path(.55,hang.outward.origin,hang.outward.destination)+Vector3.UP*.9
	var obstruction=box(obstacle_point,Vector3(.5,1.8,.5))
	await physics_frame
	for tick in 100:
		await crouch_tick(false)
		if not hang.outward.active: break
	check(not hang.running and not hang.outward.active,"new mid-flight obstruction aborts to airborne")
	check(body.traversal.hang.exit_reason=="HANG_BLOCKED","actual capsule obstruction reported")
	obstruction.queue_free()
	print("HANG_OUTWARD_COURSE_V2: ","PASS" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)
