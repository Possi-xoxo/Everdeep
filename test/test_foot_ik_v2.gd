extends "res://test/test_player_v2.gd"
var ik: Node
var feet: Node
var hips_before: Transform3D
var final_hips: Transform3D

func run() -> void:
	var lab=load("res://test/player_v2_lab.tscn").instantiate()
	root.add_child(lab)
	body=lab.get_node("PlayerV2")
	animation=body.get_node("AnimationController")
	tree=body.get_node("AnimationTree")
	ik=body.get_node("FootIKController")
	feet=body.get_node("FootGrounding")
	body.set_physics_process(false)
	animation.set_physics_process(false)
	tree.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	await settle(Vector3(0,0.05,20))
	check(ik.legs.size()==2,"two native leg solvers bound")
	ik.skeleton.skeleton_updated.connect(func(): final_hips=ik.skeleton.get_bone_global_pose(0))
	for scenario in [Vector3(0,0.001,20),Vector3(51.5,0.05,0),Vector3(57.5,0.1,0),Vector3(100,0.22,-25)]:
		body.position=scenario
		body.velocity=Vector3.ZERO
		body.animation_state.is_grounded=true
		body.animation_state.is_airborne=false
		body.animation_state.move_input_magnitude=0
		for frame in 60:
			tree.advance(0.0)
			await process_frame
		hips_before=ik.skeleton.get_bone_global_pose(0)
		var expected: Transform3D=hips_before
		expected.origin+=ik.skeleton.global_basis.inverse()*Vector3.UP*ik.pelvis.applied_offset
		check(expected.is_equal_approx(final_hips),"pelvis adds only non-accumulating vertical translation")
		for leg in ik.legs:
			var before: float=leg.animated.distance_to(leg.target.global_position)
			var after: float=leg.solved.distance_to(leg.target.global_position)
			print("IK_POSE ",scenario," ",leg.side," weight=",leg.weight," error=",before," -> ",after," solved=",leg.solved)
			check(leg.solver is TwoBoneIK3D,"uses native two-bone solver")
			check(after<=before+0.002,"native IK moves toward target")
			check(absf(leg.correction.y)<=0.201,"vertical target capped")
			check(Vector2(leg.correction.x,leg.correction.z).length()<=0.151,"horizontal target capped")
		check(body.position.is_equal_approx(scenario),"IK leaves body unchanged")
	# Unreachable lower surface and unsupported edge independently release.
	body.position=Vector3(13,3.1,-20)
	for frame in 60:
		tree.advance(0)
		await process_frame
	check(feet.left.valid!=feet.right.valid,"one-foot edge fixture")
	check(ik.legs[1].weight<0.001 and ik.legs[0].weight>0.7,"independent edge weights")
	await settle(Vector3(0,0.05,20))
	for frame in 60: await tick()
	var weight: float=ik.legs[0].weight
	await tick(Vector2.ZERO,false,true)
	check(ik.legs[0].weight<weight and ik.legs[0].weight>0,"jump blends out, no hard toggle")
	for frame in 35: await tick()
	check(ik.legs[0].weight<0.001 and ik.legs[1].weight<0.001,"airborne IK fades to zero")
	for frame in 100: await tick()
	check(ik.legs[0].weight>0.7 and ik.legs[1].weight>0.7,"land reacquires IK")
	for gait in 3:
		await settle(Vector3(0,0.05,20))
		body._run_time=4 if gait==2 else 0
		var swings:=0
		for frame in 90:
			await tick(Vector2(0,-1),gait>0)
			for leg in ik.legs:
				check(leg.solved.is_finite(),"finite solved gait pose")
				if leg.swing<0.1: swings+=1
		print("IK_GAIT ",gait," swing_releases=",swings)
		check(swings>0,"lifted swing feet not glued down")
	for gait in 3:
		for stair in 3:
			body.step_solver.cancel()
			await settle(Vector3(42+stair*10,0.05,-18))
			body.visual.rotation.y=0
			body._run_time=4 if gait==2 else 0
			for frame in 190:
				await tick(Vector2(0,-1),gait>0)
				for leg in ik.legs:
					check(leg.knee_stable,"stair knee stays on pole side")
					check(leg.length_error<0.002,"native IK preserves limb lengths")
				if body.position.z< -29: break
			check(body.position.z< -29,"IK does not block stair traversal")
		print("IK_STAIRS gait=",gait," all risers traversed")
	print("FOOT_IK_V2: ","PASS" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)
