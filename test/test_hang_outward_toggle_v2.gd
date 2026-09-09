extends "res://test/test_hang_outward_v2.gd"
func run() -> void:
	await setup_transfer()
	var a=box(Vector3(200,1.5,-2),Vector3(8,3,4))
	var b=box(Vector3(200,1.5,6),Vector3(8,3,4))
	await physics_frame
	check(not hang.automatic_ledge_to_ledge_jump_enabled,"automatic transfer defaults off")
	hang.automatic_ledge_to_ledge_jump_enabled=false
	await catch_at(Vector3(200,1.1,.65))
	check(hang.running,"normal airborne catch still works with toggle off")
	check(hang.outward.query(hang,0).reason=="DISABLED" and hang.outward.candidates.is_empty(),"disabled transfer does not search for targets")
	check(hang.navigation.resolve(hang,"JUMP"),"disabled transfer still accepts jump")
	check(hang.navigation.jumping and not hang.outward.active,"normal jump owns departure despite eligible opposing ledge")
	for tick in 35: await crouch_tick(false)
	check(not hang.outward.active and not hang.running and body.velocity.y>0,"normal ballistic jump released without transfer ownership")
	hang.automatic_ledge_to_ledge_jump_enabled=true
	await catch_at(Vector3(200,1.1,.65))
	check(hang.outward.query(hang,0).valid,"re-enabling restores target query")
	await run_outward()
	a.queue_free()
	b.queue_free()
	print("HANG_OUTWARD_TOGGLE_V2: ","PASS" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)
