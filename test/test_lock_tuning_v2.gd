extends "res://test/test_player_v2.gd"
var lock: Node
var dummy: Node3D
var cam: Node3D

func tick(stick := Vector2.ZERO, shift := false, jump := false) -> void:
	await super.tick(stick,shift,jump)
	cam._process(DT)
	await process_frame

func reset_fixture() -> void:
	lock.clear()
	body.step_solver.cancel()
	dummy.position=Vector3(0,0,8)
	await settle(Vector3(0,0.1,16))
	cam.yaw.rotation.y=0
	cam.pitch.rotation.x=deg_to_rad(-12)
	lock.toggle()
	check(lock.is_locked(),"tuning fixture acquired")

func run() -> void:
	root.size=Vector2i(1280,720)
	var lab=load("res://test/player_v2_lab.tscn").instantiate()
	root.add_child(lab)
	body=lab.get_node("PlayerV2")
	animation=body.get_node("AnimationController")
	tree=body.get_node("AnimationTree")
	lock=body.get_node("LockOnController")
	dummy=lab.get_node("LockOnTargetDummy")
	cam=body.get_node("CameraRig")
	body.set_physics_process(false)
	animation.set_physics_process(false)
	cam.set_process(false)
	tree.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	await reset_fixture()
	cam.yaw.rotation.y=1.2
	var before: Vector3=body.camera.global_position
	await tick()
	check(body.camera.global_position.distance_to(before)<0.5,"camera entry no position snap")
	for i in 120: await tick()
	check((body.camera.global_position-body.position).dot(lock.direction())< -3.5,"locked camera behind player")
	check((-body.camera.global_basis.z).dot(lock.direction())>0.97,"locked camera faces target")
	Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	var motion:=InputEventMouseMotion.new()
	motion.relative=Vector2(180,100)
	var yaw_before: float=cam.yaw.rotation.y
	var pitch_before: float=cam.pitch.rotation.x
	cam.apply_mouse_motion(motion.relative)
	check(cam.yaw.rotation.y==yaw_before and cam.pitch.rotation.x==pitch_before,"locked mouse orbit suppressed")
	for i in 400:
		await tick(Vector2(1,0),true)
		check((body.camera.global_position-body.position).dot(lock.direction())< -2.5,"camera follows circling behind player")
	check(not body.camera.is_position_behind(lock.point()),"circling target ahead of camera")
	var screen: Vector2=body.camera.unproject_position(lock.point())
	print("LOCK_CAMERA_FRAME target=",screen," viewport=",root.size)
	check(Rect2(Vector2.ZERO,root.size).has_point(screen),"circling target in frame")
	for elevation in [8.0,-8.0]:
		dummy.position.y=elevation
		for i in 90: await tick()
		check(cam.pitch.rotation.x<=deg_to_rad(cam.lock_camera_max_pitch_up)+0.001,"pitch up bounded")
		check(cam.pitch.rotation.x>=-deg_to_rad(cam.lock_camera_max_pitch_down)-0.001,"pitch down bounded")
		check(not body.camera.is_position_behind(lock.point()),"elevated target remains ahead")
	lock.clear()
	yaw_before=cam.yaw.rotation.y
	await tick()
	check(absf(cam.yaw.rotation.y-yaw_before)<0.001,"unlock keeps current yaw")
	cam.apply_mouse_motion(motion.relative)
	check(absf(cam.yaw.rotation.y-yaw_before)>0.05,"free mouse orbit restored")
	for i in 45: await tick()
	check(cam.position.is_equal_approx(Vector3(0,1.55,0)) and absf(cam.arm.spring_length-cam.selected_distance())<0.01,"free anchor and selected distance restored")
	# Existing SpringArm must retract, not a camera transform bypass.
	await reset_fixture()
	var wall:=StaticBody3D.new()
	var collision:=CollisionShape3D.new()
	var shape:=BoxShape3D.new()
	shape.size=Vector3(8,6,0.4)
	collision.shape=shape
	wall.add_child(collision)
	lab.add_child(wall)
	wall.position=Vector3(0,2,18)
	for i in 90: await tick()
	print("LOCK_CAMERA_COLLISION length=",cam.arm.get_hit_length()," position=",body.camera.global_position)
	check(cam.arm.get_hit_length()<2.0,"SpringArm retracts against wall")
	check(body.camera.global_position.z<17.8,"camera stays in front of wall")
	wall.free()
	# These are exported Inspector values, set independently at runtime.
	for spec in [["lock_walk_backward_speed",Vector2(0,1),false,2.8],["lock_walk_strafe_speed",Vector2(1,0),false,3.2],["lock_run_forward_speed",Vector2(0,-1),true,5.5],["lock_run_backward_speed",Vector2(0,1),true,4.5],["lock_run_strafe_speed",Vector2(1,0),true,5.0]]:
		await reset_fixture()
		body.set(spec[0],spec[3])
		for i in 35: await tick(spec[1],spec[2])
		check(absf(body.animation_state.horizontal_speed-spec[3])<0.03,"Inspector directional speed: "+spec[0])
	check(is_equal_approx(body.locked_speed(Vector2(1,1).normalized(),false),3.6),"diagonal interpolates speeds without adding")
	check(is_equal_approx(body.locked_speed(Vector2(1,-1).normalized(),false),3.0),"back diagonal blends independently")
	await reset_fixture()
	animation.lock_direction_blend_speed=1.0
	for i in 40: await tick(Vector2(0,-1))
	var combat=animation.grounded.combat
	var old_blend: Vector2=combat.move_blend
	await tick(Vector2(1,0))
	check(body.animation_state.combat_input.x==1 and combat.move_blend.distance_to(old_blend)<0.04,"raw physics input independent of animation smoothing")
	animation.lock_walk_to_run_blend=0.5
	for i in 6: await tick(Vector2(1,0),true)
	check(combat.gait_blend>1.0 and combat.gait_blend<1.5,"Walk Run blend duration honored")
	for i in 40: await tick(Vector2(1,0),true)
	check(is_equal_approx(combat.gait_blend,2.0),"Walk Run blend reaches target")
	var saved: Vector2=combat.move_blend
	for point in [Vector2(0,1),Vector2(0,-1),Vector2(-1,0),Vector2(1,0),Vector2(0.7,0.7),Vector2.ZERO]:
		combat.move_blend=point
		var weights: Vector4=combat.direction_weights()
		check(is_equal_approx(weights.x+weights.y+weights.z+weights.w,1.0),"debug triangulation weights sum to one")
	combat.move_blend=Vector2(0,-1)
	check(combat.direction_weights().y>0.999,"backward blend reports backward weight")
	combat.move_blend=saved
	animation.lock_animation_enter_blend=0.28
	animation.lock_animation_exit_blend=0.31
	await tick()
	var machine=tree.tree_root.get_node("Locomotion")
	for i in machine.get_transition_count():
		if machine.get_transition_to(i)==&"Locked": check(is_equal_approx(machine.get_transition(i).xfade_time,0.28),"Inspector enter blend")
		elif machine.get_transition_from(i)==&"Locked": check(is_equal_approx(machine.get_transition(i).xfade_time,0.31),"Inspector exit blend")
	print("LOCK_TUNING_V2: ","PASS" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)
