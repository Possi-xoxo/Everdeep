extends SceneTree

var failures: Array[String] = []

func _init() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error("FAIL: " + message)

func run() -> void:
	_add_floor()
	await physics_frame
	await _test_trivial_drop()
	await _test_meaningful_drop()
	await _test_intentional_jump()
	if failures.is_empty():
		print("SHORT_DROP_SUPPRESSION: PASS")
		quit(0)
	else:
		print("SHORT_DROP_SUPPRESSION: FAIL (%d)" % failures.size())
		quit(1)

func _add_floor() -> void:
	var floor := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(20.0, 0.2, 20.0)
	collision.shape = shape
	floor.add_child(collision)
	floor.position.y = -0.1
	root.add_child(floor)

func _spawn_grounded_player() -> CharacterBody3D:
	var player := (load("res://player/player.tscn") as PackedScene).instantiate() as CharacterBody3D
	root.add_child(player)
	for frame in 8:
		await physics_frame
	return player

func _test_trivial_drop() -> void:
	var player := await _spawn_grounded_player()
	var controller := player.get_node("AnimationController")
	player.floor_snap_length = 0.0
	player.position.y += 0.20
	player.velocity.y = 0.0
	var saw_airborne := false
	var saw_fall := false
	var saw_land := false
	for frame in 90:
		await physics_frame
		saw_airborne = saw_airborne or not player.is_on_floor()
		saw_fall = saw_fall or controller.current_animation_state == &"Fall" or controller.current_animation_state == &"LandPrep"
		saw_land = saw_land or controller.current_animation_state == &"Land"
		if saw_airborne and player.is_on_floor():
			break
	check(saw_airborne, "trivial test creates a physical airborne episode")
	check(not saw_fall, "0.20 m passive drop keeps locomotion presentation")
	check(not saw_land, "0.20 m passive drop suppresses Land")
	check(controller.landing_trigger_count == 0, "trivial drop does not consume a landing event")
	player.queue_free()
	await process_frame

func _test_meaningful_drop() -> void:
	var player := await _spawn_grounded_player()
	var controller := player.get_node("AnimationController")
	player.position.y += 2.0
	player.velocity.y = 0.0
	var saw_fall := false
	var saw_land := false
	for frame in 300:
		await physics_frame
		saw_fall = saw_fall or controller.current_animation_state == &"Fall" or controller.current_animation_state == &"LandPrep"
		saw_land = saw_land or controller.current_animation_state == &"Land"
		if saw_land:
			break
	check(saw_fall, "meaningful passive drop commits Fall")
	check(saw_land, "meaningful passive drop retains contact Land")
	check(controller.landing_trigger_count == 1, "meaningful drop triggers Land once")
	player.queue_free()
	await process_frame

func _test_intentional_jump() -> void:
	var player := await _spawn_grounded_player()
	var controller := player.get_node("AnimationController")
	# Reproduce the post-input state produced by EverdeepPlayer's valid jump
	# branch; headless SceneTree scripts do not generate reliable just-pressed
	# action edges for child physics callbacks.
	player.jump_sequence += 1
	player.velocity.y = player.jump_velocity
	player.floor_snap_length = 0.0
	player.position.y += 0.05
	await physics_frame
	check(controller.jump_initiated, "valid jump is marked intentional")
	check(
		controller.current_animation_state == &"StandingJump" or controller.current_animation_state == &"MovingJump",
		"intentional jump immediately bypasses passive-drop hold"
	)
	player.queue_free()
	await process_frame
