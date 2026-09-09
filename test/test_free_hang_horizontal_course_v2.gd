extends "res://test/test_free_hang_course_v2.gd"

func wait_action() -> void:
	for i in 260:
		await crouch_tick(false)
		if not body.traversal.free_hang.actions.active: break
	for i in 25: await crouch_tick(false)

func run() -> void:
	lab=load("res://test/traversal_playground/traversal_playground.tscn").instantiate()
	root.add_child(lab)
	body=lab.player
	animation=body.get_node("AnimationController")
	tree=body.get_node("AnimationTree")
	cam=body.get_node("CameraRig")
	crouch=body.crouch
	hang=body.traversal.hang
	body.set_physics_process(false)
	animation.set_physics_process(false)
	cam.set_process(false)
	tree.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	var course=lab.get_node("Courses/FreeHang")
	var free=body.traversal.free_hang
	await physics_frame
	for title in ["FreeHang_Shimmy_Long","FreeHang_Hop_Partial","FreeHang_ClimbUp","FreeHang_BlockedTop"]:
		var lip: Node3D=course.get_node(title)
		await free_catch(lip.global_position+Vector3(0,-1.9,.65),Vector3(0,2,-3))
		for i in 90: await crouch_tick(false)
		check(free.running,"horizontal course catch "+title)
		if not free.running: continue
		if title=="FreeHang_Shimmy_Long" or title=="FreeHang_Hop_Partial":
			await crouch_tick(false,Vector2.RIGHT,true)
			check(free.actions.active,"permanent horizontal hop "+title)
			if title=="FreeHang_Hop_Partial": check(free.actions.distance<.89,"permanent partial selected")
			await wait_action()
		else:
			await crouch_tick(false,Vector2.UP)
			check(free.actions.active==(title=="FreeHang_ClimbUp"),"top validation "+title)
			await wait_action()
		if free.running: await release_free()
	var start: Node3D=course.get_node("FreeHang_MixedCourse_0")
	await free_catch(start.global_position+Vector3(0,-1.9,.65),Vector3(0,2,-3))
	for i in 90: await crouch_tick(false)
	for i in 3:
		await crouch_tick(false,Vector2.RIGHT)
		await wait_action()
	await crouch_tick(false,Vector2.RIGHT,true)
	check(free.actions.active and free.actions.destination.get("remote",false),"mixed route reaches first gap without vertical hops")
	await wait_action()
	check(free.source.name=="FreeHang_MixedCourse_1","mixed route owns next source")
	await crouch_tick(false,Vector2.LEFT)
	await wait_action()
	check(free.running,"mixed route reverses on destination")
	await crouch_tick(false,Vector2.UP)
	await wait_action()
	check(not free.running and body.ground_support.has_ground_support,"mixed route climbs out, no stale anchors")
	print("FREE HORIZONTAL COURSE ","PASS" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)
