extends Node3D
## Geometry-only queries. No player transform, velocity or animation writes.
const Candidate = preload("res://interaction/mantle_geometry_candidate.gd")
@export_group("Mantle Detection")
@export var mantle_enabled: bool = true
@export_range(.4,3.0,.01) var mantle_min_height: float = 1.75
@export_range(.7,3.0,.01) var mantle_max_height: float = 2.20
@export_range(.5,1.0,.01) var mantle_forward_check_distance: float = .75
@export_range(.5,1.2,.01) var mantle_max_reach_distance: float = .90
@export_range(0,.6,.01) var mantle_max_wall_normal_up_dot: float = .25
@export_range(0,60,1) var mantle_max_top_slope_angle: float = 40.0
@export_range(.4,.8,.01) var mantle_min_top_depth: float = .55
## Legacy reference only; GroundSupportProbe and Mantle Exit now own setback.
var mantle_top_setback: float = .50
@export var mantle_candidate_priority: float = 0.0
@export var mantle_debug: bool = false
var result: Dictionary = {"valid":false,"reject_reason":"NO_FRONT_OBSTACLE"}
var candidate: Node3D
var rays: Array = []
var volume_queries: int = 0
var debug_mesh: MeshInstance3D
var debug_label: Label
@onready var motor=get_parent().get_parent()

func _ready() -> void:
	candidate=Candidate.new()
	candidate.name="SystemicMantleCandidate"
	add_child(candidate)
	debug_mesh=MeshInstance3D.new()
	add_child(debug_mesh)
	debug_mesh.top_level=true
	debug_mesh.global_transform=Transform3D.IDENTITY
	var material:=StandardMaterial3D.new()
	material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo=true
	material.no_depth_test=true
	debug_mesh.material_override=material
	var ui:=CanvasLayer.new()
	ui.name="MantleDebugUI"
	add_child(ui)
	debug_label=Label.new()
	debug_label.position=Vector2(650,300)
	debug_label.mouse_filter=Control.MOUSE_FILTER_IGNORE
	ui.add_child(debug_label)

func _ray(from: Vector3,to: Vector3) -> Dictionary:
	rays.append([from,to])
	return get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from,to,motor.collision_mask,[motor.get_rid()]))

func _reject(data: Dictionary,reason: String) -> Dictionary:
	data["reject_reason"]=reason
	return data

