extends "res://test/test_free_hang_v2.gd"

func run() -> void:
	await setup_transfer()
	box(Vector3(200,2.875,-2),Vector3(6,.25,4))
	box(Vector3(200,-.1,2),Vector3(16,.2,16))
	var free=body.traversal.free_hang
	cam.get_node("YawPivot").rotation.y=0
	await physics_frame
	var caught_rising: bool=false
	var caught_falling: bool=false
	for distance in [1.0,1.4,1.8,2.2]:
		if body.traversal.is_traversing: body.traversal.finish("TEST_RESET")
		hang.cooldown=0
		hang.release_suppression_active=false
		hang.acquisition.reset_history()
		body.position=Vector3(200,.04,distance)
		body.velocity=Vector3.ZERO
		body.visual.rotation.y=0
		body.ground_support.refresh(0)
		for tick in 20: await crouch_tick(false)
		check(body.ground_support.has_ground_support,"launch supported")
		for tick in 120:
			await crouch_tick(false,Vector2(0,-1),false,tick==0)
			if free.running: break
		print("FREE REAL JUMP distance ",distance," caught ",free.running," incoming ",free.incoming_velocity)
		if free.running:
			caught_rising=caught_rising or free.incoming_velocity.y>.1
			caught_falling=caught_falling or free.incoming_velocity.y<-.1
			for tick in 65: await crouch_tick(false)
			await release_free()
			for tick in 100: await crouch_tick(false)
			check(body.ground_support.has_ground_support,"real jump/catch/release loop returns to floor")
	check(caught_rising,"real rising jump catches")
	check(caught_falling,"real falling jump catches")
	print("FREE HANG AIRBORNE ","PASS" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)
