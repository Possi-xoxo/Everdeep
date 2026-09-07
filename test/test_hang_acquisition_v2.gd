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
	var wall=box(Vector3(200,1,8.35),Vector3(4,4,2))
	await physics_frame
	check(is_equal_approx(hang.acquisition.jump_threshold(body),1.7),"threshold derives 1.7 without changing jump")
	check(body.jump_velocity==8 and body.rise_gravity==19.6,"jump tuning unchanged")
	await air_setup()
	var started:=Time.get_ticks_usec()
	for repetition in 100: hang.detect()
	print("HANG QUERY mean usec: ",(Time.get_ticks_usec()-started)/100.0)
	for vertical in [5.0,-5.0]:
		for lateral in [-3.0,0.0,3.0]:
			await air_setup()
			body.velocity=Vector3(lateral,vertical,-2)
			body.visual.rotation.y=deg_to_rad(85) # deliberately differs from motion
			var c: Dictionary=hang.detect()
			check(c.valid,"rising/falling diagonal and imperfect facing "+str([vertical,lateral,c.reason]))
			check(hang.try_catch(DT),"diagonal catch commits")
			hang.hang_debug=true
			hang.detection_visual._process(DT)
			check(hang.detection_visual.retained_result.get("valid",false),"accepted snapshot survives immediate state commitment")
			hang.hang_debug=false
			for frame in 20: await crouch_tick(false)
			check(hang.hang_phase==hang.HangPhase.IDLE,"diagonal catch settles")
	for vertical in [-35.0,8.0]:
		await air_setup()
		body.position.y=1.25+(.70 if vertical<0 else -.60)
		body.velocity=Vector3(0,vertical,-2)
		# Large physics interval deliberately crosses beyond instantaneous band.
		var sweep: Dictionary=hang.detect(.05)
		check(sweep.valid,"fast pass swept candidate "+str([vertical,sweep.reason]))
		var saved: float=hang.predictive_distance
		hang.predictive_distance=0
		check(not hang.detect(.05).valid,"fast pass outside instantaneous reach")
		hang.predictive_distance=saved
		check(hang.try_catch(.05),"fast pass actually commits")
		for frame in 20: await crouch_tick(false)
		check(hang.hang_phase==hang.HangPhase.IDLE,"fast pass settles without blocked correction")
	await air_setup()
	body.visual.rotation.y=PI
	check(hang.detect().reason=="BEHIND","behind rejection is explicit")
	await air_setup(0,0,true)
	check(hang.detect().reason=="MOVING_AWAY","away rejection even with wall-facing")
	body.animation_state.move_input_magnitude=1
	body.animation_state.move_direction_world=Vector3.FORWARD
	check(not hang.detect().valid,"input cannot override actual away velocity")
	body.velocity=Vector3.ZERO
	check(hang.detect().valid,"input fallback when wall contact removes velocity")
	body.animation_state.move_input_magnitude=0
	check(hang.detect().reason=="NO_APPROACH","stationary with no input rejected")
	await air_setup()
	hang.last_source_id=wall.get_instance_id()
	hang.last_edge=Vector3(200,3,9.35)
	hang.cooldown=1
	check(hang.detect().reason=="REGRAB_COOLDOWN","same ledge suppression retained")
	hang.cooldown=0
	var roof=box(Vector3(200,2.85,9.9),Vector3(1,.15,.5))
	await physics_frame
	var blocked: Dictionary=hang.detect()
	check(not blocked.valid and not blocked.checks["Head / full sweep"],"blocked head rejects with diagnostic")
	roof.queue_free()
	wall.queue_free()
	await physics_frame
	var floor_box=box(Vector3(200,-.25,10),Vector3(20,.5,20))
	for height in [1.65,1.7,1.85,2.0,2.25,2.4]:
		wall=box(Vector3(200,height*.5,8.35),Vector3(4,height,2))
		await air_setup()
		body.position.y=maxf(.03,height-1.75)
		body.velocity=Vector3(0,2,-2)
		var c: Dictionary=hang.detect()
		check(c.valid==(height>1.7),"height eligibility "+str([height,c.reason]))
		if height<=1.7: check(c.reason=="BELOW_JUMP_HEIGHT","threshold rejection first")
		else:
			check(hang.try_catch(DT),"overlap ledge commits above real floor")
			for frame in 20: await crouch_tick(false)
			check(hang.hang_phase==hang.HangPhase.IDLE,"overlap ledge settles above real floor")
			body.traversal.finish("TEST_RESET")
		wall.queue_free()
		await physics_frame
	floor_box.queue_free()
	wall=box(Vector3(200,2.875,8.35),Vector3(4,.25,2))
	await air_setup()
	var thin: Dictionary=hang.detect()
	check(not thin.valid and not thin.checks.Brace,"no brace rejected")
	check(not hang.hang_debug and not hang.detection_visual.display.visible,"debug default off")
	hang.hang_debug=true
	hang.result=hang.detect()
	hang.detection_visual._process(DT)
	check(hang.detection_visual.display.visible and hang.detection_visual.mesh.get_surface_count()==1,"debug mesh built")
	check(hang.acquisition.debug_text(hang).contains("Brace: FAIL"),"HUD reports physical failure")
	var input_event:=InputEventKey.new()
	input_event.physical_keycode=KEY_F3
	input_event.pressed=true
	input_event.ctrl_pressed=true
	body.get_node("DebugCanvas")._unhandled_key_input(input_event)
	check(not hang.hang_debug,"Ctrl+F3 toggles detailed debug")
	body.get_node("DebugCanvas")._unhandled_key_input(input_event)
	body.position.z=15
	hang.result=hang.detect()
	hang.detection_visual._process(DT)
	check(not hang.detection_visual.retained.is_empty(),"short debug persistence")
	hang.hang_debug=false
	hang.detection_visual._process(DT)
	check(not hang.detection_visual.display.visible,"debug toggle hides geometry")
	var lanes=load("res://test/traversal_playground/hang_acquisition_lanes.tscn").instantiate()
	root.add_child(lanes)
	check(lanes.has_node("AboveThreshold") and lanes.has_node("FastFallRamp") and lanes.has_node("BlockedRoof"),"permanent controlled fixtures load")
	print("HANG_ACQUISITION_V2: ","PASS" if failures.is_empty() else str(failures))
	quit(0 if failures.is_empty() else 1)
