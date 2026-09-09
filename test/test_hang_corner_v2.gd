extends "res://test/test_hang_outward_v2.gd"
func run() -> void:
	await setup_transfer()
	var wall=box(Vector3(200,1.5,-2),Vector3(8,3,4))
	await physics_frame
	for side in [-1,1]:
		await catch_at(Vector3(200+side*3.65,1.1,.65))
		var q: Dictionary=hang.corner.query(hang,side)
		print("CORNER QUERY ",side," ",q.reason," reach ",q.get("max_reach_ratio",0))
		check(q.valid,"outside corner valid")
		if not q.valid: continue
		check(not hang.lateral.request(hang,side,true) and not hang.corner.active,"Shift never turns corner")
		await crouch_tick(false) # Release/rearm the existing gap-input latch.
		var cap: float=hang.braced_hang_corner_hand_correction
		hang.braced_hang_corner_hand_correction=.01
		check(not hang.corner.query(hang,side).valid,"unreachable correction rejected")
		hang.braced_hang_corner_hand_correction=cap
		var obstacle=box(q.corner+q.source_normal*.37+q.normal*.37-Vector3.UP,Vector3(.18,.6,.18))
		await physics_frame
		check(hang.corner.query(hang,side).reason=="CORNER_PATH_BLOCKED","arc obstruction rejected")
		obstacle.queue_free()
		await physics_frame
		for i in 65:
			var p: float=i/64.0
			check(maxf(hang.corner.hand(hang,q,"Left",p).weight,hang.corner.hand(hang,q,"Right",p).weight)>.99,"one hand always supports")
		check(hang.lateral.request(hang,side,false),"shimmy enters corner")
		var target: Vector3=q.anchor
		var yaw: float=body.visual.rotation.y
		var camera_point: Vector3=cam.global_position
		for tick in 150:
			await crouch_tick(false)
			if hang.corner.active:
				check(cam.global_position.is_finite() and cam.global_position.distance_to(camera_point)<.1,"camera follows without anchor jump")
				check(not cam.mantle_camera_active,"corner keeps normal orbit camera")
				camera_point=cam.global_position
				check(absf(angle_difference(yaw,body.visual.rotation.y))<.1,"smooth corner rotation")
				check(not hang.navigation.resolve(hang,"JUMP") and not hang.navigation.resolve(hang,"UP") and not hang.navigation.resolve(hang,"DOWN"),"busy corner blocks actions")
				yaw=body.visual.rotation.y
		check(hang.running and hang.hang_phase==hang.HangPhase.IDLE,"corner settles")
		check(body.position.distance_to(target)<.005,"exact corner anchor")
		check(hang.wall_normal.dot(q.normal)>.999,"new wall normal")
		check(hang.navigation.context_id.contains(str(hang.source.get_instance_id())),"fresh navigation context")
		check(hang.lateral.query(hang,side,.7).valid,"destination shimmy restored")
		# Traverse the adjacent face using real shimmy actions until the next corner.
		var turned: bool=false
		for attempt in 8:
			if not hang.lateral.request(hang,side,false): break
			var turning: bool=hang.corner.active
			for tick in 150:
				await crouch_tick(false)
				if not hang.corner.active and not hang.lateral.active: break
			if turning: turned=true; break
		check(turned and hang.wall_normal.dot(-q.source_normal)>.999,"second corner refresh / no drift")
	wall.queue_free()
	var generator=load("res://test/traversal_playground/hang_corner_course.gd").new()
	generator.compact=true
	root.add_child(generator)
	for angle in [75,105,60,120]:
		var shape=generator.prism(Vector3(220,0,0),angle)
		await physics_frame
		await catch_at(Vector3(223.65,1.1,.65))
		var q: Dictionary=hang.corner.query(hang,1)
		print("ANGLE ",angle," ",q.reason," reach ",q.get("max_reach_ratio",0))
		check(q.valid if angle in [75,105] else not q.valid,"angle window %d"%angle)
		shape.queue_free()
		await physics_frame
	var inside=box(Vector3(240,1.5,-2),Vector3(8,3,4))
	generator.block(inside,Vector3(3,0,4),Vector3(2,3,4),Color.RED)
	await physics_frame
	await catch_at(Vector3(241.6,1.1,.65))
	check(not hang.corner.query(hang,1).valid,"inside corner rejected")
	hang.braced_hang_corners_enabled=false
	check(hang.corner.query(hang,1).reason=="DISABLED","reversible disable switch")
	print("HANG_CORNER_V2: ","PASS" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)
