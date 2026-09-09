extends "res://test/test_hang_outward_v2.gd"
var course: Node3D

func catch_anchor(title: String,z: float=INF) -> bool:
	if hang.running: body.traversal.finish("TOWER_FIXTURE")
	var q: Dictionary=course.anchors[title]
	var edge: Vector3=course.to_global(q.edge)
	if is_finite(z): edge.z=course.global_position.z+z
	var n: Vector3=q.normal
	hang.cooldown=0; hang.release_suppression_active=false
	hang.navigation.jump_visual=false; hang.acquisition.reset_history()
	body.position=edge+n*.65-Vector3.UP*1.9
	body.visual.rotation.y=atan2(n.x,n.z)
	body.velocity=Vector3.UP*.01; body.move_and_slide()
	body.velocity=-n*2
	body.ground_support.last_supported_height=edge.y-3
	body.ground_support.refresh(0)
	animation._enter(&"Fall")
	await physics_frame
	var accepted: bool=hang.try_catch(DT,-n)
	print("TOWER CATCH ",title," ",accepted," ",hang.result.get("reason")," edge ",hang.result.get("edge")," normal ",hang.result.get("normal"))
	if not accepted: print("FAIL DATA ",hang.result)
	if accepted:
		for tick in 25: await crouch_tick(false)
	return accepted and hang.running

func setup_towers() -> void:
	lab=load("res://test/traversal_playground/traversal_playground.tscn").instantiate()
	root.add_child(lab)
	body=lab.player
	animation=body.get_node("AnimationController"); tree=body.get_node("AnimationTree")
	cam=body.get_node("CameraRig"); crouch=body.crouch; hang=body.traversal.hang
	body.set_physics_process(false); animation.set_physics_process(false); cam.set_process(false)
	tree.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	course=lab.get_node("Courses/TwinTowers")
	await physics_frame

func run() -> void:
	await setup_towers()
	check(not hang.automatic_ledge_to_ledge_jump_enabled,"auto targeting stays disabled")
	for title in course.anchors:
		var q: Dictionary=course.anchors[title]
		var edge: Vector3=course.to_global(q.edge)
		var contact: bool=hang.validate_contacts(course.towers[q.tower],edge,edge,q.normal,Vector3.UP)
		var clear: bool=hang.clear_segment(edge+q.normal*.5-Vector3.UP*1.75,edge+q.normal*.5-Vector3.UP*1.75,1.8)
		print("ANCHOR ",title," contacts ",contact," capsule ",clear)
		check(contact and clear,"usable anchor "+title)
	for title in ["A_FullHop","A_GapLanding","A_Curve_Start","B_Curve_Start","A_JumpOff","B_FreeJump","B_ReturnLaunch","A_TopDownEntry","A_FinalLeft"]:
		check(await catch_anchor(title),"automatic catch "+title)
		if not hang.running: continue
		if title in ["A_Curve_Start","B_Curve_Start"]:
			var side: int=-1 if title.begins_with("A") else 1
			var q: Dictionary=hang.lateral.query(hang,side,.7)
			print("CURVE ",title," ",q.reason)
			check(q.valid,"curved shimmy "+title)
			var initial: Vector3=hang.wall_normal
			for attempt in 4:
				check(hang.lateral.request(hang,side,false),"curve step commits")
				for tick in 140:
					await crouch_tick(false)
					if not hang.lateral.active: break
			check(initial.dot(hang.wall_normal)<.98,"flat lead-in enters rounded exterior")
		if title in ["A_JumpOff","B_FreeJump","B_ReturnLaunch"]:
			var source=hang.source
			check(hang.navigation.resolve(hang,"JUMP"),"free jump starts")
			var caught: bool=false
			for tick in 200:
				await crouch_tick(false)
				if hang.running and hang.source!=source: caught=true; break
			print("CROSS ",title," caught ",caught," height ",hang.top.y," pos ",body.position," reason ",hang.result.get("reason")," exit ",hang.exit_reason)
			check(caught and not hang.outward.active,"free cross "+title)
	print("TWIN_TOWER_V2: ","PASS" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)
