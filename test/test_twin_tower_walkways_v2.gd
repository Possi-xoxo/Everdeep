extends "res://test/test_twin_tower_ground_v2.gd"
func walk_to(point: Vector3) -> void:
	cam.yaw.rotation.y=0
	for tick in 220:
		var delta: Vector3=point-body.position
		if Vector2(delta.x,delta.z).length()<.055: break
		await crouch_tick(false,Vector2(delta.x,delta.z).normalized())
	var distance: float=Vector2(point.x-body.position.x,point.z-body.position.z).length()
	print("WALKWAY ",point," reached ",body.position," distance ",distance)
	check(distance<.09 and body.ground_support.has_ground_support,"standing walkway connected")

func run() -> void:
	await setup_towers()
	await stand(course.checkpoints.A_Lower.global_position)
	for p in [Vector3(-2.05,8.6,4.35),Vector3(-.4,8.6,4.35),Vector3(-.4,8.6,6.65),Vector3(-1.9,8.6,6.65)]: await walk_to(world_point("A",p))
	for tower in ["A","B"]:
		var side: float=-1 if tower=="A" else 1
		var y: float=11 if tower=="A" else 7.2
		await stand(course.checkpoints[tower+"_CurveRest"].global_position)
		for degrees in [162,167,172,177]:
			var n:=Vector3(side*sin(deg_to_rad(degrees)),0,cos(deg_to_rad(degrees)))
			await walk_to(world_point(tower,Vector3(side*2.7,y,0)+n*5.5))
		for p in [Vector3(side*1.5,y,-5.7),Vector3(side*.85,y,-4.5),Vector3(side*.85,y,-2.4)]: await walk_to(world_point(tower,p))
	await stand(world_point("B",Vector3(8.2,4.8,5.5)))
	await walk_to(world_point("B",Vector3(8.39,4.8,3.53)))
	print("TWIN_TOWER_WALKWAYS_V2: ","PASS" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)
