extends "res://test/test_player_v2.gd"
var ik: Node
var ramp: StaticBody3D

func run() -> void:
	var lab=load("res://test/player_v2_lab.tscn").instantiate()
	root.add_child(lab)
	body=lab.get_node("PlayerV2")
	animation=body.get_node("AnimationController")
	tree=body.get_node("AnimationTree")
	ik=body.get_node("FootIKController")
	ik.walk_knee_stabilization_enabled=not "--baseline" in OS.get_cmdline_user_args()
	body.set_physics_process(false)
	animation.set_physics_process(false)
	tree.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	ramp=StaticBody3D.new()
	var collision:=CollisionShape3D.new()
	var shape:=BoxShape3D.new()
	shape.size=Vector3(24,0.4,40)
	collision.shape=shape
	ramp.add_child(collision)
	var mesh:=MeshInstance3D.new()
	var box:=BoxMesh.new()
	box.size=shape.size
	mesh.mesh=box
	ramp.add_child(mesh)
	lab.add_child(ramp)
	ramp.position=Vector3(200,12,0)
	for degrees in [0,12,25,35,40]:
		for gait in 3:
			await sample_slope(degrees,gait,Vector2(0,-1))
	await sample_slope(25,0,Vector2(0,1))
	await sample_slope(25,0,Vector2(0.45,-1).normalized())
	await sample_slope(25,0,Vector2(0,-1),true)
	for stair in [1,2]:
		await settle(Vector3(42+stair*10,(stair+1)*0.6+0.1,-29))
		body.visual.rotation.y=PI
		var supported:=0
		for frame in 190:
			await tick(Vector2(0,1))
			await process_frame
			for leg in ik.legs:
				check(leg.length_error<0.002,"descending stair limb length")
				if leg.swing>0.5:
					supported+=1
					check(leg.knee_stable,"descending stair knee plane")
		check(supported>0,"descending stairs exercise supporting knees")
		check(body.position.z> -20,"descending stairs complete")
		print("KNEE_STAIRS riser=",0.10+stair*0.05," support_samples=",supported)
	print("KNEE_STABILITY_V2: ","PASS" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)

func sample_slope(degrees: float,gait: int,stick: Vector2,turning: bool=false) -> void:
	ramp.rotation.x=-deg_to_rad(degrees)
	body.step_solver.cancel()
	body.visual.rotation.y=0 if stick.y<0 else PI
	await settle(Vector3(200,12+tan(deg_to_rad(degrees))*5+0.2/cos(deg_to_rad(degrees))+0.5,5))
	body._run_time=4 if gait==2 else 0
	var inward:=0.0
	var forward:=1.0
	var samples:=0
	var contact:=0.0
	var max_outward:=0.0
	for frame in 100:
		var input:=stick.rotated(float(frame)/100.0*PI*0.6) if turning else stick
		await tick(input,gait>0)
		await process_frame
		if "--render-knee" in OS.get_cmdline_user_args() and degrees==25 and gait==0 and not turning and stick==Vector2(0,-1) and frame==50:
			var camera:=Camera3D.new()
			root.add_child(camera)
			camera.global_position=body.global_position+Vector3(0.8,0.9,-2.5)
			camera.look_at(body.global_position+Vector3.UP*0.6)
			camera.current=true
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("user://knee_walk_%s.png" % ("after" if ik.walk_knee_stabilization_enabled else "before"))
			camera.queue_free()
		for leg in ik.legs:
			check(leg.pole_valid,"non-degenerate pole")
			check(leg.ik_multiplier==1.0,"IK strength unchanged")
			if gait>0: check(leg.pole_guidance==0.0,"Run/Sprint pole path untouched")
			if leg.swing<=0.1: check(leg.pole_guidance==0.0,"swing remains animation driven")
			check(leg.length_error<0.002,"slope preserves leg length")
			check(leg.solved.is_finite(),"slope finite ankle")
			if leg.swing<0.5 or frame<20: continue
			var hip: Vector3=leg.solved_hip
			# Skeleton modifiers are restored after the callback; use captured knee.
			var knee: Vector3=leg.get("solved_knee",ik._world(leg.bones[1]).origin)
			var axis: Vector3=(leg.solved-hip).normalized()
			var bend: Vector3=knee-hip-axis*(knee-hip).dot(axis)
			var outward: Vector3=body.visual.global_basis.x*(-1 if leg.side=="Left" else 1)
			inward=minf(inward,bend.dot(outward))
			max_outward=maxf(max_outward,bend.dot(outward))
			forward=minf(forward,bend.dot(-body.visual.global_basis.z))
			if is_finite(leg.contact_error): contact=maxf(contact,leg.contact_error)
			samples+=1
	check(samples>0,"slope exercises support phase")
	if ik.walk_knee_stabilization_enabled and gait==0:
		check(inward> -0.025,"Walk supporting knee avoids inward collapse")
		if degrees>=25: check(inward> -0.005,"steep Walk inward deviation under 5mm")
		check(forward> -0.005,"Walk knee does not invert backward")
		check(max_outward<0.10,"Walk outward guidance stays modest")
	print("KNEE_SLOPE angle=",degrees," gait=",gait," turning=",turning," stick=",stick," support_samples=",samples," min_outward=",inward," max_outward=",max_outward," min_forward=",forward," max_contact=",contact)
