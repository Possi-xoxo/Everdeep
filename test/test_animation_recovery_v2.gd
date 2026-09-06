extends "res://test/test_player_v2.gd"
var inspect_pose: bool = false
var low_drop_count: int = 0

func tick(stick := Vector2.ZERO, shift := false, jump := false) -> void:
	await super.tick(stick,shift,jump)
	if not inspect_pose:
		return
	var p = tree.get("parameters/playback")
	var c = tree.get("parameters/Locomotion/playback")
	check(tree.active and p.is_playing(),"root always evaluates a pose")
	if p.get_current_node()==&"Locomotion":
		check(c.is_playing() and c.get_current_node() not in [&"",&"Start",&"End"],"nested locomotion has an actual pose source")
	var sk = animation.rig.get_node("Base Armature and Mesh/Skeleton3D")
	var deviation := 0.0
	for name in ["mixamorig_LeftArm","mixamorig_RightArm"]:
		var bone: int = sk.find_bone(name)
		deviation += sk.get_bone_pose_rotation(bone).angle_to(sk.get_bone_rest(bone).basis.get_rotation_quaternion())
	check(deviation>0.15,"evaluated arms are not the imported rest/T-pose")

func run() -> void:
	var lab = load("res://test/player_v2_lab.tscn").instantiate()
	root.add_child(lab)
	body = lab.get_node("PlayerV2")
	animation = body.get_node("AnimationController")
	tree = body.get_node("AnimationTree")
	body.set_physics_process(false)
	animation.set_physics_process(false)
	tree.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	await settle(Vector3(0,0.1,20))
	inspect_pose=true
	for repetition in 20:
		var shift := repetition%2==1
		var released := repetition%4==3
		await settle(Vector3(-9,0.7,-15))
		var left_floor := false
		var regained := false
		for i in 110:
			await tick(Vector2.ZERO if released and left_floor else Vector2(0,-1),shift)
			if body.animation_state.is_airborne:
				left_floor=true
			elif left_floor:
				regained=true
		check(left_floor and regained,"real 0.6m ledge left and regained floor")
		check(animation.current_state==&"Locomotion","real ledge returns to locomotion")
		if released:
			check(is_zero_approx(animation.gait_blend),"release during drop reaches actual idle blend")
		low_drop_count+=1
	# A genuinely suppressed tiny drop: preserve the same loop clock and
	# ownership across floor loss/contact, with no Fall or Land event.
	await settle(Vector3(0,0.1,20))
	for i in 40:
		await tick(Vector2(0,-1),true)
	body.floor_snap_length=0
	body.position.y+=0.08
	var c = tree.get("parameters/Locomotion/playback")
	var count: int = animation.landing_count
	var repairs: int = animation.playback_recoveries + animation.grounded.playback_recoveries
	for i in 15:
		var old: float = c.get_current_play_position()
		var length: float = c.get_current_length()
		await tick(Vector2(0,-1),true)
		check(animation.current_state==&"Locomotion","tiny drop suppresses Fall/Land")
		var elapsed := fposmod(c.get_current_play_position()-old,length)
		check(absf(elapsed-DT)<0.001,"tiny drop does not reset/pause gait clock")
	check(animation.landing_count==count,"tiny drop produces no Land")
	check(animation.playback_recoveries+animation.grounded.playback_recoveries==repairs,"normal tiny drop needs no recovery spam")
	# Floor loss during either pivot must hand back to a live loop, even
	# when released input provides no later animation event to rescue it.
	for shift in [false,true]:
		body.visual.rotation.y=0
		await settle(Vector3(0,0.1,20))
		for i in 30:
			await tick(Vector2(0,-1),shift)
		await tick(Vector2(0,1),shift)
		check(body.turn_180.active,"pivot fixture starts")
		body.position.y+=0.08
		for i in 20:
			await tick(Vector2.ZERO,shift)
		check(not body.turn_180.active and c.get_current_node()==&"Loops","pivot floor loss returns pose ownership to loops")
	body.floor_snap_length=0.3
	# Deliberately displace each machine to prove logical equality cannot
	# prevent recovery. Do not inspect the intentionally broken sample itself.
	inspect_pose=false
	c.stop()
	tree.advance(DT)
	await tick(Vector2(0,-1),true)
	check(c.is_playing() and c.get_current_node()==&"Loops","stopped child recovers without an input event")
	var p = tree.get("parameters/playback")
	p.start(&"Fall")
	tree.advance(DT)
	for i in 12:
		await tick(Vector2(0,-1),true)
	check(p.get_current_node()==&"Locomotion","displaced root recovers despite logical equality")
	tree.active=false
	await tick(Vector2(0,-1),true)
	check(tree.active,"disabled tree recovery")
	inspect_pose=true
	await settle(Vector3(9,3.1,-23))
	var saw_fall := false
	for i in 110:
		await tick(Vector2(0,-1),true)
		saw_fall = saw_fall or animation.current_state==&"Fall"
	check(saw_fall,"meaningful high drop still commits Fall")
	check(is_equal_approx(animation.fall_min_air_time,0.12),"Fall threshold unchanged")
	print("ANIMATION_RECOVERY_V2: ","PASS" if failures.is_empty() else failures," real low drops=",low_drop_count)
	quit(0 if failures.is_empty() else 1)
