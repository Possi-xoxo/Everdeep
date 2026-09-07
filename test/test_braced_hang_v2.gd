extends "res://test/test_mantle_geometry_v2.gd"
var hang: Node

func air_setup(vertical: float=0, yaw: float=0, away: bool=false) -> void:
	if body.traversal.is_traversing: body.traversal.finish("TEST_RESET")
	hang.cooldown=0
	crouch.requested=false
	crouch.phase=crouch.Phase.STANDING
	crouch.resize(crouch.standing_capsule_height)
	body.position=Vector3(200,1.1,10)
	body.ground_support.last_supported_height=0 # Explicit launch floor for teleported fixture.
	body.visual.rotation.y=deg_to_rad(yaw)
	body.velocity=Vector3(0,vertical,2 if away else -2)
	body.move_and_slide()
	body.ground_support.refresh(0)
	animation._enter(&"Fall")
	await physics_frame

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
	hang=body.traversal.hang
	body.set_physics_process(false)
	animation.set_physics_process(false)
	cam.set_process(false)
	tree.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	var wall=box(Vector3(200,1,8.35),Vector3(4,4,2)) # top 3, front 9.35
	await physics_frame
	for vertical in [3.0,0.0,-3.0]:
		await air_setup(vertical)
		print("DETECT ",hang.detect())
		check(hang.try_catch(DT),"automatic rising/apex/falling catch")
		check(body.velocity==Vector3.ZERO,"catch arrests momentum")
		check(not hang.request_up(),"settle lockout")
		for frame in 20: await crouch_tick(false,Vector2(0,-1))
		check(hang.hang_phase==hang.HangPhase.IDLE,"settled idle")
		var anchor: Vector3=body.position
		for frame in 20: await crouch_tick(false,Vector2(1,0),true,false,true)
		check(body.position.distance_to(anchor)<.001 and body.velocity==Vector3.ZERO,"stable anchor ignores locomotion/gravity")
		check(animation.current_state==&"HangIdle","hang idle animation")
		for arm in body.get_node("MantleHandIK").arms:
			print("HANG HAND ",arm.side," error ",arm.error," limited ",arm.limited)
			check(arm.valid and arm.weight>.99 and arm.error<.005,"anchored idle hands")
		var feet=body.get_node("FootIKController")
		for leg in feet.legs:
			var toe: Vector3=leg.solved_toe
			var gap: float=(toe-hang.wall_point).dot(hang.wall_normal)
			print("HANG FOOT ",leg.side," gap ",gap)
			check(gap>=-.02 and gap<.15,"foot immediately in front of bracing wall")
		check(hang.request_up(),"valid climb up")
		var max_support_error: float=0
		var min_wall_gap: float=1
		for frame in 140:
			await crouch_tick(true)
			if hang.running and hang.hang_phase==hang.HangPhase.TO_CROUCH:
				for arm in body.get_node("MantleHandIK").arms:
					check(arm.length_error<.005,"no hang arm stretch")
					if hang.progress<.30: check(arm.weight>.99,"hands support initial climb up")
					if hang.progress>.02 and hang.progress<.45: max_support_error=maxf(max_support_error,arm.error)
					if hang.progress>.72: check(arm.weight==0,"hands release during top out")
				if hang.progress<.60:
					for leg in feet.legs:
						var toe: Vector3=leg.solved_toe
						if toe.y<hang.top.y-.02:
							var gap: float=(toe-hang.wall_point).dot(hang.wall_normal)
							min_wall_gap=minf(min_wall_gap,gap)
			if not hang.running: break
		print("HANG END ",hang.exit_reason," pos ",body.position," p ",hang.progress)
		print("HANG UP SUPPORT ERROR ",max_support_error)
		print("HANG UP MIN TOE WALL GAP ",min_wall_gap)
		check(min_wall_gap>-.015,"no major supporting foot wall penetration")
		check(max_support_error<.015,"hands remain anchored during supporting climb phase")
		check(hang.exit_reason=="HANG_TO_CROUCH_COMPLETED","hang completes")
		check(not crouch.requested and crouch.phase==crouch.Phase.STANDING and body.ground_support.has_ground_support,"supported return to original standing locomotion")
	for angle in [45.0,79.0,100.0,180.0]:
		await air_setup(0,angle)
		check(hang.detect().valid==(angle<=100),"velocity-led loose facing "+str(angle))
	await air_setup(0,0,true)
	check(not hang.detect().valid,"moving away rejected")
	await air_setup(0,79)
	check(hang.try_catch(DT),"cone edge commits")
	for frame in 30: await crouch_tick(false)
	check((-body.visual.global_basis.z).dot(hang.facing)>.999,"cone edge aligns toward wall")
	for arm in body.get_node("MantleHandIK").arms: check(arm.error<.005,"diagonal catch reaches both grips")
	await air_setup()
	body.position.x=201.85
	check(not hang.detect().valid,"narrow edge lacks two-hand width")
	await air_setup()
	body.position.z=11
	check(not hang.detect().valid,"out of reach rejected")
	await air_setup()
	check(hang.try_catch(DT),"blocked top setup")
	for frame in 20: await crouch_tick(false)
	var blocker=box(Vector3(200,3.6,8.85),Vector3(3,1,1))
	await physics_frame
	check(not hang.request_up() and hang.running,"blocked top remains hanging")
	blocker.queue_free()
	wall.position.y+=.1
	await crouch_tick(false)
	check(not hang.running and not body.traversal.is_traversing,"moved source safely releases ownership")
	wall.position.y-=.1
	body.traversal.finish("TEST_RESET")
	wall.queue_free()
	await physics_frame
	wall=box(Vector3(200,2.85,8.35),Vector3(4,.3,2))
	await air_setup()
	var no_brace: Dictionary=hang.detect()
	print("NO BRACE ",no_brace)
	check(not no_brace.valid and no_brace.classification=="FREE_HANG_CANDIDATE","no bracing classified but not enabled")
	print("BRACED_HANG_V2 ","PASS" if failures.is_empty() else "FAIL", " failures=",failures)
	quit(0 if failures.is_empty() else 1)
