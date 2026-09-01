class_name PlayerAnimationController
extends Node

const IDLE_SOURCE := "res://Characters/Player/Animations/Idle (6).fbx"
const WALK_SOURCE := "res://Characters/Player/Animations/Walking (9).fbx"
const RUN_SOURCE := "res://Characters/Player/Animations/Running (3).fbx"
const SOURCE_CLIP := &"mixamo_com"
const LIBRARY_NAME := &"Locomotion"
const IDLE_NAME := &"Idle"
const WALK_NAME := &"Walk"
const RUN_NAME := &"Run"
const BLEND_PARAMETER := &"parameters/Locomotion/blend_position"

@export var actor: CharacterBody3D
@export var animation_player: AnimationPlayer
@export var animation_tree: AnimationTree
@export var walk_blend_speed := 5.0
@export var run_blend_speed := 8.0
@export var debug_locomotion_animation := false

var current_horizontal_speed := 0.0
var current_blend_value := 0.0
var dominant_animation := &"Idle"
var _last_dominant_animation := &""

func _ready() -> void:
	if actor == null or animation_player == null or animation_tree == null:
		push_error("PlayerAnimationController is missing a required node reference.")
		set_physics_process(false)
		return
	if not _install_locomotion_library():
		set_physics_process(false)
		return
	_configure_animation_tree()

func _physics_process(_delta: float) -> void:
	current_horizontal_speed = Vector2(actor.velocity.x, actor.velocity.z).length()
	current_blend_value = clampf(current_horizontal_speed, 0.0, run_blend_speed)
	animation_tree.set(BLEND_PARAMETER, current_blend_value)
	_update_dominant_animation()

func _install_locomotion_library() -> bool:
	var library := AnimationLibrary.new()
	var sources := {
		IDLE_NAME: IDLE_SOURCE,
		WALK_NAME: WALK_SOURCE,
		RUN_NAME: RUN_SOURCE,
	}
	for animation_name: StringName in sources:
		var animation := _load_source_animation(sources[animation_name])
		if animation == null:
			push_error("Could not load locomotion animation %s from %s." % [animation_name, sources[animation_name]])
			return false
		animation.loop_mode = Animation.LOOP_LINEAR
		_neutralize_horizontal_root_translation(animation)
		library.add_animation(animation_name, animation)
	if animation_player.has_animation_library(LIBRARY_NAME):
		animation_player.remove_animation_library(LIBRARY_NAME)
	animation_player.add_animation_library(LIBRARY_NAME, library)
	return true

func _load_source_animation(source_path: String) -> Animation:
	var packed := load(source_path) as PackedScene
	if packed == null:
		return null
	var source_root := packed.instantiate()
	var source_player := source_root.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if source_player == null or not source_player.has_animation(SOURCE_CLIP):
		source_root.free()
		return null
	var animation := source_player.get_animation(SOURCE_CLIP).duplicate(true) as Animation
	source_root.free()
	return animation

func _neutralize_horizontal_root_translation(animation: Animation) -> void:
	for track_index in animation.get_track_count():
		if animation.track_get_type(track_index) != Animation.TYPE_POSITION_3D:
			continue
		if not String(animation.track_get_path(track_index)).ends_with(":mixamorig_Hips"):
			continue
		if animation.track_get_key_count(track_index) == 0:
			continue
		var reference := animation.track_get_key_value(track_index, 0) as Vector3
		for key_index in animation.track_get_key_count(track_index):
			var value := animation.track_get_key_value(track_index, key_index) as Vector3
			value.x = reference.x
			value.z = reference.z
			animation.track_set_key_value(track_index, key_index, value)

func _configure_animation_tree() -> void:
	var blend_space := AnimationNodeBlendSpace1D.new()
	blend_space.min_space = 0.0
	blend_space.max_space = run_blend_speed
	blend_space.value_label = "Horizontal Speed"
	blend_space.add_blend_point(_animation_node(IDLE_NAME), 0.0, -1, IDLE_NAME)
	blend_space.add_blend_point(_animation_node(WALK_NAME), walk_blend_speed, -1, WALK_NAME)
	blend_space.add_blend_point(_animation_node(RUN_NAME), run_blend_speed, -1, RUN_NAME)
	var blend_tree := AnimationNodeBlendTree.new()
	blend_tree.add_node("Locomotion", blend_space, Vector2(260, 120))
	blend_tree.connect_node("output", 0, "Locomotion")
	animation_tree.tree_root = blend_tree
	animation_tree.active = true
	animation_tree.set(BLEND_PARAMETER, 0.0)

func _animation_node(animation_name: StringName) -> AnimationNodeAnimation:
	var node := AnimationNodeAnimation.new()
	node.resource_name = animation_name
	node.animation = StringName("%s/%s" % [LIBRARY_NAME, animation_name])
	return node

func _update_dominant_animation() -> void:
	if current_blend_value < walk_blend_speed * 0.5:
		dominant_animation = IDLE_NAME
	elif current_blend_value < (walk_blend_speed + run_blend_speed) * 0.5:
		dominant_animation = WALK_NAME
	else:
		dominant_animation = RUN_NAME
	if debug_locomotion_animation and dominant_animation != _last_dominant_animation:
		print("Locomotion animation: speed=%.2f blend=%.2f dominant=%s" % [current_horizontal_speed, current_blend_value, dominant_animation])
	_last_dominant_animation = dominant_animation
