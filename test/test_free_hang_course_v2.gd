extends "res://test/test_free_hang_v2.gd"

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
	for title in ["FreeHang_Basic","FreeHang_Rising","FreeHang_Falling","FreeHang_Apex","FreeHang_ForwardMomentum","FreeHang_LateralMomentum","FreeHang_FastCatch","FreeHang_VsBraced","FreeHang_NoBrace","FreeHang_Release"]:
		var lip: Node3D=course.get_node(title)
		var offset: Vector3=Vector3(1.5,0,0) if title=="FreeHang_VsBraced" else Vector3.ZERO
		var candidate: Dictionary=await free_catch(lip.global_position+offset+Vector3(0,-1.9,.65),Vector3(0,2,-3))
		check(candidate.valid and free.running,"permanent station FREE: "+title)
		if not free.running: continue
		for frame in 70: await crouch_tick(false)
		check(free.hang_phase==free.HangPhase.IDLE,"permanent station settles: "+title)
		await release_free()
		check(not body.traversal.is_traversing,"permanent station release: "+title)
		if title=="FreeHang_Release":
			cam.get_node("YawPivot").rotation.y=0
			for frame in 70:
				await crouch_tick(false,Vector2(0,1))
				if free.running: break
			print("FREE COURSE LOWER CATCH ",free.running," ",free.source.name," position ",body.global_position," last ",hang.result)
			check(free.running and free.source.name=="FreeHang_DifferentLedge","normal release/turn catches lower ledge without teleport")
	var backed=course.get_node("FreeHang_VsBraced")
	var candidate: Dictionary=await free_catch(backed.global_position+Vector3(-1.5,-1.9,.65),Vector3(0,2,-3))
	check(candidate.valid and hang.running and not free.running,"adjacent half remains braced")
	print("FREE HANG COURSE ","PASS" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)
