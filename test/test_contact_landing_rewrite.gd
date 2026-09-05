extends SceneTree

var failures: Array[String] = []
var player: CharacterBody3D
var controller: Node

func _init() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error("FAIL: " + message)

func run() -> void:
	player = (load("res://player/player.tscn") as PackedScene).instantiate() as CharacterBody3D
	root.add_child(player)
	await process_frame
	await physics_frame
	controller = player.get_node("AnimationController")
	player.set_physics_process(false)
	controller.set_physics_process(false)
	check(is_equal_approx(float(controller.get("minimum_land_air_time")), 0.06), "visible Land requires 0.06 s airborne")
	check(is_equal_approx(float(controller.get("land_clip_start")), 0.50), "Land starts at tuned impact window")
	check(is_equal_approx(float(controller.get("land_clip_exit")), 0.90), "Land exits at tuned source window")
	check(is_equal_approx(float(controller.get("land_min_impact_time")), 0.08), "Land impact reads for at least 0.08 s")
	check(is_equal_approx(float(controller.get("land_blend_in")), 0.04), "Land blend-in is contact-responsive")
	check(is_equal_approx(float(controller.get("land_blend_out")), 0.12), "Land blend-out is responsive")

	# Establish grounded history, then reject a tiny floor-loss episode.
	_set_grounded()
	player.velocity = Vector3(2.0, -0.2, 0.0)
	player.set("locomotion_state", EverdeepPlayer.LocomotionState.AIRBORNE)
	controller.call("_update_airborne_animation_state", 0.03)
	_set_grounded()
	check(int(controller.get("landing_trigger_count")) == 0, "tiny floor loss does not produce visible Land")
	check(controller.get("current_animation_state") == &"Locomotion", "tiny floor loss returns directly to locomotion")

	# A meaningful Fall is interrupted by the exact contact edge and fires once.
	player.set("current_gait", EverdeepPlayer.Gait.RUN)
	player.velocity = Vector3(4.0, -2.0, 0.0)
	controller.set("current_horizontal_speed", 4.0)
	player.set("locomotion_state", EverdeepPlayer.LocomotionState.AIRBORNE)
	controller.call("_update_airborne_animation_state", 0.10)
	check(controller.get("current_animation_state") == &"Fall", "meaningful edge fall enters Fall")
	var momentum_before := player.velocity.x
	_set_grounded()
	check(controller.get("current_animation_state") == &"Land", "ground contact immediately interrupts Fall with Land")
	check(int(controller.get("landing_trigger_count")) == 1, "contact triggers one Land")
	check(is_equal_approx(player.velocity.x, momentum_before), "Land event preserves horizontal momentum")
	for frame in 3:
		controller.call("_update_airborne_animation_state", 0.016)
	check(int(controller.get("landing_trigger_count")) == 1, "remaining grounded cannot retrigger Land")
	check(controller.get("current_animation_state") == &"Land", "minimum impact window prevents an instant exit")

	# Movement input cancels Land as soon as the brief impact window is readable.
	Input.action_press("move_forward")
	controller.call("_update_airborne_animation_state", 0.04)
	check(controller.get("current_animation_state") == &"Locomotion", "movement cancels Land after impact commitment")
	check(int(player.get("current_gait")) == EverdeepPlayer.Gait.RUN, "moving exit retains current gait")
	Input.action_release("move_forward")

	# Idle landing uses the clip exit, and a new Jump may interrupt it immediately.
	controller.call("_travel_to", &"Locomotion")
	player.velocity = Vector3(0.0, -2.0, 0.0)
	player.set("locomotion_state", EverdeepPlayer.LocomotionState.AIRBORNE)
	controller.call("_update_airborne_animation_state", 0.10)
	_set_grounded()
	check(controller.get("current_animation_state") == &"Land", "idle contact enters Land")
	controller.call("_update_airborne_animation_state", 0.03)
	check(controller.get("current_animation_state") == &"Land", "idle Land does not exit before impact commitment")
	player.velocity = Vector3(0.0, 8.0, 0.0)
	controller.set("current_horizontal_speed", 0.0)
	player.set("locomotion_state", EverdeepPlayer.LocomotionState.AIRBORNE)
	controller.call("_update_airborne_animation_state", 0.016)
	check(controller.get("current_animation_state") == &"StandingJump", "new Jump immediately interrupts Land")
	check(int(controller.get("landing_trigger_count")) == 2, "Jump cancellation creates no duplicate contact")

	if failures.is_empty():
		print("CONTACT_LANDING_REWRITE: PASS")
		quit(0)
	else:
		print("CONTACT_LANDING_REWRITE: FAIL (%d)" % failures.size())
		quit(1)

func _set_grounded() -> void:
	player.velocity.y = 0.0
	player.set("locomotion_state", EverdeepPlayer.LocomotionState.GROUNDED)
	controller.call("_update_airborne_animation_state", 0.016)
