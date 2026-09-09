@tool
extends "res://test/traversal_playground/hang_vertical_course.gd"
## Opposed, static bracing walls. Compact mode is shared by Vertical/Mixed.
func wall(at: Vector3,levels: Array=[3.0],opposed: bool=false,width: float=5,no_brace: bool=false) -> StaticBody3D:
	var body:=StaticBody3D.new()
	add_child(body)
	body.position=at
	if opposed: body.rotation.y=PI
	var first: float=levels[0]
	var top: float=levels.back()
	if no_brace:
		block(body,Vector3(0,first-.1,-1),Vector3(width,.2,2),Color(.85,.25,.2))
	else:
		block(body,Vector3(0,first*.5,-1),Vector3(width,first,2),Color(.25,.55,.6))
		if levels.size()>1:
			block(body,Vector3(0,top*.5,-1.08),Vector3(width,top,2),Color(.18,.4,.43))
			for height in levels.slice(1): block(body,Vector3(0,height-.09,-1),Vector3(width,.18,2),Color(.3,.8,.65))
	return body

func pair(x: float,label: String,gap: float=4,height: float=3,offset: float=0,no_brace: bool=false) -> void:
	wall(Vector3(x,0,0))
	wall(Vector3(x+offset,0,gap),[height],true,5,no_brace)
	sign_at(Vector3(x,4,-1),label+"\nHang facing source / Space toward opposite wall\nA/D + Space: wall-relative bias")
	var ramp:=StaticBody3D.new()
	add_child(ramp)
	ramp.position=Vector3(x,1.5,-5)
	ramp.rotation.x=-atan(.5)
	block(ramp,Vector3.ZERO,Vector3(2,.15,Vector2(3,6).length()),Color(.4,.45,.5))

func _ready() -> void:
	var floor_body:=StaticBody3D.new()
	add_child(floor_body)
	block(floor_body,Vector3(0 if compact else 104,-.28,0),Vector3(20 if compact else 236,.5,22),Color(.2,.25,.3))
	if compact:
		wall(Vector3.ZERO,[2.3,3.3,4.3])
		wall(Vector3(0,0,4),[3.3,4.3,5.3],true)
		sign_at(Vector3(0,5.5,-1),"Hang_Outward_Chain\nW up source -> Space across -> W continue up\nSpace back / A-D shimmy")
		return
	block(floor_body,Vector3(0,-.28,13),Vector3(8,.5,6),Color(.2,.25,.3))
	pair(0,"Hang_Outward_Basic / Same height / Transfer -> Shimmy")
	pair(18,"Hang_Outward_Higher",4,3.25)
	pair(36,"Hang_Outward_Lower",4,2.75)
	pair(54,"Hang_Outward_LeftBias",3.5,3,-2)
	pair(72,"Hang_Outward_RightBias",3.5,3,2)
	pair(90,"Hang_Outward_MaxRange / 3.25m anchors",4.25)
	pair(108,"Hang_Outward_OutOfRange / 3.5m anchors",4.5)
	pair(126,"Hang_Outward_Blocked")
	var obstacle:=StaticBody3D.new()
	add_child(obstacle)
	block(obstacle,Vector3(126,3,2),Vector3(8,.3,1),Color(.85,.25,.2))
	pair(144,"Hang_Outward_NoBrace",4,3,0,true)
	wall(Vector3(162,0,0))
	for x in [-1.5,1.5]: wall(Vector3(162+x,0,3.5),[3.0],true,1.6)
	sign_at(Vector3(162,4,-1),"Hang_Outward_TargetPriority\nSpace+A left / Space+D right")
	wall(Vector3(180,0,0))
	sign_at(Vector3(180,4,-1),"Hang_Outward_NoTarget\nSpace -> ordinary jump off")
	wall(Vector3(198,0,0),[2.3,3.3,4.3])
	wall(Vector3(198,0,4),[3.3,4.3,5.3],true)
	sign_at(Vector3(198,5.5,-1),"Hang_Outward_Chain\nHop up, cross, continue up, cross back")
	wall(Vector3(216,0,0),[3.0],false,4)
	wall(Vector3(221,0,0),[3.0],false,4)
	wall(Vector3(221,0,4),[3.0],true,4)
	sign_at(Vector3(219,4,-1),"Horizontal gap -> Outward\nShift+D across opening, then Space")
