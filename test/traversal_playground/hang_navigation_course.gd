@tool
extends "res://test/traversal_playground/hang_vertical_course.gd"

func wall_at(at: Vector3,height: float) -> StaticBody3D:
	var wall:=StaticBody3D.new()
	add_child(wall)
	wall.position=at
	block(wall,Vector3(0,height*.5,-1),Vector3(8,height,2),Color(.3,.65,.55))
	return wall

func button(at: Vector3,label: String) -> Node3D:
	var object=preload("res://interaction/context_interactable.gd").new()
	object.name=label
	object.requires_grounded=false
	object.action_text="Toggle "+label
	add_child(object)
	object.position=at
	var mesh:=MeshInstance3D.new()
	var sphere:=SphereMesh.new()
	sphere.radius=.07
	sphere.height=.14
	mesh.mesh=sphere
	var material:=StandardMaterial3D.new()
	material.albedo_color=Color.YELLOW
	mesh.material_override=material
	object.add_child(mesh)
	object.interacted.connect(func(_player): material.albedo_color=Color.GREEN if object.activation_count%2 else Color.YELLOW)
	return object

func curved_wall(center: Vector3) -> StaticBody3D:
	var wall:=StaticBody3D.new()
	wall.name="GentleCurve"
	add_child(wall)
	wall.position=center
	for i in 45:
		var a: float=deg_to_rad(-45+i*2)
		var b: float=deg_to_rad(-43+i*2)
		var points:=PackedVector3Array()
		for y in [0.0,3.0]:
			for radius in [8.0,10.0]:
				for angle in [a,b]: points.append(Vector3(sin(angle)*radius,y,cos(angle)*radius))
		var shape:=ConvexPolygonShape3D.new()
		shape.points=points
		var collision:=CollisionShape3D.new()
		collision.shape=shape
		wall.add_child(collision)
		var visual:=MeshInstance3D.new()
		var surface:=SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		for face in [[2,3,7],[2,7,6],[0,4,5],[0,5,1],[4,6,7],[4,7,5],[0,1,3],[0,3,2],[0,2,6],[0,6,4],[1,5,7],[1,7,3]]:
			for index in face: surface.add_vertex(points[index])
		surface.generate_normals()
		visual.mesh=surface.commit()
		var material:=StandardMaterial3D.new()
		material.albedo_color=Color(.35,.55,.8)
		material.cull_mode=BaseMaterial3D.CULL_DISABLED
		visual.material_override=material
		wall.add_child(visual)
	return wall

func _ready() -> void:
	var ground:=StaticBody3D.new()
	add_child(ground)
	block(ground,Vector3(37,-.26,0),Vector3(94,.5,36),Color(.22,.28,.3))
	wall_at(Vector3.ZERO,2.3)
	sign_at(Vector3(0,1.5,2),"Hang_SafeRelease_Low\nS releases to safe ground")
	wall_at(Vector3(12,0,0),5)
	sign_at(Vector3(12,1.5,2),"Hang_SafeRelease_High\nS stays hanging / Space jumps away")
	var ramp:=StaticBody3D.new()
	add_child(ramp)
	ramp.position=Vector3(12,2.5,-8)
	ramp.rotation.x=-atan(.5)
	block(ramp,Vector3.ZERO,Vector3(3,.25,Vector2(5,10).length()),Color(.4,.45,.5))
	var blocked:=StaticBody3D.new()
	add_child(blocked)
	blocked.position=Vector3(24,0,0)
	block(blocked,Vector3(0,3,-1.08),Vector3(8,6,2),Color(.3,.65,.55))
	block(blocked,Vector3(0,2.21,-1),Vector3(8,.18,2),Color(.3,.8,.55))
	sign_at(Vector3(24,1.5,2),"Hang_Up_NoTarget_NoTop\nW does nothing")
	wall_at(Vector3(36,0,0),2.3)
	button(Vector3(35.6,2.25,.2),"Hang_Interact_Left")
	button(Vector3(36.4,2.25,.2),"Hang_Interact_Right")
	button(Vector3(36,2.25,1.4),"Hang_Interact_OutOfRange")
	button(Vector3(36,2.25,-.2),"Hang_Interact_Blocked")
	sign_at(Vector3(36,1.3,3),"E: hanging interaction\nYellow ↔ Green / stay attached")
	wall_at(Vector3(48,0,0),2.3)
	var platform:=StaticBody3D.new()
	add_child(platform)
	block(platform,Vector3(48,.4,5),Vector3(4,.8,3),Color(.65,.45,.25))
	sign_at(Vector3(48,1.5,2),"Hang_JumpOff_Basic / Platform\nSpace + A/D: modest lateral bias")
	wall_at(Vector3(55,0,7),2.3)
	sign_at(Vector3(55,3.4,7),"Hang_JumpOff_TransferRange\nOnly ordinary airborne catch")
	curved_wall(Vector3(70,0,-8))
	sign_at(Vector3(70,1.5,4),"Hang_Curve_Gentle / Curve_Hop\nBroad 10m radius, 2° facets")
	wall_at(Vector3(80,0,-8),3)
	sign_at(Vector3(80,4,-8),"Hang_Corner_Unsupported\nSharp edge: stop, no corner transition")
