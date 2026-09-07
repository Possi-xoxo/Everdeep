extends "res://test/test_mantle_v2.gd"
var starts: int = 0
func held_tick(stick:=Vector2.ZERO,shift:=false,pressed:=false,held:=true) -> void:
	body.context_interaction.tick(pressed,held)
	await crouch_tick(false,stick,shift)

func run() -> void:
	lab=load("res://test/player_v2_lab.tscn").instantiate()
	root.add_child(lab)
	body=lab.get_node("PlayerV2")
	animation=body.get_node("AnimationController")
	tree=body.get_node("AnimationTree")
	lock=body.get_node("LockOnController")
	dummy=lab.get_node("LockOnTargetDummy")
	cam=body.get_node("CameraRig")
	dodge=body.dodge
	assist=body.roll_traversal
	crouch=body.crouch
	detector=body.traversal.get_node("LedgeDetector")
	body.set_physics_process(false)
	animation.set_physics_process(false)
	cam.set_process(false)
	tree.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	body.traversal.traversal_started.connect(func(_data): starts+=1)
	box(Vector3(200,-.25,0),Vector3(80,.5,80))
	for running in [false,true]:
		await fixture(2.4,6)
		for frame in 90: await crouch_tick(false)
		body.position.z=12.55 # 3.2m from the wall, hold before awareness.
		body.context_interaction.tick(false,false)
		var before:=starts
		var saw_early:=false
		for frame in 200:
			await held_tick(Vector2(0,-1),running,frame==0)
			if detector.result.valid and detector.result.distance>2.2:
				saw_early=true # Held input consumes the executable prompt immediately.
			if body.traversal.is_traversing: break
		check(saw_early,"early prompt walking/running "+str(running))
		check(starts==before+1,"pre-held E starts once")
		check(detector.result.distance>2.2 and detector.result.distance<=detector.mantle_acquisition_distance+.001,"held start uses full prompt range")
		for frame in 300: await held_tick()
		check(starts==before+1,"holding through completion does not restart")
		check(body.traversal.last_end_reason=="COMPLETED","held climb completes")
	# Visible prompt commits from rest, without requiring manual forward movement.
	await fixture(2.4,6)
	for frame in 90: await crouch_tick(false)
	body.position.z=11.55
	body.context_interaction.tick(false,false)
	var position_before: Vector3=body.position
	var before:=starts
	body.context_interaction.scan()
	check(body.context_interaction.prompt.visible,"stationary far awareness shown")
	await held_tick(Vector2.ZERO,false,true)
	check(starts==before+1 and body.traversal.is_traversing,"far prompt accepts input immediately")
	check(body.position.distance_to(position_before)<.05,"far acceptance does not teleport")
	for frame in 260: await held_tick()
	# Another ledge can consume the same hold, but only after normal travel.
	var upper:=box(Vector3(200,3.6,5.8),Vector3(3,2.4,2))
	for frame in 40: await held_tick()
	check(starts==before+1,"new awareness without movement cannot auto-chain")
	for frame in 180:
		await held_tick(Vector2(0,-1))
		if body.traversal.is_traversing: break
	check(starts==before+2,"normal travel to distinct next ledge rearms held intent")
	for frame in 260: await held_tick()
	check(starts==before+2,"next ledge also starts once")
	var generic=load("res://interaction/context_interactable.gd").new()
	root.add_child(generic)
	generic.position=body.position+Vector3(0,1,-.5)
	generic.requires_line_of_sight=false
	generic.priority=100
	for frame in 40: await held_tick()
	check(generic.activation_count==0,"held climb never fires generic interaction")
	await held_tick(Vector2.ZERO,false,false,false)
	await held_tick(Vector2.ZERO,false,true)
	check(generic.activation_count==1,"fresh generic press still works")
	generic.queue_free()
	upper.queue_free()
	await fixture(2.75)
	for frame in 90: await crouch_tick(false)
	body.position.z=11.5
	before=starts
	for frame in 100: await held_tick(Vector2(0,-1),true,frame==0)
	check(starts==before,"invalid geometry never starts with held E")
	print("HELD_CLIMB_V2: ","PASS" if failures.is_empty() else str(failures))
	quit(0 if failures.is_empty() else 1)
