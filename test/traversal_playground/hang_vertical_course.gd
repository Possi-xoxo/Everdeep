@tool
extends Node3D
## Permanent modular course. One static compound collider per wall chain.
@export var compact: bool=false

func block(parent: Node3D,at: Vector3,size: Vector3,color: Color) -> void:
	var shape:=BoxShape3D.new()
	shape.size=size
	var collider:=CollisionShape3D.new()
	collider.shape=shape
	parent.add_child(collider)
	collider.position=at
	var visual:=MeshInstance3D.new()
	var box:=BoxMesh.new()
	box.size=size
	visual.mesh=box
	var material:=StandardMaterial3D.new()
	material.albedo_color=color
	visual.material_override=material
	parent.add_child(visual)
	visual.position=at

func sign_at(at: Vector3,text: String) -> void:
	var label:=Label3D.new()
	add_child(label)
	label.position=at
	label.text=text
	label.font_size=30
	label.pixel_size=.007
	label.billboard=BaseMaterial3D.BILLBOARD_ENABLED

func chain(at: Vector3,heights: Array,label: String,offsets: bool=false,blocked: bool=false) -> void:
	var wall:=StaticBody3D.new()
	add_child(wall)
	wall.position=at
	wall.set_meta("vertical_levels",heights)
	var total: float=heights.back()
	block(wall,Vector3(0,total*.5,-1.08),Vector3(18,total,2),Color(.18,.40,.43))
	block(wall,Vector3(0,float(heights[0])*.5,-1),Vector3(18,heights[0],2),Color(.25,.55,.53))
	for i in heights.size():
		var x: float=.15*sin(i*2.0) if offsets else 0.0
		block(wall,Vector3(x,heights[i]-.09,-1),Vector3(18,.18,2),Color(.32,.8,.68))
	if blocked:
		var obstacle:=StaticBody3D.new()
		add_child(obstacle)
		obstacle.position=at
		block(obstacle,Vector3(0,3.05,.55),Vector3(2,.15,.8),Color(.9,.25,.12))
	sign_at(at+Vector3(0,1.6,2.2),label+"\nW: upper target first / S: lower target first\nFresh press for each hop")

func _ready() -> void:
	var floor_body:=StaticBody3D.new()
	add_child(floor_body)
	var width: float=22 if compact else 155
	block(floor_body,Vector3(width*.5-10,-.26,1),Vector3(width,.5,10),Color(.19,.25,.29))
	chain(Vector3.ZERO,[2.3,3.3,4.3,5.3],"Hang_Vertical_Basic / HopUp / HopDown\nUpperPriority / LowerSafety\nTop: pull up | Bottom: release")
	sign_at(Vector3(0,6.3,-1),"TOP-DOWN BRACED HANG ENTRY\nFace front edge / E near lip\nThen S: Hop Down / A-D: Shimmy")
	# Also present in Mixed's compact module: grounded access to the 5.3m top.
	var top_access:=StaticBody3D.new()
	add_child(top_access)
	top_access.position=Vector3(0,2.65,-7.3)
	top_access.rotation.x=-atan(.5)
	block(top_access,Vector3.ZERO,Vector3(2,.15,Vector2(5.3,10.6).length()),Color(.38,.43,.5))
	if compact: return
	chain(Vector3(22,0,0),[2.3,3.2,4.4,5.45],"Hang_VariedSpacing / small offsets",true)
	chain(Vector3(44,0,0),[2.3,3.8,4.8],"Hang_Up_OutOfRange: 1.50m > 1.40m\nDown is reachable")
	chain(Vector3(66,0,0),[2.3,4.0,5.0],"Hang_Down_OutOfRange: 1.70m > 1.60m")
	chain(Vector3(88,0,0),[2.3,3.3,4.3],"Hang_VerticalBlocked: upper destination",false,true)
	chain(Vector3(110,0,0),[2.3,3.3,4.3],"Hang_VerticalBlocked: lower destination\nUse rear ramp to start above")
	var lower_block:=StaticBody3D.new()
	add_child(lower_block)
	block(lower_block,Vector3(110,.8,.55),Vector3(2,.15,.8),Color(.9,.25,.12))
	chain(Vector3(132,0,0),[2.3,3.3,4.3,5.3,6.3,7.3,8.3],"Hang_VerticalChain: seven ledges")
	# Ordinary ramp collision: access high starts without traversal cheats.
	var ramp:=StaticBody3D.new()
	add_child(ramp)
	ramp.position=Vector3(143,4.2,-5.4)
	ramp.rotation.x=atan(.5)
	block(ramp,Vector3.ZERO,Vector3(3,.25,Vector2(8.4,16.8).length()),Color(.38,.43,.5))
	var deck:=StaticBody3D.new()
	add_child(deck)
	block(deck,Vector3(66,8.25,-14.8),Vector3(158,.3,3),Color(.38,.43,.5))
	for x in [0,22,44,66,88,110,132]:
		block(deck,Vector3(x,8.25,-8),Vector3(2,.3,11),Color(.38,.43,.5))
	sign_at(Vector3(143,2,4),"Upper-access ramp / drop onto test wall tops")
