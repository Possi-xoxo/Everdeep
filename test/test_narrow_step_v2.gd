extends "res://test/test_player_v2.gd"
func configure_solver() -> void:
	pass

func run() -> void:
	var lab=load("res://test/player_v2_lab.tscn").instantiate()
	root.add_child(lab)
	body=lab.get_node("PlayerV2")
	animation=body.get_node("AnimationController")
	tree=body.get_node("AnimationTree")
	body.set_physics_process(false)
	animation.set_physics_process(false)
	tree.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	configure_solver()
	# Isolated center rejection must still permit a validated side candidate.
	if body.step_solver.get("chosen_candidate")!=null:
		await settle(Vector3(107.7,0.05,19.4))
		var direction:=Vector3(sin(PI/3),0,-cos(PI/3))
		body.step_solver.cancel()
		check(body.step_solver.prepare(DT,direction*4,direction,true),"lateral candidate acquired")
		check(body.step_solver.chosen_candidate=="RIGHT","center rejection does not reject right candidate")
	for gait in 3:
		for fixture in [
			["short",Vector3(100,0.05,23),Vector2(0,-1),true],
			["long",Vector3(97,0.05,18),Vector2(1,0),true],
			["thin short",Vector3(120,0.05,23),Vector2(0,-1),false],
			["thin long",Vector3(117,0.05,18),Vector2(1,0),false],
			["corner left",Vector3(107,0.05,21),Vector2(1,-1).normalized(),true],
			["corner right",Vector3(113,0.05,21),Vector2(-1,-1).normalized(),true]]:
			body.step_solver.cancel()
			await settle(fixture[1])
			body.visual.rotation.y=atan2(-fixture[2].x,-fixture[2].y)
			body._run_time=4 if gait==2 else 0
			var count: int=body.step_solver.steps_started
			var highest:=0.0
			var choices=[]
			var reached:=false
			for frame in 85:
				await tick(fixture[2],gait>0)
				highest=maxf(highest,body.position.y)
				if body.step_solver.candidate and body.step_solver.get("chosen_candidate")!=null and not choices.has(body.step_solver.chosen_candidate): choices.append(body.step_solver.chosen_candidate)
				var inside: bool=body.position.z<19.5 if fixture[0]=="short" else absf(body.position.x-100)<0.15 if fixture[0]=="long" else body.position.x>108.7 and body.position.x<111.3 and body.position.z<19.3
				if inside and body.position.y>0.19 and body.is_on_floor(): reached=true
			var stepped: bool=body.step_solver.steps_started>count
			print("NARROW gait=",gait," fixture=",fixture[0]," stepped=",stepped," highest=",highest," choices=",choices," pos=",body.position)
			check(stepped==fixture[3],"narrow/corner classification "+fixture[0])
			if fixture[3]: check(reached,"completes grounded traversal "+fixture[0])
	print("NARROW_STEP_V2: ","PASS" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)
