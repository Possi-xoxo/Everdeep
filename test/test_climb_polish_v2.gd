extends "res://test/test_mantle_v2.gd"
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
	var mantle=body.traversal.mantle
	var ik=body.get_node("FootIKController")
	body.set_physics_process(false)
	animation.set_physics_process(false)
	cam.set_process(false)
	tree.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	box(Vector3(200,-.25,0),Vector3(80,.5,80))
	for height in [1.75,2.0,2.4,2.5]:
		await fixture(height,1.3+height*.2)
		for frame in 90: await crouch_tick(false)
		body.position.z=10.25 # .90m from wall, beyond original .75m probe.
		await crouch_tick(false)
		detector.mantle_acquisition_distance=.75
		body.context_interaction.scan()
		check(not detector.result.valid,"outside legacy acquisition")
		detector.mantle_acquisition_distance=2.5
		body.context_interaction.scan()
		check(detector.result.valid,"extended prompt valid")
		check(body.context_interaction.activate_selected(),"extended activation")
		var contacts:=0
		var peak:=0.0
		var correction:=0.0
		var max_length_error:=0.0
		var penetration_before:=0.0
		var penetration_after:=0.0
		var previous: Vector3=body.position
		for frame in 240:
			var entry: bool=body.traversal.phase==body.traversal.Phase.ENTRY
			await crouch_tick(false)
			if entry: check(body.position.distance_to(previous)<.075,"swept gradual approach")
			previous=body.position
			if mantle.pose_owned() and body.traversal.phase==body.traversal.Phase.ACTIVE:
				check(body.position.distance_to(mantle.trajectory(mantle.progress))<.025,"IK does not change body trajectory")
				for leg in ik.legs:
					if leg.climb_contact.valid: contacts+=1
					peak=maxf(peak,leg.weight)
					correction=maxf(correction,leg.correction.length())
					max_length_error=maxf(max_length_error,leg.length_error)
					if leg.climb_contact.valid and leg.climb_contact.mode=="WALL" and leg.weight>.9:
						var toe_index: int=ik.skeleton.find_bone("mixamorig_"+leg.side+"ToeBase")
						var toe: Vector3=ik._world(toe_index).origin
						var solved_depth: float=minf((toe-mantle.wall_point).dot(mantle.wall_normal),(leg.solved-mantle.wall_point).dot(mantle.wall_normal))
						var original_depth: float=solved_depth-(leg.solved-leg.animated).dot(mantle.wall_normal)
						penetration_before+=maxf(0,-original_depth)
						penetration_after+=maxf(0,-solved_depth)
					check(leg.correction.length()<=ik.climb_foot_max_correction+.001,"bounded visual correction")
					check(leg.solved.is_finite(),"finite foot result")
					if mantle.current_frame()>46: check(leg.climb_contact.mode!="WALL","wall IK released; top prevention is allowed before landing")
			if not mantle.running: break
		print("CONTACT height=",height," valid samples=",contacts," peak=",peak," correction=",correction," length error=",max_length_error)
		check(contacts>0 and peak>.2 and correction>.01,"native wall contact actually used")
		check(max_length_error<.005,"native chain lengths preserved")
		print("WALL penetration sums before=",penetration_before," after=",penetration_after)
		# The penetration-only pass deliberately caps offsets at .15m rather
		# than the old .30m wall-placement target. Deep clipping stays partial.
		check(penetration_after<penetration_before,"wall penetration reduced within conservative safety cap")
		check(body.traversal.last_end_reason=="COMPLETED","extended climb lands")
		check(body.ground_support.has_ground_support,"footprint landing preserved")
	await fixture(2.6)
	for frame in 90: await crouch_tick(false)
	body.position.z=10.25
	body.context_interaction.scan()
	check(not detector.result.valid and not body.context_interaction.activate_selected(),"invalid high ledge rejected in extension")
	await ready_fixture()
	body.position.z=10.5
	body.context_interaction.scan()
	check(detector.result.valid and body.context_interaction.activate_selected(),"far prompt is executable")
	for frame in 260:
		await crouch_tick(false)
		if not mantle.running: break
	await ready_fixture()
	body.context_interaction.scan()
	var roof:=box(Vector3(200,3.15,8.3),Vector3(3,.3,2))
	await crouch_tick(false)
	check(not body.context_interaction.activate_selected(),"activation revalidates changed clearance")
	roof.queue_free()
	await ready_fixture()
	body.position.z=10.55
	var acquired:=false
	for frame in 40:
		await crouch_tick(false,Vector2(0,-1))
		body.context_interaction.scan()
		if detector.result.valid:
			check(detector.result.distance>.75,"walking prompt appears before old range")
			acquired=body.context_interaction.activate_selected()
			break
	check(acquired,"natural walking activation")
	for frame in 240:
		await crouch_tick(false)
		if not mantle.running: break
	check(body.traversal.last_end_reason=="COMPLETED","walking approach completes")
	print("CLIMB_POLISH_V2: ","PASS" if failures.is_empty() else "FAIL "+str(failures))
	quit(0 if failures.is_empty() else 1)
