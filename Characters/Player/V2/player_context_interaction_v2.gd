extends Node3D
const Context = preload("res://interaction/context_interactable.gd")
@export_group("Context Interaction")
@export_range(1.5,2.5,.1) var interaction_detection_range: float = 2.0
## Full cone width, centered on the player's visual forward direction.
@export_range(60,100,1) var interaction_detection_angle: float = 80.0
@export_range(0,.5,.01) var candidate_switch_margin: float = .15
@export var interaction_debug: bool = false
var selected: Node3D
var selected_score: float = -INF
var prompt: Label
var debug_label: Label
var debug_mesh: MeshInstance3D
var _consumed_climb: String = ""
var _awaiting_climb_exit: bool = false
var _climb_exit_position := Vector3.ZERO
var held_climb_intent: bool = false
@onready var motor=get_parent()

func _ready() -> void:
	var layer:=CanvasLayer.new()
	layer.name="InteractionUI"
	add_child(layer)
	prompt=Label.new()
	prompt.name="Prompt"
	prompt.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	prompt.offset_left=-220
	prompt.offset_right=220
	prompt.offset_top=-90
	prompt.offset_bottom=-50
	prompt.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	prompt.add_theme_font_size_override("font_size",22)
	prompt.mouse_filter=Control.MOUSE_FILTER_IGNORE
	layer.add_child(prompt)
	prompt.hide()
	debug_label=Label.new()
	debug_label.position=Vector2(900,30)
	debug_label.mouse_filter=Control.MOUSE_FILTER_IGNORE
	layer.add_child(debug_label)
	debug_mesh=MeshInstance3D.new()
	add_child(debug_mesh)
	debug_mesh.top_level=true
	debug_mesh.global_transform=Transform3D.IDENTITY
	var material:=StandardMaterial3D.new()
	material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color=Color.CYAN
	debug_mesh.material_override=material

func valid(candidate) -> bool:
	if not is_instance_valid(candidate) or candidate.is_queued_for_deletion() or not candidate.is_inside_tree(): return false
	if not candidate.can_interact(motor) or not motor.traversal.can_begin(candidate.requires_grounded): return false
	if candidate==motor.traversal.hang.top_entry: return true # Full local entry query owns range/facing/path.
	var point: Vector3=candidate.get_interaction_point()
	var origin: Vector3=motor.global_position+Vector3.UP
	var offset:=point-origin
	var detector=motor.traversal.get_node("LedgeDetector")
	if candidate==detector.candidate:
		if float(detector.result.get("distance",INF))>detector.mantle_acquisition_distance: return false
		if not _held_rearm_allowed(): return false
	elif offset.length()>interaction_detection_range: return false
	var horizontal:=Vector3(offset.x,0,offset.z)
	var forward: Vector3=-motor.visual.global_basis.z
	forward.y=0
	var cone: float=motor.traversal.mantle.mantle_interaction_cone_angle if candidate==motor.traversal.get_node("LedgeDetector").candidate else interaction_detection_angle
	if horizontal.length()>.001 and forward.normalized().dot(horizontal.normalized())<cos(deg_to_rad(cone*.5))-.00001: return false
	if candidate.requires_line_of_sight:
		var q:=PhysicsRayQueryParameters3D.create(origin,point,motor.collision_mask,[motor.get_rid()])
		var hit:=get_world_3d().direct_space_state.intersect_ray(q)
		if not hit.is_empty() and hit.collider!=candidate and not candidate.is_ancestor_of(hit.collider): return false
	return true

func score(candidate) -> float:
	var offset: Vector3=candidate.get_interaction_point()-(motor.global_position+Vector3.UP)
	var facing: float=(-motor.visual.global_basis.z).normalized().dot(offset.normalized())
	return candidate.priority+2.0*facing-offset.length()/interaction_detection_range

func scan() -> void:
	motor.traversal.hang.top_entry.refresh()
	motor.traversal.get_node("LedgeDetector").refresh_contextual_candidate()
	var best: Node3D=selected if valid(selected) else null
	var best_score: float=score(best) if best!=null else -INF
	for candidate in get_tree().get_nodes_in_group("context_interactable"):
		if not valid(candidate): continue
		var value:=score(candidate)
		if best==null or value>best_score+candidate_switch_margin:
			best=candidate
			best_score=value
	selected=best
	selected_score=best_score
	refresh_ui()

func activate_selected() -> bool:
	# Deliberately revalidate the selected object, not a stale cached score.
	if not valid(selected):
		selected=null
		refresh_ui()
		return false
	var accepted: bool=selected.begin_interaction(motor)
	if accepted and selected==motor.traversal.get_node("LedgeDetector").candidate:
		_consumed_climb=_climb_key()
		_awaiting_climb_exit=true
	if accepted: selected=null
	refresh_ui()
	return accepted

