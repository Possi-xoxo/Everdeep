extends Node3D
func block(label: String,pos: Vector3,size: Vector3) -> StaticBody3D:
	var body:=StaticBody3D.new()
	body.name=label
	add_child(body)
	body.position=pos
	var shape:=CollisionShape3D.new()
	var box:=BoxShape3D.new()
	box.size=size
	shape.shape=box
	body.add_child(shape)
	var visual:=MeshInstance3D.new()
	var mesh:=BoxMesh.new()
	mesh.size=size
	visual.mesh=mesh
	body.add_child(visual)
	return body

func add_sign(text: String,pos: Vector3) -> void:
	var label:=Label3D.new()
	add_child(label)
	label.text=text
	label.position=pos
	label.billboard=BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size=40

func _ready() -> void:
	position=Vector3(-40,0,-12)
	block("Floor",Vector3(0,-.25,0),Vector3(36,.5,26))
	var heights: Array[float]=[.4,.6,.7,.8,.9,1.0,1.1,1.2,1.3,1.4,1.5,1.7]
	for i in heights.size():
		var h: float=heights[i]
		var pos:=Vector3((i%6)*5-12.5,h*.5,-floori(i/6.0)*6)
		block("Height_"+str(i),pos,Vector3(3,h,2.5))
		add_sign("%.2fm"%h,pos+Vector3(0,h*.5+.5,1.4))
	block("LowCeilingBase",Vector3(-12.5,.5,7),Vector3(3,1,2.5))
	block("LowCeilingRoof",Vector3(-12.5,2.15,7),Vector3(3,.3,2.5))
	add_sign("Low Ceiling",Vector3(-12.5,2.7,9))
	block("ThinTop",Vector3(-7.5,.5,7),Vector3(3,1,.2))
	add_sign("Thin Top",Vector3(-7.5,1.6,9))
	var steep:=block("SteepTop",Vector3(-2.5,0,8.25),Vector3(3,1,1))
	var points:=PackedVector3Array([Vector3(-1.5,0,0),Vector3(1.5,0,0),Vector3(-1.5,.9,0),Vector3(1.5,.9,0),Vector3(-1.5,0,-1),Vector3(1.5,0,-1),Vector3(-1.5,2.328,-1),Vector3(1.5,2.328,-1)])
	var hull:=ConvexPolygonShape3D.new()
	hull.points=points
	steep.get_child(0).shape=hull
	var surface:=SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in [0,1,3,0,3,2,4,6,7,4,7,5,0,2,6,0,6,4,1,5,7,1,7,3,0,4,5,0,5,1,2,3,7,2,7,6]: surface.add_vertex(points[index])
	surface.generate_normals()
	steep.get_child(1).mesh=surface.commit()
	add_sign("Steep Top",Vector3(-2.5,2.3,9))
	block("Corner",Vector3(2.5,.55,7),Vector3(2,1.1,2))
	add_sign("Corner",Vector3(2.5,1.8,9))
	block("FullWall",Vector3(7.5,3,7),Vector3(3,6,2))
	add_sign("Full Wall",Vector3(7.5,3,9))
	add_sign("MANTLE / LEDGE — DETECTION ONLY\nE sends test request; no climb",Vector3(0,3,12))
