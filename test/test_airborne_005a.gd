extends SceneTree

var failures: Array[String] = []

func _init() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error("FAIL: " + message)

func run() -> void:
	var packed := load("res://player/player.tscn") as PackedScene
	var player := packed.instantiate() as CharacterBody3D
	root.add_child(player)
	await process_frame
	await physics_frame
	var controller := player.get_node("AnimationController")
	var machine := (player.get_node("AnimationTree") as AnimationTree).tree_root as AnimationNodeStateMachine
	player.set_physics_process(false)
	controller.set_physics_process(false)
	check(machine.has_node(&"Jump") and machine.has_node(&"Fall") and machine.has_node(&"Land"), "airborne states are installed")
	check(is_equal_approx(float(controller.get("jump_clip_start")), 0.12), "jump clip starts at 0.12")
	check(is_equal_approx(float(controller.get("jump_min_animation_time")), 0.28), "jump visual commitment is 0.28 s")
	check(is_equal_approx(float(controller.get("fall_transition_velocity")), -0.5), "fall threshold is -0.5 m/s")
	check(is_equal_approx(float(controller.get("land_clip_start")), 0.90), "land uses the tuned source lead-in skip")
	check(is_equal_approx(float(controller.get("land_exit_progress")), 1.0), "land uses the tuned source exit")

	# Establish a real grounded history so a later airborne->grounded edge can land.
	player.set("locomotion_state", EverdeepPlayer.LocomotionState.GROUNDED)
	controller.call("_update_airborne_animation_state", 0.016)
	player.set("current_gait", EverdeepPlayer.Gait.RUN)
	player.velocity = Vector3(4.0, 8.0, 0.0)
	player.set("locomotion_state", EverdeepPlayer.LocomotionState.AIRBORNE)
	controller.call("_update_airborne_animation_state", 0.016)
	check(controller.get("current_animation_state") == &"Jump", "positive launch enters Jump once")
	check(int(controller.get("landing_trigger_count")) == 0, "jump does not trigger landing")
	controller.call("_update_airborne_animation_state", 0.10)
	check(controller.get("current_animation_state") == &"Jump", "Jump does not restart while ascending")
	player.velocity.y = -0.6
	controller.call("_update_airborne_animation_state", 0.10)
	check(controller.get("current_animation_state") == &"Jump", "descent cannot cut off minimum Jump window")
	controller.call("_update_airborne_animation_state", 0.10)
	check(controller.get("current_animation_state") == &"Fall", "Jump enters Fall after time and descent thresholds")
	check(int(player.get("current_gait")) == EverdeepPlayer.Gait.RUN, "Run gait persists through Jump/Fall")
	check(is_equal_approx(Vector2(player.velocity.x, player.velocity.z).length(), 4.0), "airborne presentation does not change horizontal momentum")

	player.velocity.y = 0.0
	player.set("locomotion_state", EverdeepPlayer.LocomotionState.GROUNDED)
	controller.call("_update_airborne_animation_state", 0.016)
	check(controller.get("current_animation_state") == &"Land", "physical airborne-to-grounded edge enters Land")
	check(int(controller.get("landing_trigger_count")) == 1, "first landing triggers exactly once")
	for frame in 8:
		controller.call("_update_airborne_animation_state", 0.016)
	check(int(controller.get("landing_trigger_count")) == 1, "grounded frames do not retrigger Land")
	controller.call("_update_airborne_animation_state", 0.40)
	check(controller.get("current_animation_state") == &"Locomotion", "Land exits at its useful source progress")
	check(int(player.get("current_gait")) == EverdeepPlayer.Gait.RUN, "landing returns with Run gait intact")

	# Losing the floor with downward velocity bypasses Jump.
	player.velocity = Vector3(4.0, -1.0, 0.0)
	player.set("locomotion_state", EverdeepPlayer.LocomotionState.AIRBORNE)
	controller.call("_update_airborne_animation_state", 0.016)
	check(controller.get("current_animation_state") == &"Fall", "edge fall bypasses Jump")
	player.set("locomotion_state", EverdeepPlayer.LocomotionState.GROUNDED)
	controller.call("_update_airborne_animation_state", 0.016)
	check(int(controller.get("landing_trigger_count")) == 2, "second airborne cycle permits one new Land")
	# Re-jump from Land must cancel stale landing immediately.
	player.velocity.y = 8.0
	player.set("locomotion_state", EverdeepPlayer.LocomotionState.AIRBORNE)
	controller.call("_update_airborne_animation_state", 0.016)
	check(controller.get("current_animation_state") == &"Jump", "rapid re-jump replaces Land with a fresh Jump")
	check(int(controller.get("landing_trigger_count")) == 2, "re-jump does not create a false landing")

	if failures.is_empty():
		print("AIRBORNE_005A: PASS")
		quit(0)
	else:
		print("AIRBORNE_005A: FAIL (%d)" % failures.size())
		quit(1)
