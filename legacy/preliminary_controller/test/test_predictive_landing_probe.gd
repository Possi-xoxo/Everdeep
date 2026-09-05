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
	var normal := await _run_drop(0.40)
	check(normal.saw_fall, "drop enters Fall")
	check(normal.saw_prep, "0.40 m probe enters LandPrep before contact")
	check(normal.prep_was_airborne, "LandPrep remains physically airborne")
	check(normal.saw_land, "actual contact commits Land")
	check(normal.land_count == 1, "meaningful drop triggers Land exactly once")

	var miss := await _run_drop(0.01)
	check(miss.saw_fall, "short-probe drop enters Fall")
	check(not miss.saw_prep, "short probe can miss anticipation")
	check(miss.saw_land, "probe miss still lands from physical contact")
	check(miss.land_count == 1, "probe miss still triggers one Land")

	if failures.is_empty():
		print("PREDICTIVE_LANDING_PROBE: PASS")
		quit(0)
	else:
		print("PREDICTIVE_LANDING_PROBE: FAIL (%d)" % failures.size())
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

func _run_drop(probe_distance: float) -> Dictionary:
	var player := (load("res://player/player.tscn") as PackedScene).instantiate() as CharacterBody3D
	var controller := player.get_node("AnimationController")
	controller.set("landing_probe_distance", probe_distance)
	player.position = Vector3(0.0, 0.2, 0.0)
	root.add_child(player)
	for settle_frame in 8:
		await physics_frame
	player.position = Vector3(0.0, 2.0, 0.0)
	player.velocity = Vector3.ZERO
	var result := {
		"saw_fall": false,
		"saw_prep": false,
		"prep_was_airborne": false,
		"saw_land": false,
		"land_count": 0,
	}
	for frame in 300:
		await physics_frame
		var animation_state: StringName = controller.get("current_animation_state")
		if animation_state == &"Fall":
			result.saw_fall = true
		elif animation_state == &"LandPrep":
			result.saw_prep = true
			result.prep_was_airborne = result.prep_was_airborne or not player.is_on_floor()
		elif animation_state == &"Land":
			result.saw_land = true
		result.land_count = int(controller.get("landing_trigger_count"))
		if result.saw_land and animation_state == &"Locomotion":
			break
	player.queue_free()
	await process_frame
	return result
