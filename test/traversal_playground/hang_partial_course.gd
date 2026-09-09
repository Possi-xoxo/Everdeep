@tool
extends "res://test/traversal_playground/hang_transfer_course.gd"
## Marked launch positions use the .28m bilateral hand-span edge reserve.
func station(x: float,remainder: float,title: String,gap: bool=false,corner: bool=false) -> void:
	var source:=wall(Vector3(x,0,0),8)
	source.name=title
	if corner: block(source,Vector3(3.9,1.5,-4),Vector3(.2,3,4),Color(.85,.4,.2))
	if gap: wall(Vector3(x+7,0,0),4)
	var launch: float=x+4-.28-remainder
	sign_at(Vector3(launch,4,1),title+"\nStart at yellow stripe / Shift+D\nRemaining ~%.2fm (before overshoot reserve)"%remainder)
	# Visual marker only; no new collision at the launch stripe.
	var marker:=MeshInstance3D.new()
	var mesh:=BoxMesh.new()
	mesh.size=Vector3(.04,3,.01)
	marker.mesh=mesh
	var material:=StandardMaterial3D.new()
	material.albedo_color=Color.YELLOW
	marker.material_override=material
	add_child(marker)
	marker.position=Vector3(launch,1.5,.006)
	var ramp:=StaticBody3D.new()
	add_child(ramp)
	ramp.position=Vector3(x,1.5,-7)
	ramp.rotation.x=-atan(.5)
	block(ramp,Vector3.ZERO,Vector3(2,.15,Vector2(3,6).length()),Color(.4,.45,.5))

func _ready() -> void:
	var floor_body:=StaticBody3D.new()
	add_child(floor_body)
	block(floor_body,Vector3(70,-.27,-2),Vector3(164,.5,26),Color(.2,.26,.3))
	block(floor_body,Vector3(0,-.27,14),Vector3(8,.5,14),Color(.2,.26,.3))
	station(0,4,"Hang_Hop_Full")
	station(18,2.25,"Hang_Hop_Partial_75")
	station(36,1.5,"Hang_Hop_Partial_50")
	station(54,.75,"Hang_Hop_Partial_25")
	station(72,.05,"Hang_Hop_BelowMinimum")
	station(90,.8,"Hang_Hop_Partial_ToCorner",false,true)
	station(108,.38,"Hang_Hop_Partial_BeforeGap",true)
	station(126,.05,"Hang_Hop_GapPriority",true)
	var curved:=StaticBody3D.new()
	curved.name="Hang_Hop_Partial_Curve"
	add_child(curved)
	curved.position=Vector3(146,1.5,-3)
	var collision:=CollisionShape3D.new()
	var cylinder:=CylinderShape3D.new()
	cylinder.radius=3
	cylinder.height=3
	collision.shape=cylinder
	curved.add_child(collision)
	var visual:=MeshInstance3D.new()
	var mesh:=CylinderMesh.new()
	mesh.top_radius=3; mesh.bottom_radius=3; mesh.height=3
	visual.mesh=mesh
	curved.add_child(visual)
	sign_at(Vector3(146,4,1),"Hang_Hop_Partial_Curve\nFront center: Shift+A/D\nStops within existing 35-degree curve budget")
