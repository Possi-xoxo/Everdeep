extends Node3D
## Read-only terrain probes: body collision remains the motor's responsibility.
enum SupportState { FULL_SUPPORT, EDGE_SUPPORT, UNSUPPORTED }
signal support_lost
@export_group("Ground Support")
@export_range(.15,.30,.01) var ground_support_radius: float = .22
@export_range(.08,.20,.01) var ground_support_cast_distance: float = .12
@export_range(.2,1,.2) var ground_support_required_fraction: float = .60
@export_range(.6,1,.2) var full_support_fraction: float = .80
@export_range(.08,.18,.01) var coyote_time_duration: float = .12
@export var ground_support_debug: bool = false
var support_hits: int = 0
const support_total: int = 5
var support_fraction: float = 0.0
var support_normal := Vector3.UP
var support_state: SupportState = SupportState.UNSUPPORTED
var has_ground_support: bool = false
var support_just_lost: bool = false
var coyote_remaining: float = 0.0
var initialized: bool = false
var jumping: bool = false
var solver_support: bool = false
var samples: Array = []
var debug_mesh: MeshInstance3D
var debug_label: Label
@onready var motor=get_parent()

func _ready() -> void:
	debug_mesh=MeshInstance3D.new()
	add_child(debug_mesh)
	debug_mesh.top_level=true
	debug_mesh.global_transform=Transform3D.IDENTITY
	var material:=StandardMaterial3D.new()
	material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo=true
	material.no_depth_test=true
	debug_mesh.material_override=material
	var layer:=CanvasLayer.new()
	add_child(layer)
	debug_label=Label.new()
	debug_label.position=Vector2(650,30)
	layer.add_child(debug_label)

func offsets() -> Array[Vector3]:
	var r:=ground_support_radius/sqrt(2.0)
	return [Vector3.ZERO,Vector3(-r,0,-r),Vector3(r,0,-r),Vector3(-r,0,r),Vector3(r,0,r)]

func evaluate(point: Vector3, facing_basis: Basis=Basis.IDENTITY, source: Object=null, plane_normal: Vector3=Vector3.UP) -> Dictionary:
	var hits:=0
	var normal:=Vector3.ZERO
	var probes: Array=[]
	for offset in offsets():
		var anchor:=point+facing_basis*offset
		anchor.y-=(plane_normal.x*(anchor.x-point.x)+plane_normal.z*(anchor.z-point.z))/maxf(.1,plane_normal.y)
		var from:=anchor+Vector3.UP*.04
		var to:=anchor-Vector3.UP*ground_support_cast_distance
		var query:=PhysicsRayQueryParameters3D.create(from,to,motor.collision_mask,[motor.get_rid()])
		var hit=motor.get_world_3d().direct_space_state.intersect_ray(query)
		var valid: bool=not hit.is_empty() and hit.normal.dot(Vector3.UP)>=cos(motor.floor_max_angle) and (source==null or hit.collider==source)
		if valid:
			hits+=1
			normal+=hit.normal
		probes.append({"from":from,"to":to,"valid":valid,"point":hit.get("position",to)})
	var fraction:=float(hits)/support_total
	return {"hits":hits,"fraction":fraction,"supported":fraction+.00001>=ground_support_required_fraction,"normal":normal.normalized() if hits>0 else Vector3.UP,"samples":probes}

func minimum_landing_setback() -> float:
	var distances: Array[float]=[]
	for offset in offsets(): distances.append(offset.z)
	distances.sort()
	return maxf(.015,distances[clampi(ceili(ground_support_required_fraction*5)-1,0,4)]+.015)

