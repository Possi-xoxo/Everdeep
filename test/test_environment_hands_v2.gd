extends "res://test/test_roll_traversal_v2.gd"
var hands: Node

func walk_tick() -> void:
	await roll_tick(Vector2(0,-1),false)
	hands.sample(DT)

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
	hands=body.get_node("EnvironmentalHandInteraction")
	body.set_physics_process(false)
	animation.set_physics_process(false)
	cam.set_process(false)
	hands.set_physics_process(false)
	tree.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	box(Vector3(200,-.25,0),Vector3(80,.5,80))
	for side in [-1,1]:
		await reset_at(Vector3(200,.1,10))
		var wall:=box(Vector3(200+side*.62,1.1,0),Vector3(.12,2.2,30))
		var hits:=0
		for frame in 45:
			await walk_tick()
			var candidate=hands.left if side==-1 else hands.right
			var other=hands.right if side==-1 else hands.left
			if candidate.valid:
				hits+=1
				check(not other.valid,"opposite side independent")
				check(candidate.normal.dot(Vector3(-side,0,0))>.99,"wall normal points out of surface")
				check(candidate.distance<=.5,"strict shoulder reach bound")
		check(hits>35,"walking side wall consistently detected")
		print("HAND_WALL side=",side," hits=",hits," origin=",hands.left.origin," right=",hands.right.origin)
		# Observe-only: repeated samples cannot move body or alter bone poses.
		var transform:=body.global_transform
		var velocity:=body.velocity
		var poses: Array[Transform3D]=[]
		for bone in hands.skeleton.get_bone_count(): poses.append(hands.skeleton.get_bone_pose(bone))
		hands.environment_hand_debug=true
		hands.sample(DT)
		check(body.global_transform==transform and body.velocity==velocity,"sensing never writes motor")
		for bone in poses.size(): check(poses[bone]==hands.skeleton.get_bone_pose(bone),"sensing never writes bones")
		hands.environment_hand_debug=false
		wall.free()
		hands.sample(DT)
		check(not hands.left.valid and not hands.right.valid,"deleted surface immediately invalidates")
	await reset_at(Vector3(200,.1,10))
	var wall_left:=box(Vector3(199.38,1.1,0),Vector3(.12,2.2,30))
	var wall_right:=box(Vector3(200.62,1.1,0),Vector3(.12,2.2,30))
	for frame in 12: await walk_tick()
	check(hands.left.valid and hands.right.valid,"corridor reports both independently")
	# Brief misses retain data only for the bounded grace period.
	hands.hand_collision_mask=0
	hands.sample(DT)
	check(hands.left.valid and hands.left.provisional,"one missed query receives grace")
	for frame in ceili(hands.hand_target_loss_grace_time/DT)+2: hands.sample(DT)
	check(not hands.left.valid and not hands.right.valid,"grace expires without stale targets")
	hands.hand_collision_mask=1
	hands.sample(DT)
	wall_left.add_to_group("enemy")
	hands.sample(DT)
	check(not hands.left.valid,"enemy-tagged static geometry excluded even on world layer")
	wall_left.remove_from_group("enemy")
	var s=body.animation_state
	for gate in ["idle","run","sprint","lock","dodge","air","land","step","speed","disabled"]:
		s.gait=0
		s.move_input_magnitude=1
		s.horizontal_speed=4
		s.is_grounded=true
		s.is_airborne=false
		s.locked_on=false
		dodge.is_dodging=false
		animation.current_state=&"Locomotion"
		body.step_solver.active=false
		hands.enabled=true
		match gate:
			"idle": s.move_input_magnitude=0
			"run": s.gait=1
			"sprint": s.gait=2
			"lock": s.locked_on=true
			"dodge": dodge.is_dodging=true
			"air": s.is_airborne=true
			"land": animation.current_state=&"Land"
			"step": body.step_solver.active=true
			"speed": s.horizontal_speed=8
			"disabled": hands.enabled=false
		var count: int=hands.probe_updates
		hands.sample(DT)
		check(not hands.left.valid and not hands.right.valid and hands.probe_updates==count,"gate clears targets without queries: "+gate)
	hands.enabled=true
	dodge.is_dodging=false
	wall_left.free()
	wall_right.free()
	await reset_at(Vector3(200,.1,10))
	var end_wall:=box(Vector3(199.38,1.1,9),Vector3(.12,2.2,3))
	var acquired:=false
	var released:=false
	for frame in 100:
		await walk_tick()
		acquired=acquired or hands.left.valid
		if acquired and not hands.left.valid: released=true
	check(acquired and released,"wall end acquires then releases")
	end_wall.free()
	await reset_at(Vector3(200,.1,10))
	var pillar:=box(Vector3(199.38,1.1,8),Vector3(.2,2.2,.35))
	acquired=false
	released=false
	for frame in 80:
		await walk_tick()
		acquired=acquired or hands.left.valid
		if acquired and not hands.left.valid: released=true
	check(acquired and released,"narrow pillar acquires and releases")
	pillar.free()
	await reset_at(Vector3(200,.1,10))
	var far:=box(Vector3(198.5,1.1,0),Vector3(.1,2.2,30))
	for frame in 12: await walk_tick()
	check(not hands.left.valid,"distant wall rejected")
	far.free()
	await reset_at(Vector3(200,.1,10))
	var pieces: Array[Node]=[]
	for index in 12:
		pieces.append(box(Vector3(199.38+(.025 if index%2==0 else -.025),1.1,10-index*.5),Vector3(.12,2.2,.5)))
	var valid_frames:=0
	for frame in 70:
		await walk_tick()
		if hands.left.valid:
			valid_frames+=1
			check(hands.within_reach(hands.left,hands.left.smoothed),"uneven-wall smoothing stays reachable")
	check(valid_frames>55,"uneven wall remains stable across segments")
	for piece in pieces: piece.free()
	await reset_at(Vector3(200,.1,10))
	var rail:=box(Vector3(199.38,1.25,0),Vector3(.12,.16,30))
	for frame in 20: await walk_tick()
	check(hands.left.valid,"shoulder-height narrow rail detected")
	rail.free()
	await walk_tick()
	check(not hands.left.valid and not hands.right.valid,"floor alone is not a hand target")
	print("ENVIRONMENT_HANDS_V2: ","PASS" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)
