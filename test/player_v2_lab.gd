extends Node3D
## Lab geometry only. The player scene is independently reusable.
func _ready() -> void:
	_box("Floor", Vector3(0, -0.25, 0), Vector3(64, 0.5, 90), Color(0.20, 0.25, 0.29))
	_box("LowPlatform", Vector3(-9, 0.3, -12), Vector3(8, 0.6, 8), Color(0.28, 0.48, 0.43))
	_box("MediumPlatform", Vector3(9, 1.5, -20), Vector3(8, 3, 8), Color(0.40, 0.42, 0.62))
	_ramp("LowRamp", Vector3(-9, 0, -4), 4.0, 8.0, 0.6, Color(0.34, 0.56, 0.47))
	_ramp("MediumRamp", Vector3(9, 0, -10), 4.0, 12.0, 3.0, Color(0.46, 0.48, 0.70))
	_box("TinyDrop", Vector3(-9, 0.075, 6), Vector3(8, 0.15, 5), Color(0.62, 0.49, 0.29))
	_label("WALK / RUN / SPRINT — 70 m lane", Vector3(0, 0.1, -8))
	_label("0.6 m platform", Vector3(-9, 0.7, -12))
	_label("3 m platform", Vector3(9, 3.1, -20))
	_label("15 cm curb", Vector3(-9, 0.25, 6))
	for z in range(-35, 36, 5):
		var marker := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.08, 0.01, 1.0)
		marker.mesh = mesh
		marker.position = Vector3(0, 0.008, z)
		add_child(marker)

func _box(title: String, pos: Vector3, size: Vector3, color: Color) -> void:
	var shape := BoxShape3D.new()
	shape.size = size
	var mesh := BoxMesh.new()
	mesh.size = size
	_body(title, pos, shape, mesh, color)

func _ramp(title: String, pos: Vector3, width: float, length: float, height: float, color: Color) -> void:
	var points := PackedVector3Array([
		Vector3(-width/2, 0, length/2), Vector3(width/2, 0, length/2),
		Vector3(-width/2, 0, -length/2), Vector3(width/2, 0, -length/2),
		Vector3(-width/2, height, -length/2), Vector3(width/2, height, -length/2)])
	var shape := ConvexPolygonShape3D.new()
	shape.points = points
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in [0,4,1, 1,4,5, 2,3,4, 3,5,4, 0,2,4, 1,5,3, 0,1,2, 1,3,2]:
		surface.add_vertex(points[index])
	surface.generate_normals()
	_body(title, pos, shape, surface.commit(), color)

func _body(title: String, pos: Vector3, shape: Shape3D, mesh: Mesh, color: Color) -> void:
	var body := StaticBody3D.new()
	body.name = title
	body.position = pos
	var collision := CollisionShape3D.new()
	collision.shape = shape
	body.add_child(collision)
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	visual.material_override = material
	body.add_child(visual)
	add_child(body)

func _label(title: String, pos: Vector3) -> void:
	var label := Label3D.new()
	label.text = title
	label.position = pos + Vector3(0, 0.4, 0)
	label.font_size = 42
	label.pixel_size = 0.008
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(label)

