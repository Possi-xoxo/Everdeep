extends "res://test/test_hang_outward_v2.gd"
func run() -> void:
	await setup_transfer()
	var course=load("res://test/traversal_playground/hang_partial_course.tscn").instantiate()
	root.add_child(course)
	course.position=Vector3(400,0,0)
	await physics_frame
	for spec in [Vector2(108,.38),Vector2(126,.05)]:
		await catch_at(Vector3(400+spec.x+4-.28-spec.y,1.1,.65))
		check(hang.lateral.request(hang,1,true),"priority request accepted")
		check(hang.transfer.active==(spec.y<.30),"partial before gap / gap only below minimum")
		print("PRIORITY ",spec," ",hang.transfer.last_resolution)
		for tick in 160: await crouch_tick(false)
		check(hang.running and hang.hang_phase==hang.HangPhase.IDLE,"priority action settles")
	await catch_at(Vector3(546,1.1,.65))
	var q: Dictionary=hang.lateral.preview(hang,1,true)
	print("CURVE ",q.valid," ",q.get("actual_distance")," ",q.get("limit_reason")," turn ",q.get("curve_delta"))
	check(q.valid and q.actual_distance<3 and q.curve_delta>5 and q.curve_delta<=35.001,"partial follows gentle curved path within turn budget")
	if q.valid:
		var target: Vector3=q.target
		check(hang.lateral.request(hang,1,true),"curved partial accepted")
		for tick in 160: await crouch_tick(false)
		check(body.position.distance_to(target)<.005,"curve lands at sampled endpoint")
	await catch_at(Vector3(400,1.1,.65))
	var obstacle=box(Vector3(400.95,2,.6),Vector3(.1,3,1))
	await physics_frame
	q=hang.lateral.preview(hang,1,true)
	print("BLOCKER ",q.valid," ",q.actual_distance," ",q.limit_reason)
	check(q.valid and q.actual_distance<.5,"protrusion clamps full body-safe route")
	obstacle.queue_free()
	await physics_frame
	var ceiling=box(Vector3(400,3.2,.5),Vector3(7,.15,2))
	await physics_frame
	q=hang.lateral.preview(hang,1,true)
	check(not q.valid,"ceiling blocks hop arc even with valid target")
	ceiling.queue_free()
	await physics_frame
	await catch_at(Vector3(400+90+4-.28-.8,1.1,.65))
	q=hang.lateral.preview(hang,1,true)
	check(q.valid and q.actual_distance<.8,"partial stops before corner")
	if q.valid: check(q.curve_delta<.01,"no corner rotation introduced")
	course.queue_free()
	print("HANG_PARTIAL_COURSE_V2: ","PASS" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)
