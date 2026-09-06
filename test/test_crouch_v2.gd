extends "res://test/test_roll_traversal_v2.gd"
var crouch: Node
func crouch_tick(held: bool,stick:=Vector2.ZERO,shift:=false,jump:=false,roll:=false) -> void:
	await physics_frame
	body.step_motor(DT,stick,shift,jump,roll,held)
	animation._physics_process(DT)
	tree.advance(DT)
	cam._process(DT)
	await process_frame

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
	crouch=body.get_node("CrouchController")
	body.set_physics_process(false)
	animation.set_physics_process(false)
	cam.set_process(false)
	tree.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	box(Vector3(200,-.25,0),Vector3(80,.5,80))
	await reset_at(Vector3(200,.1,10))
	check(InputMap.has_action("crouch"),"crouch input exists")
	check(InputMap.action_get_events("crouch")[0].physical_keycode==KEY_CTRL,"CTRL bound")
	var base: float=crouch.collision.position.y-crouch.collision.shape.height*.5
	await crouch_tick(true)
	check(animation.current_state==&"CrouchEnter","enter clip selected")
	check(crouch.collision.shape.height<1.8 and crouch.collision.shape.height>1.1,"capsule begins shrinking smoothly")
	check(absf(crouch.collision.position.y-crouch.collision.shape.height*.5-base)<.0001,"capsule bottom preserved")
	for frame in 270: await crouch_tick(true)
	print("ENTER_TIMING phase=",crouch.phase," node=",animation.current_state," position=",animation._playback.get_current_play_position()," length=",animation._playback.get_current_length())
	check(animation.current_state==&"CrouchIdle","crouch idle loop")
	var head_max: float=0
	var sk=body.get_node("EnvironmentalHandInteraction").skeleton
	for frame in 70:
		await crouch_tick(true,Vector2(0,-1),false,true)
		head_max=maxf(head_max,(sk.global_transform*sk.get_bone_global_pose(sk.find_bone("mixamorig_Head")).origin).y-body.position.y)
	print("CROUCH_HEAD_MAX ",head_max)
	check(animation.current_state==&"CrouchWalk","canonical sneak selected")
	check(absf(body.animation_state.horizontal_speed-body.walk_speed)<.01,"crouch inherits walk speed")
	check(body.animation_state.gait==0 and body._run_time==0,"Shift cannot accumulate Sprint")
	check(body.is_on_floor() and not body.animation_state.jump_started,"crouch blocks Jump")
	check(not body.get_node("EnvironmentalHandInteraction").can_use_environment_hand_ik(),"crouch blocks wall hands")
	for frame in 230: await crouch_tick(false)
	check(not crouch.active() and animation.current_state==&"Locomotion","clear release stands")
	check(absf(crouch.collision.shape.height-1.8)<.001,"standing height restored")
	await reset_at(Vector3(200,.1,10))
	for frame in 270: await crouch_tick(true)
	var ceiling:=box(Vector3(200,1.45,8),Vector3(5,.3,8))
	for frame in 5: await crouch_tick(false)
	var transitions: int=crouch.transition_count
	for frame in 40: await crouch_tick(false)
	check(crouch.active() and not crouch.can_stand,"ceiling blocks standing")
	check(crouch.transition_count==transitions,"blocked stand does not restart clip")
	dummy.position=Vector3(200,0,0)
	lock.toggle()
	check(lock.is_locked() and crouch.active(),"low ceiling allows crouched lock without standing")
	for moving in [false,true]:
		await crouch_tick(true,Vector2(0,-1) if moving else Vector2.ZERO,false,false,true)
		check(dodge.is_dodging and dodge.clip==(dodge.STAND if moving else dodge.BACK),"crouch dodge selects existing action")
		for frame in 160:
			await crouch_tick(true,Vector2(0,-1) if moving else Vector2.ZERO)
			check(crouch.collision.shape.height<1.11,"crouch dodge never expands capsule")
		check(crouch.active(),"held CTRL returns to crouch after dodge")
	# CTRL release during an action must not expand under a new low ceiling.
	var dodge_roof:=box(body.position+Vector3(0,1.4,0),Vector3(12,.3,12))
	await crouch_tick(true,Vector2.ZERO,false,false,true)
	for frame in 130: await crouch_tick(false)
	check(crouch.active() and crouch.collision.shape.height<1.11,"released CTRL during dodge still checks ceiling")
	dodge_roof.free()
	ceiling.free()
	for frame in 230: await crouch_tick(false)
	check(not crouch.active(),"released CTRL auto-stands after clearance returns")
	check(lock.is_locked(),"locked crouch exit preserves target")
	for frame in 270: await crouch_tick(true)
	check(crouch.active() and animation.current_state==&"CrouchLocked","locked CTRL enters crouch")
	lock.clear()
	await reset_at(Vector3(200,.1,10))
	for frame in 270: await crouch_tick(true)
	var tunnel:=box(Vector3(200,1.45,6),Vector3(4,.3,5))
	for frame in 100: await crouch_tick(true,Vector2(0,-1))
	var blocked_during_exit:=false
	for frame in 370:
		await crouch_tick(false,Vector2(0,-1))
		blocked_during_exit=blocked_during_exit or (crouch.active() and not crouch.can_stand)
	check(body.position.z<3.1,"crouch passes low tunnel")
	check(blocked_during_exit and not crouch.active(),"released CTRL remains crouched in tunnel then auto-stands outside")
	tunnel.free()
	for frame in 270: await crouch_tick(true)
	var low:=box(Vector3(200,.5,body.position.z-2),Vector3(4,.3,1))
	var start_z: float=body.position.z
	for frame in 120: await crouch_tick(true,Vector2(0,-1))
	check(body.position.z>start_z-2,"too-low geometry blocks capsule")
	low.free()
	for frame in 230: await crouch_tick(false)
	await reset_at(Vector3(200,.1,10))
	for frame in 270: await crouch_tick(true)
	var curb:=box(Vector3(200,.075,5),Vector3(5,.15,5))
	for frame in 180: await crouch_tick(true,Vector2(0,-1))
	check(body.position.z<6 and body.position.y>.10,"crouch StepSolver clears curb")
	check(body.position.is_finite(),"crouch terrain pose finite")
	var feet=body.get_node("FootIKController")
	for leg in feet.legs:
		check(leg.solved.is_finite() and leg.length_error<.01,"crouch terrain IK finite and non-stretching")
	print("CROUCH_IK ",feet.debug_text() if feet.has_method("debug_text") else "finite")
	check(absf(feet.pelvis.applied_offset)<=feet.max_pelvis_drop+.001,"crouch respects existing pelvis cap")
	curb.free()
	for frame in 230: await crouch_tick(false)
	await reset_at(Vector3(200,.1,10))
	for frame in 270: await crouch_tick(true)
	var stairs: Array[Node]=[]
	for i in 3: stairs.append(box(Vector3(200,.05*(i+1),7-i),Vector3(5,.1*(i+1),1)))
	var stair_peak: float=0
	for frame in 180:
		await crouch_tick(true,Vector2(0,-1))
		stair_peak=maxf(stair_peak,body.position.y)
	check(stair_peak>.28 and body.position.z<4.6,"crouch traverses three consecutive stair risers")
	for stair in stairs: stair.free()
	for direction in [Vector2(1,0),Vector2(0,1),Vector2(-1,0)]:
		for frame in 45: await crouch_tick(true,direction)
		check(not body.turn_180.active and animation.current_state==&"CrouchWalk","crouch direction changes use free facing, not standing pivot clips")
	print("CROUCH_V2: ","PASS" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)
