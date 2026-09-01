class_name DamagePacket
extends RefCounted

var damage: float
var source: Node
var hit_position: Vector3
var hit_direction: Vector3


func _init(
	damage_amount: float = 0.0,
	damage_source: Node = null,
	position: Vector3 = Vector3.ZERO,
	direction: Vector3 = Vector3.ZERO
) -> void:
	damage = maxf(damage_amount, 0.0)
	source = damage_source
	hit_position = position
	hit_direction = direction.normalized() if not direction.is_zero_approx() else Vector3.ZERO
