extends "res://test/test_dodge_v2.gd"
var lab: Node3D
var assist: Node

func box(pos: Vector3,size: Vector3) -> StaticBody3D:
	var node:=StaticBody3D.new()
	var collision:=CollisionShape3D.new()
	var shape:=BoxShape3D.new()
	shape.size=size
	collision.shape=shape
	node.add_child(collision)
	lab.add_child(node)
	node.position=pos
	return node

func reset_at(pos:=Vector3(200,.1,3.5)) -> void:
	lock.clear()
	dodge.finish()
	dodge.cooldown=0
	assist.cancel()
	body.step_solver.cancel()
	body.turn_180.cancel()
	body._run_time=0
	body.visual.rotation.y=0
	cam.get_node("YawPivot").rotation.y=0
	await settle(pos)

func obstacle(height: float, running: bool, width:=6.0, ceiling:=false) -> void:
	await reset_at()
	var ledge:=box(Vector3(200,height/2,-13),Vector3(width,height,30))
	var roof: StaticBody3D
	if ceiling: roof=box(Vector3(200,2.3,2),Vector3(6,.2,8))
	await physics_frame
	var before: int=assist.steps_started
	await roll_tick(Vector2(0,-1),running,false,true)
	var highest:=body.position.y
	for frame in 180:
		var y:=body.position.y
		await roll_tick(Vector2(0,-1),running)
		highest=maxf(highest,body.position.y)
		check(assist.last_lift_rise<=assist.roll_step_up_speed*DT+.002,"collision-swept assist bounded per tick")
		if body.position.y-y>assist.roll_step_up_speed*DT+.002: print("ROLL_CONTACT_RISE total=",body.position.y-y," assist=",assist.last_lift_rise)
		check(body.velocity.y<=.01,"no positive launch velocity")
		if not dodge.is_dodging: break
	var accepted: bool=height<=.70 and width>1 and not ceiling
	check((assist.steps_started>before)==accepted,"ledge validity height=%s width=%s roof=%s" % [height,width,ceiling])
	if accepted:
		check(highest>=height-.01 and body.position.z<1.5,"roll reaches valid top")
	else:
		check(highest<.02 and body.position.z>2.3,"rejected obstacle cannot be climbed")
	print("ROLL_LEDGE h=",height," run=",running," width=",width," roof=",ceiling," assists=",assist.steps_started-before," max_y=",highest," end=",body.position," reason=",assist.reason)
	ledge.free()
	if roof!=null: roof.free()

func drop(height: float, running: bool) -> void:
	var platform:=box(Vector3(200,height/2,4),Vector3(8,height,3))
	await reset_at(Vector3(200,height+.1,3.5))
	var land_before: int=animation.landing_count
	await roll_tick(Vector2(0,-1),running,false,true)
	var left_floor:=false
	var fell:=false
	var recontact:=false
	for frame in 240:
		await roll_tick(Vector2(0,-1),running)
		if not dodge.is_dodging: break
		check(animation.current_state in [&"DodgeStand",&"DodgeRun"],"active roll presentation survives drop/contact")
		if not body.is_on_floor():
			left_floor=true
			check(dodge.dodge_airborne,"airborne state published")
			fell=fell or body.velocity.y<-.1
		elif left_floor: recontact=true
		for leg in ik.legs:
			if dodge.dodge_progress>.3: check(leg.weight<.01,"roll suppresses terrain IK across flight")
	check(not dodge.is_dodging,"air roll eventually completes")
	check(animation.landing_count==land_before,"landing cannot interrupt active roll")
	if height>=1: check(left_floor and fell,"gravity continues after floor loss")
	if height>=60:
		check(animation.current_state==&"Fall" and not body.is_on_floor(),"roll exits to Fall while still airborne")
		var starts: int=dodge.starts
		await roll_tick(Vector2.ZERO,false,false,true)
		check(dodge.starts==starts,"no aerial dodge start")
	elif height>=1: check(recontact,"shallow landing occurs during roll")
	print("ROLL_DROP h=",height," run=",running," airborne=",left_floor," landed_in_roll=",recontact," end_state=",animation.current_state)
	platform.free()

