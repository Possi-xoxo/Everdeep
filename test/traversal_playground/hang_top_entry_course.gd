@tool
extends "res://test/traversal_playground/hang_navigation_course.gd"
## Permanent top-edge E-entry fixtures with ordinary ramp access.
func station(x: float,width: float,height: float,label: String,invalid: String="") -> void:
	var wall:=StaticBody3D.new()
	wall.name=label
	add_child(wall)
	wall.position=Vector3(x,0,0)
	if invalid=="NO_BRACE": block(wall,Vector3(0,height-.12,-2),Vector3(width,.24,4),Color(.85,.4,.25))
	else: block(wall,Vector3(0,height*.5,-2),Vector3(width,height,4),Color(.25,.65,.6))
	var access:=StaticBody3D.new()
	add_child(access)
	access.position=Vector3(x,height*.5,-4-height)
	access.rotation.x=-atan(.5)
	block(access,Vector3.ZERO,Vector3(minf(width,2),.15,Vector2(height,height*2).length()),Color(.4,.45,.5))
	if invalid in ["ANCHOR","PATH"]:
		var obstacle:=StaticBody3D.new()
		add_child(obstacle)
		block(obstacle,Vector3(x,height-(.8 if invalid=="ANCHOR" else -.9),.5),Vector3(1.2,.3,.7),Color(.9,.2,.15))
	# Thin visual-only launch/range markings; no duplicate collision planes.
	for distance in [.35,.7]:
		var marking:=MeshInstance3D.new()
		var mesh_box:=BoxMesh.new()
		mesh_box.size=Vector3(width,.008,.015)
		marking.mesh=mesh_box
		wall.add_child(marking)
		marking.position=Vector3(0,height+.005,-distance)
	sign_at(Vector3(x,height+1,-1.5),label+"\nFace the edge / E: enter hang\nLines: 0.35m and 0.70m")

func _ready() -> void:
	var floor_body:=StaticBody3D.new()
	add_child(floor_body)
	block(floor_body,Vector3(40,-.26,-4),Vector3(104,.5,26),Color(.2,.26,.3))
	station(0,5,3,"Hang_TopEntry_Basic")
	station(10,8,3,"Hang_TopEntry_Wide")
	station(20,1.2,2.5,"Hang_TopEntry_Narrow")
	station(28,5,3.5,"Hang_TopEntry_Angled")
	station(38,5,4,"Hang_TopEntry_Range")
	station(48,5,3,"Hang_TopEntry_NoBrace","NO_BRACE")
	station(58,5,3,"Hang_TopEntry_Blocked","ANCHOR")
	station(68,5,3,"Hang_TopEntry_PathBlocked","PATH")
	curved_wall(Vector3(83,0,-10))
	var ramp:=StaticBody3D.new()
	add_child(ramp)
	ramp.position=Vector3(83,1.5,-5)
	ramp.rotation.x=-atan(.5)
	block(ramp,Vector3.ZERO,Vector3(2,.15,Vector2(3,6).length()),Color(.4,.45,.5))
	sign_at(Vector3(83,4,-1),"Hang_TopEntry_Curve\nGentle facets / E near outside edge")
