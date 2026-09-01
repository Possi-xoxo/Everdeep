class_name MeleeHitbox
extends Area3D

signal hit_confirmed(hit: DamagePacket, hurtbox: Hurtbox)

@export_range(0.0, 10000.0, 1.0) var damage: float = 20.0
@export var debug_hits: bool = false

var _damage_source: Node
var _already_hit_targets: Dictionary = {}


func _ready() -> void:
	monitoring = false
	area_entered.connect(_on_area_entered)


func begin_attack(source: Node) -> void:
	_damage_source = source
	_already_hit_targets.clear()
	monitoring = true
	call_deferred("_check_existing_overlaps")


func end_attack() -> void:
	monitoring = false
	_damage_source = null


func _check_existing_overlaps() -> void:
	if not monitoring:
		return
	for area in get_overlapping_areas():
		_try_hit(area)


func _on_area_entered(area: Area3D) -> void:
	_try_hit(area)


func _try_hit(area: Area3D) -> void:
	if not monitoring or not area is Hurtbox:
		return
	var hurtbox := area as Hurtbox
	var target_id := hurtbox.get_damage_target_id()
	if _already_hit_targets.has(target_id):
		return

	var direction := -global_basis.z
	var hit := DamagePacket.new(damage, _damage_source, hurtbox.global_position, direction)
	if not hurtbox.receive_hit(hit):
		return
	_already_hit_targets[target_id] = true
	if debug_hits:
		print("Combat hit: ", damage, " damage to ", hurtbox.get_path())
	hit_confirmed.emit(hit, hurtbox)