func run() -> void:
	lab=load("res://test/player_v2_lab.tscn").instantiate()
	root.add_child(lab)
	root.size=Vector2i(1280,720)
	body=lab.get_node("PlayerV2")
	animation=body.get_node("AnimationController")
	tree=body.get_node("AnimationTree")
	lock=body.get_node("LockOnController")
	dummy=lab.get_node("LockOnTargetDummy")
	ik=body.get_node("FootIKController")
	cam=body.get_node("CameraRig")
	dodge=body.dodge
	assist=body.roll_traversal
	body.set_physics_process(false)
	animation.set_physics_process(false)
	cam.set_process(false)
	tree.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	box(Vector3(200,-.25,0),Vector3(80,.5,80))
	for running in [false,true]:
		for h in [.3,.5,.7,.75,.8,4.0]: await obstacle(h,running)
		await obstacle(.7,running,.25)
		await obstacle(.7,running,6,true)
		for h in [.2,1.0,60.0]: await drop(h,running)
	# Ordinary locomotion retains its own threshold and fails on the .7 ledge.
	await reset_at()
	var tall:=box(Vector3(200,.35,-13),Vector3(6,.7,30))
	for frame in 60: await roll_tick(Vector2(0,-1),true)
	check(body.position.y<.02 and body.position.z>2.3 and is_equal_approx(body.step_solver.max_step_height,.35),"ordinary 35cm solver unchanged")
	tall.free()
	# Backstep into a rear ledge cannot acquire the forward roll allowance.
	await reset_at()
	var rear:=box(Vector3(200,.35,7),Vector3(6,.7,4))
	var before: int=assist.steps_started
	await roll_tick(Vector2.ZERO,false,false,true)
	await finish_roll()
	check(assist.steps_started==before and body.position.y<.02,"Backstep never starts roll assist")
	rear.free()
	# Recovery cannot start an assist, but an already accepted lift may finish.
	await reset_at()
	var ledge:=box(Vector3(200,.35,-13),Vector3(6,.7,30))
	await roll_tick(Vector2(0,-1),true,false,true)
	for frame in 80:
		await roll_tick()
		if assist.active: break
	check(assist.active,"active-lift fixture")
	var zero:=Curve.new()
	zero.add_point(Vector2.ZERO)
	zero.add_point(Vector2(1,0))
	dodge.movement_curve=zero
	for frame in 30: await roll_tick()
	check(not assist.active and body.velocity.y<=0,"accepted lift finishes without indefinite hover when curve falls to zero")
	ledge.free()
	await reset_at(Vector3(200,.1,2.55))
	ledge=box(Vector3(200,.35,-13),Vector3(6,.7,30))
	await physics_frame
	before=assist.steps_started
	await roll_tick(Vector2(0,-1),false,false,true)
	dodge.movement_curve=zero
	for frame in 50: await roll_tick()
	check(assist.steps_started==before and body.position.y<.02,"zero-motion recovery cannot acquire a new lift")
	ledge.free()
	# Locked tangent movement aims into a curb to the left, not toward target.
	await reset_at(Vector3(200,.1,0))
	dummy.position=Vector3(200,0,-8)
	lock.toggle()
	for frame in 40: await roll_tick()
	var side:=box(Vector3(197,.35,0),Vector3(4,.7,20))
	before=assist.steps_started
	await roll_tick(Vector2(-1,0),false,false,true)
	for frame in 65:
		var camera_before: Vector3=cam.global_position
		await roll_tick()
		check(cam.global_position.distance_to(camera_before)<.5,"locked camera has no traversal teleport")
	check(assist.steps_started>before and body.position.x<199 and body.position.y>.65,"locked strafe roll climbs along captured tangent")
	check(lock.is_locked() and absf(body.position.z)<.05,"locked traversal retains target with no targetward bias")
	var point: Vector3=dummy.get_node("LockOnPoint").global_position
	check(not body.camera.is_position_behind(point) and Rect2(Vector2.ZERO,Vector2(root.size)).has_point(body.camera.unproject_position(point)),"locked camera retains target framing on top")
	side.free()
	# Side-only geometry cannot vacuum a forward roll upward.
	await reset_at()
	side=box(Vector3(202,.35,0),Vector3(1,.7,20))
	before=assist.steps_started
	await roll_tick(Vector2(0,-1),false,false,true)
	await finish_roll()
	check(assist.steps_started==before,"no upward vacuum from nearby side surface")
	side.free()
	# Existing stair lane still uses bounded individual assists, never launches.
	for running in [false,true]:
		await reset_at(Vector3(62,.1,-18))
		before=assist.steps_started
		await roll_tick(Vector2(0,-1),running,false,true)
		for frame in 180:
			await roll_tick(Vector2(0,-1),running)
			check(body.velocity.y<=.01,"stair roll never stores launch velocity")
			for leg in ik.legs: check(leg.solved.is_finite(),"stair roll IK finite")
			if not dodge.is_rolling(): break
		check(assist.steps_started>before and body.position.y>1.1,"existing stairs traversed with roll assist")
		print("ROLL_STAIRS run=",running," end=",body.position," assists=",assist.steps_started-before)
	# Removing a validated top during lift must hand back to gravity immediately.
	await reset_at()
	ledge=box(Vector3(200,.35,-13),Vector3(6,.7,30))
	await roll_tick(Vector2(0,-1),true,false,true)
	for frame in 80:
		await roll_tick()
		if assist.active: break
	check(assist.active,"support-removal fixture")
	ledge.free()
	await roll_tick()
	check(not assist.active and body.velocity.y<0,"lost support cancels assist without hovering")
	print("ROLL_TRAVERSAL_V2: ","PASS" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)
