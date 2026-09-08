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
	var wall=box(Vector3(200,1.125,8.35),Vector3(4,2.25,2))
	var floor_box=box(Vector3(200,-.25,10),Vector3(30,.5,30))
	await physics_frame
	# Original exact failure: all physical checks pass, but .09/.05 m/s with
	# no input was discarded by the old .1 m/s switch.
	for speed in [.11,.09,.05,.01]:
		await air_setup()
		body.position.y=.5
		body.velocity=Vector3(0,-2,-speed)
		body.animation_state.move_input_magnitude=0
		body.animation_state.move_direction_world=Vector3.ZERO
		var candidate: Dictionary=hang.detect()
		check(candidate.valid,"slow released momentum remains valid "+str(speed))
		check(candidate.radial_speed>0 and not candidate.grace,"actual momentum, not grace")
	# Repress must be consumed before animation state updates, on this tick.
	await air_setup()
	body.position.y=.5
	body.velocity=Vector3(0,-2,0)
	body.animation_state.move_input_magnitude=0
	body.animation_state.move_direction_world=Vector3.ZERO
	await crouch_tick(false,Vector2(0,-1))
	check(hang.running,"repress catches on first input tick, not one tick late")
	# At contact the motor can retain tangential sliding speed while the wall
	# zeros ONLY its inward component. Fresh intent must still allow the grip.
	await air_setup()
	body.position=Vector3(200,.5,9.801)
	body.velocity=Vector3(.4,0,-2)
	body.move_and_slide()
	var slide: Dictionary=hang.detect(DT,Vector3.FORWARD)
	check(slide.valid and slide.wall_contact and slide.approach_source=="INPUT","wall-slide intent survives tangential speed")
	body.velocity=Vector3(.4,0,.05)
	check(hang.detect(DT,Vector3.FORWARD).reason=="MOVING_AWAY","wall-contact history cannot override away movement")
	await air_setup()
	body.position.y=.5
	body.velocity=Vector3(0,0,-.05)
	hang.acquisition.prepare_tick(hang,DT,Vector2.ZERO)
	check(hang.detect().valid,"prime candidate before obstruction")
	body.velocity=Vector3.ZERO
	var roof=box(Vector3(200,2.2,9.9),Vector3(1,.1,.3))
	await physics_frame
	var obstructed: Dictionary=hang.detect()
	check(not obstructed.valid and not obstructed.checks["Head / full sweep"],"grace never bypasses new head obstruction")
	roof.queue_free()
	await physics_frame
	# Prime a nearby candidate just outside vertical reach, then coast to zero.
	await air_setup()
	body.position.y=.04
	body.velocity=Vector3(0,2,-.05)
	hang.acquisition.prepare_tick(hang,DT,Vector2.ZERO)
	var prime: Dictionary=hang.detect()
	check(not prime.valid and prime.reason=="VERTICAL_REACH","candidate primed before band, not remotely caught")
	body.position.y=.10
	body.velocity=Vector3.ZERO
	hang.acquisition.prepare_tick(hang,DT,Vector2.ZERO)
	var retained: Dictionary=hang.detect()
	check(retained.valid and retained.grace,".15 second candidate-specific direction grace")
	for frame in 12: hang.acquisition.prepare_tick(hang,DT,Vector2.ZERO)
	check(hang.detect().reason=="NO_APPROACH","grace expires without refreshing itself")
	# A previously valid candidate must not weaken physical/away gates.
	await air_setup()
	body.position.y=.5
	body.velocity=Vector3(0,0,-.05)
	hang.acquisition.prepare_tick(hang,DT,Vector2.ZERO)
	check(hang.detect().valid,"prime physical candidate")
	body.velocity=Vector3(0,0,.05)
	hang.acquisition.prepare_tick(hang,DT,Vector2(0,-1))
	check(hang.detect(DT,Vector3.FORWARD).reason=="MOVING_AWAY","away velocity defeats input and grace")
	body.velocity=Vector3.ZERO
	check(hang.detect().reason=="NO_APPROACH","away clears remembered approach")
	# Historical sweep: previous hand band crossed the edge; prediction now
	# points away vertically. Use a downward reference shift without a floor.
	floor_box.queue_free()
	await physics_frame
	await air_setup()
	body.position.y=.55
	body.velocity=Vector3(0,-35,-.05)
	hang.acquisition.prepare_tick(hang,DT,Vector2.ZERO)
	body.position.y=-.03
	hang.acquisition.prepare_tick(hang,DT,Vector2.ZERO)
	var swept: Dictionary=hang.detect()
	check(swept.valid and swept.sweep_required,"previous-to-current sweep catches missed falling band")
	check(hang.try_catch(DT),"historical sweep commits from current capsule")
	for frame in 20: await crouch_tick(false)
	check(hang.hang_phase==hang.HangPhase.IDLE,"historical correction settles safely")
	await air_setup()
	body.position.y=.5
	hang.acquisition.prepare_tick(hang,DT,Vector2.ZERO)
	body.position.z+=5
	hang.acquisition.prepare_tick(hang,DT,Vector2.ZERO)
	check(hang.acquisition.recent_start==body.position and not hang.detect().valid,"teleport discards swept history")
	# Repeat A/B/C/D/E/F using the real motor on the same 2.25 m wall.
	floor_box=box(Vector3(200,-.25,10),Vector3(30,.5,30))
	await physics_frame
	for repeat_index in 3:
		for scenario in ["A","B","C","D","E","F"]:
			await air_setup()
			body.position=Vector3(200,.02,10.40)
			body.velocity=Vector3.ZERO
			for frame in 8: await crouch_tick(false)
			check(body.ground_support.has_ground_support,"reproduction grounded setup")
			var diagonal: bool=scenario=="D"
			var input:=Vector2(.45,-1).normalized() if diagonal else Vector2(0,-1)
			body.velocity=Vector3(.8 if diagonal else 0,0,-2)
			if scenario=="F":
				body.position.y=1.25
				body.velocity.y=-3
				body.move_and_slide()
				body.ground_support.refresh(0)
			var released:=false
			var repressed:=false
			for frame in 60:
				var stick:=input
				if scenario in ["B","C"] and frame>=1:
					stick=Vector2.ZERO
					released=true
				if scenario=="C" and frame>=3:
					stick=input
					repressed=true
				await crouch_tick(false,stick,false,frame==0 and scenario!="F")
				if hang.running: break
			print("INPUT REPRO ",repeat_index," ",scenario," catch=",hang.running," reason=",hang.result.reason)
			check(hang.running,"motor reproduction "+scenario)
			if scenario in ["B","C"]: check(released,"release happened before catch")
			if scenario=="C": check(repressed,"repress happened before catch")
	print("HANG_INPUT_REPRESS_V2: ","PASS" if failures.is_empty() else str(failures))
	quit(0 if failures.is_empty() else 1)
