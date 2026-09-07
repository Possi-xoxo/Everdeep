extends "res://test/test_mantle_v2.gd"
const Contact=preload("res://Characters/Player/V2/player_mantle_foot_contact_v2.gd")
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
	var ik=body.get_node("FootIKController")
	var m=body.traversal.mantle
	for moving in [false,true]:
		for height in [1.75,2.1,2.5]:
			await fixture(height)
			if moving and is_equal_approx(height,2.1): test_obstacle.rotation.y=deg_to_rad(15)
			for tick in 90: await crouch_tick(false)
			body.velocity=Vector3(0,0,-2) if moving else Vector3.ZERO
			body.context_interaction.scan()
			check(body.context_interaction.activate_selected(),"penetration fixture accepted")
			var wall_count:=0
			var top_count:=0
			var limited_count:=0
			var improvement:=Vector2.ZERO
			for tick in 260:
				await crouch_tick(false)
				if m.pose_owned() and body.traversal.phase==body.traversal.Phase.ACTIVE:
					check(body.position.distance_to(m.trajectory(m.progress))<.025,"IK cannot alter controller trajectory")
					for leg in ik.legs:
						var contact: Dictionary=leg.climb_contact
						check(leg.length_error<.005 and leg.solved.is_finite(),"no stretch or invalid native solve")
						check(leg.knee_stable,"authored knee bend remains on pole side")
						check(leg.correction.length()<=.151,"final target respects conservative cap")
						if m.current_frame()>28 and m.current_frame()<30:
							check(leg.weight<.01 and leg.correction.length()<.005,"wall offset smoothly releases when authored feet clear")
						if contact.valid:
							check(contact.penetration>0,"never pin a non-penetrating foot")
							var offset: Vector3=contact.target-leg.animated
							check(offset.length()<=.151 and offset.dot(contact.normal)>0,"outward/upward bounded correction")
							check(offset.cross(contact.normal).length()<.001,"normal-only target, no lateral pinning")
							if contact.limited: limited_count+=1
							if contact.mode=="WALL":
								wall_count+=1
								check(m.current_frame()>=10 and m.current_frame()<40,"wall phase only")
								improvement.x+=(leg.solved-leg.animated).dot(contact.normal)
							else:
								top_count+=1
								check(m.current_frame()>40,"top phase relative to hoist")
								improvement.y+=(leg.solved-leg.animated).dot(contact.normal)
						# Direct geometry negatives: safe samples and empty space
						# beside the same ledge must never acquire top-plane targets.
						var pose:=Transform3D(leg.animated_basis,leg.animated)
						var above: Dictionary=Contact._surface(ik,leg,pose,[m.top+Vector3.UP*.01],m.top,Vector3.UP,.02,.15,1,"LEDGE_TOP",25)
						check(not above.valid and above.weight==0,"above surface remains authored")
						var wall_clear: Dictionary=Contact._surface(ik,leg,pose,[m.wall_point+m.wall_normal*.01],m.wall_point,m.wall_normal,.02,.15,1,"WALL",25)
						check(not wall_clear.valid and wall_clear.weight==0,"clear wall sample never pulled toward wall")
						var outside: Dictionary=Contact._surface(ik,leg,pose,[m.top+Vector3(10,-.03,0)],m.top,Vector3.UP,.02,.15,1,"LEDGE_TOP",25)
						check(not outside.valid,"finite top footprint, not infinite plane")
				if not m.running: break
			print("PENETRATION moving=",moving," height=",height," wall=",wall_count," top=",top_count," limited=",limited_count," projected improvement=",improvement)
			check(wall_count>0 and top_count>0,"both surfaces actually corrected")
			check(improvement.x>0 and improvement.y>0,"native IK reduces both penetrations")
			check(limited_count>0,"deep clipping stays capped")
			check(body.traversal.last_end_reason=="COMPLETED" and body.ground_support.has_ground_support,"unchanged supported landing")
	print("CLIMB_PENETRATION_V2: ","PASS" if failures.is_empty() else str(failures))
	quit(0 if failures.is_empty() else 1)
