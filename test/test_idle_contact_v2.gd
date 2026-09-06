extends "res://test/test_player_v2.gd"
var ik: Node

func freeze(position: Vector3) -> void:
	body.position=position
	body.velocity=Vector3.ZERO
	body.animation_state.is_grounded=true
	body.animation_state.is_airborne=false
	body.animation_state.jump_started=false
	body.animation_state.move_input_magnitude=0
	body.animation_state.horizontal_speed=0
	for frame in 120:
		tree.advance(0)
		await process_frame

func run() -> void:
	var lab=load("res://test/player_v2_lab.tscn").instantiate()
	root.add_child(lab)
	body=lab.get_node("PlayerV2")
	animation=body.get_node("AnimationController")
	tree=body.get_node("AnimationTree")
	ik=body.get_node("FootIKController")
	body.set_physics_process(false)
	animation.set_physics_process(false)
	tree.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	await settle(Vector3(0,0.05,20))
	await freeze(Vector3(0,0.001,20))
	for leg in ik.legs: check(leg.contact_error<0.001,"flat idle contact")
	for cm in [10,20,25,35,40,45]:
		var height: float=cm/100.0
		var x: float=38+(cm/5-1)*6+1.5
		await freeze(Vector3(x,height,0))
		print("IDLE_CONTACT cm=",cm," valid=",ik.feet.left.valid," / ",ik.feet.right.valid," forced=",ik.legs[0].plant.idle_forced_support," / ",ik.legs[1].plant.idle_forced_support," gap=",ik.legs[0].contact_error," / ",ik.legs[1].contact_error," drop=",ik.pelvis.applied_offset)
		for leg in ik.legs:
			check(leg.knee_stable and leg.length_error<0.002,"no Idle hyperextension")
			check(absf(ik.pelvis.applied_offset)<=ik.idle_max_pelvis_drop+0.001,"Idle pelvis drop bound")
			if cm<=40:
				check(leg.plant.idle_forced_support and leg.plant.support_confidence>0.999,"valid in-range idle fully supported")
				check(leg.weight>0.999,"idle IK reaches full weight")
				check(ik.vertical_correction_limit(leg)==0.4,"Idle-only vertical cap")
				check(absf(leg.correction.y)<=0.4001,"residual Idle correction remains capped")
			elif leg.side=="Right":
				check(not leg.plant.idle_forced_support,"unsupported low foot never forced")
		if cm<=40:
			for leg in ik.legs: check(leg.contact_error<0.002,"reachable Idle soles contact")
		check(body.position.is_equal_approx(Vector3(x,height,0)),"visual solver never relocates body")
	# >40 cm with both probes in range must also decline forced support.
	await freeze(Vector3(87.5,0.2,0))
	check(ik.feet.left.valid and ik.feet.right.valid,"45 cm two-valid fixture")
	for leg in ik.legs: check(not leg.plant.idle_forced_support,"height delta gate applies to both valid feet")
	# Leaving rest uses normal planting and the normal cap on the first input.
	await freeze(Vector3(63.5,0.25,0))
	await tick(Vector2(0,-1))
	check(ik.pelvis_drop_limit()==0.2,"movement restores normal pelvis target budget")
	for leg in ik.legs:
		check(not leg.plant.idle_forced_support and not leg.plant.locked,"movement releases Idle support and locks")
		check(ik.vertical_correction_limit(leg)==0.2,"moving cap unchanged")
		check(leg.weight>0.8,"influence releases smoothly")
	check(is_equal_approx(ik.feet.left_probe.target_position.length(),ik.feet.foot_probe_distance),"moving probe range unchanged")
	await freeze(Vector3(81.5,0.4,0))
	await tick(Vector2(0,-1))
	check(ik.pelvis.target_offset>=-0.20 and ik.pelvis.current_offset< -0.20,"40 cm Idle exits by smooth recovery, not hard clamp")
	for leg in ik.legs: check(not leg.plant.idle_forced_support and not leg.plant.locked,"40 cm Idle locks release on movement")
	for frame in 90: await tick()
	await tick(Vector2.ZERO,false,true)
	for leg in ik.legs: check(not leg.plant.locked and not leg.plant.idle_forced_support,"jump releases Idle lock")
	print("IDLE_CONTACT_V2: ","PASS" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)
