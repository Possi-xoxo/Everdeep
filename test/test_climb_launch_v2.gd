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
	check(ik.climb_foot_blend_in_start==10 and ik.climb_foot_blend_in_end==15,"penetration-only wall window defaults")
	for moving in [false,true]:
		for distance in [.55,2.45]:
			await ready_fixture()
			body.position.z=9.35+distance
			body.velocity=Vector3(0,0,-2) if moving else Vector3.ZERO
			body.context_interaction.scan()
			check(body.context_interaction.activate_selected(),"launch accepted moving=%s distance=%s" % [moving,distance])
			var expected: float=.75 if moving else .65
			check(is_equal_approx(mantle.selected_launch_distance,expected),"separate launch selection")
			var saw_launch:=false
			var saw_contact:=false
			for tick in 300:
				var entry: bool=body.traversal.phase==body.traversal.Phase.ENTRY
				await crouch_tick(false)
				if mantle.running and body.traversal.phase==body.traversal.Phase.ACTIVE:
					var wall_distance: float=(body.position-mantle.wall_contact).dot(-mantle.facing)+mantle.wall_contact_distance
					if entry:
						saw_launch=true
						check(absf(wall_distance-expected)<.005,"clip starts at launch, not contact")
					var frame: float=mantle.current_frame()
					if frame<ik.climb_foot_blend_in_start:
						for leg in ik.legs: check(leg.climb_contact.weight==0 and not leg.climb_contact.valid,"no wall foot IK during launch (ground influence may still fade out)")
					if frame>=17 and frame<25:
						saw_contact=true
						check(absf(wall_distance-.50)<.005,"contact reached by source frame 17")
					if frame>=25:
						var old_path: Vector3=mantle.profile_position(mantle.progress,mantle.wall_contact,mantle.landing)
						check(body.position.distance_to(old_path)<.025,"original hoist trajectory preserved")
				if not mantle.running: break
			check(saw_launch and saw_contact,"observed both launch and contact")
			check(body.traversal.last_end_reason=="COMPLETED","launch completes at unchanged landing")
			# Source-frame sampling also checks smooth, monotonic gap closure.
			var previous: float=expected
			for i in 101:
				var frame: float=lerpf(mantle.playback_start_frame,17,float(i)/100)
				var point: Vector3=mantle.trajectory(mantle.frame_progress(frame))
				var wall_distance: float=(point-mantle.wall_contact).dot(-mantle.facing)+.50
				check(wall_distance<=previous+.00001 and wall_distance>=.49999,"monotonic bounded launch interpolation")
				check(previous-wall_distance<.006,"no contact snap")
				previous=wall_distance
	print("CLIMB_LAUNCH_V2: ","PASS" if failures.is_empty() else str(failures))
	quit(0 if failures.is_empty() else 1)
