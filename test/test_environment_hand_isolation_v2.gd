extends "res://test/test_environment_hand_contact_v2.gd"

func assert_clean(label: String) -> void:
	check(not hands.can_use_environment_hand_ik(),"ineligible: "+label)
	check(not arm_ik.environment_hand_contact_active and arm_ik.active_side==-1,"no cached contact: "+label)
	for arm in arm_ik.arms:
		check(arm.weight==0 and arm.rotation_weight==0 and arm.solver.influence==0,"actual IK/wrist/pole weights zero: "+label)
		check(not arm.override_active,"no wrist bone write: "+label)
	# SkeletonModifier evaluation is deferred; wait for its capture, without
	# advancing the motor or animation. Weight assertions above are immediate.
	await process_frame
	for arm in arm_ik.arms:
		for index in 3:
			check(arm.animation_chain[index].is_equal_approx(arm.solved_chain[index]),"source evaluated arm pose unchanged: "+label+"/"+arm.side+str(index))

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
	box(Vector3(199.38,1.1,0),Vector3(.12,2.2,80))
	for gate in ["idle","run","sprint","stand_roll","run_roll","sprint_roll","backstep","jump","fall","lock","turn"]:
		await reset_contact()
		for frame in 45: await roll_tick(Vector2(0,-1))
		check(arm_ik.environment_hand_contact_active and arm_ik.arms[0].weight>.5,"Walk contact prepared: "+gate)
		if gate!="turn":
			for frame in 20: await roll_tick()
			check(arm_ik.contact_state==arm_ik.ContactState.IDLE_HOLD,"Walk-acquired contact persists before action: "+gate)
		var acquisitions: int=arm_ik.contact_acquisitions
		if gate=="lock":
			dummy.position=Vector3(200,0,0)
			lock.toggle()
		if gate=="fall": body.position.y=3
		if gate in ["sprint","sprint_roll"]: body._run_time=body.sprint_buildup_duration+1
		if gate in ["run_roll","sprint_roll"]:
			await roll_tick(Vector2(0,-1),true)
			await assert_clean(gate+" preparation")
		var stick:=Vector2.ZERO if gate in ["idle","backstep"] else (Vector2(0,1) if gate=="turn" else Vector2(0,-1))
		var shifted: bool=gate in ["run","sprint","run_roll","sprint_roll"]
		var rolled: bool=gate in ["stand_roll","run_roll","sprint_roll","backstep"]
		await roll_tick(stick,shifted,gate=="jump",rolled)
		if rolled:
			var expected: String={"stand_roll":"DOD_STAND_TO_ROLL","run_roll":"DOD_RUN_TO_ROLL","sprint_roll":"DOD_SPRINT_TO_ROLL","backstep":"DPD_DODING_BACK"}[gate]
			check(String(dodge.clip)==expected,"correct source clip exercised: "+gate)
		if gate=="idle":
			check(arm_ik.environment_hand_contact_active and arm_ik.contact_state==arm_ik.ContactState.IDLE_HOLD,"Idle holds only prior Walk contact")
			check(not hands.can_acquire_environment_hand_contact() and hands.can_persist_environment_hand_contact(),"acquisition and persistence distinct")
			stick=Vector2(0,-1)
			shifted=true
			await roll_tick(stick,shifted)
		await assert_clean(gate+" first evaluated pose")
		var compared:=0
		var saw_land:=false
		for frame in 150:
			await roll_tick(stick,shifted)
			if not hands.can_use_environment_hand_ik() and hands.eligibility()!="IDLE":
				await assert_clean(gate+" frame "+str(frame))
				compared+=1
			if animation.current_state==&"Land": saw_land=true
			# Explicit disabled-vs-enabled-ineligible replay of the same evaluated
			# pose, without advancing AnimationTree or touching other modifiers.
			if frame==4 and not hands.can_use_environment_hand_ik():
				await process_frame
				var reference: Array=[]
				for arm in arm_ik.arms: reference.append(arm.solved_chain.duplicate())
				arm_ik.enabled=false
				arm_ik.skeleton.advance(DT)
				await process_frame
				for side in 2:
					for bone in 3: check(reference[side][bone].is_equal_approx(arm_ik.arms[side].solved_chain[bone]),"disabled baseline identical: "+gate)
				arm_ik.enabled=true
			if frame==5 and gate=="run":
				await roll_tick(Vector2(0,-1))
				check(arm_ik.contact_acquisitions==acquisitions and arm_ik.active_side==-1,"quick Walk return respects forced cooldown")
		print("ISOLATION ",gate," compared=",compared," saw_land=",saw_land)
		if gate=="fall": check(saw_land,"passive fall exercised Land pose")
	print("ENVIRONMENT_HAND_ISOLATION_V2: ","PASS" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)
