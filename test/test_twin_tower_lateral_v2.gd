extends "res://test/test_twin_tower_ground_v2.gd"
func lateral_step(side: int,hop: bool) -> bool:
	var accepted: bool=hang.lateral.request(hang,side,hop)
	if not accepted: return false
	for tick in 200:
		await crouch_tick(false)
		if not hang.lateral.active and not hang.transfer.active: break
	return hang.running and hang.hang_phase==hang.HangPhase.IDLE

func run() -> void:
	await setup_towers()
	check(await catch_anchor("A_FullHop",4.65),"lower lateral start")
	var q: Dictionary=hang.lateral.preview(hang,1,true)
	print("FULL ",q.get("actual_distance"))
	check(q.valid and q.actual_distance>2.9,"full hop fits")
	check(await lateral_step(1,true),"full hop settles")
	q=hang.lateral.preview(hang,1,true)
	print("PARTIAL ",q.get("actual_distance"))
	check(q.valid and q.actual_distance<1.5,"partial hop required near gap")
	check(await lateral_step(1,true),"partial hop settles")
	check(await lateral_step(1,true),"gap transfer settles")
	print("GAP ARRIVAL ",hang.ledge_edge)
	check(hang.ledge_edge.z<course.global_position.z-.5,"crossed real facade gap")
	for tower in ["A","B"]:
		check(await catch_anchor(tower+"_Curve_Start"),"curve entry")
		var side: int=-1 if tower=="A" else 1
		var count: int=0
		var pulled: bool=false
		var partial: bool=false
		while count<30:
			# Most of the route uses full hops; shimmy crosses the curved-to-rest join.
			var angle: float=rad_to_deg(acos(clampf(hang.wall_normal.z,-1,1)))
			var hop: bool=angle<115
			if angle>130 and not partial:
				var near_end: Dictionary=hang.lateral.preview(hang,side,true)
				if near_end.valid and near_end.actual_distance<2.95:
					hop=true; partial=true
					print("CURVE PARTIAL ",tower," ",near_end.actual_distance)
			var advanced: bool=await lateral_step(side,hop)
			print("CURVE TOUR ",tower," ",count," angle ",angle," advanced ",advanced," reason ",hang.lateral.preview(hang,side,hop).reason)
			if not advanced: break
			count+=1
			if hang.check_pull_up():
				pulled=hang.request_up()
				for tick in 180: await crouch_tick(false)
				break
		check(pulled and body.ground_support.has_ground_support,"full curve reaches standing balcony "+tower)
		check(partial,"curved partial hop available "+tower)
	# Both lower rest windows must permit the hoist (not merely a valid target).
	for title in ["A_Rest","B_LowerCheckpoint","A_CrossLanding","A_TopDownEntry","B_CatchA"]:
		var z: float=4.2 if title=="A_Rest" else (4.3 if title=="B_LowerCheckpoint" else (-4.0 if title in ["A_CrossLanding","A_TopDownEntry"] else 0.0))
		if title=="A_Rest": z=3.5
		check(await catch_anchor(title,z),"rest catch")
		var accepted: bool=hang.request_up()
		print("REST PULL ",title," ",accepted," ",hang.exit_reason)
		check(accepted,"rest hoist "+title)
		for tick in 180: await crouch_tick(false)
		check(body.ground_support.has_ground_support,"rest grounded "+title)
	check(await catch_anchor("A_FinalLeft",4.2),"summit branch source")
	var source=hang.source
	check(hang.navigation.resolve(hang,"JUMP"),"summit free jump starts")
	var caught: bool=false
	for tick in 200:
		await crouch_tick(false)
		if hang.running and hang.source!=source: caught=true; break
	check(caught and absf(hang.top.y-30.8)<.1,"summit branch normal catch")
	print("TWIN_TOWER_LATERAL_V2: ","PASS" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)
