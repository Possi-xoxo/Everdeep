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
	var wall=box(Vector3(200,1,8.35),Vector3(12,4,2))
	await air_setup()
	check(hang.try_catch(DT),"lateral fixture catch")
	for frame in 30: await crouch_tick(false)
	var original: Vector3=hang.alignment
	var raw_rig=load("res://Characters/Player/Models/Blender Master Rig.glb").instantiate()
	var raw_player: AnimationPlayer=raw_rig.find_children("*","AnimationPlayer",true,false)[0]
	for name in hang.lateral.CLIPS:
		var info: Dictionary=hang.lateral.motion.measurements[name]
		print("AUTHORED ",name," ",info)
		check(not str(hang.lateral.CLIPS[name]).contains("FREE_HANG"),"only braced clips assigned")
		var runtime: Animation=animation.player.get_animation(hang.lateral.CLIPS[name])
		var track: int=hang.hip_track(runtime)
		for key in runtime.track_get_key_count(track):
			check(Vector3(runtime.track_get_key_value(track,key)).distance_to(runtime.track_get_key_value(track,0))<.00001,"root compensated in all axes")
		if name.begins_with("HangHop"):
			check(absf(hang.lateral.travel_distance(hang,-1 if name.ends_with("Left") else 1,true)-float(info.raw_lateral_m))<.00001,"hop uses exact authored distance without common scaling")
			var raw: Animation=raw_player.get_animation(hang.lateral.CLIPS[name])
			var first: Vector3=raw.position_track_interpolate(track,0)
			var last: Vector3=raw.position_track_interpolate(track,raw.length)
			for i in range(241):
				var p: float=float(i)/240
				var value: Vector3=raw.position_track_interpolate(track,raw.length*p)
				var sample: Vector3=hang.lateral.motion.sample(name,p)
				check(absf(sample.x-(value.x-first.x)/(last.x-first.x))<.0001,"hop lateral follows authored samples")
				check(absf(sample.y+(value.z-first.z-(last.z-first.z)*p)/100)<.0001,"hop vertical follows authored samples")
		else: check(float(info.derived_distance_m)>.45 and float(info.derived_distance_m)<.65,"shimmy support-derived travel baseline")
	raw_rig.free()
	var overhead=box(original+Vector3(0,2.1,0),Vector3(6,.1,2))
	await physics_frame
	check(not hang.lateral.request(hang,1,true),"ceiling on authored arc rejects before commitment")
	overhead.queue_free()
	await physics_frame
	for hop in [false,true]:
		for side in [-1,1]:
			var start: Vector3=hang.alignment
			check(hang.lateral.request(hang,side,hop),"lateral commits")
			var expected: StringName=hang.lateral.state
			check(not hang.request_up() and not hang.request_release(),"W/S locked during lateral")
			check(not hang.lateral.request(hang,-side,not hop),"direction/modifier cannot change committed move")
			var samples: int=0
			var minimum_foot_gap: float=1
			var saw_contact: bool=false
			var saw_release: bool=false
			for frame in 150:
				await crouch_tick(false)
				if not hang.lateral.active: break
				check(animation.current_state==expected,"correct animation no restart")
				check(absf(hang.idle_pose.offset+.10)<.0001,"shared visual baseline continuous during lateral actions")
				check(body.global_position.distance_to(hang.lateral.expected_position)<.001,"body follows sampled trajectory")
				check(not cam.mantle_camera_active,"normal hang camera retained")
				for arm in body.get_node("MantleHandIK").arms:
					check(arm.length_error<.005,"no arm stretch")
					saw_contact=saw_contact or arm.weight>.5
					saw_release=saw_release or arm.weight<.1
				for leg in body.get_node("FootIKController").legs:
					minimum_foot_gap=minf(minimum_foot_gap,(leg.solved_toe-hang.wall_point).dot(hang.wall_normal))
				samples+=1
			check(samples>20 and not hang.lateral.active,"action completes")
			print("LATERAL ",expected," minimum toe gap=",minimum_foot_gap)
			check(minimum_foot_gap>-.025,"no major wall penetration")
			check(saw_contact and saw_release,"hands contact and release without permanent pinning")
			check(hang.hang_phase==hang.HangPhase.IDLE,"returns stable idle")
			var distance: float=hang.lateral.travel_distance(hang,side,hop)
			check(hang.alignment.distance_to(start+hang.facing.cross(Vector3.UP)*side*distance)<.001,"exact authoritative distance")
		var expected_pair: Vector3=original+hang.facing.cross(Vector3.UP)*(hang.lateral.travel_distance(hang,1,hop)-hang.lateral.travel_distance(hang,-1,hop))
		check(hang.alignment.distance_to(expected_pair)<.001,"no drift beyond authored left/right distance difference")
	# Same source end rejection and intervening obstruction.
	check(not hang.lateral.query(hang,1,7).valid,"ledge end rejects")
	var block=box(hang.alignment+hang.facing.cross(Vector3.UP)*.8+Vector3.UP*.9,Vector3(.15,1.8,1))
	await physics_frame
	check(not hang.lateral.request(hang,1,true),"obstructed hop rejects")
	check(hang.hang_phase==hang.HangPhase.IDLE,"reject stays idle")
	block.queue_free()
	await physics_frame
	# Continuous hold repeats without restarting each tick; Shift next action only.
	for frame in 190: await crouch_tick(false,Vector2(1,0),false)
	check(hang.alignment.distance_to(original)>.6,"hold repeats shimmies")
	for frame in 150:
		await crouch_tick(false)
		if not hang.lateral.active: break
	check(hang.request_up(),"pull-up still works after lateral")
	for frame in 130: await crouch_tick(crouch.requested)
	check(hang.exit_reason=="HANG_TO_CROUCH_COMPLETED","lateral then pull-up completes")
	await air_setup()
	check(hang.try_catch(DT),"dynamic obstruction fixture")
	for frame in 30: await crouch_tick(false)
	check(hang.lateral.request(hang,1,true),"hop initially clear")
	for frame in 10: await crouch_tick(false)
	block=box(original+Vector3(.8,.9,0),Vector3(.15,1.8,1))
	await physics_frame
	for frame in 130:
		await crouch_tick(false)
		if not hang.lateral.active: break
	check(hang.running and hang.hang_phase==hang.HangPhase.IDLE,"new obstacle stops safely in hang")
	block.queue_free()
	await physics_frame
	# Internal gap within the SAME collider must not permit a transfer.
	wall.get_child(0).queue_free()
	for spec in [Vector2(-2.2,5.6),Vector2(3.4,5.2)]:
		var collision:=CollisionShape3D.new()
		var shape:=BoxShape3D.new()
		shape.size=Vector3(spec.y,4,2)
		collision.shape=shape
		collision.position.x=spec.x
		wall.add_child(collision)
	await physics_frame
	check(not hang.lateral.query(hang,1,1.4).valid,"same-collider gap rejects full travel")
	wall.queue_free()
	print("HANG_LATERAL_V2: ","PASS" if failures.is_empty() else str(failures))
	quit(0 if failures.is_empty() else 1)
