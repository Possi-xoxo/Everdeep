extends "res://test/test_player_v2.gd"
var lock: Node
var dummy: Node3D
var ik: Node

func run() -> void:
	var lab=load("res://test/player_v2_lab.tscn").instantiate()
	root.add_child(lab)
	body=lab.get_node("PlayerV2")
	animation=body.get_node("AnimationController")
	tree=body.get_node("AnimationTree")
	lock=body.get_node("LockOnController")
	ik=body.get_node("FootIKController")
	dummy=lab.get_node("LockOnTargetDummy")
	body.set_physics_process(false)
	animation.set_physics_process(false)
	tree.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	check(InputMap.has_action("lock_on"),"lock input action exists")
	check(InputMap.action_get_events("lock_on")[0].physical_keycode==KEY_F,"F binding")
	await reset_player()
	await process_frame
	var key:=InputEventKey.new()
	key.physical_keycode=KEY_F
	key.pressed=true
	Input.parse_input_event(key)
	await physics_frame
	body._physics_process(DT)
	key.pressed=false
	Input.parse_input_event(key)
	animation._physics_process(DT)
	tree.advance(DT)
	check(lock.is_locked() and lock.target==dummy,"acquires grouped dummy")
	check(lock.indicator.visible,"indicator enabled")
	for frame in 45: await tick()
	check(tree.get("parameters/Locomotion/playback").get_current_node()==&"Locked","dedicated locked branch")
	check(animation.grounded.combat.label(body.animation_state)=="IDL_IDLE_D","combat idle D")
	for name: String in animation.grounded.combat.CLIPS.values():
		check(animation.player.has_animation(name),"combat clip imported: "+name)
		check(animation.player.get_animation(name).loop_mode==Animation.LOOP_LINEAR,"combat clip loops: "+name)
	var branch=tree.tree_root.get_node("Locomotion").get_node("Locked")
	check(branch.get_blend_point_node(1).get_blend_point_node(1).animation==&"LOC_WALKING_BACKWARDS","corrected backward Walk wired into blend tree")
	check(branch.get_blend_point_node(2).get_blend_point_node(1).animation==&"LOC_RUNNING_BACKWARDS","straight backward Run replaces diagonal placeholder")
	check(branch.get_blend_point_count()==3 and branch.max_space==2,"Locked branch has Idle/Walk/Run only")
	for gait_index in [1,2]:
		var directional=branch.get_blend_point_node(gait_index)
		check(directional.get_blend_point_count()==4,"four combat cardinal directions")
		check(directional.sync_mode==AnimationNodeBlendSpace2D.SYNC_MODE_CYCLIC_MUTABLE,"direction loops phase synchronized")
	var yaw: float=body.visual.global_rotation.y
	body.camera.get_parent().get_parent().get_parent().rotation.y=1.2
	for frame in 20: await tick()
	check(absf(wrapf(body.visual.global_rotation.y-yaw,-PI,PI))<0.01,"camera orbit does not turn body")
	lock.toggle()
	check(not lock.is_locked() and not lock.indicator.visible,"F unlock")
	for frame in 30: await tick()
	check(tree.get("parameters/Locomotion/playback").get_current_node()==&"Loops","returns Free")
	for run in [false,true]:
		for stick in [Vector2(0,-1),Vector2(0,1),Vector2(-1,0),Vector2(1,0),Vector2(-1,-1),Vector2(1,-1),Vector2(-1,1),Vector2(1,1)]:
			await reset_player()
			lock.toggle()
			var initial:=body.position
			for frame in 40:
				await tick(stick,run)
				await process_frame
				check(not body.turn_180.active and not body.turn_arc_active,"locked directions never reverse")
				check(body.animation_state.gait<2 and body._run_time==0,"locked never builds Sprint")
				for leg in ik.legs: check(leg.solved.is_finite() and leg.length_error<0.002,"combat IK finite and length safe")
			check(body.position.distance_to(initial)>1,"combat movement travels")
			check(absf(body.animation_state.horizontal_speed-(6.0 if run else 4.0))<0.02,"normalized combat speed")
			check((-body.visual.global_basis.z).dot(lock.direction())>0.95,"combat faces target")
			if stick.x==0:
				check((body.position.z-initial.z)*stick.y>0,"forward/back moves in requested target relation")
			print("COMBAT_DIRECTION run=",run," input=",stick," clip=",animation.grounded.combat.label(body.animation_state))
	# Multiple revolutions exercise changing target-relative basis and long Shift.
	await reset_player()
	lock.toggle()
	var start_radius:=Vector2(body.position.x-dummy.position.x,body.position.z-dummy.position.z).length()
	var max_error:=0.0
	for frame in 1000:
		await tick(Vector2(1,0),true)
		check(lock.is_locked(),"circle keeps lock")
		check(body.animation_state.gait==1 and body._run_time==0,"long Shift remains Run")
		check(animation.gait_blend<=2 and tree.get("parameters/Locomotion/Loops/blend_position")<=2,"Sprint contribution excluded")
		max_error=maxf(max_error,rad_to_deg(acos(clampf((-body.visual.global_basis.z).dot(lock.direction()),-1,1))))
	var end_radius:=Vector2(body.position.x-dummy.position.x,body.position.z-dummy.position.z).length()
	print("COMBAT_CIRCLE radius=",start_radius," -> ",end_radius," max_facing_error=",max_error)
	check(absf(end_radius-start_radius)<1.5,"circle avoids substantial spiral")
	var momentum:=body.velocity
	lock.toggle()
	check(body.velocity.is_equal_approx(momentum),"unlock does not zero momentum")
	await tick(Vector2(1,0),true)
	check(body.animation_state.horizontal_speed>1,"unlock keeps moving")
	# Enter directly from Sprint, including cancellation of captured pivot state.
	await reset_player()
	body._run_time=4
	await tick(Vector2(0,-1),true)
	check(body.animation_state.gait==2,"Sprint entry fixture")
	var before:=body.velocity
	lock.toggle()
	check(body.animation_state.gait<2 and body._run_time==0,"lock immediately cancels Sprint")
	check(body.velocity.is_equal_approx(before),"lock retains momentum")
	for frame in 30: await tick(Vector2(1,0),true)
	check(tree.get("parameters/Locomotion/playback").get_current_node()==&"Locked","Sprint enters Locked branch")
	await reset_player()
	for frame in 35: await tick(Vector2(0,-1),true)
	await tick(Vector2(0,1),true)
	check(body.turn_180.active,"free reversal still triggers")
	lock.toggle()
	check(not body.turn_180.active and not body.turn_180.resume_pending,"locking cancels active free reversal")
	for frame in 20: await tick(Vector2(0,1),true)
	check(not body.turn_180.active,"locked backpedal does not retrigger reversal")
	await reset_player()
	lock.toggle()
	for frame in 35: await tick(Vector2(1,0),true)
	await tick(Vector2(1,0),true,true)
	check(animation.current_state==&"JumpMoving" and lock.is_locked(),"combat Run uses moving jump")
	for frame in 120: await tick(Vector2(1,0),true)
	check(lock.is_locked() and tree.get("parameters/Locomotion/playback").get_current_node()==&"Locked","moving jump returns Locked")
	await reset_player()
	lock.toggle()
	for frame in 30: await tick()
	await tick(Vector2.ZERO,false,true)
	check(animation.current_state==&"JumpStanding" and lock.is_locked(),"locked jump preserves lock")
	var saw_fall:=false
	for frame in 120:
		await tick()
		saw_fall=saw_fall or animation.current_state==&"Fall"
	check(saw_fall and lock.is_locked(),"locked Fall and landing")
	check(animation.current_state==&"Locomotion" and tree.get("parameters/Locomotion/playback").get_current_node()==&"Locked","landing returns Locked")
	tree.active=false
	for frame in 30: await tick()
	check(tree.active and tree.get("parameters/Locomotion/playback").get_current_node()==&"Locked","playback recovery respects Locked branch")
	# Same group/marker contract, no dummy-specific path in the player.
	lock.clear()
	var second=load("res://test/lock_on_target_dummy.tscn").instantiate()
	lab.add_child(second)
	second.position=body.position+Vector3(5,0,-3)
	dummy.position=body.position+Vector3(0,0,-12)
	lock.toggle()
	check(lock.target==dummy,"centering has priority over proximity")
	lock.clear()
	second.position=body.position+Vector3(0,0,-5)
	lock.toggle()
	check(lock.target==second,"nearest equally centered target selected")
	lock.clear()
	second.free()
	# Existing stairs: lock to an elevated target beyond the upper landing.
	for run in [false,true]:
		lock.clear()
		body.step_solver.cancel()
		await settle(Vector3(62,0.1,-18))
		body.visual.rotation.y=0
		dummy.position=Vector3(62,1.2,-33)
		lock.toggle()
		var stepped:=false
		for frame in 210:
			await tick(Vector2(0,-1),run)
			stepped=stepped or body.step_solver.active
			if body.position.z< -29: break
		check(stepped and body.position.z< -29 and lock.is_locked(),"locked stair ascent retains StepSolver")
		print("COMBAT_STAIRS run=",run," end=",body.position)
	await reset_player()
	lock.toggle()
	# Acquisition rejects behind/out-of-range; invalidation clears immediately.
	lock.clear()
	dummy.position=body.position+Vector3(0,0,6)
	lock.toggle()
	check(not lock.is_locked(),"reject behind camera")
	dummy.position=body.position+Vector3(0,0,-22)
	lock.toggle()
	check(not lock.is_locked(),"reject outside acquire distance")
	dummy.position=body.position+Vector3(0,0,-10)
	lock.toggle()
	dummy.position.z-=35
	await tick()
	check(not lock.is_locked() and not lock.indicator.visible,"range break")
	dummy.position=body.position+Vector3(0,0,-10)
	lock.toggle()
	dummy.remove_from_group("lock_on_target")
	await tick()
	check(not lock.is_locked(),"disabled target invalidates")
	dummy.add_to_group("lock_on_target")
	lock.toggle()
	dummy.queue_free()
	await process_frame
	await tick()
	check(lock.target==null and not lock.is_locked(),"freed target safely clears")
	print("LOCK_ON_V2: ","PASS" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)

func reset_player() -> void:
	lock.clear()
	body.step_solver.cancel()
	body.turn_180.cancel()
	body._run_time=0
	body.camera.get_parent().get_parent().get_parent().rotation.y=0
	dummy.position=Vector3(0,0,8)
	body.visual.rotation.y=0
	await settle(Vector3(0,0.1,16))