func detect_ledge_geometry() -> Dictionary:
	rays.clear()
	volume_queries=0
	var data: Dictionary={"valid":false,"reject_reason":"NO_FRONT_OBSTACLE","type":1,"mode":0,"front_hit":false,"top_found":false,"standing_clearance":false}
	if not mantle_enabled: return _reject(data,"DISABLED")
	var collision: CollisionShape3D=motor.crouch.collision
	var base: Vector3=collision.global_position-Vector3.UP*collision.shape.height*.5
	var forward: Vector3=-motor.visual.global_basis.z
	forward.y=0
	forward=forward.normalized()
	var right:=forward.cross(Vector3.UP)
	data["floor_reference"]=base
	var front: Dictionary={}
	# Center first, then small lateral offsets. Deterministic order avoids
	# switching faces due to tiny score changes near corners.
	var half_cone: float=motor.traversal.mantle.mantle_interaction_cone_angle*.5
	var nearest: float=INF
	for fraction in [0.0,-.25,.25,-.5,.5,-.75,.75,-1.0,1.0]:
		var direction:=forward.rotated(Vector3.UP,deg_to_rad(half_cone*fraction))
		for height in [.20,.65,1.05]:
			var origin: Vector3=base+Vector3.UP*height
			var hit:=_ray(origin,origin+direction*mantle_forward_check_distance)
			if hit.is_empty() or absf(hit.normal.y)>mantle_max_wall_normal_up_dot: continue
			var inward_normal:=Vector3(-hit.normal.x,0,-hit.normal.z).normalized()
			if forward.dot(inward_normal)<cos(deg_to_rad(half_cone))-.00001: continue
			# Project to the face along its normal, avoiding a lateral alignment jump.
			var point: Vector3=origin+inward_normal*((hit.position-origin).dot(hit.normal)/inward_normal.dot(hit.normal))
			var distance: float=origin.distance_to(point)
			if distance<nearest-.001:
				nearest=distance
				front=hit.duplicate()
				front.position=point
	if front.is_empty(): return data
	data["front_hit"]=true
	data["obstacle_position"]=front.position
	data["obstacle_normal"]=front.normal
	data["obstacle_source"]=front.collider
	var horizontal: Vector3=front.position-base
	horizontal.y=0
	data["distance"]=horizontal.length()
	if horizontal.length()>mantle_max_reach_distance: return _reject(data,"TOO_FAR")
	if absf(front.normal.dot(Vector3.UP))>mantle_max_wall_normal_up_dot: return _reject(data,"BAD_FACE_NORMAL")
	var inward: Vector3=-front.normal
	inward.y=0
	inward=inward.normalized()
	right=inward.cross(Vector3.UP)
	var top_origin: Vector3=front.position+inward*.04
	top_origin.y=base.y+mantle_max_height+.25
	data["top_search_origin"]=top_origin
	var top:=_ray(top_origin,Vector3(top_origin.x,base.y+.02,top_origin.z))
	if top.is_empty():
		var high_origin:=base+Vector3.UP*(mantle_max_height+.02)
		var high:=_ray(high_origin,high_origin+inward*mantle_forward_check_distance)
		return _reject(data,"TOO_HIGH" if not high.is_empty() else "NO_TOP_SURFACE")
	data["top_found"]=true
	data["top_position"]=top.position
	data["top_normal"]=top.normal
	var height: float=top.position.y-base.y
	data["ledge_height"]=height
	if height<mantle_min_height-.005: return _reject(data,"TOO_LOW")
	if height>mantle_max_height+.005: return _reject(data,"TOO_HIGH")
	var slope: float=rad_to_deg(acos(clampf(top.normal.dot(Vector3.UP),-1,1)))
	data["top_slope"]=slope
	var slope_limit: float=minf(mantle_max_top_slope_angle,rad_to_deg(motor.floor_max_angle))
	if slope>slope_limit: return _reject(data,"TOP_TOO_STEEP")
	if top.collider!=front.collider: return _reject(data,"NO_TOP_SURFACE")
	var radius: float=motor.ground_support.ground_support_radius
	var setback: float=maxf(motor.traversal.mantle.mantle_landing_edge_setback,motor.ground_support.minimum_landing_setback())
	var required_depth: float=maxf(mantle_min_top_depth,setback+radius+.03)
	data["required_top_depth"]=required_depth
	data["top_depth"]=0.0
	var landing: Vector3=front.position+inward*setback
	# Sample a support strip plus the standing footprint, not one head ray.
	for distance in [.04,required_depth*.25,required_depth*.5,required_depth*.75,required_depth]:
		for lateral in [0.0,-radius*.95,radius*.95]:
			var point: Vector3=front.position+inward*distance+right*lateral
			var expected_y: float=top.position.y-(top.normal.x*(point.x-top.position.x)+top.normal.z*(point.z-top.position.z))/top.normal.y
			var support:=_ray(Vector3(point.x,expected_y+.06,point.z),Vector3(point.x,expected_y-.06,point.z))
			if support.is_empty() or support.collider!=front.collider: return _reject(data,"TOP_TOO_SHALLOW")
			if support.normal.dot(Vector3.UP)<cos(deg_to_rad(slope_limit)): return _reject(data,"TOP_TOO_STEEP")
			if absf(support.position.y-top.position.y)>.03+required_depth*tan(deg_to_rad(slope_limit)): return _reject(data,"TOP_TOO_SHALLOW")
		data["top_depth"]=distance
	var center_y: float=top.position.y-(top.normal.x*(landing.x-top.position.x)+top.normal.z*(landing.z-top.position.z))/top.normal.y
	var center:=_ray(Vector3(landing.x,center_y+.06,landing.z),Vector3(landing.x,center_y-.06,landing.z))
	if center.is_empty() or center.collider!=front.collider: return _reject(data,"TOP_TOO_SHALLOW")
	landing.y=center.position.y+.015
	data["landing_position"]=landing
	data["player_alignment_position"]=Vector3(front.position.x,base.y,front.position.z)-inward*(motor.crouch.standing_capsule_radius+.05)
	data["player_alignment_facing"]=inward
	data["target_position"]=landing
	data["target_normal"]=top.normal
	var query:=PhysicsShapeQueryParameters3D.new()
	query.shape=motor.crouch.standing_shape
	query.transform=Transform3D(Basis.IDENTITY,landing+Vector3.UP*motor.crouch.standing_capsule_height*.5)
	query.collision_mask=motor.collision_mask
	query.exclude=[motor.get_rid()]
	query.margin=.005
	volume_queries+=1
	if not get_world_3d().direct_space_state.intersect_shape(query,1).is_empty(): return _reject(data,"DESTINATION_BLOCKED")
	data["standing_clearance"]=true
	data["valid"]=true
	data["reject_reason"]="NONE"
	return data

