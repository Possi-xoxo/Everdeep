extends "res://test/test_hang_outward_v2.gd"
func run() -> void:
	await setup_transfer()
	var a=box(Vector3(200,1.5,-2),Vector3(8,3,4))
	var b=box(Vector3(200,1.5,7),Vector3(8,3,4))
	await physics_frame
	await catch_at(Vector3(200,1.1,.65))
	check(not hang.automatic_ledge_to_ledge_jump_enabled,"uses default normal jump, not committed transfer")
	check(is_equal_approx(hang.facing_acceptance_half_angle,100),"facing cone not widened")
	check(hang.navigation.resolve(hang,"JUMP"),"wall jump starts")
	var caught: bool=false
	var turned: bool=false
	for tick in 160:
		await crouch_tick(false)
		if not hang.running and animation._playback.get_current_node()==&"HangJumpOff":
			var facing: Vector3=hang.navigation.catch_forward(hang)
			if facing.dot(Vector3.BACK)>.8: turned=true
			check(not hang.outward.active,"ordinary airborne ownership retained")
		if hang.running and hang.source==b:
			caught=true
			for key in ["Facing","Approach","Vertical reach","Horizontal reach","Regrab","Body","Head / full sweep"]:
				check(hang.result.checks[key],"catch retained safeguard: "+key)
			break
	check(turned,"detector follows authored turn toward new wall")
	check(caught,"normal wall jump catches eligible opposite ledge without input")
	for tick in 35: await crouch_tick(false)
	check(hang.running and hang.source==b and hang.hang_phase==hang.HangPhase.IDLE,"normal catch settles into stable hang")
	check(hang.navigation.catch_forward(hang).dot(-body.visual.global_basis.z)>.999,"attached facing returns to ordinary root")
	a.queue_free(); b.queue_free()
	print("HANG_JUMP_RECATCH_V2: ","PASS" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)
