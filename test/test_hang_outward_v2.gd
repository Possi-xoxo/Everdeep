extends "res://test/test_hang_transfer_v2.gd"
func run_outward(side: float=0) -> void:
	check(hang.navigation.resolve(hang,"JUMP",side),"context jump accepted")
	check(hang.outward.active and not hang.navigation.jumping,"outward owns jump instead of airborne")
	if not hang.outward.active: return
	var target: Vector3=hang.outward.destination.anchor
	var dest=hang.outward.destination.source
	var seen: bool=false
	var seen_catch: bool=false
	var yaw: float=body.visual.rotation.y
	var camera_yaw: float=cam.get_node("YawPivot").rotation.y
	cam._process(DT)
	var camera_position: Vector3=cam.global_position
	for tick in 140:
		await crouch_tick(false)
		cam._process(DT)
		check(cam.global_position.distance_to(camera_position)<.4,"ordinary camera follows without position jumps")
		check(absf(angle_difference(camera_yaw,cam.get_node("YawPivot").rotation.y))<.001,"transfer does not rotate camera orbit")
		camera_position=cam.global_position
		if hang.outward.active:
			if hang.outward.playback_time>hang.outward.flight_duration+.05:
				seen_catch=true
				check(body.position.distance_to(target)<.005,"catch recovery stays at destination without another jump")
				check(hang.hang_phase==hang.HangPhase.OUTWARD,"catch recovery retains traversal ownership")
			check(body.position.distance_to(hang.outward.expected_position)<.005,"outward follows collision-checked curve")
			check(not hang.try_catch(DT),"automatic catch cannot steal ownership")
			check(absf(angle_difference(yaw,body.visual.rotation.y))<.22,"continuous facing rotation")
			if hang.outward.progress>.4 and hang.outward.progress<.7:
				seen=true
				check(hang.outward.contact_weight(hang)==0 and hang.outward.contact_weight(hang,true)==0,"no mid-flight contact pinning")
				for arm in body.get_node("MantleHandIK").arms: check(arm.weight<.001,"hand solver releases in flight")
				for leg in body.get_node("FootIKController").legs: check(leg.weight<.001,"foot solver releases in flight")
			yaw=body.visual.rotation.y
	check(seen,"sampled authored flight")
	check(seen_catch,"real catch recovery plays before entering idle")
	check(hang.running and not hang.outward.active and hang.hang_phase==hang.HangPhase.IDLE,"stable destination hang")
	check(hang.source==dest and body.position.distance_to(target)<.005,"exact destination ownership and anchor")
	check((-body.visual.global_basis.z).dot(hang.facing)>.999,"destination facing aligned")

func run() -> void:
	await setup_transfer()
	hang.automatic_ledge_to_ledge_jump_enabled=true # Explicitly test the opt-in feature.
	var a=box(Vector3(200,1.5,-2),Vector3(8,3,4))
	var b=box(Vector3(200,1.5,6),Vector3(8,3,4))
	await physics_frame
	await catch_at(Vector3(200,1.1,.65))
	print("OUTWARD MEASURE ",hang.outward.authored_distance," / ",hang.outward.duration)
	print("OUTWARD QUERY ",hang.outward.query(hang,0).reason)
	await run_outward()
	await run_outward()
	for offset in [.25,-.25,.5,-.5]:
		if hang.running: body.traversal.finish("RESET")
		b.position.y=1.5+offset
		await physics_frame
		await catch_at(Vector3(200,1.1,.65))
		await run_outward()
		check(absf(hang.top.y-3-offset)<.01,"height bias exact")
	b.queue_free()
	await physics_frame
	await catch_at(Vector3(200,1.1,.65))
	check(hang.navigation.resolve(hang,"JUMP"),"fallback accepted")
	check(hang.navigation.jumping and not hang.outward.active,"no target uses original jump off")
	for tick in 35: await crouch_tick(false)
	check(not hang.running and body.velocity.y>0,"fallback airborne impulse preserved")
	a.queue_free()
	print("HANG_OUTWARD_V2: ","PASS" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)