func refresh_contextual_candidate() -> void:
	if mantle_enabled and motor.traversal.can_begin(true): result=detect_ledge_geometry()
	else:
		rays.clear()
		volume_queries=0
		result={"valid":false,"reject_reason":"STATE_BLOCKED" if mantle_enabled else "DISABLED"}
	candidate.available=result.valid
	candidate.priority=mantle_candidate_priority

func _line(mesh: ImmediateMesh,a: Vector3,b: Vector3,color: Color) -> void:
	mesh.surface_set_color(color)
	mesh.surface_add_vertex(a)
	mesh.surface_add_vertex(b)

func _cross(mesh: ImmediateMesh,point: Vector3,color: Color) -> void:
	for axis in [Vector3.RIGHT,Vector3.UP,Vector3.BACK]: _line(mesh,point-axis*.06,point+axis*.06,color)

func _process(_delta: float) -> void:
	var enabled: bool=mantle_debug or get_parent().traversal_debug
	debug_mesh.visible=enabled
	debug_label.visible=enabled
	if not enabled: return
	debug_label.text="MANTLE DETECTOR\nFront Hit: %s / Distance: %.2f\nHeight: %.2f / Range: %.2f–%.2f\nTop Found: %s / Slope: %.1f\nVerified Depth: %.2f / Required: %.2f\nStanding Clearance: %s\nCandidate Valid: %s\nReject: %s" % [result.get("front_hit",false),result.get("distance",0),result.get("ledge_height",0),mantle_min_height,mantle_max_height,result.get("top_found",false),result.get("top_slope",0),result.get("top_depth",0),result.get("required_top_depth",mantle_min_top_depth),result.get("standing_clearance",false),result.valid,result.reject_reason]
	var mesh:=ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	for ray in rays: _line(mesh,ray[0],ray[1],Color.YELLOW)
	for key in ["obstacle_position","top_search_origin","top_position","landing_position","player_alignment_position"]:
		if result.has(key): _cross(mesh,result[key],Color.GREEN if result.valid else Color.RED)
	if result.has("obstacle_position"): _line(mesh,result.obstacle_position,result.obstacle_position+result.obstacle_normal*.3,Color.RED)
	if result.has("top_position"):
		_line(mesh,result.top_position,result.top_position+result.top_normal*.3,Color.GREEN)
		_line(mesh,Vector3(result.top_position.x,result.floor_reference.y,result.top_position.z),result.top_position,Color.CYAN)
	if result.has("landing_position"):
		var radius: float=motor.crouch.standing_capsule_radius
		var height: float=motor.crouch.standing_capsule_height
		var base: Vector3=result.landing_position
		for hemisphere in [0,1]:
			var center: Vector3=base+Vector3.UP*(radius if hemisphere==0 else height-radius)
			for latitude in 5:
				var a: float=PI*.5*latitude/4
				var y: float=sin(a)*radius*(-1 if hemisphere==0 else 1)
				for i in 24:
					var p:=Vector3(cos(TAU*i/24),0,sin(TAU*i/24))*cos(a)*radius+Vector3.UP*y
					var q:=Vector3(cos(TAU*(i+1)/24),0,sin(TAU*(i+1)/24))*cos(a)*radius+Vector3.UP*y
					_line(mesh,center+p,center+q,Color.CYAN)
		for i in 8:
			var side:=Vector3(cos(TAU*i/8),0,sin(TAU*i/8))*radius
			_line(mesh,base+side+Vector3.UP*radius,base+side+Vector3.UP*(height-radius),Color.CYAN)
	# Keep ImmediateMesh valid even when all queries were skipped.
	_line(mesh,global_position,global_position,Color.TRANSPARENT)
	mesh.surface_end()
	debug_mesh.mesh=mesh
