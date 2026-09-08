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
	box(Vector3(200,-.25,10),Vector3(30,.5,30))
	var mantle=body.traversal.mantle
	var sprint: Animation=animation.player.get_animation(mantle.ACTION)
	var up: Animation=animation.player.get_animation("TRV_BRACED_HANG_TO_CROUCH")
	for frame in range(10,36):
		var p: float=(float(frame)/30)/up.length
		var actual: Vector3=up.position_track_interpolate(hang.hip_track(up),float(frame)/30)
		var expected: Vector3=sprint.position_track_interpolate(hang.hip_track(sprint),hang.sprint_progress(p)*sprint.length)
		check(actual.distance_to(expected)<.001,"runtime root translation matches sprint tail")
	for height in [1.85,2.25,2.75,3.25]:
		var wall=box(Vector3(200,height*.5,7.35),Vector3(4,height,4))
		await air_setup()
		body.position.y=height-1.75+.05
		check(hang.try_catch(DT),"unchanged catch for hoist fixture")
		for frame in 20: await crouch_tick(false)
		check(hang.request_up(),"tight arc passes full crouched capsule preflight")
		var previous: Vector3=hang.alignment
		for index in 201:
			var p: float=float(index)/200
			var point: Vector3=hang.up_position(p)
			if p>=10.0/(30*up.length):
				var reference_from:=Vector3(hang.alignment.x,hang.landing.y-mantle.reference_climb_height,hang.alignment.z)
				var expected: Vector3=mantle.reference_profile_position(hang.sprint_progress(p),reference_from,hang.landing)
				check(point.distance_to(expected)<.00001,"body path exactly matches mapped sprint tail")
			check(hang.clear_segment(previous,point,crouch.crouch_capsule_height),"dense path clearance")
			previous=point
		check((hang.up_position(.60)-hang.alignment).dot(hang.facing)>.02,"forward motion overlaps lift before old 65% gate")
		check(hang.up_position(1).distance_to(hang.landing)<.00001,"unchanged landing endpoint")
		check(absf((hang.landing-hang.ledge_edge).dot(hang.facing)-.15)<.001,"15 cm setback preserved")
		var support_error: float=0
		var min_toe_gap: float=1
		var late_samples: int=0
		for frame in 140:
			await crouch_tick(crouch.requested)
			if hang.running and hang.hang_phase==hang.HangPhase.TO_CROUCH:
				for arm in body.get_node("MantleHandIK").arms:
					if hang.progress>.12 and hang.progress<.14: support_error=maxf(support_error,arm.error)
					check(arm.length_error<.005,"no arm stretching")
				if hang.progress>.15 and hang.progress<.60:
					for leg in body.get_node("FootIKController").legs:
						min_toe_gap=minf(min_toe_gap,(leg.solved_toe-hang.wall_point).dot(hang.wall_normal))
				if hang.progress>=.78 and hang.progress<=.90:
					var lowest: float=INF
					var leading: float=INF
					for leg in body.get_node("FootIKController").legs:
						lowest=minf(lowest,leg.solved_toe.y-hang.top.y)
						leading=minf(leading,(leg.solved_toe-hang.wall_point).dot(hang.wall_normal))
					check(lowest>=-.015 and lowest<.10,"rendered late feet clear lip without floating high above it")
					check(leading<.06,"leading rendered foot reaches lip during late hoist")
					late_samples+=1
			if not hang.running: break
		# Shared lower baseline retains anatomical reach limits. Measured early
		# contact error is ~3.2 cm; do not stretch the arm to force exact contact.
		check(support_error<.035,"early hand support within conservative reach tolerance")
		check(late_samples>0,"rendered late hoist sampled")
		check(min_toe_gap>-.015,"no major supporting toe penetration")
		check(hang.exit_reason=="HANG_TO_CROUCH_COMPLETED" and body.ground_support.has_ground_support,"supported completion on representative height")
		print("HOIST height=",height," support error=",support_error," toe gap=",min_toe_gap)
		wall.queue_free()
		await physics_frame
	print("HANG_HOIST_ARC_V2: ","PASS" if failures.is_empty() else str(failures))
	quit(0 if failures.is_empty() else 1)
