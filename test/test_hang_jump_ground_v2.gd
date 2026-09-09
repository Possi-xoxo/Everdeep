extends "res://test/test_hang_outward_v2.gd"
func run() -> void:
	for floor_height in [0.0,1.2]:
		await setup_transfer()
		var wall=box(Vector3(200,1.5,-2),Vector3(8,3,4))
		var floor_body=box(Vector3(200,floor_height-.1,16.5),Vector3(30,.2,30))
		await physics_frame
		await catch_at(Vector3(200,1.1,.65))
		animation._has_ground_contact=true # Player previously stood on ground.
		check(hang.navigation.resolve(hang,"JUMP"),"normal hang jump accepted")
		check(hang.navigation.jumping and not hang.outward.active,"no outward destination")
		var landed: bool=false
		for tick in 180:
			await crouch_tick(false)
			if not hang.running and body.animation_state.is_grounded:
				if not landed: print("GROUND_CONTACT ",floor_height," ",animation.current_state," jump_visual ",hang.navigation.jump_visual)
				landed=true
		check(landed,"hang jump lands on ground")
		check(animation.current_state==&"Locomotion","landing returns to standing idle without a second jump")
		check(animation._playback.get_current_node()==&"Locomotion","evaluated playback exits airborne animation")
		check(not hang.navigation.jump_visual and not animation.fall_visual_committed,"airborne presentation cleared")
		for tick in 30: await crouch_tick(false,Vector2(0,-1))
		check(animation.current_state==&"Locomotion","walking after landing stays in locomotion")
		wall.queue_free()
		floor_body.queue_free()
		lab.queue_free()
		await physics_frame
	print("HANG_JUMP_GROUND_V2: ","PASS" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)
