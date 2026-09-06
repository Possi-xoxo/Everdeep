extends "res://test/test_player_v2.gd"
var ik: Node

func freeze(position: Vector3, frames: int=90) -> void:
	body.position=position
	body.velocity=Vector3.ZERO
	body.animation_state.is_grounded=true
	body.animation_state.is_airborne=false
	body.animation_state.jump_started=false
	body.animation_state.move_input_magnitude=0
	for frame in frames:
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
	for frame in 180: await tick()
	for leg in ik.legs:
		print("PLANT_IDLE ",leg.side," support=",leg.plant.support_confidence," weight=",leg.weight," locked=",leg.plant.locked," acquisitions=",leg.plant.lock_count)
		check(leg.plant.support_confidence>0.8,"idle support strong")
		check(leg.plant.locked,"idle locks")
		check(leg.plant.lock_count<=2,"idle does not chatter")
	for gait in 3:
		await settle(Vector3(0,0.05,20))
		body._run_time=4 if gait==2 else 0
		var locked_frames:=0
		var acquisitions:=0
		var swing_weight:=0.0
		var support_weight:=0.0
		var swing_samples:=0
		var support_samples:=0
		var authored_slide:=0.0
		var solved_slide:=0.0
		var slide_samples:=0
		var previous: Array[Dictionary]=[{},{}]
		for frame in 160:
			var incoming_weights: Array[float]=[ik.legs[0].weight,ik.legs[1].weight]
			await tick(Vector2(0,-1),gait>0)
			for i in 2:
				var leg=ik.legs[i]
				var p=leg.plant
				if p.locked: locked_frames+=1
				if p.raw_support>0.8:
					support_weight+=leg.weight
					support_samples+=1
				if p.raw_support<0.05 and p.support_confidence<0.2:
					swing_weight+=leg.weight
					swing_samples+=1
				if p.locked and p.lock_blend>0.5 and not previous[i].is_empty() and previous[i].locked and previous[i].count==p.lock_count:
					authored_slide+=Vector2(leg.animated.x-previous[i].animated.x,leg.animated.z-previous[i].animated.z).length()
					solved_slide+=Vector2(leg.solved.x-previous[i].solved.x,leg.solved.z-previous[i].solved.z).length()
					slide_samples+=1
					check(p.locked_world_position.is_equal_approx(previous[i].anchor),"anchor stays fixed")
				previous[i]={"locked":p.locked,"animated":leg.animated,"solved":leg.solved,"count":p.lock_count,"anchor":p.locked_world_position}
				check(leg.knee_stable and leg.length_error<0.002,"planting preserves knee/limb length")
				# Full Idle influence may smoothly decay into the lower moving gait.
				check(leg.weight<=maxf(incoming_weights[i],ik.grounded_contact_weight())+0.0001,"gait transition never overshoots")
				if frame>30: check(leg.weight<=ik.grounded_contact_weight()+0.05,"settled gait weight remains bounded")
		for leg in ik.legs: acquisitions+=leg.plant.lock_count
		print("PLANT_GAIT ",gait," lock_frames=",locked_frames," total_acquisitions=",acquisitions," stance/swing_weight=",support_weight/maxi(1,support_samples)," / ",swing_weight/maxi(1,swing_samples)," anchored slide=",authored_slide," -> ",solved_slide," samples=",slide_samples)
		check(support_samples>0 and swing_samples>0,"independent stance/swing phases detected")
		check(support_weight/support_samples>swing_weight/swing_samples,"support receives stronger IK")
		if gait==0:
			check(slide_samples>0,"walk acquires short locks")
			check(solved_slide<authored_slide,"walking lock reduces measured skating")
	# Jump releases anchors on the same evaluated pose, then fades IK out.
	await settle(Vector3(0,0.05,20))
	for frame in 90: await tick()
	await tick(Vector2.ZERO,false,true)
	for leg in ik.legs: check(not leg.plant.locked,"jump releases lock immediately")
	for frame in 35: await tick()
	for leg in ik.legs: check(leg.weight<0.001,"airborne IK neutral")
	for frame in 140: await tick()
	for leg in ik.legs: check(leg.plant.support_confidence>0.8,"landing naturally reacquires support")
	# Frozen split-curb pose: the animated probe moves across the edge, but
	# the still-supported anchor must remain on the OLD upper surface.
	var x: float=51.5-(ik.legs[0].animated.x-body.position.x)-0.04
	await freeze(Vector3(x,0.15,0))
	var left=ik.legs[0].plant
	check(left.locked,"upper curb foot can plant")
	var anchor: Vector3=left.locked_world_position
	var old_id: int=ik.feet.left.collider_id
	await freeze(Vector3(x+0.08,0.15,0),3)
	check(ik.feet.left.collider_id!=old_id,"probe crossed to different terrain")
	check(left.locked and left.locked_world_position.is_equal_approx(anchor),"old stair anchor retained")
	check(absf(ik.legs[0].desired_destination.y-anchor.y)<0.005,"locked target does not jump to new floor height")
	# Remove only the test fixture's collision temporarily, then restore it.
	var surface=instance_from_id(old_id)
	var layer: int=surface.collision_layer
	surface.collision_layer=0
	await freeze(Vector3(x+0.08,0.15,0),2)
	check(not left.locked and left.lock_blend==0,"missing anchor support releases despite valid animated ray")
	surface.collision_layer=layer
	await settle(Vector3(12.3,3.05,-20))
	for frame in 90: await tick()
	var one_invalid:=0
	var air_frames:=0
	for frame in 65:
		await tick(Vector2(1,0))
		for i in 2:
			var valid: bool=ik.feet.left.valid if i==0 else ik.feet.right.valid
			if not valid: check(not ik.legs[i].plant.locked,"unsupported foot never remains anchored")
		if ik.feet.left.valid!=ik.feet.right.valid: one_invalid+=1
		if body.animation_state.is_airborne:
			air_frames+=1
			for leg in ik.legs: check(not leg.plant.locked,"walk-off fall clears locks")
	check(one_invalid>0 and air_frames>0,"edge fixture covers single support and fall")
	print("PLANT_EDGE single_valid=",one_invalid," air_frames=",air_frames)
	await settle(Vector3(0,0.05,20))
	# Reversal presentation wins over planting; no gameplay changes.
	for running in [false,true]:
		await settle(Vector3(0,0.05,20))
		for frame in 60: await tick(Vector2(0,-1),running)
		await tick(Vector2(0,1),running)
		var turn_frames:=0
		for frame in 50:
			await tick(Vector2(0,1),running)
			if body.turn_180.active:
				turn_frames+=1
				for leg in ik.legs: check(not leg.plant.locked,"180 never fights a lock")
		check(turn_frames>0,"180 fixture active")
	for stair in [1,2]:
		body.step_solver.cancel()
		await settle(Vector3(42+stair*10,0.05,-18))
		body.visual.rotation.y=0
		var locks:=0
		for frame in 200:
			await tick(Vector2(0,-1))
			for leg in ik.legs:
				if leg.plant.locked: locks+=1
				check(leg.knee_stable and leg.length_error<0.002,"stairs keep finite stable limbs")
			if body.position.z< -29: break
		print("PLANT_STAIRS ",stair," lock_frames=",locks," end=",body.position)
		check(body.position.z< -29,"planting leaves traversal unchanged")
	print("FOOT_PLANTING_V2: ","PASS" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)
