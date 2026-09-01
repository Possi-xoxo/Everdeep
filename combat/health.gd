class_name HealthComponent
extends Node

signal damaged(amount: float, current_health: float, hit: DamagePacket)
signal health_depleted(hit: DamagePacket)
signal health_reset(current_health: float)

@export_range(1.0, 10000.0, 1.0) var maximum_health: float = 100.0

var current_health: float


func _ready() -> void:
	current_health = maximum_health


func receive_damage(hit: DamagePacket) -> void:
	if hit == null or current_health <= 0.0:
		return
	var applied_damage := minf(hit.damage, current_health)
	current_health = maxf(current_health - applied_damage, 0.0)
	damaged.emit(applied_damage, current_health, hit)
	if current_health <= 0.0:
		health_depleted.emit(hit)


func reset_to_full() -> void:
	current_health = maximum_health
	health_reset.emit(current_health)
