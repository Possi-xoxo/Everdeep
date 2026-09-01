class_name TargetDummy
extends Node3D

@export_range(0.1, 5.0, 0.1) var reset_delay: float = 1.0

@onready var visual_root: Node3D = $VisualRoot
@onready var body_mesh: MeshInstance3D = $VisualRoot/BodyMesh
@onready var health: HealthComponent = $Health

var _feedback_tween: Tween
var _body_material: StandardMaterial3D
var _base_material_color: Color


func _ready() -> void:
	_body_material = body_mesh.material_override as StandardMaterial3D
	if _body_material != null:
		_base_material_color = _body_material.albedo_color
	health.damaged.connect(_on_damaged)
	health.health_depleted.connect(_on_health_depleted)
	health.health_reset.connect(_on_health_reset)


func _on_damaged(_amount: float, _current_health: float, hit: DamagePacket) -> void:
	if _feedback_tween != null:
		_feedback_tween.kill()
	var recoil_direction := hit.hit_direction
	var recoil_sign := signf(recoil_direction.x) if absf(recoil_direction.x) > 0.05 else 1.0
	visual_root.rotation = Vector3.ZERO
	_feedback_tween = create_tween()
	_feedback_tween.set_trans(Tween.TRANS_QUAD)
	_feedback_tween.tween_property(visual_root, "rotation:z", deg_to_rad(-10.0 * recoil_sign), 0.06)
	if _body_material != null:
		_feedback_tween.parallel().tween_property(_body_material, "albedo_color", Color(1.0, 0.15, 0.08), 0.03)
	_feedback_tween.tween_property(visual_root, "rotation:z", 0.0, 0.14)
	if _body_material != null:
		_feedback_tween.parallel().tween_property(_body_material, "albedo_color", _base_material_color, 0.14)


func _on_health_depleted(_hit: DamagePacket) -> void:
	if _feedback_tween != null:
		_feedback_tween.kill()
	_feedback_tween = create_tween()
	_feedback_tween.set_trans(Tween.TRANS_BACK)
	_feedback_tween.tween_property(visual_root, "scale", Vector3(1.0, 0.15, 1.0), 0.18)
	await get_tree().create_timer(reset_delay).timeout
	health.reset_to_full()


func _on_health_reset(_current_health: float) -> void:
	visual_root.rotation = Vector3.ZERO
	visual_root.scale = Vector3.ONE
	if _body_material != null:
		_body_material.albedo_color = _base_material_color
