extends "res://test/test_hang_outward_v2.gd"
func run() -> void:
	await setup_transfer()
	var wall=box(Vector3(200,1.5,-2),Vector3(12,3,4))
	await physics_frame
	for side in [-1,1]:
		for remaining in [4.0,2.25,1.5,.75,.38,.05]:
			await catch_at(Vector3(200+side*(6-.28-remaining),1.1,.65))
			var stamp: int=Time.get_ticks_usec()
			var q: Dictionary=hang.lateral.preview(hang,side,true)
			print("PARTIAL ",side," remain=",remaining," actual=",q.actual_distance," available=",q.available_distance," us=",Time.get_ticks_usec()-stamp)
			if remaining<hang.braced_hang_hop_min_distance:
				check(not q.valid and q.actual_distance==0,"tiny remainder cannot hop")
				continue
			check(q.valid,"useful partial/full hop valid")
			if not q.valid: continue
			check(q.actual_distance<=minf(remaining,3)+.002,"never exceeds remaining ledge")
			check(q.actual_distance>minf(remaining,3)*.90,"uses almost all space, reserving authored overshoot")
			var target: Vector3=q.target
			check(hang.lateral.request(hang,side,true),"hop request accepted")
			var max_progress: float=0
			for tick in 160:
				await crouch_tick(false)
				var sample: Vector3=hang.lateral.motion.sample(hang.lateral.state,hang.lateral.progress)
				check(absf(hang.lateral.expected_position.y-hang.lateral.start.y-sample.y)<.001,"authored vertical arc preserved")
				for arm in body.get_node("MantleHandIK").arms: check(arm.length_error<.005,"partial hop retains arm lengths")
				max_progress=maxf(max_progress,hang.lateral.progress)
				if not hang.lateral.active: break
			check(max_progress>=.995,"full animation completes")
			check(body.position.distance_to(target)<.005,"lands at clamped target")
			check(hang.hang_phase==hang.HangPhase.IDLE,"stable hang after partial hop")
			if remaining<3:
				var again: Dictionary=hang.lateral.preview(hang,side,true)
				check(not again.valid,"repeated edge request cannot accumulate drift")
	wall.queue_free()
	print("HANG_PARTIAL_HOP_V2: ","PASS" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)
