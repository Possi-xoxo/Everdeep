extends "res://test/test_crouch_v2.gd"

func moving_check(shift: bool) -> void:
	check(crouch.animation_moving,"movement presentation remains active")
	check(animation.current_state==((&"CrouchLockedRun" if shift else &"CrouchLocked") if lock.is_locked() else (&"CrouchRun" if shift else &"CrouchWalk")),"same locomotion branch, no Idle")
	if lock.is_locked():
		check(absf(absf(crouch.direction_blend.x)+absf(crouch.direction_blend.y)-1.0)<.001,"reversal stays on movement diamond: zero Idle weight")

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
	crouch=body.crouch
	body.set_physics_process(false)
	animation.set_physics_process(false)
	cam.set_process(false)
	tree.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	box(Vector3(200,-.25,0),Vector3(80,.5,80))
	await reset_at(Vector3(200,.1,10))
	check(not tree.tree_root.has_node(&"CrouchRunStop") and not animation.CLIPS.has("CrouchRunStop"),"stop state and binding removed")
	check(animation.player.has_animation("BOW_STANDING_RUN_FORWARD_STOP"),"source stop asset retained")
	for locked in [false,true]:
		if locked:
			dummy.position=body.position+Vector3(0,0,-8)
			lock.toggle()
		for shift in [false,true]:
			for frame in 60: await crouch_tick(true,Vector2(0,-1),shift)
			for stick in [Vector2(0,1),Vector2(-1,0),Vector2(1,0),Vector2(0,-1),Vector2(1,0),Vector2(0,1),Vector2(-1,0),Vector2(0,-1)]:
				# Include a physical zero-speed sample; presentation must follow input.
				body.velocity.x=0
				body.velocity.z=0
				for frame in 12:
					await crouch_tick(true,stick,shift)
					moving_check(shift)
			for frame in 4:
				await crouch_tick(true)
				moving_check(shift)
			check(not crouch.crouch_has_move_intent and crouch.idle_grace_timer>0,"short release uses grace")
			await crouch_tick(true,Vector2(0,1),shift)
			moving_check(shift)
			check(crouch.idle_grace_timer==0,"return cancels grace")
			for frame in 35: await crouch_tick(true)
			check(not crouch.animation_moving,"true stop expires grace")
			check(animation.current_state==(&"CrouchLocked" if locked else &"CrouchIdle"),"true stop directly idles")
			if locked: check(crouch.direction_blend.length()<.001,"true stop reaches blendspace Idle")
			for frame in 15: await crouch_tick(true,Vector2(.05,0))
			check(not crouch.animation_moving,"input noise cannot restart movement")
	for frame in 20: await crouch_tick(true,Vector2(0,-1))
	await crouch_tick(true)
	await crouch_tick(true,Vector2.ZERO,false,false,true)
	check(dodge.is_dodging and String(animation.current_state).begins_with("Dodge"),"Dodge takes priority during grace")
	for frame in 160: await crouch_tick(true)
	check(not crouch.animation_moving,"no stale grace after Dodge")
	print("CROUCH_CONTINUITY_V2: ","PASS" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)
