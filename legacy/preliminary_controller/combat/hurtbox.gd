class_name Hurtbox
extends Area3D

@export var health: HealthComponent


func _ready() -> void:
	monitoring = false
	monitorable = true


func receive_hit(hit: DamagePacket) -> bool:
	if health == null or hit == null:
		return false
	health.receive_damage(hit)
	return true


func get_damage_target_id() -> int:
	return health.get_instance_id() if health != null else get_instance_id()
