extends "res://test/test_twin_tower_v2.gd"
func world_point(tower: String,point: Vector3) -> Vector3:
	return course.to_global(point)+Vector3(-1 if tower=="A" else 1,0,0)

func stand(point: Vector3,yaw: float=0) -> void:
	if body.traversal.is_traversing: body.traversal.finish("GROUND_FIXTURE")
	hang.cooldown=0; hang.release_suppression_active=false
	hang.navigation.jump_visual=false; hang.acquisition.reset_history()
	body.position=point+Vector3.UP*.04; body.velocity=Vector3.DOWN
	body.visual.rotation.y=yaw; cam.yaw.rotation.y=yaw
	body.move_and_slide(); body.apply_floor_snap(); body.ground_support.refresh(0)
	body.animation_state.is_airborne=false; body.animation_state.is_grounded=true
	body.animation_state.jump_started=false; crouch.requested=false
	animation._enter(&"Locomotion")
	for tick in 35: await crouch_tick(false)
	check(body.ground_support.has_ground_support,"launch platform grounded")

func run() -> void:
	await setup_towers()
	for spec in [["A",Vector3(-.6,.6,8.2),2.6],["B",Vector3(5.5,1.6,8.8),3.6]]:
		if spec[0]=="B": spec[1].z=9.35
		await stand(world_point(spec[0],spec[1]))
		body.context_interaction.scan()
		var accepted: bool=body.context_interaction.activate_selected()
		print("TOWER MANTLE ",spec[0]," ",accepted)
		check(accepted,"entry mantle "+spec[0])
		for tick in 180: await crouch_tick(false)
		check(body.ground_support.has_ground_support and absf(body.position.y-spec[2])<.1,"mantle landing "+spec[0])
	for spec in [["A",Vector3(-.85,2.6,4.85),PI/2,5.0],["B",Vector3(4.25,3.6,6.95),.5,6.0],["A",Vector3(-1.9,8.6,6.65),0.0,11.0],["A",Vector3(-.85,11,-2.4),PI/2,13.4],["B",Vector3(8.39,4.8,3.53),deg_to_rad(-115),7.2],["B",Vector3(.85,7.2,-2.4),-PI/2,9.6],["B",Vector3(.85,19.2,3.05),-PI/2,21.6]]:
		if spec[3]==7.2: spec[2]=deg_to_rad(65)
		if spec[3]==6.0: spec[1].z=7.45
		await stand(world_point(spec[0],spec[1]),spec[2])
		var caught: bool=false
		for tick in 160:
			await crouch_tick(false,Vector2(0,-1),false,tick==0)
			if hang.running: caught=true; break
		print("GROUND JUMP ",spec[0]," target ",spec[3]," caught ",caught," top ",hang.top.y," reason ",hang.result.get("reason"))
		check(caught and absf(hang.top.y-spec[3])<.08,"ground jump catch %.1f"%spec[3])
	for tower in ["A","B"]:
		check(await catch_anchor(tower+"_SummitLedge",0),"summit catch "+tower)
		check(hang.request_up(),"summit pull-up "+tower)
		for tick in 180: await crouch_tick(false)
		check(body.ground_support.has_ground_support and not hang.running,"summit grounded "+tower)
		var orb=course.orbs[tower]
		await stand(orb.global_position+Vector3(0,-1,1.3))
		body.context_interaction.scan()
		check(body.context_interaction.selected==orb,"orb normal E selection "+tower)
		check(body.context_interaction.activate_selected() and orb.lit,"orb activated "+tower)
	check(course.both_reported,"both-orb feedback")
	await stand(course.checkpoints.A_Upper.global_position,-PI/2)
	hang.top_entry.refresh()
	print("TOWER TOP DOWN ",hang.top_entry.result.get("reason"))
	check(hang.top_entry.begin_interaction(body),"top-down E activation")
	for tick in 160: await crouch_tick(false)
	check(hang.running and hang.hang_phase==hang.HangPhase.IDLE,"top-down settles")
	check(hang.lateral.query(hang,-1,.7).valid,"top-down route continues laterally")
	# Fresh-instance playground resets clear every action and test orb state.
	course.checkpoint="A_Upper"
	for repeat in 3:
		lab.request_reset(&"TwinTowers")
		await process_frame; await process_frame
		check(lab.player.global_position.distance_to(course.checkpoints.A_Upper.global_position)<.15,"R uses section checkpoint")
		check(not lab.player.traversal.hang.running and not lab.player.get_node("CameraRig").mantle_camera_active,"reset clears traversal and camera")
		check(not course.orbs.A.lit and not course.orbs.B.lit and not course.both_reported,"reset clears orb test state")
	print("TWIN_TOWER_GROUND_V2: ","PASS" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)
