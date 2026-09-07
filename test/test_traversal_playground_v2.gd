extends "res://test/test_crouch_v2.gd"
var playground: Node3D
func bind_player() -> void:
	body=playground.player
	animation=body.get_node("AnimationController")
	tree=body.get_node("AnimationTree")
	lock=body.get_node("LockOnController")
	cam=body.get_node("CameraRig")
	dodge=body.dodge
	assist=body.roll_traversal
	crouch=body.crouch
	body.set_physics_process(false)
	animation.set_physics_process(false)
	cam.set_process(false)
	tree.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL

func reset_course(course: StringName) -> void:
	playground.request_reset(course)
	for frame in 3: await process_frame
	bind_player()
	for frame in 40: await crouch_tick(false)

func run() -> void:
	playground=load("res://test/traversal_playground/traversal_playground.tscn").instantiate()
	root.add_child(playground)
	playground.set_physics_process(false)
	for frame in 3: await process_frame
	bind_player()
	for course in [&"Hub",&"Vertical",&"Speed",&"Mixed"]:
		await reset_course(course)
		check(body.ground_support.has_ground_support,"safe spawn "+String(course))
		check(body.animation_state.horizontal_speed<.01 and body._run_time==0,"clean reset locomotion")
		var old_player:=body
		body.position.y=-10
		playground._physics_process(DT)
		for frame in 3: await process_frame
		bind_player()
		check(not is_instance_valid(old_player),"fall frees prior controller")
		for frame in 40: await crouch_tick(false)
		check(body.ground_support.has_ground_support and playground.current_course==course,"fall returns to selected course")
	var vertical=playground.get_node("Courses/Vertical")
	var speed=playground.get_node("Courses/Speed")
	var mixed=playground.get_node("Courses/Mixed")
	var rises: Array[float]=[]
	for obstacle in vertical.get_node("Geometry").get_children():
		rises.append(obstacle.get_meta("rise_m"))
	for height in [.3,.35,.65,.75,1.5,1.7,2.0,2.4,2.5,2.75]:
		check(rises.has(height),"labeled representative height "+str(height))
	var gaps:=0
	for obstacle in speed.get_node("Geometry").get_children():
		if obstacle.get_meta("gap_m")>0: gaps+=1
	check(gaps>=6,"flow route repeatedly interrupts flat running")
	check(speed.get_node("Geometry").get_child(-1).position.z< -90,"substantial horizontal route")
	check(mixed.get_node("Geometry/Climb_240")!=null and mixed.get_node("Geometry/CoyoteBeam_050")!=null,"mixed climbing and support modules")
	# No hidden safety floor can bridge the real speed-course gaps.
	for course in [vertical,speed,mixed]:
		for obstacle in course.get_node("Geometry").get_children():
			var shape: BoxShape3D=obstacle.get_node("Collision").shape
			var mesh: BoxMesh=obstacle.get_node("Mesh").mesh
			check(shape.size.is_equal_approx(mesh.size),"visible measurements match collision")
	await reset_course(&"Vertical")
	for entry in [["Stage_1_Rise_030","step"],["Stage_2_Rise_035","jump"],["Stage_3_Rise_065","roll"],["Stage_4_Rise_075","jump"],["Stage_5_Rise_150","jump"],["Stage_6_Rise_170","bypass"]]:
		await reset_course(&"Vertical")
		var obstacle=vertical.get_node("Geometry/"+entry[0])
		var shape: BoxShape3D=obstacle.get_node("Collision").shape
		var top_y: float=obstacle.position.y+shape.size.y*.5
		var rise: float=obstacle.get_meta("rise_m")
		var x: float=1.8 if entry[1]=="bypass" else obstacle.position.x
		var base_y: float=top_y-rise+(.3 if entry[1]=="bypass" else 0)
		var face_z: float=obstacle.position.z+shape.size.z*.5
		body.position=vertical.to_global(Vector3(x,base_y+.02,face_z+.65))
		for frame in 100: await crouch_tick(false)
		check(body.ground_support.has_ground_support,"lower-stage approach supported "+entry[0])
		if entry[1]!="step":
			for frame in 10: await crouch_tick(false,Vector2(0,-1),true)
		var succeeded:=false
		for frame in 120:
			await crouch_tick(false,Vector2(0,-1),entry[1]!="step",frame==0 and entry[1] in ["jump","bypass"],frame==0 and entry[1]=="roll")
			if body.animation_state.is_grounded and body.position.y>=top_y-.03 and vertical.to_local(body.position).z<face_z:
				succeeded=true
				break
		check(succeeded,"authored threshold traversable "+entry[0]+" by "+entry[1])
	await reset_course(&"Vertical")
	# Test the actual authored tower climb faces, not a substitute fixture.
	var previous_top:=0.0
	for obstacle: StaticBody3D in vertical.get_node("Geometry").get_children():
		var shape: BoxShape3D=obstacle.get_node("Collision").shape
		var top_y: float=obstacle.position.y+shape.size.y*.5
		var rise: float=obstacle.get_meta("rise_m")
		previous_top=top_y-rise
		if rise<1.75 or rise>2.5: continue
		body.position=vertical.to_global(Vector3(obstacle.position.x,previous_top+.02,obstacle.position.z+shape.size.z*.5+.65))
		body.velocity=Vector3.ZERO
		for frame in 100: await crouch_tick(false)
		body.context_interaction.scan()
		check(body.context_interaction.activate_selected(),"authored tower climb "+str(rise))
		if is_equal_approx(rise,2.0):
			for frame in 20: await crouch_tick(false)
			check(body.traversal.is_traversing,"committed mantle reset setup")
			await reset_course(&"Vertical")
			check(not body.traversal.is_traversing and not body.dodge.is_dodging,"reset clears committed actions")
			body.position=vertical.to_global(Vector3(obstacle.position.x,previous_top+.02,obstacle.position.z+shape.size.z*.5+.65))
			for frame in 100: await crouch_tick(false)
			body.context_interaction.scan()
			check(body.context_interaction.activate_selected(),"climb works after reset")
		for frame in 240:
			await crouch_tick(false)
			if not body.traversal.is_traversing: break
		check(body.traversal.last_end_reason=="COMPLETED","tower climb completion "+str(rise))
	await reset_course(&"Vertical")
	var impossible=vertical.get_node("Geometry/TooHigh_275")
	var shape: BoxShape3D=impossible.get_node("Collision").shape
	var base_y: float=impossible.position.y+shape.size.y*.5-2.75
	body.position=vertical.to_global(Vector3(0,base_y+.02,impossible.position.z+2+.65))
	for frame in 100: await crouch_tick(false)
	body.context_interaction.scan()
	check(not body.context_interaction.activate_selected(),"authored 2.75m obstacle remains impossible")
	await reset_course(&"Speed")
	var segment:=0
	var jump_count:=0
	var frozen_progress:=0.0
	var airborne:=false
	for frame in 1400:
		var platform: StaticBody3D=speed.get_node("Geometry").get_child(segment)
		var platform_shape: BoxShape3D=platform.get_node("Collision").shape
		var local: Vector3=speed.to_local(body.global_position)
		var jump_now: bool=body.animation_state.is_grounded and local.z<=platform.position.z-platform_shape.size.z*.5+.75
		if jump_now:
			frozen_progress=body._run_time
			jump_count+=1
			airborne=true
		await crouch_tick(false,Vector2(0,-1),true,jump_now)
		if jump_now: frozen_progress=body._run_time
		if airborne: check(is_equal_approx(body._run_time,frozen_progress),"real flow gap holds buildup")
		if airborne and body.animation_state.is_grounded:
			var next: StaticBody3D=speed.get_node("Geometry").get_child(segment+1)
			var next_shape: BoxShape3D=next.get_node("Collision").shape
			check(speed.to_local(body.global_position).z<next.position.z+next_shape.size.z*.5,"jump lands on next flow platform")
			airborne=false
			segment+=1
			if segment==3: break
		if body.position.y< -6: break
	check(segment==3 and jump_count==3,"three successive real course gaps traversed")
	check(body.animation_state.gait==1 and body._run_time==0,"RUN jumps reset buildup across real flow gaps")
	await crouch_tick(false,Vector2(0,-1),true)
	check(body._run_time>0,"ground running resumes buildup after gap")
	print("TRAVERSAL_PLAYGROUND_V2: ","PASS" if failures.is_empty() else str(failures))
	quit(0 if failures.is_empty() else 1)
