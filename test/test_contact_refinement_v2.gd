extends "res://test/test_player_v2.gd"
func run() -> void:
	var lab=load("res://test/player_v2_lab.tscn").instantiate()
	root.add_child(lab)
	body=lab.get_node("PlayerV2")
	animation=body.get_node("AnimationController")
	tree=body.get_node("AnimationTree")
	body.set_physics_process(false)
	animation.set_physics_process(false)
	tree.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	await settle(Vector3(0,0.05,20))
	var ik=body.get_node("FootIKController")
	# This regression compares the pre-Idle-refinement global contact weights.
	# Idle-specific behavior has its own test_idle_contact_v2 suite.
	ik.idle_ik_override_enabled=false
	var means=[]
	for weight in [0.8,0.95]:
		ik.foot_ik_weight=weight
		var total:=0.0
		for p in [Vector3(0,0.001,20),Vector3(51.5,0.15,0),Vector3(57.5,0.2,0)]:
			body.position=p
			for frame in 90:
				tree.advance(0)
				await process_frame
			for leg in ik.legs:
				total+=leg.terrain_error
				check(leg.knee_stable and leg.length_error<0.002,"contact strength never stretches limb")
			print("CONTACT_REFINED weight=",weight," pos=",p," errors=",ik.legs[0].terrain_error," / ",ik.legs[1].terrain_error)
		means.append(total/6)
	print("CONTACT_MEAN before=",means[0]," after=",means[1])
	check(means[1]<means[0]*0.6,"terrain error materially reduced")
	for gait in 3:
		await settle(Vector3(0,0.05,20))
		body._run_time=4 if gait==2 else 0
		var released:=0
		for frame in 90:
			await tick(Vector2(0,-1),gait>0)
			check(is_equal_approx(ik.grounded_contact_weight(),[0.95,0.8,0.65][gait]),"gait contact weight")
			for leg in ik.legs:
				if leg.swing<0.1: released+=1
				check(leg.knee_stable and leg.length_error<0.002,"moving contact stable")
		check(released>0,"swing feet still release")
		print("CONTACT_GAIT ",gait," swing_releases=",released)
	print("CONTACT_REFINEMENT_V2: ","PASS" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)