func refresh(delta: float, confirmed_solver: bool=false) -> void:
	var previous:=has_ground_support
	var point: Vector3=motor.global_position
	var floor_normal: Vector3=motor.get_floor_normal() if motor.is_on_floor() else Vector3.UP
	# Capsule's lowest point sits above an inclined tangent plane. Account for
	# that geometric offset without lengthening the short support casts.
	if motor.is_on_floor(): point.y-=motor.crouch.standing_capsule_radius*(1.0/maxf(.1,floor_normal.y)-1.0)
	var data:=evaluate(point,motor.visual.global_basis,null,floor_normal)
	support_hits=data.hits
	support_fraction=data.fraction
	support_normal=data.normal
	samples=data.samples
	if motor.velocity.y<=0: jumping=false
	# Proximity alone cannot land a falling body before physical contact.
	has_ground_support=data.supported and not jumping and (motor.is_on_floor() or confirmed_solver)
	solver_support=confirmed_solver
	support_state=SupportState.UNSUPPORTED if not has_ground_support else (SupportState.FULL_SUPPORT if support_fraction+.00001>=full_support_fraction else SupportState.EDGE_SUPPORT)
	coyote_remaining=maxf(0,coyote_remaining-delta)
	support_just_lost=initialized and previous and not has_ground_support and not jumping and not confirmed_solver
	if support_just_lost:
		coyote_remaining=coyote_time_duration
		support_lost.emit()
	if has_ground_support or confirmed_solver: coyote_remaining=0
	initialized=true

func consume_jump() -> void:
	coyote_remaining=0
	jumping=true
	has_ground_support=false
	support_just_lost=false

func reset_coyote() -> void:
	coyote_remaining=0
	support_just_lost=false

func debug_text() -> String:
	return "GROUND SUPPORT\nBody Is On Floor: %s\nState: %s / Hits: %d / 5\nFraction: %.2f / Required: %.2f\nRadius: %.2fm / Cast: %.2fm\nHas Support: %s / Solver: %s\nJust Lost: %s\nCoyote Active: %s / Remaining: %.3f" % [motor.is_on_floor(),SupportState.keys()[support_state],support_hits,support_fraction,ground_support_required_fraction,ground_support_radius,ground_support_cast_distance,has_ground_support,solver_support,support_just_lost,coyote_remaining>0,coyote_remaining]

func _process(_delta: float) -> void:
	debug_label.visible=ground_support_debug
	debug_mesh.visible=ground_support_debug
	if not ground_support_debug: return
	debug_label.text=debug_text()
	var mesh:=ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	for sample in samples:
		mesh.surface_set_color(Color.GREEN if sample.valid else Color.RED)
		mesh.surface_add_vertex(sample.from)
		mesh.surface_add_vertex(sample.to)
		mesh.surface_add_vertex(sample.point-Vector3.RIGHT*.025)
		mesh.surface_add_vertex(sample.point+Vector3.RIGHT*.025)
	for radius in [ground_support_radius,motor.crouch.standing_capsule_radius]:
		mesh.surface_set_color(Color.CYAN if radius==ground_support_radius else Color.ORANGE)
		for i in 32:
			mesh.surface_add_vertex(motor.global_position+Vector3(cos(TAU*i/32),.01,sin(TAU*i/32))*Vector3(radius,1,radius))
			mesh.surface_add_vertex(motor.global_position+Vector3(cos(TAU*(i+1)/32),.01,sin(TAU*(i+1)/32))*Vector3(radius,1,radius))
	var radius: float=motor.crouch.collision.shape.radius
	var height: float=motor.crouch.collision.shape.height
	mesh.surface_set_color(Color.ORANGE)
	for axis in [Vector3.RIGHT,Vector3.BACK]:
		for side in [-1,1]:
			mesh.surface_add_vertex(motor.global_position+axis*radius*side+Vector3.UP*radius)
			mesh.surface_add_vertex(motor.global_position+axis*radius*side+Vector3.UP*(height-radius))
		for half in [-1,1]:
			var center: Vector3=motor.global_position+Vector3.UP*(radius if half<0 else height-radius)
			for i in 16:
				mesh.surface_add_vertex(center+axis*cos(PI*i/16)*radius+Vector3.UP*sin(PI*i/16)*radius*half)
				mesh.surface_add_vertex(center+axis*cos(PI*(i+1)/16)*radius+Vector3.UP*sin(PI*(i+1)/16)*radius*half)
	mesh.surface_end()
	debug_mesh.mesh=mesh
