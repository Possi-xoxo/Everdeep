extends "res://test/test_braced_hang_v2.gd"

func add_shape(parent: Node3D,point: Vector3,size: Vector3) -> void:
	var collision:=CollisionShape3D.new()
	var shape:=BoxShape3D.new()
	shape.size=size
	collision.shape=shape
	parent.add_child(collision)
	collision.position=point

func run() -> void:
	lab=load("res://test/player_v2_lab.tscn").instantiate()
	root.add_child(lab)
	body=lab.get_node("PlayerV2")
	animation=body.get_node("AnimationController")
	tree=body.get_node("AnimationTree")
	cam=body.get_node("CameraRig")
	crouch=body.crouch
	hang=body.traversal.hang
	body.set_physics_process(false)
	animation.set_physics_process(false)
	cam.set_process(false)
	tree.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	var wall:=StaticBody3D.new()
	root.add_child(wall)
	add_shape(wall,Vector3(200,3,8.27),Vector3(4,6,2))
	add_shape(wall,Vector3(200,1.5,8.35),Vector3(4,3,2))
	for height in [3.0,4.0,5.0,6.0]: add_shape(wall,Vector3(200,height-.09,8.35),Vector3(4,.18,2))
	await air_setup()
	check(hang.try_catch(DT),"catch bottom shelf")
	for frame in 30: await crouch_tick(false)
	print("VERTICAL MEASUREMENTS ",hang.vertical.measurements)
	var start: Vector3=hang.alignment
	# Range and corridor failures must be classified before input commits.
	hang.vertical_up_range=.8
	hang.vertical.refresh(hang,0,true)
	check(not hang.vertical.upper.valid,"out-of-range upper rejected")
	hang.vertical_up_range=1.4
	var blocker=box(Vector3(200,3.35,9.85),Vector3(1,.12,.7))
	await physics_frame
	hang.vertical.refresh(hang,0,true)
	check(not hang.vertical.upper.valid,"blocked upper corridor rejected")
	check(not hang.vertical.resolve(hang,1) and hang.running,"blocked upper and pull-up remain hanging")
	blocker.queue_free()
	await physics_frame
	for side in [1,1,1,-1,-1,-1]:
		hang.vertical.refresh(hang,0,true)
		var target: Dictionary=hang.vertical.upper if side>0 else hang.vertical.lower
		print("TARGET ",side," ",target)
		check(target.valid,"vertical target found")
		if not target.valid: break
		var expected: Vector3=target.anchor
		check(hang.vertical.resolve(hang,side),"context action accepted")
		check(hang.vertical.active and not hang.release_active,"hop preferred to fallback")
		check(not hang.vertical.resolve(hang,side),"busy input cannot chain")
		for frame in 150:
			await crouch_tick(false)
			if not hang.vertical.active: break
		check(hang.running and hang.hang_phase==hang.HangPhase.IDLE,"hop returns attached idle")
		check(body.position.distance_to(expected)<.001,"exact target convergence")
		check(absf(animation.rig.position.y+.23)<.001,"shared visual baseline preserved")
		for arm in body.get_node("MantleHandIK").arms: check(arm.length_error<.005,"vertical IK does not stretch arms")
		if side>0 and absf(hang.top.y-6.0)<.01:
			hang.vertical.refresh(hang,0,true)
			check(not hang.vertical.upper.valid and hang.climb_destination_valid,"top has pull-up fallback")
		for frame in 15: await crouch_tick(false)
	check(body.position.distance_to(start)<.001,"up/down chain has no accumulated drift")
	hang.vertical.refresh(hang,0,true)
	check(not hang.vertical.lower.valid,"no lower target at bottom")
	check(not hang.vertical.resolve(hang,-1) and hang.running,"S without safe ground stays hanging")
	print("HANG_VERTICAL_V2: ","PASS" if failures.is_empty() else str(failures))
	quit(0 if failures.is_empty() else 1)
