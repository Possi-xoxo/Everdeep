extends "res://test/test_hang_top_entry_v2.gd"
var held_origin:=Vector3.ZERO
var observing_hold: bool=false
var hold_ticks: int=0
func crouch_tick(held: bool,stick:=Vector2.ZERO,shift:=false,jump:=false,roll:=false) -> void:
	await super.crouch_tick(held,stick,shift,jump,roll)
	if hang.top_entry.active and animation._playback.get_current_node()==&"HangTopEntry": check(cam.traversal_camera_mode=="TOP_DOWN_HANG_GLIDE","playing entry owns camera glide")
	if cam.traversal_camera_mode=="TOP_DOWN_HANG_GLIDE":
		if not observing_hold:
			held_origin=cam.global_position
			var old_yaw: float=cam.yaw.rotation.y
			cam.apply_mouse_motion(Vector2(3,1))
			check(not is_equal_approx(old_yaw,cam.yaw.rotation.y),"orbit remains available")
		observing_hold=true
		hold_ticks+=1
		var progress: float=clampf(hang.top_entry.clock/hang.top_entry.length,0,1)
		var expected: Vector3=cam._mantle_start.lerp(cam._hang_camera_top,smoothstep(0,1,progress))
		check(cam.global_position.distance_to(expected)<.0001,"camera follows full-animation eased path")
		if progress>.95: check(cam.global_position.distance_to(cam._hang_camera_top)<.025,"camera reaches finish during final animation frames")
		if hang.top_entry.frame()>16: check(cam._top_hold,"hold continues after hand contact")
		check(cam.arm.shape==cam._free_shape,"spring arm collision retained")
	else:
		if observing_hold and hang.running:
			check(hang.hang_phase==hang.HangPhase.IDLE,"rejoin waits for idle")
			check(cam.traversal_camera_mode=="TOP_DOWN_HANG_REJOIN" or (cam.traversal_camera_mode=="HANG" and cam.global_position.distance_to(body.to_global(cam._base_position))<.002),"smooth reunion or already-arrived hang follow")
		observing_hold=false
func launch(point: Vector3,yaw: float=PI) -> void:
	await super.launch(point,yaw)
	# Fixture teleport resets presentation only, before the next activation.
	cam.mantle_camera_active=false
	cam._top_sequence=false
	cam._top_hold=false
	cam._mantle_tracking=false
	cam._process(DT)
	check(not cam._top_hold,"grounded prompt does not hold camera")
