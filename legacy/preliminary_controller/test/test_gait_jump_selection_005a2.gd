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
	var tree := player.get_node("AnimationTree") as AnimationTree
	var machine := tree.tree_root as AnimationNodeStateMachine
	player.set_physics_process(false)
	controller.set_physics_process(false)
	check(machine.has_node(&"StandingJump"), "StandingJump state is installed")
	check(machine.has_node(&"MovingJump"), "MovingJump state is installed")
	check(not machine.has_node(&"Jump"), "single-source Jump state was replaced")
	check(is_equal_approx(float(controller.get("standing_jump_speed_threshold")), 0.30), "standing threshold is 0.30 m/s")
	var anim_player := player.get_node("VisualRoot/MasterRig/AnimationPlayer") as AnimationPlayer
	check(anim_player.has_animation(&"AIR_STANDING_JUMP_(2)"), "standing Jump action exists")
	check(anim_player.has_animation(&"AIR_RUNNING_JUMP"), "moving Jump action exists")
	check(anim_player.get_animation(&"AIR_STANDING_JUMP_(2)").loop_mode == Animation.LOOP_NONE, "standing Jump is one-shot")
	check(anim_player.get_animation(&"AIR_RUNNING_JUMP").loop_mode == Animation.LOOP_NONE, "moving Jump is one-shot")

	# Tiny residual speed remains a standing takeoff, and the choice stays fixed midair.
	_begin_simulated_jump(0.20, EverdeepPlayer.Gait.WALK)
	check(controller.get("current_animation_state") == &"StandingJump", "sub-threshold residual velocity selects StandingJump")
	player.velocity.x = 6.0
	controller.set("current_horizontal_speed", 6.0)
	controller.call("_update_airborne_animation_state", 0.10)
	check(controller.get("current_animation_state") == &"StandingJump", "standing selection does not morph or restart midair")
	_end_simulated_airborne_cycle()

	_begin_simulated_jump(2.0, EverdeepPlayer.Gait.WALK)
	check(controller.get("current_animation_state") == &"MovingJump", "Walk jump selects MovingJump")
	check(int(player.get("current_gait")) == EverdeepPlayer.Gait.WALK, "Walk gait persists")
	_end_simulated_airborne_cycle()

	_begin_simulated_jump(4.0, EverdeepPlayer.Gait.RUN)
	check(controller.get("current_animation_state") == &"MovingJump", "Run jump selects MovingJump")
	check(is_equal_approx(player.velocity.x, 4.0), "Run momentum is unchanged by selection")
	check(int(player.get("current_gait")) == EverdeepPlayer.Gait.RUN, "Run gait persists")
	_end_simulated_airborne_cycle()

	_begin_simulated_jump(8.0, EverdeepPlayer.Gait.SPRINT)
	check(controller.get("current_animation_state") == &"MovingJump", "Sprint temporarily uses MovingJump")
	check(is_equal_approx(player.velocity.x, 8.0), "Sprint momentum is unchanged by selection")
	check(int(player.get("current_gait")) == EverdeepPlayer.Gait.SPRINT, "Sprint gait persists")
	_end_simulated_airborne_cycle()

	# A floor-loss edge has downward velocity and must bypass both Jump states.
	controller.call("_travel_to", &"Locomotion")
	player.velocity = Vector3(4.0, -1.0, 0.0)
	controller.set("current_horizontal_speed", 4.0)
	player.set("locomotion_state", EverdeepPlayer.LocomotionState.AIRBORNE)
	controller.call("_update_airborne_animation_state", 0.016)
	check(controller.get("current_animation_state") == &"Fall", "edge fall bypasses both Jump states")

	if failures.is_empty():
		print("GAIT_JUMP_SELECTION_005A2: PASS")
		quit(0)
	else:
		print("GAIT_JUMP_SELECTION_005A2: FAIL (%d)" % failures.size())
		quit(1)

func _begin_simulated_jump(speed: float, gait: int) -> void:
	player.set("locomotion_state", EverdeepPlayer.LocomotionState.GROUNDED)
	controller.call("_update_airborne_animation_state", 0.016)
	controller.call("_travel_to", &"Locomotion")
	player.set("current_gait", gait)
	player.velocity = Vector3(speed, 8.0, 0.0)
	controller.set("current_horizontal_speed", speed)
	player.set("locomotion_state", EverdeepPlayer.LocomotionState.AIRBORNE)
	controller.call("_update_airborne_animation_state", 0.016)

func _end_simulated_airborne_cycle() -> void:
	player.velocity.y = -1.0
	controller.call("_update_airborne_animation_state", 1.0)
	check(controller.get("current_animation_state") == &"Fall", "selected Jump transitions to Fall")
	player.velocity.y = 0.0
	player.set("locomotion_state", EverdeepPlayer.LocomotionState.GROUNDED)
	controller.call("_update_airborne_animation_state", 0.016)
	check(controller.get("current_animation_state") == &"Land", "Fall still transitions to Land")