func _climb_key() -> String:
	var data: Dictionary=motor.traversal.get_node("LedgeDetector").result
	var source=data.get("obstacle_source")
	if not data.get("valid",false) or not is_instance_valid(source): return ""
	# Same collider may contain multiple ledges. Height/face identify the ledge,
	# without rearming just because the ray slides sideways along the same face.
	var normal: Vector3=data.obstacle_normal
	return "%s/%.1f/%s" % [source.get_instance_id(),data.top_position.y,normal.snapped(Vector3.ONE*.1)]

func _held_rearm_allowed() -> bool:
	if not held_climb_intent or _consumed_climb.is_empty(): return true
	if _awaiting_climb_exit or _climb_key()==_consumed_climb: return false
	var traveled: Vector3=motor.global_position-_climb_exit_position
	return Vector2(traveled.x,traveled.z).length()>=.5 and motor.animation_state.move_input_magnitude>.01

func tick(pressed: bool=false, held: bool=false) -> void:
	if motor.traversal.hang.is_attached():
		selected=null
		var movement_input: bool=Input.is_action_pressed("move_left") or Input.is_action_pressed("move_right") or Input.is_action_pressed("move_forward") or Input.is_action_pressed("move_backward")
		if pressed and not Input.is_action_just_pressed("jump") and not movement_input:
			motor.traversal.hang.navigation.resolve(motor.traversal.hang,"INTERACT")
		return
	held_climb_intent=held or pressed
	if not held_climb_intent:
		_consumed_climb=""
		_awaiting_climb_exit=false
	if _awaiting_climb_exit and not motor.traversal.is_traversing:
		_awaiting_climb_exit=false
		_climb_exit_position=motor.global_position
	scan()
	if not held_climb_intent: return
	if motor.traversal.is_traversing: return
	var detector=motor.traversal.get_node("LedgeDetector")
	if selected!=detector.candidate:
		# Held intent never fires doors, generic interactions or other actions.
		if pressed: activate_selected()
		return
	# Selected climb is already executable; successful acceptance consumes it.
	activate_selected()

func _process(_delta: float) -> void:
	# UI also clears between physics ticks when a source is removed.
	if not is_instance_valid(selected) or selected.is_queued_for_deletion(): selected=null
	refresh_ui()

func refresh_ui() -> void:
	if motor.traversal.hang.is_attached():
		var nav=motor.traversal.hang.navigation
		prompt.visible=is_instance_valid(nav.selected) and not nav.interacting
		prompt.text="E to "+nav.selected.get_action_text() if prompt.visible else ""
		debug_label.visible=false
		debug_mesh.visible=false
		return
	prompt.visible=valid(selected) and not motor.traversal.is_traversing
	prompt.text="E to "+selected.get_action_text() if prompt.visible else ""
	debug_label.visible=interaction_debug or motor.traversal.traversal_debug or motor.traversal.mantle.mantle_debug
	if debug_label.visible:
		debug_label.text="TRAVERSAL\nCandidate: %s\nType: %s / Mode: CONTEXTUAL\nDistance: %.2f / Action: %s\nAvailable: %s\n%s" % [selected.name if is_instance_valid(selected) else "None",Context.Type.keys()[selected.get_interaction_type()] if is_instance_valid(selected) else "NONE",motor.global_position.distance_to(selected.get_interaction_point()) if is_instance_valid(selected) else 0.0,selected.get_action_text() if is_instance_valid(selected) else "",is_instance_valid(selected),motor.traversal.debug_text()]
	if debug_label.visible:
		debug_label.text+="\nHeld climb: %s / Consumed ledge: %s" % [held_climb_intent,not _consumed_climb.is_empty()]
		debug_label.text+="\n"+motor.traversal.hang.top_entry.debug_text()
	debug_mesh.visible=interaction_debug
	if interaction_debug:
		var mesh:=ImmediateMesh.new()
		mesh.surface_begin(Mesh.PRIMITIVE_LINES)
		var origin: Vector3=motor.global_position+Vector3.UP
		for i in 48:
			for angle in [TAU*i/48,TAU*(i+1)/48]: mesh.surface_add_vertex(origin+Vector3(cos(angle),0,sin(angle))*interaction_detection_range)
		if is_instance_valid(selected):
			mesh.surface_add_vertex(origin)
			mesh.surface_add_vertex(selected.get_interaction_point())
			for axis in [Vector3.RIGHT,Vector3.UP,Vector3.BACK]:
				mesh.surface_add_vertex(selected.get_interaction_point()-axis*.1)
				mesh.surface_add_vertex(selected.get_interaction_point()+axis*.1)
		mesh.surface_end()
		debug_mesh.mesh=mesh
