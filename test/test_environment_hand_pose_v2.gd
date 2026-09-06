extends "res://test/test_environment_hand_contact_v2.gd"

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
		await reset_contact()
		var wall:=box(Vector3(200+side*.62,1.1,0),Vector3(.12,2.2,50))
		var reach_frames:=0
		var max_palm_error:=0.0
		var max_finger_error:=0.0
		var last_alpha:=0.0
		var prep_seen:=false
		var approach_seen:=false
		var captured_start:=Transform3D.IDENTITY
		for frame in 110:
			await roll_tick(Vector2(0,-1))
			if arm_ik.active_side<0: continue
			var arm=arm_ik.arms[arm_ik.active_side]
			if arm_ik.contact_state==arm_ik.ContactState.REACHING:
				reach_frames+=1
				if reach_frames==1:
					captured_start=arm_ik.reach_start_local_transform
					check(arm.prepared_target.distance_to(arm.animated)<.0001,"first prepared target is actual animated hand")
				check(arm_ik.reach_start_local_transform.is_equal_approx(captured_start),"start transform captured once, not resampled")
				prep_seen=prep_seen or arm_ik.reach_stage()=="REACHING_PREP"
				approach_seen=approach_seen or arm_ik.reach_stage()=="REACHING_CONTACT"
				var progress: float=arm_ik.reach_elapsed/arm_ik.hand_reach_total_duration
				if progress<arm_ik.hand_reach_prep_fraction: check(arm.weight<=.351,"prep keeps animation dominant")
				if progress<arm_ik.hand_rotation_start_fraction: check(arm.rotation_weight==0,"rotation delayed until configured start")
				check(arm_ik.reach_alpha>=last_alpha,"reach alpha monotonic")
				check(arm.weight<=arm_ik.environment_hand_contact_weight*arm_ik.reach_alpha+.0001,"position authority eases with reach")
				last_alpha=arm_ik.reach_alpha
			if arm_ik.contact_state==arm_ik.ContactState.CONTACT:
				max_palm_error=maxf(max_palm_error,rad_to_deg(arm.contact_basis.z.angle_to(-arm_ik.contact_surface_normal)))
				max_finger_error=maxf(max_finger_error,rad_to_deg(arm.contact_basis.y.angle_to(Vector3.UP.slide(arm_ik.contact_surface_normal).normalized())))
				check((arm.palm-arm_ik.contact_hit_position).dot(arm_ik.contact_surface_normal)>.045,"established palm outside wall")
		check(reach_frames>=32 and reach_frames<=35,"reach lasts approximately .55 seconds")
		check(prep_seen and approach_seen,"both staged reach phases evaluated")
		check(max_palm_error<22 and max_finger_error<22,"palm faces wall and fingers point upward")
		var count: int=arm_ik.contact_acquisitions
		var tangent: Vector3=arm_ik.contact_wall_tangent
		for frame in 60: await roll_tick()
		check(arm_ik.contact_state==arm_ik.ContactState.IDLE_HOLD,"Idle holds existing contact")
		check(tangent.dot(arm_ik.contact_wall_tangent)>.999,"Idle tangent stable")
		for frame in 30: await roll_tick(Vector2(0,-1))
		check(arm_ik.contact_state==arm_ik.ContactState.CONTACT,"ordinary Walk retains contact")
		check(tangent.dot(arm_ik.contact_wall_tangent)>.999,"straight Walk preserves tangent")
		for frame in 20: await roll_tick(Vector2(0,-1))
		check(arm_ik.contact_acquisitions==count and arm_ik.reach_alpha==1,"continued Walk has no new reach")
		var old_velocity: Vector3=body.velocity
		body.velocity=-old_velocity
		arm_ik.update_tangent()
		check(tangent.dot(arm_ik.contact_wall_tangent)>.999,"reversed travel tangent cannot spin hand 180 degrees")
		body.velocity=old_velocity
		var desired: Basis=arm_ik.reach_target_transform.basis
		check(absf(desired.determinant()-1)<.0001 and absf(desired.x.dot(desired.y))<.0001,"contact frame orthonormal and right handed")
		var tweak:=Vector3(5,0,0)
		if side<0: arm_ik.left_hand_contact_rotation_offset=tweak
		else: arm_ik.right_hand_contact_rotation_offset=tweak
		var corrected: Basis=arm_ik.palm_basis(Basis.IDENTITY,arm_ik.contact_surface_normal)
		check(corrected.is_equal_approx(desired*Basis.from_euler(tweak*PI/180)),"per-hand correction applied after geometry in degrees")
		arm_ik.left_hand_contact_rotation_offset=Vector3.ZERO
		arm_ik.right_hand_contact_rotation_offset=Vector3.ZERO
		# Genuine release with a valid nearby wall tests immediate return, rather
		# than hiding reacquisition behind invalid candidates.
		arm_ik.release_contact("TEST_WALK_AWAY")
		var initial_weight: float=arm_ik.arms[arm_ik.active_side].weight
		var release_basis: Basis=arm_ik.arms[arm_ik.active_side].contact_basis
		var release_target: Vector3=arm_ik.arms[arm_ik.active_side].target.global_position-body.global_position
		await roll_tick(Vector2(0,-1))
		var releasing=arm_ik.arms[arm_ik.active_side]
		check(rad_to_deg(release_basis.get_rotation_quaternion().angle_to(releasing.contact_basis.get_rotation_quaternion()))<6,"release orientation has no first-frame snap")
		check(release_target.distance_to(releasing.target.global_position-body.global_position)<.035,"release target has no first-frame snap")
		for frame in 5: await roll_tick(Vector2(0,-1))
		check(arm_ik.contact_state==arm_ik.ContactState.RELEASING,"release remains active halfway")
		check(arm_ik.arms[arm_ik.active_side].weight>0 and arm_ik.arms[arm_ik.active_side].weight<initial_weight,"release fades instead of snapping")
		for frame in 8: await roll_tick(Vector2(0,-1))
		check(arm_ik.contact_state==arm_ik.ContactState.COOLDOWN,"release completes after .22 seconds")
		for frame in 80: await roll_tick(Vector2(0,-1))
		check(arm_ik.contact_acquisitions==count and arm_ik.active_side==-1,"valid wall cannot bypass cooldown")
		for frame in 30: await roll_tick(Vector2(0,-1))
		check(arm_ik.contact_acquisitions==count+1,"cooldown expiry allows acquisition")
		for frame in 35: await roll_tick(Vector2(0,-1))
		var backward_tangent: Vector3=arm_ik.contact_wall_tangent
		for frame in 20:
			await roll_tick(Vector2(0,1))
			if arm_ik.environment_hand_contact_active:
				check(backward_tangent.dot(arm_ik.contact_wall_tangent)>0,"backward input cannot invert held tangent")
		print("BACKWARD side=",side," state=",arm_ik.reach_stage()," release=",arm_ik.contact_release_reason)
		print("POSE side=",side," reach_frames=",reach_frames," palm_error=",max_palm_error," finger_error=",max_finger_error)
		wall.free()
	# Cancel early reach through all action gates as well as established contact.
	for gate in ["run","lock","dodge","jump"]:
		await reset_contact()
		var wall:=box(Vector3(199.38,1.1,0),Vector3(.12,2.2,30))
		for frame in 8: await roll_tick(Vector2(0,-1))
		check(arm_ik.contact_state==arm_ik.ContactState.REACHING,"early reach prepared: "+gate)
		if gate=="lock":
			dummy.position=Vector3(200,0,0)
			lock.toggle()
		await roll_tick(Vector2(0,-1),gate=="run",gate=="jump",gate=="dodge")
		check(not arm_ik.environment_hand_contact_active,"action cancels reach immediately: "+gate)
		for frame in 15: await roll_tick(Vector2(0,-1),gate=="run")
		check(arm_ik.contact_state==arm_ik.ContactState.COOLDOWN,"cancelled reach starts cooldown: "+gate)
		wall.free()
	print("ENVIRONMENT_HAND_POSE_V2: ","PASS" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)
