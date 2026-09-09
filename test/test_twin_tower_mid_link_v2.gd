extends "res://test/test_twin_tower_lateral_v2.gd"
func run() -> void:
	await setup_towers()
	check(await catch_anchor("A_MixRightUp",4.2),"preceding upper grip")
	check(hang.vertical.resolve(hang,1),"hop onto level connector")
	for tick in 160: await crouch_tick(false)
	check(hang.running and absf(hang.top.y-16.8)<.02,"preceding hop settles")
	check(await catch_anchor("A_MixLeft",-.1644),"screenshot hang position")
	print("RIGHT LINK ",hang.lateral.preview(hang,1,false).reason)
	for step in 5: check(await lateral_step(1,false),"right shimmy toward checkpoint")
	check(hang.ledge_edge.z<course.global_position.z-3.2,"reaches checkpoint opening")
	check(hang.request_up(),"checkpoint pull-up")
	for tick in 180: await crouch_tick(false)
	check(body.ground_support.has_ground_support,"checkpoint grounded")
	check(await catch_anchor("A_CrossReentry",-3.6),"return hang")
	print("RETURN LINK ",hang.lateral.preview(hang,-1,false).reason," contacts ",hang.contact_still_exists()," alignment ",hang.alignment)
	for step in 5: check(await lateral_step(-1,false),"left shimmy back toward launch")
	check(hang.vertical.query(hang,1).valid,"upper launch remains reachable")
	check(hang.vertical.resolve(hang,1),"hop toward launch")
	for tick in 160: await crouch_tick(false)
	check(hang.running and absf(hang.top.y-18.2)<.02,"launch hop settles")
	check(await catch_anchor("B_FreeJump"),"cross tower source")
	var source=hang.source
	check(hang.navigation.resolve(hang,"JUMP"),"normal free jump")
	var caught: bool=false
	for tick in 200:
		await crouch_tick(false)
		if hang.running and hang.source!=source: caught=true; break
	check(caught and not hang.outward.active,"normal catch onto updated landing")
	print("TWIN_TOWER_MID_LINK_V2: ","PASS" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)
