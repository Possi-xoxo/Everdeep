extends "res://test/test_free_hang_v2.gd"

func settle_free(at: Vector3) -> void:
	await free_catch(at,Vector3(0,-2,-2))
	for i in 100: await crouch_tick(false)
	check(body.traversal.free_hang.running,"free catch")

func action_tick(stick: Vector2,shift: bool=false) -> void:
	await crouch_tick(false,stick,shift)
	for i in 260:
		await crouch_tick(false)
		for leg in body.get_node("FootIKController").legs:
			if body.traversal.free_hang.running: check(leg.weight==0,"Free actions never brace feet")
		if not body.traversal.free_hang.actions.active: break

func run() -> void:
	await setup_transfer()
	var free=body.traversal.free_hang
	box(Vector3(200,2.875,-2),Vector3(10,.25,4))
	box(Vector3(200,-.1,1),Vector3(20,.2,12))
	await physics_frame
	await settle_free(Vector3(200,1.1,.65))
	await crouch_tick(false,Vector2.ZERO,false,true)
	check(free.running and not free.actions.active,"Space has NO action in stable Free Hang")
	for pair in [[Vector2.LEFT,false],[Vector2.RIGHT,false],[Vector2.LEFT,true],[Vector2.RIGHT,true]]:
		var before: Vector3=body.position
		await crouch_tick(false,pair[0],pair[1])
		check(free.actions.active,"horizontal action starts: "+free.actions.last_resolution)
		var expected: float=free.actions.distance
		var name: StringName=free.actions.state
		var peak: float=0
		var hand_error: float=0
		for i in 260:
			await crouch_tick(false)
			peak=maxf(peak,body.position.y-before.y)
			for arm in body.get_node("MantleHandIK").arms:
				check(arm.length_error<.005,"moving hand IK preserves arm lengths")
				if arm.weight>.99: hand_error=maxf(hand_error,arm.error)
			if not free.actions.active: break
		print("FREE MOVE ",name," expected ",expected," actual ",body.position-before," peak ",peak," full_contact_error ",hand_error," exit ",free.exit_reason)
		check(free.running,"horizontal movement retains Free ownership")
		check(absf(absf(body.position.x-before.x)-expected)<.03,"authored distance reached")
		if pair[1]: check(peak>.3,"hop has authored arc, not a linear slide")
		for i in 25: await crouch_tick(false)
	await action_tick(Vector2.UP)
	print("FREE CLIMB ",free.actions.last_resolution," ",free.exit_reason," pos ",body.position)
	check(not free.running and body.ground_support.has_ground_support,"W climbs to grounded crouch")
	await settle_free(Vector3(200,1.1,.65))
	await action_tick(Vector2.DOWN)
	check(not free.running and free.exit_reason=="FREE_RELEASED","S releases with dedicated lead-out")
	check(not hang.running and not hang.navigation.jumping,"no Braced launch inherited")
	print("FREE MOVEMENT TEST ","PASS" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)
