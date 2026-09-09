@tool
extends "res://test/traversal_playground/hang_vertical_course.gd"
## Permanent catch stations and horizontal-only Free Hang movement course.
const FREE_COLOR = Color(.70,.34,.82)
const BRACED_COLOR = Color(.25,.65,.48)

func slab(at: Vector3,title: String,backed: bool=false) -> StaticBody3D:
	var structure:=StaticBody3D.new()
	structure.name=title
	add_child(structure)
	structure.position=at
	block(structure,Vector3(0,-.125,-1.5),Vector3(6,.25,3),FREE_COLOR if not backed else BRACED_COLOR)
	if backed: block(structure,Vector3(0,-at.y*.5,-1.5),Vector3(6,at.y,3),BRACED_COLOR)
	return structure

func platform(at: Vector3,size: Vector3,color: Color) -> void:
	var structure:=StaticBody3D.new()
	add_child(structure)
	block(structure,at,size,color)

func ramp(at: Vector3,height: float) -> void:
	# Walkable 11-degree access; render and collision are the same shallow box.
	var structure:=StaticBody3D.new()
	add_child(structure)
	structure.position=at
	structure.rotation.x=-atan2(height,6.0)
	block(structure,Vector3.ZERO,Vector3(2,.18,sqrt(36+height*height)),Color(.42,.45,.55))

func _ready() -> void:
	platform(Vector3(38,-.26,5),Vector3(96,.5,36),Color(.23,.27,.32))
	sign_at(Vector3(0,3,10),"FREE HANG — 6 return / R retry / Home hub\nA/D: Shimmy | Shift+A/D: Hop | W: Climb | S: Release\nSpace: NO ACTION / No vertical hops\nHorizontal course behind you (+Z)")
	var titles: Array[String]=["FreeHang_Basic","FreeHang_Rising","FreeHang_Falling","FreeHang_Apex","FreeHang_ForwardMomentum","FreeHang_LateralMomentum","FreeHang_FastCatch","FreeHang_VsBraced","FreeHang_NoBrace","FreeHang_Release"]
	var instructions: Array[String]=["Jump toward the unsupported lip; S releases to safe floor","Jump late, near wall: catch on ascent","Walk off the launch shelf toward the purple lip","Jump earlier: catch near apex","Run forward; watch body settle under fixed hands","Approach diagonally; compare lateral swing","Sprint jump toward lip; swing remains bounded","Left green = BRACED / Right purple = FREE","Only one brace height present: classification stays FREE","S releases; steer outward to the lower ledge"]
	for index in titles.size():
		var x: float=index*8.0
		var height: float=3.0
		if index==2: height=3.45
		if index==9: height=3.6
		var lip: StaticBody3D=slab(Vector3(x,height,0),titles[index])
		sign_at(Vector3(x,4.9,-1.5),titles[index]+"\n"+instructions[index])
		# Colored approach marks offer repeatable jump timing without triggers.
		for distance in [1.0,2.5,5.0]:
			platform(Vector3(x,.001,distance),Vector3(2,.006,.06),Color(.8,.7,.25))
		if index==2:
			platform(Vector3(x,.60,2.3),Vector3(2,1.2,1.5),Color(.42,.45,.55))
			ramp(Vector3(x,.60,6.05),1.2)
		if index==7:
			# A compound collider: reliable bracing on its left half only.
			block(lip,Vector3(-1.5,-1.5,-1.5),Vector3(3,3,3),BRACED_COLOR)
		if index==8:
			# Upper brace probe passes, lower probe misses. No per-frame family switch.
			block(lip,Vector3(0,-.80,-1.5),Vector3(6,.18,3),Color(.75,.50,.25))
		if index==9:
			# Catch on release belongs to a different physical source below/outward.
			var lower: StaticBody3D=slab(Vector3(x,2.5,1.4),"FreeHang_DifferentLedge")
			lower.rotation.y=PI
			sign_at(Vector3(x,1,5),"Approach upper lip from the side\nRelease, turn outward toward the lower lip")
	# Start overlooks all stations; walking around each side returns to floor.
	build_horizontal_course()

func horizontal_lip(at: Vector3,width: float,title: String) -> StaticBody3D:
	var structure:=StaticBody3D.new()
	structure.name=title
	add_child(structure)
	structure.position=at
	block(structure,Vector3(0,-.125,-1.5),Vector3(width,.25,3),FREE_COLOR)
	# Visual-only ruler: 10cm markings make late hand/body sliding visible.
	for i in range(floori(-width*5),ceili(width*5)):
		var mark:=MeshInstance3D.new()
		var shape:=BoxMesh.new()
		shape.size=Vector3(.01,.20,.002)
		mark.mesh=shape
		mark.position=Vector3(i*.1,-.125,.002)
		var material:=StandardMaterial3D.new()
		material.albedo_color=Color(.25,.12,.35)
		mark.material_override=material
		structure.add_child(mark)
	return structure

func build_horizontal_course() -> void:
	platform(Vector3(38,-.26,32),Vector3(96,.5,24),Color(.23,.27,.32))
	horizontal_lip(Vector3(0,3,30),12,"FreeHang_Shimmy_Long")
	sign_at(Vector3(0,4.8,29),"SHIMMY + HOP LEFT / RIGHT\nA/D repeats | Shift+A/D once per press\nAuthored ~0.4m shimmy / ~0.89m hop")
	horizontal_lip(Vector3(16,3,30),2.3,"FreeHang_Hop_Partial")
	sign_at(Vector3(16,4.8,29),"PARTIAL HOP\nCatch center; Shift+A/D\nFull overshoot fails; shorter safe hop wins")
	horizontal_lip(Vector3(31,3,30),2,"FreeHang_GapTransfer_Source")
	horizontal_lip(Vector3(33.18,3,30),2,"FreeHang_GapTransfer_Target")
	sign_at(Vector3(32,4.8,29),"SMALL GAP / 18cm\nShimmy to end, then Shift+D\nParallel ledges only; no outward launch")
	horizontal_lip(Vector3(48,3,30),6,"FreeHang_ClimbUp")
	sign_at(Vector3(48,4.8,29),"CLIMB / RELEASE\nW: crouched pull-up | S: let go\nSpace does nothing")
	horizontal_lip(Vector3(64,3,30),5,"FreeHang_BlockedTop")
	platform(Vector3(64,3.7,28.5),Vector3(5,.3,3),Color(.4,.3,.5))
	sign_at(Vector3(64,5,29),"BLOCKED TOP\nW must do nothing\nS always releases once idle")
	# One horizontal chain, with no hidden vertical-hop dependency.
	for i in 3:
		horizontal_lip(Vector3(i*3.18,3,42),3,"FreeHang_MixedCourse_%d" % i)
	sign_at(Vector3(3.18,4.8,41),"MIXED FREE HANG\nCatch -> shimmy -> hop -> small gaps\nReverse direction -> W climb / S release")
