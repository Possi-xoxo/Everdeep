extends "res://test/test_crouch_v2.gd"
const Context = preload("res://interaction/context_interactable.gd")
var detector: Node
var traversal: Node

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
	detector=body.context_interaction
	traversal=body.traversal
	body.set_physics_process(false)
	animation.set_physics_process(false)
	cam.set_process(false)
	tree.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	box(Vector3(200,-.25,0),Vector3(80,.5,80))
	await reset_at(Vector3(200,.1,10))
	body.visual.rotation=Vector3.ZERO
	check(InputMap.action_get_events("interact")[0].physical_keycode==KEY_E,"E mapped")
	for action in InputMap.get_actions():
		if action==&"interact" or String(action).begins_with("ui_"): continue
		for event in InputMap.action_get_events(action):
			if event is InputEventKey: check(event.physical_keycode!=KEY_E and event.keycode!=KEY_E,"no E conflict: "+String(action))
	detector.scan()
	check(detector.selected==null and not detector.prompt.visible,"no candidate no UI")
	var candidate=load("res://test/traversal_test_interactable.tscn").instantiate()
	lab.add_child(candidate)
	candidate.position=Vector3(200,0,8.5)
	await crouch_tick(false)
	detector.scan()
	check(detector.selected==candidate and detector.prompt.text=="E to Climb","action text prompt")
	body.animation_state.is_airborne=true
	detector.scan()
	check(detector.selected==null,"grounded-only candidate rejects airborne state")
	body.animation_state.is_airborne=false
	body.visual.rotation.y=PI
	detector.scan()
	check(detector.selected==null,"behind rejected")
	body.visual.rotation.y=0
	var wall:=box(Vector3(200,1,9.25),Vector3(2,2,.1))
	await crouch_tick(false)
	detector.scan()
	check(detector.selected==null,"occlusion rejects")
	wall.queue_free()
	await crouch_tick(false)
	var other=load("res://test/traversal_test_interactable.tscn").instantiate()
	lab.add_child(other)
	other.position=Vector3(200.35,0,8.5)
	other.action_text="Interact"
	other.interaction_type=Context.Type.GENERIC_INTERACT
	detector.scan()
	check(detector.selected==candidate,"front relevance beats side")
	for frame in 5:
		detector.scan()
		check(detector.selected==candidate,"candidate remains stable")
	other.priority=5
	detector.scan()
	check(detector.selected==other,"explicit priority wins")
	check(detector.activate_selected() and other.activation_count==1 and not traversal.is_traversing,"generic callback no ownership")
	other.available=false
	detector.scan()
	candidate.available=false
	check(not detector.activate_selected() and not detector.prompt.visible,"availability revalidated on activation")
	candidate.available=true
	detector.scan()
	candidate.position.z=0
	check(not detector.activate_selected(),"range revalidated")
	candidate.position.z=8.5
	# Crouch does not block contextual use. Lock target direction matches test.
	for frame in 65: await crouch_tick(true)
	dummy.position=Vector3(200,0,0)
	lock.toggle()
	check(lock.is_locked(),"lock setup")
	detector.scan()
	# Exercise the real InputMap boundary, not just controller calls.
	await process_frame
	Input.action_press("interact")
	await physics_frame
	body._physics_process(DT)
	Input.action_release("interact")
	check(traversal.is_traversing and traversal.phase==traversal.Phase.ENTRY,"E begins traversal")
	check(not lock.is_locked() and lock.target==null and not detector.prompt.visible,"lock and prompt cleared")
	check(not detector.activate_selected(),"active traversal rejects reentry")
	check(not traversal.request_traversal_interrupt(traversal.Interrupt.DAMAGE),"light damage does not detach")
	var phases: Array[int]=[]
	for frame in 70:
		await crouch_tick(true,Vector2(0,-1),true,true,true)
		if traversal.is_traversing:
			phases.append(traversal.phase)
			check(body.animation_state.move_input_magnitude==0 and not dodge.is_dodging and not body.animation_state.jump_started,"movement authority yielded without disabling physics")
		else: break
	check(phases.has(traversal.Phase.ACTIVE) and phases.has(traversal.Phase.EXIT) and not traversal.is_traversing,"full lifecycle returns authority")
	# Clear the newly permitted action from the release tick.
	for frame in 170: await crouch_tick(true)
	await crouch_tick(true,Vector2(0,-1))
	check(body.animation_state.move_input_magnitude>0,"locomotion input resumes")
	for frame in 10: await crouch_tick(true)
	body.visual.rotation.y=0
	candidate.position=body.position+Vector3(0,0,-1.5)
	detector.scan()
	check(detector.activate_selected(),"second traversal")
	traversal.traversal_interrupt_window_open=false
	check(not traversal.request_traversal_interrupt(traversal.Interrupt.PLAYER_CANCEL),"closed interrupt window")
	traversal.traversal_interrupt_window_open=true
	check(traversal.request_traversal_interrupt(traversal.Interrupt.PLAYER_CANCEL),"explicit allowed cancellation")
	await crouch_tick(true,Vector2.ZERO,false,false,true)
	detector.scan()
	check(detector.selected==null and not detector.activate_selected(),"Dodge blocks interaction")
	for frame in 170: await crouch_tick(true)
	body.visual.rotation.y=0
	candidate.position=body.position+Vector3(0,0,-1.5)
	detector.scan()
	candidate.queue_free()
	check(not detector.activate_selected() and not detector.prompt.visible,"freed candidate no stale UI")
	other.available=true
	other.interaction_type=Context.Type.MANTLE
	other.position=body.position+Vector3(0,0,-1.5)
	detector.scan()
	check(detector.activate_selected(),"source-loss setup")
	other.queue_free()
	await crouch_tick(true)
	check(not traversal.is_traversing and traversal.last_end_reason=="SOURCE_LOST","active source loss releases ownership")
	check(traversal.request_automatic_traversal(Context.Type.LEDGE,{"requires_grounded":false,"test_duration":.2}),"automatic request bypasses UI")
	for frame in 20: await crouch_tick(true)
	check(not traversal.is_traversing,"automatic dummy safely finishes")
	print("TRAVERSAL_PHASE0_V2: ","PASS" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)
