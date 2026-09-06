extends "res://interaction/context_interactable.gd"
## Adapter only: geometry is owned by LedgeDetector, UI by ContextInteraction.
func _ready() -> void:
	action_text="Climb"
	interaction_type=Type.MANTLE
	available=false
	requires_line_of_sight=false # Detector already checks front/top/clearance.
	super._ready()

func can_interact(player: Node) -> bool:
	var detector=get_parent()
	var obstacle=detector.result.get("obstacle_source")
	return player==detector.motor and super.can_interact(player) and detector.result.get("valid",false) and is_instance_valid(obstacle) and not obstacle.is_queued_for_deletion()

func get_interaction_point() -> Vector3:
	return get_parent().result.get("obstacle_position",global_position)

func candidate_data() -> Dictionary:
	var data=super.candidate_data()
	# Preserve validated landing/normal fields over generic placeholder data.
	data.merge(get_parent().result,true)
	return data

func begin_interaction(player: Node) -> bool:
	get_parent().refresh_contextual_candidate()
	if not can_interact(player): return false
	return super.begin_interaction(player)
