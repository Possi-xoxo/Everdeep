extends "res://test/test_mantle_geometry_v2.gd"
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
	body.set_physics_process(false)
	animation.set_physics_process(false)
	cam.set_process(false)
	tree.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	box(Vector3(200,-.25,0),Vector3(80,.5,80))
	for height in [1.5,1.65,1.75,2.0,2.1,2.2,2.25,2.4,2.5,2.6]:
		await fixture(height)
		# Reset teleports from the previous top: allow its landing state to finish.
		for frame in 90: await crouch_tick(false)
		body.context_interaction.scan()
		print("HEIGHT ",height," valid=",detector.result.valid," reject=",detector.result.reject_reason)
		var expected: bool=height>=1.75 and height<=detector.mantle_max_height
		check(detector.result.valid==expected,"new height range "+str(height))
		if not expected: continue
		var accepted: bool=body.context_interaction.activate_selected()
		print("BEGIN ",height," accepted=",accepted," reject=",mantle.last_reject)
		check(accepted,"real mantle accepted")
		if not accepted: continue
		var saw_action:=false
		var saw_arc_motion:=false
		var previous_camera: Vector3=cam.global_position
		var yaw_before: float=cam.yaw.rotation.y
		for frame in 260:
			await crouch_tick(false,Vector2(0,-1))
			check(cam.global_position.distance_to(previous_camera)<.20,"camera has no mantle snap")
			previous_camera=cam.global_position
			check(is_equal_approx(cam.yaw.rotation.y,yaw_before),"mantle preserves camera yaw")
			if mantle.current_frame()>33 and mantle.current_frame()<39:
				var tangent: Vector3=mantle.trajectory(mantle.progress+.001)-mantle.trajectory(mantle.progress)
				if tangent.y>0 and Vector2(tangent.x,tangent.z).length()>0: saw_arc_motion=true
			if animation.current_state==&"Mantle": saw_action=true
			if not body.traversal.is_traversing: break
		print("END ",height," reason=",body.traversal.last_end_reason," pos=",body.position," progress=",mantle.progress)
		check(saw_action,"TRV plays")
		check(saw_arc_motion,"hoist midpoint moves up and forward together")
		check(body.traversal.last_end_reason=="COMPLETED","mantle completed")
		check(absf(body.position.y-height)<.05 and body.is_on_floor(),"standing on top")
		check(animation.current_state==&"Locomotion" and animation.gait_blend>.9,"moving exit no idle bridge")
		for frame in 120: await crouch_tick(false)
		check(not cam.mantle_camera_active,"camera smoothly returns to normal")
	for reason in [body.traversal.Interrupt.DODGE,body.traversal.Interrupt.JUMP,body.traversal.Interrupt.DAMAGE]:
		await ready_fixture()
		check(body.context_interaction.activate_selected(),"interrupt setup")
		check(body.traversal.request_traversal_interrupt(reason),"ENTRY interrupt")
		check(not mantle.running and not body.traversal.is_traversing,"interrupt cleanup")
	await ready_fixture()
	check(body.context_interaction.activate_selected(),"source loss setup")
	for frame in 20: await crouch_tick(false)
	check(not body.traversal.request_traversal_interrupt(body.traversal.Interrupt.DODGE),"ACTIVE committed")
	check(not body.context_interaction.activate_selected(),"E spam blocked")
	test_obstacle.queue_free()
	await crouch_tick(false)
	check(not mantle.running and body.traversal.last_end_reason=="SOURCE_LOST_OR_MOVED","source loss releases ownership")
	await ready_fixture()
	var roof:=box(Vector3(200,3.15,8.3),Vector3(3,.3,2))
	await crouch_tick(false)
	body.context_interaction.scan()
	check(not detector.result.valid,"low ceiling rejects")
	roof.queue_free()
	await ready_fixture(.2)
	check(not detector.result.valid,"thin top rejects")
	await ready_fixture()
	body.position.x=201.48
	body.context_interaction.scan()
	check(not detector.result.valid,"corner rejects")
	for speed in [.85,1.15]:
		await ready_fixture()
		for frame in 65: await crouch_tick(true)
		dummy.position=Vector3(200,0,0)
		lock.toggle()
		check(lock.is_locked(),"lock setup")
		mantle.mantle_playback_speed=speed
		body.context_interaction.scan()
		check(body.context_interaction.activate_selected(),"crouched mantle")
		for frame in 320:
			await crouch_tick(false)
			if mantle.running and body.traversal.phase==body.traversal.Phase.ACTIVE:
				check(body.position.distance_to(mantle.trajectory(mantle.progress))<.025,"animation synchronized position")
				if animation._playback.get_current_play_position()>.3:
					var skeleton: Skeleton3D=animation.rig.get_node("Base Armature and Mesh/Skeleton3D")
					var clip: Animation=animation.player.get_animation(mantle.ACTION)
					var source_time: float=float(mantle.playback_start_frame)/30.0+animation._playback.get_current_play_position()*speed
					var expected_pose: Vector3=clip.position_track_interpolate(mantle.source_track,source_time)
					check(skeleton.get_bone_pose_position(skeleton.find_bone("mixamorig_Hips")).distance_to(expected_pose)<.2,"evaluated pose follows source timestamp")
			if not mantle.running: break
		check(body.traversal.last_end_reason=="COMPLETED" and not crouch.requested and not lock.is_locked(),"standing free exit at playback speed "+str(speed))
	for angle in [0.0,45.0,-60.0,69.0,-70.0,90.0,180.0]:
		await ready_fixture()
		body.visual.rotation.y=deg_to_rad(angle)
		body.context_interaction.scan()
		var expected: bool=absf(angle)<=70
		check(is_instance_valid(body.context_interaction.selected)==expected,"cone "+str(angle))
		if not expected: continue
		check(body.context_interaction.activate_selected(),"diagonal activation")
		check(mantle.playback_start_frame==10,"idle starts at 10")
		for frame in 250:
			await crouch_tick(false)
			if not mantle.running: break
		check(body.traversal.last_end_reason=="COMPLETED","diagonal completes "+str(angle))
	await ready_fixture()
	body.velocity=Vector3(0,0,-1.0)
	check(body.context_interaction.activate_selected(),"moving activation")
	check(mantle.playback_start_frame==1,"moving starts at 1")
	for frame in 250:
		await crouch_tick(false,Vector2(0,-1),true)
		if mantle.running and body.traversal.phase==body.traversal.Phase.ACTIVE and mantle.current_frame()<=11:
			check(absf(body.position.y-mantle.start.y)<.002,"approach has no early lift")
		if not mantle.running: break
	check(body.traversal.last_end_reason=="COMPLETED" and mantle.current_frame()<52,"frame 51 handoff")
	check(body.velocity.length()>.5,"held movement resumes during exit")
	for height in [1.75,2.0,2.2]:
		await fixture(height,6.0)
		for frame in 90: await crouch_tick(false)
		body.context_interaction.scan()
		check(body.context_interaction.activate_selected(),"edge idle setup")
		check(is_equal_approx(mantle.safe_edge_setback,.15),"support footprint permits .15m setback")
		check(body.ground_support.evaluate(mantle.landing,Basis.IDENTITY,test_obstacle).supported,"edge landing support independent of platform depth")
		var exit_position:=Vector3.ZERO
		var saw_soft_blend:=false
		for frame in 260:
			await crouch_tick(false)
			if body.traversal.phase==body.traversal.Phase.EXIT:
				if exit_position==Vector3.ZERO: exit_position=body.position
				check(Vector2(body.position.x-exit_position.x,body.position.z-exit_position.z).length()<.002,"no scripted exit translation")
				if mantle.exit_elapsed>.12 and animation._playback.get_fading_from_node()==&"Mantle": saw_soft_blend=true
			if not mantle.running: break
		check(saw_soft_blend,"mantle weight still fading after old .12s exit")
		for frame in 120: await crouch_tick(false)
		check(body.is_on_floor() and absf(body.position.y-height)<.02,"idle edge remains supported")
		check(Vector2(body.position.x-exit_position.x,body.position.z-exit_position.z).length()<.002,"idle remains at endpoint")
		var skeleton: Skeleton3D=animation.rig.get_node("Base Armature and Mesh/Skeleton3D")
		for bone in ["mixamorig_LeftFoot","mixamorig_RightFoot"]:
			var point: Vector3=skeleton.global_transform*skeleton.get_bone_global_pose(skeleton.find_bone(bone)).origin
			var query:=PhysicsRayQueryParameters3D.create(point+Vector3.UP*.3,point-Vector3.UP*.5,body.collision_mask,[body.get_rid()])
			var hit=body.get_world_3d().direct_space_state.intersect_ray(query)
			check(not hit.is_empty() and hit.collider==test_obstacle,"settled foot remains above ledge support")
	print("MANTLE_V2: ","PASS" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)

func ready_fixture(depth: float=2.0) -> void:
	await fixture(2.1,depth)
	for frame in 90: await crouch_tick(false)
	body.context_interaction.scan()
