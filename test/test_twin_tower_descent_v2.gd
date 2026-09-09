extends "res://test/test_twin_tower_lateral_v2.gd"
func run() -> void:
	await setup_towers()
	check(await catch_anchor("B_HopDown"),"B descent start")
	check(hang.vertical.resolve(hang,-1),"B down commit")
	for tick in 160: await crouch_tick(false)
	for step in 8:
		if hang.ledge_edge.x>course.global_position.x+1+7.9: break
		check(await lateral_step(1,false),"B lower shimmy "+str(step))
	print("B LOWER END ",hang.ledge_edge," pull ",hang.check_pull_up()," ",hang.exit_reason)
	check(hang.request_up(),"B lower end pull-up")
	for tick in 180: await crouch_tick(false)
	check(body.ground_support.has_ground_support,"B lower rest grounded")
	print("TWIN_TOWER_DESCENT_V2: ","PASS" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)
