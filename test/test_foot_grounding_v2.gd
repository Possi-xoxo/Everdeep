extends "res://test/test_player_v2.gd"
var feet: Node

func run() -> void:
	var lab = load("res://test/player_v2_lab.tscn").instantiate()
	root.add_child(lab)
	body=lab.get_node("PlayerV2")
	animation=body.get_node("AnimationController")
	tree=body.get_node("AnimationTree")
	feet=body.get_node("FootGrounding")
	body.set_physics_process(false)
	animation.set_physics_process(false)
	tree.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	await settle(Vector3(0,0.05,20))
	check(feet.left.bone_index==62 and feet.right.bone_index==57,"verified foot indices")
	for frame in 60:
		await tick()
		check(feet.left.valid and feet.right.valid,"idle flat targets valid")
		check(absf(feet.left.raw_ground_position.y)<0.002 and absf(feet.right.raw_ground_position.y)<0.002,"flat heights stable")
		check(feet.left.ground_normal.dot(Vector3.UP)>0.999,"flat normal points up")
	print("FEET_FLAT ankle_Y=",feet.left.bone_position.y," estimated_sole_gap=",feet.left.distance)
	# Isolate sensing at an edge without forcing a capsule to balance there.
	# Only the test fixture places the whole player; no bones are edited.
	body.position=Vector3(51.5,0.20,0)
	feet.sample_pose(DT)
	print("FEET_CURB L=",feet.left.raw_ground_position," R=",feet.right.raw_ground_position," valid=",feet.left.valid,"/",feet.right.valid)
	check(feet.left.valid and feet.right.valid and absf(absf(feet.foot_height_delta)-0.15)<0.002,"independent 15cm split-height targets")
	body.position=Vector3(100,0.25,-25)
	feet.sample_pose(DT)
	check(feet.left.valid and feet.right.valid,"ramp hits valid")
	check(feet.left.raw_ground_normal.y>0.99 and absf(feet.left.raw_ground_normal.z)>0.02,"ramp normal reflects slope")
	body.position=Vector3(13,3.1,-20)
	feet.sample_pose(DT)
	print("FEET_EDGE valid=",feet.left.valid,"/",feet.right.valid)
	check(feet.left.valid!=feet.right.valid,"unsupported platform foot invalidates immediately")
	body.position=Vector3(120,0.35,-24)
	feet.sample_pose(DT)
	print("FEET_STEEP ",feet.left.reason,"/",feet.right.reason)
	check(feet.left.hit and feet.right.hit and not feet.left.valid and not feet.right.valid,"55 degree surface rejected")
	# Observer cannot change any gameplay state or any bone pose.
	var transform := body.global_transform
	var velocity := body.velocity
	var poses: Array[Transform3D]=[]
	for i in feet.skeleton.get_bone_count(): poses.append(feet.skeleton.get_bone_pose(i))
	feet.foot_grounding_debug=true
	feet.sample_pose(DT)
	check(body.global_transform==transform and body.velocity==velocity,"sensor cannot move motor")
	for i in poses.size(): check(poses[i]==feet.skeleton.get_bone_pose(i),"sensor does not write bones")
	feet.foot_grounding_debug=false
	for gait in 3:
		await settle(Vector3(0,0.05,20))
		body.visual.rotation.y=0
		body._run_time=4 if gait==2 else 0
		var valid_samples := 0
		for frame in 60:
			await tick(Vector2(0,-1),gait>0)
			for data in [feet.left,feet.right]:
				var actual: Vector3=feet.skeleton.global_transform*feet.skeleton.get_bone_global_pose(data.bone_index).origin
				check(actual.distance_to(data.bone_position)<0.0001,"sensor reads current evaluated pose")
				if data.valid:
					valid_samples+=1
					check(Vector2(data.raw_ground_position.x-data.smoothed_ground_position.x,data.raw_ground_position.z-data.smoothed_ground_position.z).length()<0.001,"no horizontal target lag")
		print("FEET_GAIT ",gait," valid_samples=",valid_samples,"/120")
		check(valid_samples>60,"moving probes regularly acquire ground")
	for index in [1,2,3,5]:
		body.step_solver.cancel()
		await settle(Vector3(38+index*6,0.05,7))
		body.visual.rotation.y=0
		var upper_hits:=0
		for frame in 85:
			await tick(Vector2(0,-1),false)
			if feet.left.valid and feet.left.raw_ground_position.y>0.04: upper_hits+=1
		check(upper_hits>0,"curb upper surface sensed")
	for i in 3:
		body.step_solver.cancel()
		await settle(Vector3(42+i*10,0.05,-18))
		body.visual.rotation.y=0
		var upper_hits:=0
		for frame in 165:
			await tick(Vector2(0,-1),true)
			if feet.left.valid and feet.left.raw_ground_position.y>0.1: upper_hits+=1
		check(upper_hits>0,"stair targets reacquire upper treads")
		print("FEET_STAIRS riser=",0.1+i*0.05," upper_hits=",upper_hits)
	body.step_solver.cancel()
	await settle(Vector3(105,0.05,5))
	body.visual.rotation.y=0
	var diagonal_hits:=0
	for frame in 100:
		await tick(Vector2(0,-1),false)
		if feet.left.valid and feet.left.raw_ground_position.y>0.1: diagonal_hits+=1
	check(diagonal_hits>0,"rotated diagonal curb sensed")
	await settle(Vector3(0,0.05,20))
	await tick(Vector2.ZERO,false,true)
	check(not feet.left.valid and not feet.right.valid,"jump invalidates immediately")
	for frame in 90:
		await tick()
		if body.animation_state.is_airborne: check(not feet.left.valid and not feet.right.valid,"airborne targets remain invalid")
	check(feet.left.valid and feet.right.valid,"landing reacquires targets")
	print("FOOT_GROUNDING_V2: ","PASS" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)
