extends Node3D

const CROSSFADE_TIME := 0.15
const MIN_PLAYBACK_SPEED := 0.25
const MAX_PLAYBACK_SPEED := 2.0

@onready var character_preview: Node3D = $CharacterPreview
@onready var camera: Camera3D = $CameraRig/Camera3D
@onready var info_label: Label = $CanvasLayer/DebugPanel/MarginContainer/Info

var animation_player: AnimationPlayer
var skeleton: Skeleton3D
var animation_names: Array[StringName] = []
var imported_loop_modes: Dictionary = {}
var loop_overrides: Dictionary = {}
var current_index := 0
var playback_speed := 1.0
var is_paused := false
var crossfade_enabled := true
var preview_start_transform: Transform3D


func _ready() -> void:
	preview_start_transform = character_preview.transform
	camera.look_at(Vector3(0.0, 0.9, 0.0), Vector3.UP)
	animation_player = _find_descendant_of_type(character_preview, "AnimationPlayer") as AnimationPlayer
	skeleton = _find_descendant_of_type(character_preview, "Skeleton3D") as Skeleton3D
	if animation_player == null:
		info_label.text = "Animation Lab\n\nERROR: No AnimationPlayer found in canonical GLB."
		set_process(false)
		return
	for name in animation_player.get_animation_list():
		animation_names.append(name)
		imported_loop_modes[name] = animation_player.get_animation(name).loop_mode
	animation_names.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a).naturalnocasecmp_to(String(b)) < 0)
	if animation_names.is_empty():
		info_label.text = "Animation Lab\n\nERROR: AnimationPlayer contains no clips."
		set_process(false)
		return
	_play_selected(false)


func _process(_delta: float) -> void:
	_update_info()


func _unhandled_key_input(event: InputEvent) -> void:
	if not event.pressed or event.echo or animation_names.is_empty():
		return
	match event.keycode:
		KEY_LEFT, KEY_PAGEUP:
			_select_relative(-1)
		KEY_RIGHT, KEY_PAGEDOWN:
			_select_relative(1)
		KEY_SPACE:
			_replay_current()
		KEY_P:
			_toggle_pause()
		KEY_L:
			_toggle_loop()
		KEY_R:
			_reset_preview()
		KEY_C:
			crossfade_enabled = not crossfade_enabled
		KEY_MINUS, KEY_KP_SUBTRACT:
			_set_playback_speed(playback_speed - 0.25)
		KEY_EQUAL, KEY_PLUS, KEY_KP_ADD:
			_set_playback_speed(playback_speed + 0.25)
		KEY_0, KEY_KP_0:
			_set_playback_speed(1.0)
		KEY_1, KEY_2, KEY_3, KEY_4, KEY_5:
			var requested := int(event.keycode - KEY_1)
			if requested < animation_names.size():
				current_index = requested
				_play_selected()


func _select_relative(offset: int) -> void:
	current_index = wrapi(current_index + offset, 0, animation_names.size())
	_play_selected()


func _play_selected(use_crossfade := true) -> void:
	var name := animation_names[current_index]
	_apply_loop_mode(name)
	var blend := CROSSFADE_TIME if use_crossfade and crossfade_enabled else 0.0
	animation_player.play(name, blend, playback_speed)
	is_paused = false


func _replay_current() -> void:
	animation_player.stop()
	_play_selected(false)


func _toggle_pause() -> void:
	if is_paused:
		animation_player.play()
	else:
		animation_player.pause()
	is_paused = not is_paused


func _toggle_loop() -> void:
	var name := animation_names[current_index]
	var animation := animation_player.get_animation(name)
	var currently_looping := animation.loop_mode != Animation.LOOP_NONE
	loop_overrides[name] = not currently_looping
	_apply_loop_mode(name)


func _apply_loop_mode(name: StringName) -> void:
	var animation := animation_player.get_animation(name)
	if loop_overrides.has(name):
		animation.loop_mode = Animation.LOOP_LINEAR if bool(loop_overrides[name]) else Animation.LOOP_NONE
	else:
		animation.loop_mode = int(imported_loop_modes[name]) as Animation.LoopMode


func _set_playback_speed(value: float) -> void:
	playback_speed = clampf(value, MIN_PLAYBACK_SPEED, MAX_PLAYBACK_SPEED)
	animation_player.speed_scale = playback_speed


func _reset_preview() -> void:
	character_preview.transform = preview_start_transform
	_replay_current()


func _update_info() -> void:
	var name := animation_names[current_index]
	var animation := animation_player.get_animation(name)
	var skeleton_path := "Not found"
	if skeleton != null:
		skeleton_path = String(character_preview.get_path_to(skeleton))
	var loop_source := "override" if loop_overrides.has(name) else "imported"
	info_label.text = (
		"Animation Lab\n\n"
		+ "Current:  %s\n" % name
		+ "Index:    %d / %d\n" % [current_index + 1, animation_names.size()]
		+ "Duration: %.3f s\n" % animation.length
		+ "Position: %.3f s\n" % animation_player.current_animation_position
		+ "Loop:     %s (%s)\n" % ["ON" if animation.loop_mode != Animation.LOOP_NONE else "OFF", loop_source]
		+ "Playback: %.2fx%s\n" % [playback_speed, "  PAUSED" if is_paused else ""]
		+ "Crossfade: %s (%.2f s)\n\n" % ["ON" if crossfade_enabled else "OFF", CROSSFADE_TIME]
		+ "Skeleton: %s\n" % skeleton_path
		+ "Animations: %d\n\n" % animation_names.size()
		+ "Left/Right or PgUp/PgDn: Change clip\n"
		+ "1-5: Select first five clips   Space: Replay\n"
		+ "P: Pause   L: Loop override   C: Crossfade\n"
		+ "-/+: Playback speed   0: Reset speed   R: Recenter"
	)


func _find_descendant_of_type(node: Node, type_name: String) -> Node:
	if node.is_class(type_name):
		return node
	for child in node.get_children():
		var result := _find_descendant_of_type(child, type_name)
		if result != null:
			return result
	return null
