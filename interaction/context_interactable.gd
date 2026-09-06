extends Node3D
## General opt-in component. Subclasses can override availability and activation.
signal interacted(player)
enum Type { NONE, MANTLE, LADDER, ROPE, CRAWLSPACE, SQUEEZE, VAULT, LEDGE, WALL_RUN, WALL_JUMP, GENERIC_INTERACT }
enum Mode { CONTEXTUAL, AUTOMATIC }
@export var action_text: String = "Interact"
@export var interaction_type: Type = Type.GENERIC_INTERACT
@export var priority: float = 0.0
@export var available: bool = true
@export var requires_grounded: bool = true
@export var requires_line_of_sight: bool = true
@export var interaction_point: NodePath = ^"InteractionPoint"
@export_range(.1,5,.1) var test_duration: float = .8
var activation_count: int = 0

func _ready() -> void:
	add_to_group("context_interactable")

func can_interact(_player: Node) -> bool:
	return available and is_inside_tree() and not is_queued_for_deletion()

func get_action_text() -> String: return action_text
func get_interaction_type() -> int: return interaction_type
func get_interaction_point() -> Vector3:
	var marker=get_node_or_null(interaction_point)
	return marker.global_position if marker is Node3D else global_position

func candidate_data() -> Dictionary:
	return {"type":interaction_type,"mode":Mode.CONTEXTUAL,"source":self,"interaction_point":get_interaction_point(),"target_position":get_interaction_point(),"target_normal":Vector3.ZERO,"action_text":action_text,"priority":priority,"requires_grounded":requires_grounded,"test_duration":test_duration}

func begin_interaction(player: Node) -> bool:
	if not can_interact(player): return false
	if interaction_type!=Type.GENERIC_INTERACT:
		if not player.get_node("TraversalController").request_contextual_traversal(candidate_data()): return false
	activation_count+=1
	interacted.emit(player)
	print("Context interaction: ",name," / ",action_text)
	return true
