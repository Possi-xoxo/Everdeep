extends "res://test/test_braced_hang_v2.gd"

func run() -> void:
	lab=load("res://test/player_v2_lab.tscn").instantiate()
	root.add_child(lab)
	body=lab.get_node("PlayerV2")
	animation=body.get_node("AnimationController")
	tree=body.get_node("AnimationTree")
	cam=body.get_node("CameraRig")
	crouch=body.crouch
	hang=body.traversal.hang
	body.set_physics_process(false)
	animation.set_physics_process(false)
	cam.set_process(false)
	tree.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	var original_rig: Vector3=animation.rig.position
	var original_visual: Vector3=body.visual.position
	var foot_solver=body.get_node("FootIKController")
	box(Vector3(200,-.25,10),Vector3(30,.5,30))
	for configuration in [Vector2(1.85,1),Vector2(2.25,2),Vector2(2.75,3),Vector2(3.25,4)]:
		var height: float=configuration.x
		var depth: float=configuration.y
		var wall=box(Vector3(200,height*.5,9.35-depth*.5),Vector3(4,height,depth))
		var wall_relief: float=.03 if height==2.75 else 0.0
		if wall_relief>0:
			var relief:=CollisionShape3D.new()
			var shape:=BoxShape3D.new()
			shape.size=Vector3(4,height-.5,wall_relief)
			relief.shape=shape
			relief.position=Vector3(0,-.25,depth*.5+wall_relief*.5)
			wall.add_child(relief)
		await air_setup()
		body.position.y=height-1.75+.05
		check(hang.try_catch(DT),"representative ledge catch")
		var anchor: Vector3=hang.alignment
		var capsule_height: float=crouch.collision.shape.height
		var prior_offset: float=hang.idle_pose.offset
		for frame in 70:
			await crouch_tick(false)
			check(absf(hang.idle_pose.offset-prior_offset)<.009,"offset blends without snap")
			prior_offset=hang.idle_pose.offset
		check(body.position.distance_to(anchor)<.001 and hang.alignment==anchor,"render correction never moves gameplay anchor/body")
		check(crouch.collision.shape.height==capsule_height,"idle polish leaves capsule unchanged")
		check(body.visual.position==original_visual,"VisualRoot baseline untouched")
		check(animation.rig.position.is_equal_approx(original_rig+Vector3(0,-.05,0)),"exact nonaccumulating render-only offset")
		for arm in body.get_node("MantleHandIK").arms:
			check(absf(arm.solved.y-height+.075)<.003,"idle hand meets wall just below ledge lip")
			check(arm.length_error<.005 and not arm.limited,"hands reach without stretching")
			check(arm.animated.distance_to(arm.solved)<=hang.braced_hang_max_hand_correction+.001,"hand correction bounded")
		for leg in foot_solver.legs:
			var gap: float=(leg.solved_toe-hang.wall_point).dot(hang.wall_normal)
			check(absf(gap-wall_relief-.02)<.003,"foot braces with 2 cm clearance from actual local wall depth")
			check(leg.length_error<.005,"leg lengths preserved")
			check(absf(leg.correction.y)<.001 and absf(leg.correction.dot(hang.facing.cross(Vector3.UP)))<.001,"feet retain authored vertical/lateral position")
		var leg: Dictionary=foot_solver.legs[0]
		var pose: Transform3D=foot_solver._world(leg.bones[2])
		pose.origin+=hang.wall_normal*.5
		var legacy: Dictionary={"valid":false,"target":pose.origin,"weight":0.0}
		var limited: Dictionary=hang.idle_pose.foot_contact(hang,foot_solver,leg,pose,[pose.origin,pose.origin],legacy)
		check(not limited.valid and limited.limited and limited.target==pose.origin,"distant foot preserves animation instead of stretching")
		hang.hang_debug=true
		hang.detection_visual._process(DT)
		check(hang.detection_visual.mesh.get_surface_count()==1,"idle debug geometry available")
		check(hang.idle_pose.debug_text(hang).contains("CORRECTION_OR_REACH_LIMIT"),"debug reports foot safety fallback")
		hang.hang_debug=false
		if height<2.5:
			check(hang.request_release(),"release still works")
			for frame in 90: await crouch_tick(false)
			check(not hang.running and body.ground_support.has_ground_support,"normal release lands")
		else:
			check(hang.request_up(),"existing top-out still works")
			for frame in 140:
				await crouch_tick(crouch.requested)
				if hang.up_elapsed>.15:
					check(hang.idle_pose.weight==0,"idle correction yields completely to existing HangUp")
				if not hang.running: break
			check(hang.exit_reason=="HANG_TO_CROUCH_COMPLETED","top-out completes unchanged")
		check(hang.idle_pose.weight==0 and animation.rig.position==original_rig,"base rig restored exactly after exit")
		check(hang.idle_pose.feet.is_empty(),"idle foot targets cleared")
		for arm in body.get_node("MantleHandIK").arms: check(arm.weight==0,"hang hand IK releases")
		wall.queue_free()
		await physics_frame
	print("HANG_IDLE_POSE_V2: ","PASS" if failures.is_empty() else str(failures))
	quit(0 if failures.is_empty() else 1)
