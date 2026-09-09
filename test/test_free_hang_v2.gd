extends "res://test/test_hang_transfer_v2.gd"

func release_free() -> void:
	await crouch_tick(false,Vector2.DOWN)
	for i in 30:
		if not body.traversal.free_hang.running: break
		await crouch_tick(false)

func free_catch(point: Vector3,velocity: Vector3) -> Dictionary:
	if body.traversal.is_traversing: body.traversal.finish("TEST_RESET")
	hang.cooldown=0
	hang.release_suppression_active=false
	hang.acquisition.reset_history()
	body.position=point
	body.velocity=Vector3.UP*.001
	body.move_and_slide()
	body.velocity=velocity
	body.visual.rotation.y=0
	body.ground_support.last_supported_height=0
	body.ground_support.refresh(0)
	animation._enter(&"Fall")
	await physics_frame
	var candidate: Dictionary=hang.detect(DT,Vector3.FORWARD)
	print("FREE QUERY ",point," ",candidate.get("classification","NONE")," ",candidate.reason)
	if candidate.valid: check(hang.try_catch(DT,Vector3.FORWARD),"commit valid candidate")
	return candidate

func run() -> void:
	await setup_transfer()
	var free=body.traversal.free_hang
	box(Vector3(200,2.875,-2),Vector3(6,.25,4))
	box(Vector3(210,1.5,-2),Vector3(6,3,4))
	box(Vector3(220,2.875,-2),Vector3(.30,.25,4))
	box(Vector3(200,-.1,1),Vector3(16,.2,12))
	await physics_frame
	check(free.clips_ready,"private catch and idle prepared")
	for velocity in [Vector3(0,4,-2),Vector3(0,0,-2),Vector3(0,-5,-2),Vector3(4,-2,-4),Vector3(15,-35,-15)]:
		var candidate: Dictionary=await free_catch(Vector3(200,1.1,.65),velocity)
		check(candidate.valid and candidate.get("free_hang",false),"unsupported ledge FREE across airborne trajectories")
		if not free.running: continue
		check(not hang.running,"mutually exclusive families")
		check(free.incoming_velocity.is_equal_approx(velocity),"capture actual incoming XYZ velocity")
		check(free.retained_momentum.length()<=free.free_hang_max_catch_velocity*free.free_hang_momentum_retention+.001,"bounded momentum")
		var targets: Dictionary=free.hand_targets.duplicate()
		await crouch_tick(false,Vector2.ZERO,false,true)
		check(free.running,"catch input lockout")
		var maximum: float=0
		var max_hand_error: float=0
		for tick in 120:
			await crouch_tick(false)
			maximum=maxf(maximum,free.swing_offset.length())
			check(free.hand_targets==targets,"hand anchors fixed throughout swing")
			check(free.swing_offset.length()<=free.free_hang_max_swing_offset+.001,"offset cap")
			for leg in body.get_node("FootIKController").legs: check(leg.weight==0,"no Free Hang foot IK")
			for arm in body.get_node("MantleHandIK").arms:
				check(arm.length_error<.005,"arm length preserved")
				if tick>20: max_hand_error=maxf(max_hand_error,arm.error)
		print("FREE METRICS ",velocity," max_swing ",maximum," hand_error ",max_hand_error," phase ",free.hang_phase)
		check(maximum>.002,"retained momentum visibly moves body")
		check(free.running and free.hang_phase==free.HangPhase.IDLE,"settles to idle")
		check(max_hand_error<.04,"settled hands within 4cm")
		await release_free()
		check(not free.running and not body.traversal.is_traversing,"S releases ownership")
		check(body.velocity.length()<1,"no old momentum restored")
		check(not hang.detect(DT,Vector3.FORWARD).valid,"same ledge suppressed")
	var braced: Dictionary=await free_catch(Vector3(210,1.1,.65),Vector3(0,-2,-2))
	check(braced.valid and braced.classification=="BRACED" and hang.running,"wall-backed remains BRACED")
	var invalid: Dictionary=await free_catch(Vector3(220,1.1,.65),Vector3(0,-2,-2))
	check(not invalid.valid,"insufficient hand width rejects")
	print("FREE HANG TEST ","PASS" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)
