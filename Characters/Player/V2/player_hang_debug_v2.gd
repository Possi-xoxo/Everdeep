extends Node3D
## Opt-in live geometry; one short-lived snapshot, not a recording system.
var display: MeshInstance3D
var mesh: ImmediateMesh
var retained: Array[Dictionary]=[]
var remaining: float=0
var retained_result: Dictionary={}
var last_query_serial: int=-1
var h: Node

func _ready() -> void:
	h=get_parent()
	display=MeshInstance3D.new()
	add_child(display)
	display.top_level=true
	display.global_transform=Transform3D.IDENTITY
	var material:=StandardMaterial3D.new()
	material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo=true
	material.no_depth_test=true
	display.material_override=material
	display.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func line(a: Vector3,b: Vector3,color: Color) -> void:
	mesh.surface_set_color(color)
	mesh.surface_add_vertex(a)
	mesh.surface_add_vertex(b)

func cross_at(p: Vector3,color: Color,size: float=.07) -> void:
	line(p-Vector3.RIGHT*size,p+Vector3.RIGHT*size,color)
	line(p-Vector3.UP*size,p+Vector3.UP*size,color)
	line(p-Vector3.BACK*size,p+Vector3.BACK*size,color)

func arrow(a: Vector3,b: Vector3,color: Color) -> void:
	line(a,b,color)
	var dir: Vector3=(b-a).normalized()
	var side:=dir.cross(Vector3.UP).normalized()
	line(b,b-dir*.12+side*.07,color)
	line(b,b-dir*.12-side*.07,color)

func _process(delta: float) -> void:
	display.visible=h.debug_detection_enabled()
	if not display.visible:
		retained.clear()
		retained_result.clear()
		last_query_serial=-1
		remaining=0
		return
	var q=h.acquisition
	remaining-=delta
	if q.query_serial!=last_query_serial and not q.candidates.is_empty():
		retained=q.candidates.duplicate(true)
		retained_result=h.result.duplicate(true)
		remaining=h.debug_persistence
	elif remaining<=0:
		retained.clear()
		retained_result.clear()
	last_query_serial=q.query_serial
	mesh=ImmediateMesh.new()
	display.mesh=mesh
	mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	var center: Vector3=q.base+Vector3.UP*h.hang_vertical_offset
	var low: Vector3=center-Vector3.UP*h.vertical_reach_below
	var high: Vector3=center+Vector3.UP*h.vertical_reach_allowance
	for i in 32:
		var angle: float=TAU*i/32.0
		var next: float=TAU*(i+1)/32.0
		var v: Vector3=Vector3(cos(angle),0,sin(angle))*h.max_grab_distance
		var w: Vector3=Vector3(cos(next),0,sin(next))*h.max_grab_distance
		line(low+v,low+w,Color.YELLOW)
		line(high+v,high+w,Color.YELLOW)
		if i%4==0:
			line(low+v,high+v,Color.YELLOW)
			line(low+v,low+v+q.prediction,Color.ORANGE)
			line(high+v,high+v+q.prediction,Color.ORANGE)
	arrow(center,center+q.motion*.15,Color.BLUE)
	arrow(center,center+q.intent,Color.MAGENTA)
	arrow(center,center+q.prediction,Color.ORANGE)
	for sign_value in [-1,1]:
		var cone: Vector3=q.search_direction.rotated(Vector3.UP,deg_to_rad(h.braced_hang_forward_cone_degrees*.5*sign_value))
		line(center,center+cone*h.max_grab_distance,Color.CYAN)
		var facing_limit: Vector3=q.forward.rotated(Vector3.UP,deg_to_rad(h.facing_acceptance_half_angle*sign_value))
		line(center,center+facing_limit*h.max_grab_distance,Color.WHITE)
	for c in retained:
		var color:=Color.CYAN if c.valid else Color.RED
		if c.valid and h.result.get("valid",false) and c.edge.distance_to(h.result.get("edge",Vector3.INF))<.025: color=Color.GREEN
		if not h.running and (h.motor.is_on_floor() or h.motor.ground_support.has_ground_support): color=Color.RED
		cross_at(c.edge,color)
		arrow(c.edge,c.edge+c.normal*.35,color)
		if not c.has("anchor"): continue
		var tangent: Vector3=c.facing.cross(Vector3.UP)
		line(c.edge-tangent*.28,c.edge+tangent*.28,color)
		cross_at(c.anchor,color,.12)
		line(c.anchor,c.anchor+Vector3.UP*h.motor.crouch.standing_capsule_height,color)
		for hand in c.hands: cross_at(hand,color,.05)
		for brace in c.braces:
			line(brace-c.facing*.12,brace+c.facing*.12,color)
		if c.braces.size()==4:
			line(c.braces[0],c.braces[1],color)
			line(c.braces[0],c.braces[2],color)
			line(c.braces[2],c.braces[3],color)
			line(c.braces[1],c.braces[3],color)
	mesh.surface_end()
