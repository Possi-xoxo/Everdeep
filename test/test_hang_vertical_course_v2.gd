extends "res://test/test_hang_vertical_v2.gd"

func place(wall: Node3D,height: float) -> void:
	var edge: Vector3=wall.global_position+Vector3.UP*height
	body.position=edge+Vector3.BACK*.5-Vector3.UP*hang.hang_vertical_offset
	hang.vertical.active=false
	hang.begin({"source":wall,"edge":edge,"top":edge,"normal":Vector3.BACK,"top_normal":Vector3.UP,"facing":Vector3.FORWARD,"anchor":body.position})
	hang.hang_phase=hang.HangPhase.IDLE
	hang.elapsed=hang.settle_duration
	hang.vertical.refresh(hang,0,true)

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
	var course=load("res://test/traversal_playground/hang_vertical_course.tscn").instantiate()
	root.add_child(course)
	course.position=Vector3(200,0,20)
	await physics_frame
	var walls: Array=[]
	for child in course.get_children():
		if child.has_meta("vertical_levels"): walls.append(child)
	check(walls.size()==7,"permanent seven-station course")
	place(walls[0],2.3)
	check(hang.vertical.upper.valid and not hang.vertical.lower.valid,"basic upper and bottom safety preview")
	check(hang.vertical.resolve(hang,1) and hang.vertical.active,"W prioritizes hop")
	place(walls[0],3.3)
	check(hang.vertical.lower.valid and hang.vertical.resolve(hang,-1) and hang.vertical.active,"S chooses lower target, never release")
	place(walls[0],5.3)
	check(not hang.vertical.upper.valid and hang.climb_destination_valid,"top pull-up preview")
	check(hang.vertical.resolve(hang,1) and hang.hang_phase==hang.HangPhase.TO_CROUCH,"W actual pull-up fallback")
	crouch.resize(crouch.standing_capsule_height)
	place(walls[1],3.2)
	check(hang.vertical.upper.valid and absf(hang.vertical.upper.vertical-1.2)<.01,"varied 1.2m spacing")
	place(walls[2],2.3)
	check(not hang.vertical.upper.valid,"1.5m up is out of range")
	place(walls[2],3.8)
	check(hang.vertical.lower.valid,"1.5m down is in range")
	place(walls[3],4.0)
	check(not hang.vertical.lower.valid,"1.7m down is out of range")
	place(walls[4],2.3)
	check(not hang.vertical.upper.valid,"blocked upper station")
	place(walls[5],3.3)
	check(not hang.vertical.lower.valid,"blocked lower station")
	place(walls[6],5.3)
	check(hang.vertical.upper.valid and hang.vertical.lower.valid,"long chain has both directions")
	var began: int=Time.get_ticks_usec()
	hang.vertical.refresh(hang,0,true)
	print("VERTICAL PREVIEW USEC ",Time.get_ticks_usec()-began)
	hang.hang_debug=true
	hang.detection_visual._process(.016)
	check(hang.detection_visual.mesh.get_surface_count()>0,"vertical debug draws geometry")
	check(hang.vertical.debug_text(hang).contains("HOP_DOWN"),"context overlay")
	print("HANG_VERTICAL_COURSE_V2: ","PASS" if failures.is_empty() else str(failures))
	quit(0 if failures.is_empty() else 1)
