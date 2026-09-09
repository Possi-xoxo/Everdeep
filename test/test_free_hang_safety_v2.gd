extends "res://test/test_free_hang_v2.gd"

func run() -> void:
	await setup_transfer()
	var free=body.traversal.free_hang
	var lip=box(Vector3(200,2.875,-2),Vector3(6,.25,4))
	box(Vector3(200,-.1,1),Vector3(16,.2,12))
	await physics_frame
	await free_catch(Vector3(200,1.1,.65),Vector3(2,-4,-3))
	for tick in 70: await crouch_tick(false)
	check(free.running,"settle fixture")
	# A previous Braced release may still have a render-only fade queued.
	hang.idle_pose.bound=true
	hang.idle_pose.rig_base=free.rig_base_position
	hang.idle_pose.visual_blend=1
	hang.idle_pose.blend=1
	animation._physics_process(DT)
	tree.advance(DT)
	check(animation.rig.position.is_equal_approx(free.rig_base_position),"Free pose excludes residual Braced baseline")
	var targets: Dictionary=free.hand_targets.duplicate()
	# Appearance of brace geometry does not reclassify a committed hang.
	var brace=box(Vector3(200,1.5,-1),Vector3(6,3,2))
	await physics_frame
	await crouch_tick(false,Vector2(1,-1),true,false,true)
	check(free.running and not hang.running,"classification locked after commitment")
	check(free.hand_targets==targets,"incompatible inputs do not move hand anchors")
	brace.queue_free()
	await physics_frame
	# Camera target is the stable reference, not procedural displacement.
	free.swing_offset=Vector3(.04,0,.02)
	body.global_position=free.baseline+free.swing_offset
	cam._process(DT)
	check(cam.global_position.distance_to(free.baseline+body.global_basis*cam._base_position)<.001,"camera excludes swing correction")
	await release_free()
	check(not free.running,"S releases")
	for tick in 100:
		await crouch_tick(false)
		check(not free.running,"no immediate same-ledge reacquisition")
	check(body.ground_support.has_ground_support,"release lands through normal support physics")
	check(animation.current_state!=&"Fall","landing exits Fall presentation")
	# Same-source suppression is not a global ban on another ledge.
	await free_catch(Vector3(200,1.1,.65),Vector3(0,-3,-2))
	for tick in 90: await crouch_tick(false)
	await release_free()
	var previous_source: int=hang.last_source_id
	box(Vector3(210,2.875,-2),Vector3(6,.25,4))
	body.position=Vector3(210,1.1,.65)
	body.velocity=Vector3(0,-2,-2)
	body.ground_support.last_supported_height=0
	body.ground_support.refresh(0)
	await physics_frame
	check(hang.try_catch(DT,Vector3.FORWARD) and free.running,"release permits different ledge")
	check(free.source.get_instance_id()!=previous_source,"new physical source")
	# Genuine contact loss releases, rather than switching hang families.
	free.source.position.y+=.1
	await crouch_tick(false)
	check(not free.running and not body.traversal.is_traversing,"moving source releases safely")
	var blocked=box(Vector3(200,.9,.5),Vector3(.7,1.8,.7))
	await physics_frame
	var invalid: Dictionary=await free_catch(Vector3(200,1.1,.65),Vector3(0,-2,-2))
	check(not invalid.valid,"occupied hanging body space rejected")
	blocked.queue_free()
	lip.queue_free()
	print("FREE HANG SAFETY ","PASS" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)
