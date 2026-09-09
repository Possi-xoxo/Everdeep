extends "res://test/test_hang_transfer_v2.gd"
func run() -> void:
	await setup_transfer()
	var motion=hang.lateral.motion
	var peak: float=0
	var length: float=motion.measurements["HangHopRight"].duration
	var left: Array=motion.profiles[&"HangHopLeft"].duplicate()
	for i in 241:
		var original: Vector3=motion.original_right_profile[i]
		var value: Vector3=motion.profiles[&"HangHopRight"][i]
		check(value.y==original.y and value.z==original.z,"vertical arc and retreat untouched")
		if i/240.0*length*30<=30: check(value==original,"departure through frame 30 preserved")
		peak=maxf(peak,value.x)
	check(absf((peak-1)*3-.08)<.001,"right tail capped near 8cm")
	check(motion.sample(&"HangHopRight",1)==Vector3(1,0,0),"exact 3m endpoint")
	var compressed: Array=motion.profiles[&"HangHopRight"].duplicate()
	motion.compress_right_tail(3,.08)
	check(compressed==motion.profiles[&"HangHopRight"],"repeated preparation does not accumulate")
	check(left==motion.profiles[&"HangHopLeft"],"left profile untouched")
	motion.configure_right_hop(false)
	check(motion.profiles[&"HangHopRight"]==motion.original_right_profile,"original curve preserved for revert")
	print("RIGHT_HOP_TAIL: ","PASS" if failures.is_empty() else failures," / peak overshoot ",(peak-1)*3)
	quit(0 if failures.is_empty() else 1)
