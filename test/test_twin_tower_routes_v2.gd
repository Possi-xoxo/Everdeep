extends "res://test/test_twin_tower_v2.gd"
func run() -> void:
	await setup_towers()
	for spec in [["A_GapLanding",-4.2,6.2],["A_ReturnGap",4.2,7.4],["A_UpperRight",4.2,8.6],["A_MixStart",-.2,14.6],["A_MixRight",4.2,15.8],["A_MixRightUp",4.2,17.0],["A_MixLeft",0,18.2],["A_CrossReentry",-.2,18.2],["A_TopDownEntry",4.2,28.6],["A_FinalUp",4.2,29.8],["A_FinalLeft",0,31.0],["A_FinalCenter",0,32.2],["B_InnerStart",-.2,10.8],["B_InnerRight",4.2,12.0],["B_LowerCheckpoint",3.0,13.2],["B_InnerLeft",-.2,14.4],["B_InnerBack",-4.2,15.6],["B_UpperStart",4.2,22.8],["B_UpperRight",4.2,24.0],["B_UpperLeft",-.2,25.2],["B_UpperBack",-4.2,26.4],["B_SummitCatch",4.2,32.0]]:
		if spec[0] in ["A_MixStart","B_InnerStart"]: spec[1]=-.35
		if spec[0]=="A_UpperRight": spec[1]=3.5
		if spec[0]=="A_MixRightUp": spec[2]=16.8
		check(await catch_anchor(spec[0],spec[1]),"route source "+spec[0])
		if not hang.running: continue
		var q: Dictionary=hang.vertical.query(hang,1)
		print("UP EDGE ",spec[0]," ",q.reason," -> ",q.get("edge"))
		check(q.valid and absf(q.edge.y-spec[2])<.05,"route upper "+spec[0])
		if q.valid:
			check(hang.vertical.resolve(hang,1),"upper hop commits")
			for tick in 160: await crouch_tick(false)
			check(hang.running and hang.hang_phase==hang.HangPhase.IDLE and absf(hang.top.y-spec[2])<.05,"upper hop settles "+spec[0])
	# Opposite ends do not expose the next target: lateral reposition is required.
	for spec in [["A_MixStart",-2.4],["A_MixRight",0],["A_TopDownEntry",-4.2],["B_InnerStart",-2.4],["B_UpperStart",3.05],["B_UpperLeft",2.4]]:
		check(await catch_anchor(spec[0],spec[1]),"shortcut source")
		check(not hang.vertical.query(hang,1).valid,"no W-only shortcut "+spec[0])
	check(await catch_anchor("B_HopDown"),"descent source")
	var down: Dictionary=hang.vertical.query(hang,-1)
	print("DOWN ",down)
	check(down.valid and absf(down.edge.y-4.8)<.05,"S selects lower route")
	if down.valid:
		check(hang.vertical.resolve(hang,-1),"S commits hop down")
		for tick in 160: await crouch_tick(false)
		check(hang.running and absf(hang.top.y-4.8)<.02,"downward route settles")
	for title in course.checkpoints:
		var point: Vector3=course.checkpoints[title].global_position
		check(hang.clear_segment(point,point,1.8),"checkpoint standing clearance "+title)
	print("TWIN_TOWER_ROUTES_V2: ","PASS" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)
