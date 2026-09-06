extends "res://test/test_crouch_v2.gd"

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
	ik=body.get_node("FootIKController")
	body.set_physics_process(false)
	animation.set_physics_process(false)
	cam.set_process(false)
	tree.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	box(Vector3(200,-.25,0),Vector3(80,.5,80))
	await reset_at(Vector3(200,.1,10))
	for frame in 20: await crouch_tick(true)
	check(animation.current_state==&"CrouchEnter","CRC entry is not skipped")
	for frame in 30: await crouch_tick(true)
	dummy.position=Vector3(200,0,2)
	lock.toggle()
	check(lock.is_locked() and crouch.active(),"acquire lock without stand")
	var space=tree.tree_root.get_node("CrouchLocked")
	var locomotion_states=[&"CrouchIdle",&"CrouchWalk",&"CrouchRun",&"CrouchLocked",&"CrouchLockedRun"]
	for index in tree.tree_root.get_transition_count():
		if tree.tree_root.get_transition_from(index) in locomotion_states and tree.tree_root.get_transition_to(index) in locomotion_states:
			check(is_equal_approx(tree.tree_root.get_transition(index).xfade_time,crouch.crouch_locomotion_blend_time),"crouch locomotion crossfade duration")
	crouch.direction_blend=Vector2.ZERO
	await crouch_tick(true,Vector2(0,-1))
	check(crouch.direction_blend.length()<=DT/crouch.crouch_idle_to_move_blend+.0001,"idle departure pose is rate limited")
	for item in [["Forward",Vector2(0,-1),"BOW_STANDING_WALK_FORWARD"],["Left",Vector2(-1,0),"BOW_STANDING_WALK_LEFT"],["Right",Vector2(1,0),"BOW_STANDING_WALK_RIGHT"],["Back",Vector2(0,1),"BOW_STANDING_WALK_BACK"]]:
		var slot: int={"Forward":1,"Left":2,"Right":3,"Back":4}[item[0]]
		check(space.get_blend_point_node(slot).animation==item[2],"exact directional clip "+item[0])
		for frame in 70:
			await crouch_tick(true,item[1],false,true)
			check(lock.is_locked() and crouch.active(),"locked crouch retained")
			check(body.animation_state.gait==0 and body._run_time==0,"locked crouch suppresses Shift")
			check(not body.animation_state.jump_started,"locked crouch suppresses Jump")
			for leg in ik.legs: check(leg.solved.is_finite() and leg.length_error<.002,"directional IK non-stretching")
		check(crouch.direction_blend.distance_to(Vector2(item[1].x,-item[1].y))<.01,"direction converges "+item[0])
		check((-body.visual.global_basis.z).dot(lock.direction())>.95,"face target during "+item[0])
		check(absf(body.animation_state.horizontal_speed-body.walk_speed)<.02,"Walk speed in all directions")
	var before_stop: Vector2=crouch.direction_blend
	await crouch_tick(true)
	check(crouch.direction_blend.distance_to(before_stop)<=DT/crouch.crouch_locomotion_blend_time+.0001,"idle arrival pose is rate limited")
	for item in [[Vector2(0,-1),1,"BOW_STANDING_RUN_FORWARD"],[Vector2(-1,0),2,"BOW_STANDING_RUN_LEFT"],[Vector2(1,0),3,"BOW_STANDING_RUN_RIGHT"],[Vector2(0,1),4,"BOW_STANDING_RUN_BACK"]]:
		for frame in 60: await crouch_tick(true,item[0],true)
		check(animation.current_state==&"CrouchLockedRun" and crouch.running,"Shift selects crouch Run")
		check(tree.tree_root.get_node("CrouchLockedRun").get_blend_point_node(item[1]).animation==item[2],"correct running direction")
		check(body._run_time==0 and body.animation_state.gait!=2,"crouch Run never builds Sprint")
		check(absf(body.animation_state.horizontal_speed-body.run_start_speed)<.02,"crouch Run inherits starting Run speed")
	for frame in 60: await crouch_tick(true,Vector2(0,-1),true)
	await crouch_tick(true)
	check(animation.current_state==&"CrouchLockedRun","Run release holds movement during grace")
	for frame in 70: await crouch_tick(true)
	check(animation.current_state==&"CrouchLocked","true stop returns directly to locked idle")
	await crouch_tick(true,Vector2(0,-1),true,false,true)
	check(dodge.is_dodging and dodge.clip==dodge.STAND,"crouch Run still uses crouch walk roll")
	for frame in 160: await crouch_tick(true)
	check(not body.get_node("EnvironmentalHandInteraction").can_use_environment_hand_ik(),"crouch hands disabled")
	# Runtime copy is in-place; imported resource is not replaced.
	var source=load("res://Characters/Player/Models/Blender Master Rig.glb").instantiate()
	var raw=source.get_node("AnimationPlayer").get_animation("BOW_STANDING_WALK_RIGHT")
	var runtime=animation.player.get_animation("BOW_STANDING_WALK_RIGHT")
	check(raw!=runtime,"runtime animation is a separate resource")
	for t in raw.get_track_count():
		if raw.track_get_type(t)!=Animation.TYPE_POSITION_3D or not str(raw.track_get_path(t)).ends_with(":mixamorig_Hips"): continue
		var span: Vector3=raw.track_get_key_value(t,raw.track_get_key_count(t)-1)-raw.track_get_key_value(t,0)
		check(span.is_finite(),"imported BOW source readable")
		var first: Vector3=runtime.track_get_key_value(t,0)
		for k in runtime.track_get_key_count(t):
			var v: Vector3=runtime.track_get_key_value(t,k)
			check(is_equal_approx(v.x,first.x) and is_equal_approx(v.y,first.y),"runtime horizontal travel canceled")
	source.free()
	lock.toggle()
	check(not lock.is_locked() and crouch.active(),"unlock remains crouched")
	for frame in 60: await crouch_tick(true,Vector2(0,-1),true)
	check(animation.current_state==&"CrouchRun","Free Shift uses BOW forward Run")
	await crouch_tick(true)
	check(animation.current_state==&"CrouchRun","Free Run remains moving during grace")
	for frame in 60: await crouch_tick(true,Vector2(1,0))
	check(animation.current_state==&"CrouchWalk" and body.walk_direction_smoothing_active,"Free crouch uses sneak and Walk turning")
	# Slope fixture, using the unchanged foot system.
	for frame in 230: await crouch_tick(false)
	var ramp=box(Vector3(230,12,0),Vector3(24,.4,40))
	ramp.rotation.x=-deg_to_rad(20.0)
	await reset_at(Vector3(230,12+tan(deg_to_rad(20.0))*5+.2/cos(deg_to_rad(20.0))+.5,5))
	for frame in 270: await crouch_tick(true)
	for frame in 150:
		await crouch_tick(true,Vector2(0,-1))
		for leg in ik.legs:
			check(leg.solved.is_finite() and leg.length_error<.002 and leg.knee_stable,"crouch slope knee/length stability")
	print("CROUCH_LOCKED_V2: ","PASS" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)
