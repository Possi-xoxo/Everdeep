extends "res://test/test_hang_outward_v2.gd"
func run() -> void:
	await setup_transfer()
	box(Vector3(200,1.5,-2),Vector3(8,3,4))
	await physics_frame
	await catch_at(Vector3(200,1.1,.65))
	var beam=box(body.position+Vector3.UP*2.05,Vector3(3,.15,3))
	await physics_frame
	var collision_mask: int=body.collision_mask
	for attempt in range(1,4):
		await crouch_tick(false,Vector2.ZERO,false,true)
		check(hang.navigation.jumping,"distinct Space starts departure")
		check(not hang.navigation.resolve(hang,"JUMP"),"busy jump does not count again")
		for tick in 100:
			await crouch_tick(false)
			if not hang.navigation.jumping: break
		print("BLOCKED ATTEMPT ",attempt," running ",hang.running," count ",hang.navigation.failed_jump_attempts)
		if attempt<3:
			check(hang.running and hang.navigation.failed_jump_attempts==attempt,"first two failures remain attached")
			for tick in 20: await crouch_tick(false)
		else:
			check(not hang.running and hang.release_active,"third failure disengages")
			check(hang.release_suppression_active,"escape preserves regrab suppression")
			check(body.velocity.y<0 and body.collision_mask==collision_mask,"normal downward release keeps collision")
	beam.queue_free()
	await physics_frame
	await catch_at(Vector3(200,1.1,.65))
	check(hang.navigation.failed_jump_attempts==0,"new hang clears failures")
	hang.navigation.failed_jump_attempts=2
	hang.navigation.failed_jump_anchor=hang.alignment
	await crouch_tick(false,Vector2.ZERO,false,true)
	for tick in 100:
		await crouch_tick(false)
		if not hang.navigation.jumping: break
	check(not hang.running and hang.exit_reason=="HANG_JUMP_OFF","clear jump succeeds, not emergency release")
	check(hang.navigation.failed_jump_attempts==0,"successful launch clears failures")
	check(is_equal_approx(body.velocity.z,4.8),"stronger outward launch")
	print("HANG_FAILED_JUMP_ESCAPE_V2: ","PASS" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)
