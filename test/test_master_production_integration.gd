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
	check(packed != null, "production Player scene loads")
	if packed == null:
		quit(1)
		return
	var player := packed.instantiate() as CharacterBody3D
	root.add_child(player)
	await process_frame
	await physics_frame
	var rig := player.get_node_or_null("VisualRoot/MasterRig")
	var anim_player := player.get_node_or_null("VisualRoot/MasterRig/AnimationPlayer") as AnimationPlayer
	var controller := player.get_node_or_null("AnimationController")
	var tree := player.get_node_or_null("AnimationTree") as AnimationTree
	check(rig != null, "Player instances the canonical MasterRig")
	check(player.get_node_or_null("VisualRoot/PlayerModel") == null, "legacy PlayerModel is not in production hierarchy")
	check(rig != null and rig.get_node_or_null("Base Armature and Mesh/Skeleton3D") != null, "canonical Skeleton3D is present")
	check(anim_player != null, "canonical AnimationPlayer is present")
	check(controller != null and tree != null and tree.active, "canonical AnimationTree controller is active")
	var required := {
		&"IDL_IDLE_A": Animation.LOOP_LINEAR,
		&"LOC_WALKING": Animation.LOOP_LINEAR,
		&"LOC_RUNNING_FOWARD_A": Animation.LOOP_LINEAR,
		&"LOC_SPRINT_FORWARD": Animation.LOOP_LINEAR,
		&"AIR_STANDING_JUMP_(2)": Animation.LOOP_NONE,
		&"AIR_FALLING_IDLE": Animation.LOOP_LINEAR,
		&"AIR_FALLING_TO_LANDING": Animation.LOOP_NONE,
	}
	if anim_player != null:
		check(anim_player.get_animation_list().size() == 846, "master AnimationPlayer retains all 846 actions")
		for action: StringName in required:
			check(anim_player.has_animation(action), "required action exists: " + action)
			if anim_player.has_animation(action):
				check(anim_player.get_animation(action).loop_mode == required[action], "loop mode is correct: " + action)
	var machine := tree.tree_root as AnimationNodeStateMachine
	for state_name in [&"Locomotion", &"Jump", &"Fall", &"Land"]:
		check(machine != null and machine.has_node(state_name), "state exists: " + state_name)
	for omitted in [&"WalkStart", &"RunStart", &"WalkStop", &"RunStop", &"Pivot"]:
		check(machine == null or not machine.has_node(omitted), "experimental state omitted: " + omitted)
	check(is_equal_approx(float(player.get("walk_speed")), 2.5), "walk speed remains 2.5")
	check(is_equal_approx(float(player.get("run_speed")), 4.0), "run speed remains 4.0")
	check(is_equal_approx(float(player.get("sprint_speed")), 8.0), "sprint speed remains 8.0")
	check(is_equal_approx(float(player.get("sprint_activation_delay")), 4.0), "sprint delay remains 4.0")
	if anim_player != null:
		for action in [&"LOC_WALKING", &"AIR_STANDING_JUMP_(2)", &"AIR_FALLING_TO_LANDING"]:
			var animation := anim_player.get_animation(action)
			for track_index in animation.get_track_count():
				if animation.track_get_type(track_index) == Animation.TYPE_POSITION_3D and String(animation.track_get_path(track_index)).ends_with(":mixamorig_Hips"):
					var first := animation.track_get_key_value(track_index, 0) as Vector3
					var last := animation.track_get_key_value(track_index, animation.track_get_key_count(track_index) - 1) as Vector3
					check(is_equal_approx(first.x, last.x) and is_equal_approx(first.y, last.y), "horizontal hips translation is neutralized: " + action)
					if action != &"LOC_WALKING":
						check(is_equal_approx(first.z, last.z), "airborne hips height is physics-owned: " + action)
	if failures.is_empty():
		print("MASTER_PRODUCTION_INTEGRATION: PASS")
		quit(0)
	else:
		print("MASTER_PRODUCTION_INTEGRATION: FAIL (%d)" % failures.size())
		quit(1)
