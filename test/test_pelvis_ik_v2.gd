extends "res://test/test_player_v2.gd"
var ik: Node
var pelvis: Node

func freeze_at(position: Vector3, frames: int = 90) -> void:
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
	pelvis=ik.pelvis
	print("PELVIS_BONE ",ik.skeleton.get_bone_name(pelvis.bone)," index=",pelvis.bone," parent=",ik.skeleton.get_bone_parent(pelvis.bone))
	check(pelvis.bone==0 and ik.skeleton.get_bone_parent(0)==-1,"verified root Hips")
	check(pelvis.get_index()<ik.legs[0].solver.get_index(),"pelvis before legs")
	for fixture in [Vector3(0,0.001,20),Vector3(51.5,0.15,0),Vector3(57.5,0.20,0),Vector3(56,0.201,0),Vector3(100,0.22,-25),Vector3(13,3.1,-20)]:
		ik.pelvis_enabled=false
		await freeze_at(fixture)
		var before: float=absf(ik.legs[1].solved.y-ik.feet.right.ankle_target_transform.origin.y)
		ik.pelvis_enabled=true
		await freeze_at(fixture)
		print("PELVIS_FIXTURE ",fixture," offset=",pelvis.current_offset," lower foot error=",before," -> ",absf(ik.legs[1].solved.y-ik.feet.right.ankle_target_transform.origin.y)," support=",pelvis.support)
		check(pelvis.current_offset<=0 and pelvis.current_offset>=-ik.pelvis_drop_limit(),"bounded downward only")
		check(body.position.is_equal_approx(fixture),"no physical displacement")
		var saved: float=pelvis.current_offset
		await freeze_at(fixture,180)
		check(absf(saved-pelvis.current_offset)<0.0001,"no frozen-pose drift or oscillation")
		if fixture.x==51.5 or fixture.x==57.5:
			check(absf(ik.legs[1].solved.y-ik.feet.right.ankle_target_transform.origin.y)<before,"lower foot reach improves")
		if fixture.x==0 or fixture.x==56: check(absf(pelvis.current_offset)<0.015,"flat/top returns near neutral")
		if fixture.x==13: check(pelvis.support[1]==0,"invalid foot excluded")
	# Existing landing sink consumes the downward budget rather than stacking.
	await freeze_at(Vector3(57.5,0.20,0))
	animation.land_visual_offset=-0.25
	pelvis.prepare(DT)
	check(pelvis.applied_offset==0,"landing sink suppresses extra pelvis drop")
	animation.land_visual_offset=0
	body.animation_state.is_grounded=false
	body.animation_state.is_airborne=true
	var old: float=pelvis.current_offset
	for frame in 60:
		tree.advance(0)
		await process_frame
		check(absf(pelvis.current_offset)<=absf(old)+0.00001,"airborne fade monotonic")
		old=pelvis.current_offset
	check(pelvis.current_offset==0,"airborne neutral")
	await settle(Vector3(0,0.05,20))
	await tick(Vector2.ZERO,false,true)
	for frame in 150:
		await tick()
		var sink: float=minf(animation.land_visual_offset,0)
		check(sink+pelvis.applied_offset>=minf(sink,pelvis.current_offset)-0.00001,"real landing shares drop budget")
	check(absf(pelvis.current_offset)<0.02,"jump/land returns near neutral")
	await settle(Vector3(100,0.05,-20))
	for frame in 150:
		await tick(Vector2(0,-1))
		for leg in ik.legs: check(leg.knee_stable and leg.length_error<0.002,"ramp walking stable")
	for gait in 3:
		for stair in 3:
			for down in [false,true]:
				body.step_solver.cancel()
				await settle(Vector3(42+stair*10,6*(0.1+stair*0.05)+0.05 if down else 0.05,-29.5 if down else -18))
				body.visual.rotation.y=PI if down else 0
				body._run_time=4 if gait==2 else 0
				var max_delta:=0.0
				for frame in 200:
					old=pelvis.current_offset
					await tick(Vector2(0,1 if down else -1),gait>0)
					max_delta=maxf(max_delta,absf(old-pelvis.current_offset))
					for leg in ik.legs:
						check(leg.knee_stable and leg.length_error<0.002,"stable knee and limb length")
					check(pelvis.current_offset<=0 and pelvis.current_offset>=-0.20,"dynamic drop bounded")
					if (down and body.position.z> -20) or (not down and body.position.z< -29): break
				print("PELVIS_STAIRS gait=",gait," riser=",stair," down=",down," max_frame_delta=",max_delta)
				check(max_delta<0.03,"smooth procedural pelvis displacement")
				check(body.position.z> -20 if down else body.position.z< -29,"stairs traversed")
	print("PELVIS_IK_V2: ","PASS" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)
