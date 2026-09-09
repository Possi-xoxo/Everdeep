extends "res://test/test_free_hang_moves_v2.gd"

func run() -> void:
	await setup_transfer()
	var free=body.traversal.free_hang
	box(Vector3(200,2.875,-2),Vector3(2.3,.25,4))
	box(Vector3(209,2.875,-2),Vector3(2,.25,4))
	box(Vector3(211.18,2.875,-2),Vector3(2,.25,4))
	box(Vector3(220,2.875,-2),Vector3(6,.25,4))
	box(Vector3(220,3.7,-2),Vector3(6,.3,4))
	box(Vector3(230,2.875,-2),Vector3(8,.25,4))
	await physics_frame
	await settle_free(Vector3(200,1.1,.65))
	await crouch_tick(false,Vector2.RIGHT,true)
	check(free.actions.active and free.actions.distance>=.40 and free.actions.distance<.89,"partial hop validates authored overshoot")
	print("FREE PARTIAL ",free.actions.distance)
	for i in 150: await crouch_tick(false)
	check(free.running and not free.actions.active,"partial hop completes")
	await settle_free(Vector3(209.70,1.1,.65))
	var source: Node=free.source
	await crouch_tick(false,Vector2.RIGHT,true)
	check(free.actions.active and free.actions.destination.get("remote",false),"small lateral gap transfer selected")
	for i in 150: await crouch_tick(false)
	check(free.running and free.source!=source,"remote arrival commits destination source")
	check(not hang.running,"remote remains Free, never Braced")
	await settle_free(Vector3(220,1.1,.65))
	await action_tick(Vector2.UP)
	check(free.running and not free.actions.active,"blocked climb does nothing, no vertical hop fallback")
	await release_free()
	check(not free.running,"S releases despite blocked top")
	await settle_free(Vector3(230,1.1,.65))
	await crouch_tick(false,Vector2.LEFT,true)
	var selected: StringName=free.actions.state
	for i in 20: await crouch_tick(false,Vector2.DOWN,false,true)
	check(free.running and free.actions.state==selected,"mid-hop drop and Space cannot interrupt")
	for i in 160: await crouch_tick(false,Vector2.DOWN)
	check(free.running and not free.actions.active,"held conflicting drop doesn't fire on arrival")
	await crouch_tick(false)
	await release_free()
	check(not free.running,"fresh S releases after action")
	# Simultaneous source loss and W must not dereference a freed source.
	await settle_free(Vector3(230,1.1,.65))
	free.source.queue_free()
	await physics_frame
	await crouch_tick(false,Vector2.UP)
	check(not free.running and not body.traversal.is_traversing,"source loss releases before interpreting W")
	print("FREE PATH TEST ","PASS" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)
