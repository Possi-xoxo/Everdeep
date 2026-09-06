extends CanvasLayer
@export var enabled: bool = true
@export var lock_tuning_debug: bool = false
@onready var label: Label = $Panel/Label
@onready var motor = get_parent()

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode==KEY_F10:
		lock_tuning_debug=not lock_tuning_debug
		if lock_tuning_debug: enabled=true
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F9:
		var ik=motor.get_node("FootIKController")
		ik.knee_ik_debug=not ik.knee_ik_debug
		if ik.knee_ik_debug: enabled=true
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F8:
		var ik = motor.get_node("FootIKController")
		ik.foot_ik_debug=not ik.foot_ik_debug
		if ik.foot_ik_debug: enabled=true
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F7:
		var feet = motor.get_node("FootGrounding")
		feet.foot_grounding_debug=not feet.foot_grounding_debug
		if feet.foot_grounding_debug: enabled=true
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F3:
		enabled = not enabled
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F4:
		motor.step_solver.debug_steps = not motor.step_solver.debug_steps
		if motor.step_solver.debug_steps: enabled = true

func _process(_delta: float) -> void:
	$Panel.visible = enabled
	if not enabled:
		return
	var s = motor.animation_state
	if motor.debug_walk_direction:
		label.text=motor.walk_direction_debug_text()
		return
	if motor.crouch.crouch_debug:
		label.text=motor.crouch.debug_text()
		return
	var gait: String = ["WALK", "RUN", "SPRINT"][s.gait] if s.horizontal_speed > 0.1 or s.move_input_magnitude > 0.01 else "IDLE"
	label.text = "Player V2\n\nGait: %s\nPhysical: %s\nAnimation: %s\nHorizontal Speed: %.2f m/s\nVertical Velocity: %.2f m/s\nRun Buildup: %.0f%%\nAir Time: %.2f s\n\nWASD: Move  Shift: Run / Sprint\nSpace: Jump  Mouse: Orbit\nF3: Debug  Esc: Release mouse" % [gait, "GROUNDED" if s.is_grounded else "AIRBORNE", $"../AnimationController".presentation_label(), s.horizontal_speed, s.vertical_velocity, s.run_buildup_ratio * 100.0, s.air_time]
	var animation = $"../AnimationController"
	label.text+="\nAlt: Dodge"
	if s.locked_on: label.text=label.text.replace("Shift: Run / Sprint","Shift: Combat Run (no Sprint)").replace("Mouse: Orbit","Mouse orbit disabled")
	if lock_tuning_debug:
		label.text="F10: Tuning overlay\n"+motor.lock_on.debug_text()
		label.text+="\nAnimation Branch: "+("LOCKED" if s.locked_on else "FREE")
		if s.locked_on: label.text+="\nCombat Animation: "+animation.grounded.combat.label(s)
		label.text+="\n\n"+motor.get_node("CameraRig").debug_text()
		var combat=animation.grounded.combat
		label.text+="\nLOCK MOVEMENT\nSpeed Target: %.2f / Actual: %.2f\nRun Requested: %s / Sprint Allowed: %s\nRaw Combat Input: %s\nSmoothed Blend: %s / Gait Blend: %.2f" % [motor.target_speed,s.horizontal_speed,s.gait==1,not s.locked_on,combat.raw_combat_move_input,combat.move_blend,combat.gait_blend]
		var weights: Vector4=combat.direction_weights()
		label.text+="\nDirectional Weights (F/B/L/R): %.2f / %.2f / %.2f / %.2f" % [weights.x,weights.y,weights.z,weights.w]
	var ik = motor.get_node("FootIKController")
	var hands=motor.get_node("EnvironmentalHandInteraction")
	if hands.environment_hand_debug: label.text+="\n\n"+hands.debug_text()
	var hand_ik=motor.get_node("EnvironmentalHandIK")
	if hands.environment_hand_debug or hand_ik.environment_hand_ik_debug: label.text="F11: Environmental hand debug\nState: "+hands.state_reason+"\n"+hand_ik.debug_text()
	if lock_tuning_debug or motor.dodge.debug_dodge: label.text+="\n\n"+motor.lock_on.realign_debug_text()
	if motor.dodge.debug_dodge: label.text+="\n\n"+motor.dodge.handoff_debug_text()+motor.dodge.debug_text(motor.velocity)
	if motor.dodge.debug_dodge or motor.roll_traversal.debug_steps: label.text+="\n\n"+motor.roll_traversal.debug_text()
	if ik.knee_ik_debug: label.text += "\n\n"+ik.knee_debug_text()
	if ik.foot_ik_debug: label.text += "\n\n"+ik.debug_text()
	var feet = motor.get_node("FootGrounding")
	if feet.foot_grounding_debug:
		label.text += "\n\n" + feet.debug_text()
	if animation.debug_facing_and_passive_fall:
		label.text += "\n\n" + animation.facing_and_fall_debug_text()
	if motor.step_solver.debug_steps:
		label.text += "\n\n" + motor.step_solver.debug_text()
	if animation.debug_tree_playback:
		label.text += "\n\n" + animation.playback_debug_text()
	var turn = motor.turn_180
	if turn != null and turn.debug_180:
		label.text += "\n\nRun180 Active: %s\nStored Entry Speed: %.2f\nTurn Target Direction: %s\nHorizontal Translation Paused: %s" % [turn.active and turn.running, turn.entry_speed, turn.target_direction, turn.active and turn.running and turn.progress >= turn.run_180_carry_end_progress]
		label.text += "\n\n180 Turn Active: %s\nTurn Type: %s\nTurn Progress: %.2f\nTurn Target Angle: %.1f\nMovement Multiplier: %.2f\nSource Gait: %s\nTarget Gait: %s" % [turn.active, "RUN" if turn.running else "WALK", turn.progress, rad_to_deg(turn.target_angle), turn.movement_multiplier, ["WALK","RUN","SPRINT"][turn.source_gait], ["WALK","RUN","SPRINT"][turn.target_gait]]
	if motor.debug_turn_arc:
		label.text += "\n\nDesired Angle: %.1f degrees\nArc Active: %s\nArc Limit: %.1f degrees\nFacing Delta: %.1f degrees\nAllowed Move Delta: %.1f degrees\nTurn Sign: %s" % [rad_to_deg(s.desired_turn_angle), s.turn_arc_active, motor.max_move_angle_from_forward, rad_to_deg(s.facing_delta), rad_to_deg(s.allowed_move_delta), "Left" if motor.last_large_turn_sign > 0 else "Right"]
	if animation.grounded.debug_grounded:
		label.text += "\n\nMove Local: (%.2f, %.2f)\nLocomotion Direction: %s\nTransition: %s\nFacing Delta: %.1f degrees" % [s.move_local.x, s.move_local.y, animation.grounded.direction_label(s), "None" if animation.grounded.transition == &"Loops" else animation.grounded.transition, rad_to_deg(s.facing_delta)]
	if animation.debug_land_visual_compression:
		label.text += "\n\nLand Visual Offset: %.3f\nVisualRoot Base Y: %.3f\nVisualRoot Current Y: %.3f" % [animation.land_visual_offset, animation.visual_root_base_position.y, $"../VisualRoot".position.y]
		label.text += "\nLand Source / Window: %.3f / %.3f\nContact Frame: %d" % [animation.land_source_progress, animation.land_window_progress, animation.land_contact_frame]
		if not animation.land_debug_sample.is_empty():
			label.text += "\nFoot Bone Y (L/R): %.3f / %.3f" % [animation.land_debug_sample.left_foot_y, animation.land_debug_sample.right_foot_y]
