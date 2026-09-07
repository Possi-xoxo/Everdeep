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
	body.set_physics_process(false)
	animation.set_physics_process(false)
	cam.set_process(false)
	tree.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	box(Vector3(200,-.25,0),Vector3(80,.5,80))
	var m=body.traversal.mantle
	var hands=body.get_node("MantleHandIK")
	for moving in [false,true]:
		for height in [1.75,2.1,2.5]:
			await fixture(height)
			if moving and is_equal_approx(height,2.1):
				test_obstacle.rotation.y=deg_to_rad(15)
				test_obstacle.get_child(0).shape.size.x=2.0
			for tick in 90: await crouch_tick(false)
			body.velocity=Vector3(0,0,-2) if moving else Vector3.ZERO
			body.context_interaction.scan()
			print("HAND FIXTURE height=",height," moving=",moving," geometry=",detector.result.get("reject_reason")," preflight=",m.last_reject)
			check(body.context_interaction.activate_selected(),"height/hand fixture accepted")
			check(absf(m.actual_climb_height-(m.landing.y-m.alignment.y))<.001,"actual committed travel")
			check(m.trajectory(m.frame_progress(50)).distance_to(m.landing)<.001,"exact final destination")
			check(is_equal_approx(m.mantle_playback_speed,.88),"unchanged playback rate")
			var max_error:=0.0
			var max_length_error:=0.0
			var clamp_samples:=0
			var initial_grips: Array=[]
			var last_weights: Array=[0.0,0.0]
			var last_elbows: Array=[Vector3.ZERO,Vector3.ZERO]
			for tick in 260:
				await crouch_tick(false)
				if m.pose_owned() and body.traversal.phase==body.traversal.Phase.ACTIVE:
					check(body.position.distance_to(m.trajectory(m.progress))<.025,"collision-controlled retargeted path")
					if initial_grips.is_empty():
						for arm in hands.arms: initial_grips.append(arm.grip)
					for index in hands.arms.size():
						var arm: Dictionary=hands.arms[index]
						check(arm.grip.distance_to(initial_grips[index])<.0001,"grip does not slide")
						check(absf(arm.weight-last_weights[index])<.25,"smooth source-frame envelope")
						last_weights[index]=arm.weight
						max_length_error=maxf(max_length_error,arm.length_error)
						if m.current_frame()>=24 and m.current_frame()<=37:
							clamp_samples+=1
							max_error=maxf(max_error,arm.error)
							check(arm.valid and arm.weight>.999,"full bilateral clamp window")
							if last_elbows[index]!=Vector3.ZERO: check(arm.elbow_direction.dot(last_elbows[index])>0,"no clamp elbow flip")
							last_elbows[index]=arm.elbow_direction
						if m.current_frame()>=44: check(arm.weight==0,"hands released before landing")
					check(hands.arms[0].grip.distance_to(hands.arms[1].grip)>.45,"separate grip positions")
				if not m.running: break
			print("HANDS_HEIGHT moving=",moving," height=",height," clamp samples=",clamp_samples," max error=",max_error," chain error=",max_length_error)
			check(clamp_samples>0 and max_error<.015,"wrists remain on actual ledge within 1.5cm")
			check(max_length_error<.005,"no arm stretch")
			check(body.traversal.last_end_reason=="COMPLETED" and body.ground_support.has_ground_support,"retargeted climb lands")
			for arm in hands.arms: check(arm.solver.influence==0,"no hand authority after mantle")
	# Different heights produce different vertical paths without changing XZ.
	for frame in [17,25,37,50]:
		var low: Vector3=m.profile_position(m.frame_progress(frame),Vector3.ZERO,Vector3(0,1.765,-.65))
		var high: Vector3=m.profile_position(m.frame_progress(frame),Vector3.ZERO,Vector3(0,2.515,-.65))
		check(absf(high.y-low.y-.75*m.height_difference_weight(m.frame_progress(frame)))<.001,"phase-aware height delta")
		check(absf(low.z-high.z)<.001,"unchanged horizontal path")
	print("MANTLE_HANDS_HEIGHT_V2: ","PASS" if failures.is_empty() else str(failures))
	quit(0 if failures.is_empty() else 1)
