extends "res://test/test_roll_traversal_v2.gd"
var hands: Node
var arm_ik: Node

func setup_player() -> void:
	await reset_at(Vector3(200,.1,10))
	for frame in 135: await roll_tick()

func assert_arms() -> void:
	check(not (arm_ik.arms[0].weight>0 and arm_ik.arms[1].weight>0),"only one arm has influence")
	for arm in arm_ik.arms:
		check(arm.solved.is_finite() and arm.elbow.is_finite(),"finite solver result")
		check(arm.shoulder.distance_to(arm.elbow)<.285 and arm.elbow.distance_to(arm.solved)<.290,"arm segments do not stretch")
		if arm.weight<=.00001: check(arm.solved.distance_to(arm.animated)<.0001,"inactive hand stays animation-driven")

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
	arm_ik=body.get_node("EnvironmentalHandIK")
	body.set_physics_process(false)
	animation.set_physics_process(false)
	cam.set_process(false)
	tree.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	box(Vector3(200,-.25,0),Vector3(80,.5,80))
	for side in [-1,1]:
		await setup_player()
		var wall:=box(Vector3(200+side*.62,1.1,0),Vector3(.12,2.2,30))
		var reached:=0
		for frame in 70:
			await roll_tick(Vector2(0,-1))
			assert_arms()
			var index:=0 if side<0 else 1
			var arm=arm_ik.arms[index]
			if arm.weight>.2:
				reached+=1
				check(arm_ik.active_side==index,"correct arm selected")
				check(arm.solved.distance_to(arm.target.global_position)<arm.animated.distance_to(arm.target.global_position),"IK hand approaches smoothed target")
				check((arm.elbow-body.global_position).dot(Vector3(side,0,0))>.05,"elbow remains outside torso centerline")
		check(reached>40,"stable wall reach acquired")
		print("ARM_WALL side=",side," reached=",reached," weight=",arm_ik.arms[0 if side<0 else 1].weight)
		var count: int=hands.probe_updates
		await roll_tick(Vector2(0,-1))
		check(hands.probe_updates-count==2,"one Phase 1 sample per evaluated pose, no duplicate queries")
		for frame in 15: await roll_tick()
		check(not arm_ik.environment_hand_contact_active and arm_ik.active_side==-1,"Idle no longer holds wall after release")
		wall.free()
	await setup_player()
	var walls: Array[Node]=[box(Vector3(199.38,1.1,0),Vector3(.12,2.2,30)),box(Vector3(200.62,1.1,0),Vector3(.12,2.2,30))]
	var previous: int=-1
	var switches:=0
	for frame in 90:
		await roll_tick(Vector2(0,-1))
		assert_arms()
		if arm_ik.active_side>=0:
			if previous>=0 and previous!=arm_ik.active_side: switches+=1
			previous=arm_ik.active_side
	check(switches==0,"corridor score hysteresis prevents alternation")
	# Removing the chosen wall requires complete release before other arm takes over.
	walls[previous].free()
	for frame in 30:
		await roll_tick(Vector2(0,-1))
		assert_arms()
	check(arm_ik.active_side==-1 and arm_ik.environment_hand_cooldown_remaining>0,"global cooldown blocks opposite hand after fade-out")
	for frame in 110: await roll_tick(Vector2(0,-1))
	check(arm_ik.active_side==1-previous,"opposite hand can acquire after global cooldown")
	walls[1-previous].free()
	for gate in ["run","lock","dodge","jump"]:
		await setup_player()
		var wall:=box(Vector3(199.38,1.1,0),Vector3(.12,2.2,30))
		for frame in 20: await roll_tick(Vector2(0,-1))
		check(arm_ik.arms[0].weight>.2,"reach prepared before "+gate)
		if gate=="lock":
			dummy.position=Vector3(200,0,0)
			lock.toggle()
		await roll_tick(Vector2(0,-1),gate=="run",gate=="jump",gate=="dodge")
		for frame in 15:
			await roll_tick(Vector2(0,-1),gate=="run")
			assert_arms()
		check(arm_ik.arms[0].weight==0 and arm_ik.arms[1].weight==0,"state suppresses IK: "+gate)
		wall.free()
	await setup_player()
	var pillar:=box(Vector3(199.38,1.1,8),Vector3(.12,2.2,.4))
	var touched:=false
	for frame in 150:
		await roll_tick(Vector2(0,-1))
		assert_arms()
		touched=touched or arm_ik.environment_hand_contact_active
	check(touched and arm_ik.arms[0].weight==0,"pillar attempts staged reach then releases; full contact not required on narrow targets")
	pillar.free()
	await setup_player()
	var pieces: Array[Node]=[]
	for index in 14: pieces.append(box(Vector3(199.38+(.025 if index%2==0 else -.025),1.1,10-index*.5),Vector3(.12,2.2,.5)))
	var reaching:=0
	for frame in 75:
		await roll_tick(Vector2(0,-1))
		assert_arms()
		if arm_ik.environment_hand_contact_active: reaching+=1
	check(reaching>0,"uneven wall permits staged reach attempts without elbow flips; sharp edges can cancel prep")
	for piece in pieces: piece.free()
	await setup_player()
	var cap_wall:=box(Vector3(199.38,1.1,0),Vector3(.12,2.2,30))
	for frame in 30: await roll_tick(Vector2(0,-1))
	arm_ik.max_environment_hand_reach=.30 # Deliberately short cap exercises clamp.
	for frame in 5: await roll_tick(Vector2(0,-1))
	print("ARM_CAP ",arm_ik.debug_text()," actual=",arm_ik.arms[0].target.global_position.distance_to(arm_ik.arms[0].shoulder))
	check(not arm_ik.environment_hand_contact_active and arm_ik.contact_release_reason=="OUT_OF_REACH","shortened reach cap rejects contact and softly releases instead of stretching")
	cap_wall.free()
	for frame in 15: await roll_tick(Vector2(0,-1))
	check(arm_ik.arms[0].weight==0,"lost surface restores animation authority")
	print("ENVIRONMENT_HAND_IK_V2: ","PASS" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)
