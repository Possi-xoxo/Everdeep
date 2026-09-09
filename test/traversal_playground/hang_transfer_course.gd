@tool
extends "res://test/traversal_playground/hang_vertical_course.gd"
## Permanent horizontal-gap fixtures. Blue compatible walls, red invalid.
func wall(at: Vector3,width: float=4,height: float=3,no_brace: bool=false) -> StaticBody3D:
	var body:=StaticBody3D.new()
	add_child(body)
	body.position=at
	block(body,Vector3(0,height-.10 if no_brace else height*.5,-2),Vector3(width,.20 if no_brace else height,4),Color(.3,.6,.8) if not no_brace else Color(.9,.3,.2))
	return body

func pair(x: float,label: String,separation: float=5,height_delta: float=0,no_brace: bool=false,blocked: bool=false,target_width: float=4) -> StaticBody3D:
	wall(Vector3(x,0,0))
	var target:=wall(Vector3(x+separation,0,0),target_width,3+height_delta,no_brace)
	if blocked:
		var obstruction:=StaticBody3D.new()
		add_child(obstruction)
		block(obstruction,Vector3(x+separation*.5,2,.6),Vector3(.3,3,1.5),Color(.9,.2,.15))
	sign_at(Vector3(x+1.5,3.9,1.8),label+"\nCatch near the inner edges\nShift+A/D: transfer / release input to rearm")
	# Rear ramp to source; top-down E is another ordinary way to enter.
	var ramp:=StaticBody3D.new()
	add_child(ramp)
	ramp.position=Vector3(x,1.5,-7)
	ramp.rotation.x=-atan(.5)
	block(ramp,Vector3.ZERO,Vector3(2,.15,Vector2(3,6).length()),Color(.4,.45,.5))
	return target

func _ready() -> void:
	var floor_body:=StaticBody3D.new()
	add_child(floor_body)
	block(floor_body,Vector3(100,-.26,-2),Vector3(228,.5,26),Color(.20,.26,.3))
	block(floor_body,Vector3(0,-.26,14),Vector3(8,.5,14),Color(.20,.26,.3))
	pair(0,"Hang_Transfer_Left / Right\nTransfer <-> Shimmy")
	pair(18,"Hang_Transfer_Higher",5,.25)
	pair(36,"Hang_Transfer_Lower",5,-.25)
	pair(54,"Hang_Transfer_MaxRange\nStart x +1.5 / ~4.5m anchor distance",7.65)
	pair(74,"Hang_Transfer_OutOfRange\nStart x +1.5 / >4.5m",8.0)
	pair(94,"Hang_Transfer_Blocked",5,0,false,true)
	pair(112,"Hang_Transfer_NoBrace",5,0,true)
	pair(130,"Hang_Transfer_TargetPriority\nTwo in-range targets / near target first",3.8,0,false,false,1.2)
	wall(Vector3(135.3,0,0),1.2)
	# Chain allows transfer then shimmy toward the next edge before reinput.
	for x in [152,157,162,167]: wall(Vector3(x,0,0))
	sign_at(Vector3(158,4,1.8),"Hang_Transfer_Chain\nOne discrete press per transfer")
	var tower:=pair(182,"Hang_Transfer_ToVertical")
	block(tower,Vector3(0,2.5,-2.08),Vector3(4,5,4),Color(.18,.4,.43))
	for height in [4.0,5.0]: block(tower,Vector3(0,height-.09,-2),Vector3(4,.18,4),Color(.3,.8,.65))
	# A visual 5mm seam with continuous collision, not a transfer-sized gap.
	var seam:=StaticBody3D.new()
	add_child(seam)
	seam.position=Vector3(208,0,0)
	block(seam,Vector3(-2.5935,1.5,-2),Vector3(6.813,3,4),Color(.3,.65,.45))
	block(seam,Vector3(4.409,1.5,-2),Vector3(7.182,3,4),Color(.3,.65,.45))
	var bridge:=CollisionShape3D.new()
	var bridge_shape:=BoxShape3D.new()
	bridge_shape.size=Vector3(.01,3,4)
	bridge.shape=bridge_shape
	seam.add_child(bridge)
	bridge.position=Vector3(.8155,1.5,-2)
	sign_at(Vector3(208,4,1.8),"Continuous_Hop / Tiny seam\nNormal hop remains first priority")
