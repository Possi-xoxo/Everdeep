extends "res://test/player_v2_lab.gd"
## Standalone west-side sensing course; no changes to existing traversal lanes.
func _ready() -> void:
	_box("Floor",Vector3(-43,-.25,12),Vector3(24,.5,30),Color(.20,.25,.29))
	_label("HAND SENSING / F11 DEBUG / WALK ONLY",Vector3(-40,.1,23))
	_box("LeftWall",Vector3(-36,1,12),Vector3(.2,2,12),Color(.3,.45,.5))
	_box("RightWallAbruptEnd",Vector3(-40,1,16),Vector3(.2,2,6),Color(.35,.45,.5))
	for index in 10:
		_box("UnevenStone%d" % index,Vector3(-44+(.04 if index%2==0 else -.04),1,8+index*.65),Vector3(.25,2,.64),Color(.4,.4,.45))
	var cylinder:=CylinderShape3D.new()
	cylinder.radius=.3
	cylinder.height=2
	var mesh:=CylinderMesh.new()
	mesh.top_radius=.3
	mesh.bottom_radius=.3
	mesh.height=2
	_body("Pillar",Vector3(-47,1,18),cylinder,mesh,Color(.5,.45,.35))
	_box("Rail",Vector3(-47,1.25,9),Vector3(.12,.16,6),Color(.5,.4,.25))
	for x in [-51.6,-50.4]:
		_box("CorridorWall",Vector3(x,1,13),Vector3(.16,2,10),Color(.4,.5,.4))
	_label("BOTH SIDES",Vector3(-51,.05,20))
