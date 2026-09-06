extends SceneTree
const DT := 1.0 / 60.0
var body: CharacterBody3D
var animation: Node
var tree: AnimationTree
var visual: Node3D
var collision: CollisionShape3D
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, message: String) -> void:
	if not value and message not in failures:
		failures.append(message)
		push_error(message)

func tick(stick := Vector2.ZERO, shift := false, jump := false) -> void:
	await physics_frame
	body.step_motor(DT, stick, shift, jump)
	var physical_transform := body.transform
	var physical_velocity := body.velocity
	var collision_transform := collision.transform
	var dimensions := Vector2(collision.shape.radius, collision.shape.height)
	var visual_basis := visual.basis
	animation._physics_process(DT)
	tree.advance(DT)
	check(body.transform == physical_transform and body.velocity == physical_velocity, "animation must not modify body transform or velocity")
	check(collision.transform == collision_transform and Vector2(collision.shape.radius, collision.shape.height) == dimensions, "animation must not modify collider")
	check(visual.basis == visual_basis, "compression must not modify scale or facing")
	check(animation.land_visual_offset >= -float(animation._land_profile.amount) - 0.00001 and animation.land_visual_offset <= 0.00001, "sink remains within selected profile limits")
	check(visual.position == animation.visual_root_base_position + Vector3(0, animation.land_visual_offset, 0), "sink is absolute relative to base")

func settle(pos := Vector3(0, 0.1, 18)) -> void:
	body.position = pos
	body.velocity = Vector3.ZERO
	for i in 35:
		await tick()
	check(body.is_on_floor(), "setup grounded")
	check(visual.position == animation.visual_root_base_position, "recovery returns exactly to base")

func jump_until_land(stick := Vector2.ZERO, shift := false) -> void:
	var count: int = animation.landing_count
	await tick(stick, shift, true)
	check(animation.land_visual_offset == 0.0, "takeoff restores visual base")
	for i in 90:
		await tick(stick, shift)
		if animation.landing_count > count:
			return
	check(false, "jump must reach contact Land")

func run() -> void:
	var lab := load("res://test/player_v2_lab.tscn").instantiate() as Node3D
	root.add_child(lab)
	body = lab.get_node("PlayerV2")
	animation = body.get_node("AnimationController")
	tree = body.get_node("AnimationTree")
	visual = body.get_node("VisualRoot")
	collision = body.get_node("CollisionShape3D")
	body.set_physics_process(false)
	animation.set_physics_process(false)
	tree.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	await settle()
	check(animation.visual_root_base_position == Vector3.ZERO, "neutral base unchanged")
	check(not animation.debug_land_visual_compression, "compression debug defaults off")
	for episode in 3:
		await jump_until_land()
		var deepest := 0.0
		for i in 45:
			await tick()
			deepest = minf(deepest, animation.land_visual_offset)
		check(animation.active_standing_landing, "standing jump at rest selects standing-only landing")
		check(deepest <= -animation.standing_land_sink_amount * 0.95, "stationary Land reaches calibrated peak compression")
		check(visual.position == animation.visual_root_base_position, "repeated Land has no drift")
	# Walking, running and sprinting contacts share one calibrated profile.
	for gait in [0, 1, 2]:
		await settle()
		body.set("_run_time", 4.0 if gait == 2 else 0.0)
		for i in 15:
			await tick(Vector2(0, -1), gait > 0)
		await jump_until_land(Vector2(0, -1), gait > 0)
		check(not animation.active_standing_landing, "moving jump preserves existing landing profile")
		check(float(animation._land_profile.amount) == animation.land_visual_sink_amount and float(animation._land_profile.start) == animation.land_clip_start, "moving landing retains live sink and clip settings")
		var deepest := 0.0
		for i in 30:
			await tick(Vector2(0, -1), gait > 0)
			deepest = minf(deepest, animation.land_visual_offset)
		check(deepest < -0.03, "moving Land compresses briefly")
		check(body.animation_state.gait == gait, "moving Land retains gait")
		check(body.animation_state.horizontal_speed >= 3.9, "moving Land retains momentum")
		check(visual.position == animation.visual_root_base_position, "moving Land recovers")
	await settle()
	await jump_until_land()
	await tick()
	await tick()
	# Verify the resulting pose, not merely that an offset property was assigned.
	var skeleton := body.get_node("VisualRoot/MasterRig/Base Armature and Mesh/Skeleton3D") as Skeleton3D
	# Source 0.40 lands on the toes with raised ankles; ankle height is not
	# a valid contact proxy for this crouch. Mesh soles are measured by render QA.
	for bone_name in ["mixamorig_LeftToe_End", "mixamorig_RightToe_End"]:
		var toe_y := (skeleton.global_transform * skeleton.get_bone_global_pose(skeleton.find_bone(bone_name)).origin).y - body.global_position.y
		check(toe_y > -0.04 and toe_y < 0.06, "calibrated early Land toe must be near floor: " + bone_name)
	check(animation.land_source_progress >= float(animation._land_profile.start), "evaluated Land starts inside selected source window")
	var frozen_offset: float = animation.land_visual_offset
	animation._physics_process(DT)
	tree.advance(0.0)
	check(is_equal_approx(animation.land_visual_offset, frozen_offset), "sink follows animation progress when pose clock is paused")
	animation.debug_land_visual_compression = true
	await tick()
	check(not animation.land_debug_sample.is_empty(), "optional foot diagnostics sample actual imported bones")
	animation.debug_land_visual_compression = false
	check(animation.land_visual_offset < 0.0, "cancel fixture is compressed")
	await tick(Vector2.ZERO, false, true)
	check(animation.current_state == &"JumpStanding" and visual.position == animation.visual_root_base_position, "immediate re-jump clears compression")
	for i in 100:
		await tick()
	# New movement exits Land without a one-frame teleport to neutral.
	await jump_until_land()
	for i in 2:
		await tick()
	var previous_depth: float = animation.land_visual_offset
	for i in 20:
		await tick(Vector2(0, -1))
		check(absf(animation.land_visual_offset - previous_depth) <= float(animation._land_profile.amount) * 0.25 + 0.001, "movement cancellation recovers smoothly relative to configured depth")
		previous_depth = animation.land_visual_offset
	await settle()
	var count: int = animation.landing_count
	body.floor_snap_length = 0.0
	body.position.y = 0.08
	body.velocity = Vector3.ZERO
	for i in 20:
		await tick()
		check(animation.land_visual_offset == 0.0, "suppressed tiny drop never compresses")
	check(animation.landing_count == count, "tiny drop retains landing suppression")
	body.floor_snap_length = 0.3
	# Actual sloped contact, not a fabricated Land transition.
	body.position = Vector3(9, 3.5, -10)
	body.velocity = Vector3.ZERO
	var ramp_compressed := false
	for i in 90:
		await tick()
		ramp_compressed = ramp_compressed or animation.land_visual_offset < -0.03
	check(ramp_compressed and body.is_on_floor(), "ramp landing compresses with stable physical contact")
	check(visual.position == animation.visual_root_base_position, "ramp landing recovers exactly")
	# Zero amount and zero durations are supported Inspector settings.
	await settle()
	animation.land_visual_sink_amount = 0.0
	animation.standing_land_sink_amount = 0.0
	animation.land_sink_peak_progress = 0.0
	animation.land_sink_recover_progress = 0.0
	animation.land_visual_recover_time = 0.0
	await jump_until_land()
	for i in 30:
		await tick()
		check(visual.position == animation.visual_root_base_position, "zero sink disables visual translation")
	print("LAND_VISUAL_COMPRESSION_V2: ", "PASS" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)
