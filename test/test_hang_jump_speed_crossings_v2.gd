extends "res://test/test_twin_tower_v2.gd"
func run() -> void:
	await setup_towers()
	for spec in [["A_JumpOff",0,19.2],["B_FreeJump",-4.1,16.8],["B_ReturnLaunch",-4.1,27.4],["A_FinalLeft",4.2,30.8]]:
		check(await catch_anchor(spec[0],spec[1]),"crossing source")
		var source=hang.source
		hang.navigation.resolve(hang,"JUMP")
		var caught: bool=false
		for tick in 200:
			await crouch_tick(false)
			if hang.running and hang.source!=source: caught=true; break
		print("SPEED CROSS ",spec[0]," caught ",caught," height ",hang.top.y)
		check(caught and absf(hang.top.y-spec[2])<.05,"intended opposite grip catches")
		check(not hang.outward.active,"no auto targeting required")
	print("HANG_JUMP_SPEED_CROSSINGS_V2: ","PASS" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)
