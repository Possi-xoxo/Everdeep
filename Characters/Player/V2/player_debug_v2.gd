extends CanvasLayer
@export var enabled: bool = true
@onready var label: Label = $Panel/Label
@onready var motor = get_parent()

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F3:
		enabled = not enabled

func _process(_delta: float) -> void:
	$Panel.visible = enabled
	if not enabled:
		return
	var s = motor.animation_state
	var gait: String = ["WALK", "RUN", "SPRINT"][s.gait] if s.horizontal_speed > 0.1 or s.move_input_magnitude > 0.01 else "IDLE"
	label.text = "Player V2\n\nGait: %s\nPhysical: %s\nAnimation: %s\nHorizontal Speed: %.2f m/s\nVertical Velocity: %.2f m/s\nRun Buildup: %.0f%%\nAir Time: %.2f s\n\nWASD: Move  Shift: Run / Sprint\nSpace: Jump  Mouse: Orbit\nF3: Debug  Esc: Release mouse" % [gait, "GROUNDED" if s.is_grounded else "AIRBORNE", $"../AnimationController".presentation_label(), s.horizontal_speed, s.vertical_velocity, s.run_buildup_ratio * 100.0, s.air_time]
