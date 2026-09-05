extends SceneTree
var failures: Array[String] = []
var body: CharacterBody3D
var animation: Node
var tree: AnimationTree
const DT := 1.0 / 60.0

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)
		push_error("V2: " + message)

func tick(stick := Vector2.ZERO, shift := false, jump := false) -> void:
	await physics_frame
	body.step_motor(DT, stick, shift, jump)
	animation._physics_process(DT)
	tree.advance(DT)

func settle(pos: Vector3) -> void:
	body.position = pos
	body.velocity = Vector3.ZERO
	for i in 30:
		await tick()
	check(body.is_on_floor(), "test setup reaches ground")

func run() -> void:
	var lab := load("res://test/player_v2_lab.tscn").instantiate() as Node3D
	root.add_child(lab)
	body = lab.get_node("PlayerV2")
	animation = body.get_node("AnimationController")
	tree = body.get_node("AnimationTree")
	body.set_physics_process(false)
	animation.set_physics_process(false)
	tree.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	await settle(Vector3(0, 0.1, 20))
	check(animation.current_state == &"Locomotion", "spawn remains idle without Land")
	var imported := load("res://Characters/Player/Models/Blender Master Rig.glb").instantiate() as Node3D
	var imported_player := imported.get_node("AnimationPlayer") as AnimationPlayer
	for clip: StringName in animation.CLIPS.values():
		check(imported_player.has_animation(clip), "actual imported clip exists: " + clip)
		print("V2_CLIP|", clip, "|", imported_player.get_animation(clip).length)
	check(imported.get_node_or_null("Base Armature and Mesh/Skeleton3D") != null, "canonical skeleton path")
	check(imported_player.get_animation(animation.CLIPS.Run) != animation.player.get_animation(animation.CLIPS.Run), "V2 normalization isolates imported animation resources")
	imported.free()
	for i in 60:
		await tick(Vector2(0, -1))
	check(absf(body.animation_state.horizontal_speed - 4.0) < 0.05, "Walk reaches 4 m/s")
	check(absf(animation.gait_blend - 1.0) < 0.01, "Walk blend settles")
	var run_action: Animation = animation.player.get_animation(animation.CLIPS.Run)
	for i in 180:
		await tick(Vector2(0, -1), true)
		check(body.animation_state.gait == 1, "Run remains selected before buildup completes")
		check(animation.gait_blend <= 2.001, "Run buildup never blends prematurely into Sprint")
	check(absf(body.target_speed - 5.5) < 0.05, "Run target builds gradually to 5.5 after three seconds")
	check(animation.player.get_animation(animation.CLIPS.Run) == run_action, "Run action remains the same resource during buildup")
	for i in 65:
		await tick(Vector2(0, -1), true)
	check(body.animation_state.gait == 2, "four seconds activates Sprint")
	for i in 30:
		await tick(Vector2(0, -1), true)
	check(absf(body.animation_state.horizontal_speed - 8.0) < 0.05, "Sprint reaches 8 m/s")
	var land_before: int = animation.landing_count
	await tick(Vector2(0, -1), true, true)
	check(animation.current_state == &"JumpMoving", "Sprint jump selects MovingJump immediately")
	check(body.animation_state.horizontal_speed >= 7.9, "jump preserves takeoff momentum")
	check(body.animation_state.gait == 2, "airborne gait stays Sprint")
	var saw_fall := false
	for i in 65:
		# Keep the long-running scenario on the test floor.
		if body.position.z < -38:
			body.position.z = 25
		await tick(Vector2(0, -1), true)
		saw_fall = saw_fall or animation.current_state == &"Fall"
	check(saw_fall, "jump descends through Fall")
	check(animation.landing_count == land_before + 1, "one Land per physical jump contact")
	check(body.animation_state.gait == 2, "Sprint persists on landing")
	for i in 30:
		await tick()
	check(body.animation_state.horizontal_speed < 0.1, "ground braking stops")
	await settle(Vector3(0, 0.1, 20))
	await tick(Vector2.ZERO, false, true)
	check(animation.current_state == &"JumpStanding", "Idle jump selects StandingJump")
	for i in 70:
		await tick()
	land_before = animation.landing_count
	for i in 30:
		await tick()
	check(animation.landing_count == land_before, "remaining grounded cannot repeat Land")
	# A tiny physical drop with snap disabled only in this test must not flash Fall.
	var snap := body.floor_snap_length
	body.floor_snap_length = 0.0
	body.position.y = 0.08
	body.velocity = Vector3.ZERO
	for i in 20:
		await tick()
		check(animation.current_state == &"Locomotion", "very short floor loss holds locomotion")
	check(animation.landing_count == land_before, "unpresented tiny drop skips Land")
	body.floor_snap_length = snap
	# Medium ledge: use the actual lab platform and run beyond its side.
	await settle(Vector3(9, 3.05, -20))
	land_before = animation.landing_count
	saw_fall = false
	for i in 125:
		await tick(Vector2(1, 0))
		check(animation.current_state not in [&"JumpStanding", &"JumpMoving"], "passive edge never selects Jump")
		saw_fall = saw_fall or animation.current_state == &"Fall"
	check(saw_fall, "medium platform fall presents Fall")
	check(animation.landing_count == land_before + 1, "medium platform contact plays one Land")
	await settle(Vector3(-9, 0.1, 1))
	for i in 165:
		await tick(Vector2(0, -1))
	check(body.position.y > 0.55, "natural CharacterBody traversal climbs low ramp")
	# Return transitions settle without replacing the graph or action resource.
	for i in 60:
		await tick()
	check(animation.current_state == &"Locomotion" and animation.gait_blend < 0.01, "release returns smoothly to Idle")
	check(ProjectSettings.get_setting("application/run/main_scene") == "res://test/player_v2_lab.tscn", "V2 lab is the active main scene")
	if failures.is_empty():
		print("PLAYER_V2: PASS")
	else:
		print("PLAYER_V2: FAIL ", failures.size())
	quit(0 if failures.is_empty() else 1)
