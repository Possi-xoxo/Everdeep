extends "res://test/test_hang_outward_v2.gd"

func run() -> void:
	await setup_transfer()
	await crouch_tick(false)
	var player: AnimationPlayer=animation.player
	var normal: Animation=player.get_animation(hang.navigation.JUMP_CLIP)
	var outward: Animation=player.get_animation(hang.outward.CLIP)
	var catch_clip: Animation=player.get_animation(&"HangTopEntry_Full")
	var hip: int=hang.hip_track(normal)
	var root_rotation: int=normal.find_track(normal.track_get_path(hip),Animation.TYPE_ROTATION_3D)
	var skeleton: Skeleton3D=body.get_node("MantleHandIK").skeleton
	var rig_basis: Basis=(body.visual.global_basis.inverse()*skeleton.global_basis).orthonormalized()
	var rig_rotation: Quaternion=rig_basis.get_rotation_quaternion()
	check((rig_basis*Vector3.BACK).dot(Vector3.DOWN)>.999,"source yaw maps to negative visual Y")
	check(is_equal_approx(normal.length,1.3),"normal jump playback duration unchanged")
	check(is_equal_approx(hang.outward.flight_duration,1.04/1.1),"jump-off is another 10 percent faster")
	check(is_equal_approx(hang.outward_catch_playback_speed,1.25*.85),"catch playback is 15 percent slower")
	check(is_equal_approx(outward.length,hang.outward.playback_duration),"private timeline includes real catch recovery")
	check(is_equal_approx(catch_clip.length,46.0/30.0),"full top-down clip remains intact")
	check(is_equal_approx(player.get_animation(&"TRV_JUMPING_TO_BRACED_HANG").length,.2),"automatic catch remains separate")
	check(is_equal_approx(hang.outward.duration,normal.length),"movement and pose clocks remain shared")
	var worst_limb: float=0
	var worst_root: float=0
	for frame in range(31):
		var time: float=frame/30.0
		var runtime: float=time/hang.outward_playback_speed
		var p: float=time/normal.length
		check(hang.outward.arrival_weight(hang,p)<.00001,"no early idle morph through frame 30")
		for target_turn in [-PI,-PI+.4,PI-.4]:
			var turn: float=hang.outward.rotation_angle(hang,p,target_turn)
			var expected: Quaternion=rig_rotation*normal.rotation_track_interpolate(root_rotation,time)
			var actual: Quaternion=Quaternion(Vector3.UP,turn)*rig_rotation*outward.rotation_track_interpolate(root_rotation,runtime)
			worst_root=maxf(worst_root,expected.normalized().angle_to(actual.normalized()))
			check(expected.normalized().angle_to(actual.normalized())<.005,"root turn matches normal jump within 0.3 degrees at frame %d"%frame)
		for track in normal.get_track_count():
			if normal.track_get_type(track)!=Animation.TYPE_ROTATION_3D or track==root_rotation: continue
			var error: float=normal.rotation_track_interpolate(track,time).normalized().angle_to(outward.rotation_track_interpolate(track,runtime).normalized())
			worst_limb=maxf(worst_limb,error)
			check(error<.003,"authored limb pose retained at frame %d"%frame)
	for target_turn in [-PI,-PI+.4,PI-.4]:
		check(absf(angle_difference(hang.outward.rotation_angle(hang,1,target_turn),target_turn))<.0001,"catch ends at requested wall facing")
	for track in outward.get_track_count():
		if outward.track_get_type(track)!=Animation.TYPE_ROTATION_3D: continue
		var catch_track: int=catch_clip.find_track(outward.track_get_path(track),Animation.TYPE_ROTATION_3D)
		if catch_track<0: continue
		for runtime in [1.12,1.28,outward.length]:
			var catch_time: float=16.0/30.0+(runtime-1.0/1.375)*1.0625
			check(outward.rotation_track_interpolate(track,runtime).normalized().angle_to(catch_clip.rotation_track_interpolate(catch_track,minf(catch_time,catch_clip.length)).normalized())<.005,"real jump-to-hang recovery plays instead of idle")
	print("POSE_MAX_ERRORS_DEG ",rad_to_deg(worst_root)," / ",rad_to_deg(worst_limb))
	print("HANG_OUTWARD_POSE_V2: ","PASS" if failures.is_empty() else failures.size())
	quit(0 if failures.is_empty() else 1)
