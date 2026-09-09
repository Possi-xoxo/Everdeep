@tool
extends "res://test/traversal_playground/hang_transfer_course.gd"
## Convex collision and visible prism share the same vertices.
func prism(at: Vector3,angle: float=90) -> StaticBody3D:
	var body:=StaticBody3D.new()
	add_child(body)
	body.position=at
	var radians:=deg_to_rad(angle)
	var polygon: Array[Vector3]=[Vector3(-4,0,0),Vector3(4,0,0),Vector3(4+cos(radians)*4,0,-sin(radians)*4),Vector3(-4,0,-4)]
	var points:=PackedVector3Array()
	for p in polygon: points.append(p); points.append(p+Vector3.UP*3)
	var collider:=CollisionShape3D.new()
	var shape:=ConvexPolygonShape3D.new()
	shape.points=points
	collider.shape=shape
	body.add_child(collider)
	var surface:=SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_smooth_group(-1)
	for i in range(1,3):
		for p in [polygon[i],polygon[i+1],polygon[0],polygon[i+1]+Vector3.UP*3,polygon[i]+Vector3.UP*3,polygon[0]+Vector3.UP*3]: surface.add_vertex(p)
	for i in 4:
		var a: Vector3=polygon[i]
		var b: Vector3=polygon[(i+1)%4]
		for p in [a+Vector3.UP*3,b+Vector3.UP*3,a,b+Vector3.UP*3,b,a]: surface.add_vertex(p)
	surface.generate_normals()
	var visual:=MeshInstance3D.new()
	visual.mesh=surface.commit()
	var material:=ShaderMaterial.new()
	material.shader=load("res://test/traversal_playground/lateral_checker.gdshader")
	visual.material_override=material
	body.add_child(visual)
	return body

func _ready() -> void:
	var floor_body:=StaticBody3D.new()
	add_child(floor_body)
	block(floor_body,Vector3(0,-.27,4),Vector3(18,.5,14),Color(.2,.26,.3))
	if compact:
		var tower:=prism(Vector3.ZERO)
		# Adjacent-face higher grip: turn first, then W to continue climbing.
		block(tower,Vector3(0,3.5,-2),Vector3(7.84,1,3.84),Color(.22,.5,.5))
		block(tower,Vector3(0,3.91,-2),Vector3(8,.18,4),Color(.3,.8,.7))
		sign_at(Vector3(0,4.7,1),"CORNER + VERTICAL\nCatch / A-D around corner / W to next grip")
		return
	block(floor_body,Vector3(88,-.27,-2),Vector3(194,.5,22),Color(.2,.26,.3))
	block(floor_body,Vector3(0,-.27,14),Vector3(8,.5,14),Color(.2,.26,.3))
	var titles: Array[String]=["Hang_Corner_Right90","Hang_Corner_Left90","Hang_Corner_Chain","Hang_Corner_LongShimmy","Hang_Corner_AfterPartialHop","Hang_Corner_Blocked","Hang_Corner_OutOfReach","Hang_Corner_75","Hang_Corner_105","Hang_Corner_Inside_Unsupported","Hang_Corner_CurveBoundary","Hang_Corner_NoHop"]
	for i in titles.size():
		var at:=Vector3(i*17,0,0)
		var angle: float=75 if i==7 else (105 if i==8 else 90)
		var body: StaticBody3D=prism(at,angle)
		body.name=titles[i]
		var hint: String="A / D: shimmy around outside corner"
		if i==2: hint="Continue around all four faces; reverse to retrace"
		if i==4: hint="Shift+D from front center, then D at the end"
		if i==5:
			var obstacle:=StaticBody3D.new()
			add_child(obstacle)
			block(obstacle,at+Vector3(4.37,2,.37),Vector3(.18,.6,.18),Color(.9,.2,.1))
			hint="Body arc obstruction: must reject"
		if i==6:
			# In-range angle with raised destination, outside same-height reach rules.
			block(body,Vector3(3.9,3.3,-2),Vector3(.2,.6,4),Color(.9,.5,.2))
			hint="Raised destination grip: no same-height reachable anchor"
		if i==9:
			block(body,Vector3(3,1.5,2),Vector3(2,3,4),Color(.7,.35,.3))
			hint="Front inside junction: unsupported / no traversal"
		if i==10:
			body.queue_free()
			var curved:=StaticBody3D.new()
			add_child(curved)
			curved.position=at+Vector3(0,1.5,-3)
			var shape:=CylinderShape3D.new()
			shape.radius=3; shape.height=3
			var collision:=CollisionShape3D.new()
			collision.shape=shape; curved.add_child(collision)
			var visual:=MeshInstance3D.new()
			var mesh:=CylinderMesh.new()
			mesh.top_radius=3; mesh.bottom_radius=3; mesh.height=3
			visual.mesh=mesh; curved.add_child(visual)
			hint="Gradual normal change: existing curved shimmy only"
		if i==11: hint="Shift+A/D may stop short; must NEVER turn the corner"
		sign_at(at+Vector3(0,4.5,1),titles[i]+"\n"+hint)
