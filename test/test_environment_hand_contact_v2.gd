extends "res://test/test_roll_traversal_v2.gd"
var hands: Node
var arm_ik: Node

func reset_contact() -> void:
	arm_ik.enabled=false
	await reset_at(Vector3(200,.1,10))
	# Separate scenarios must allow the genuine-release global cooldown to expire.
	for frame in 135: await roll_tick()
	arm_ik.enabled=true

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
	hands=body.get_node("EnvironmentalHandInteraction")
	arm_ik=body.get_node("EnvironmentalHandIK")
	body.set_physics_process(false)
	animation.set_physics_process(false)
	cam.set_process(false)
	tree.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	box(Vector3(200,-.25,0),Vector3(80,.5,80))
	for side in [-1,1]:
		await reset_contact()
		var wall:=box(Vector3(200+side*.62,1.1,0),Vector3(.12,2.2,30))
		for frame in 30: await roll_tick()
		check(not arm_ik.environment_hand_contact_active,"Idle cannot acquire")
		var minimum_palm:=INF
		var contacts:=0
		var first:=Vector3.ZERO
		for frame in 80:
			await roll_tick(Vector2(0,-1))
			if arm_ik.environment_hand_contact_active:
				contacts+=1
				if contacts==1: first=arm_ik.contact_world_position
				var distance: float=(arm_ik.contact_world_position-arm_ik.contact_hit_position).dot(arm_ik.contact_surface_normal)
				check(absf(distance-arm_ik.hand_palm_clearance)<.00001,"palm target stays projected on offset plane")
				var arm=arm_ik.arms[arm_ik.active_side]
				minimum_palm=minf(minimum_palm,(arm.palm-arm_ik.contact_hit_position).dot(arm_ik.contact_surface_normal))
		check(contacts>65,"sustained wall contact")
		check(first.distance_to(arm_ik.contact_world_position)>body.walk_speed*.9,"contact slides with configured walking speed, not a world lock")
		check(minimum_palm>=0,"palm model remains outside plane")
		var acquisitions: int=arm_ik.contact_acquisitions
		for frame in 30: await roll_tick(Vector2(0,-1))
		check(arm_ik.environment_hand_contact_active,"continued Walk maintains contact")
		arm_ik.hand_palm_clearance=.08
		for frame in 4: await roll_tick(Vector2(0,-1))
		check(absf((arm_ik.contact_world_position-arm_ik.contact_hit_position).dot(arm_ik.contact_surface_normal)-.08)<.0001,"Inspector clearance updates held contact")
		arm_ik.hand_palm_clearance=.05
		for frame in 15: await roll_tick()
		check(not arm_ik.environment_hand_contact_active and arm_ik.arms[0].weight==0 and arm_ik.arms[1].weight==0,"Idle releases and becomes animation-only")
		for frame in 15: await roll_tick(Vector2(0,-1))
		check(arm_ik.contact_acquisitions==acquisitions and arm_ik.active_side==-1,"Idle to Walk respects release cooldown")
		print("CONTACT side=",side," minimum_palm=",minimum_palm," acquisitions=",acquisitions)
		for frame in 40: await roll_tick(Vector2(-side,0))
		check(not arm_ik.environment_hand_contact_active,"walking away releases")
		wall.free()
	for gate in ["run","lock","dodge","jump"]:
		await reset_contact()
		var wall:=box(Vector3(199.38,1.1,0),Vector3(.12,2.2,30))
		for frame in 20: await roll_tick(Vector2(0,-1))
		if gate=="lock":
			dummy.position=Vector3(200,0,0)
			lock.toggle()
		await roll_tick(Vector2(0,-1),gate=="run",gate=="jump",gate=="dodge")
		check(not arm_ik.environment_hand_contact_active,"state immediately releases contact: "+gate)
		for frame in 15: await roll_tick(Vector2(0,-1),gate=="run")
		check(arm_ik.arms[0].weight==0,"incompatible state fades arm to zero")
		wall.free()
	await reset_contact()
	var end:=box(Vector3(199.38,1.1,9),Vector3(.12,2.2,3))
	var acquired:=false
	for frame in 100:
		await roll_tick(Vector2(0,-1))
		acquired=acquired or arm_ik.environment_hand_contact_active
	check(acquired and not arm_ik.environment_hand_contact_active and arm_ik.arms[0].weight==0,"wall end releases without floating hand")
	end.free()
	await reset_contact()
	var pillar:=box(Vector3(199.38,1.1,8),Vector3(.14,2.2,.4))
	acquired=false
	for frame in 95:
		await roll_tick(Vector2(0,-1))
		acquired=acquired or arm_ik.environment_hand_contact_active
	check(acquired and not arm_ik.environment_hand_contact_active,"pillar pass releases instead of wrapping")
	pillar.free()
	await reset_contact()
	var wall:=box(Vector3(199.38,1.1,0),Vector3(.12,2.2,30))
	for frame in 20: await roll_tick(Vector2(0,-1))
	# Inject a changed normal into the existing sensor record to exercise the
	# contact policy independently of the shape-cast's own face rejection.
	hands.left.raw_normal=Vector3.FORWARD
	arm_ik.update_contact(DT)
	check(not arm_ik.environment_hand_contact_active,"sharp normal/body change releases")
	wall.free()
	await reset_contact()
	var pieces: Array[Node]=[]
	for i in 14: pieces.append(box(Vector3(199.38+(.025 if i%2==0 else -.025),1.1,10-i*.5),Vector3(.12,2.2,.5)))
	var contact_frames:=0
	for frame in 75:
		await roll_tick(Vector2(0,-1))
		if arm_ik.environment_hand_contact_active:
			contact_frames+=1
			check(absf((arm_ik.contact_world_position-arm_ik.contact_hit_position).dot(arm_ik.contact_surface_normal)-arm_ik.hand_palm_clearance)<.0001,"uneven-wall plane projection")
	check(contact_frames>0 and arm_ik.contact_acquisitions>0,"uneven wall permits touch then conservative corner release")
	print("UNEVEN_CONTACT frames=",contact_frames," reason=",arm_ik.contact_release_reason)
	for piece in pieces: piece.free()
	print("ENVIRONMENT_HAND_CONTACT_V2: ","PASS" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)
