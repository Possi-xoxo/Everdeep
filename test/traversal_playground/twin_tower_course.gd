extends Node3D
## Permanent two-strand course. Geometry only: no traversal/controller overrides.
const ORB=preload("res://test/traversal_playground/twin_tower_orb.gd")
const HEIGHTS={"A":32.2,"B":32.0}
const LEDGE=Color(.30,.75,.63)
const STONE=Color(.25,.30,.37)
const REST=Color(.70,.55,.28)
var towers: Dictionary={}
var sections: Dictionary={}
var checkpoints: Dictionary={}
var anchors: Dictionary={}
var orbs: Dictionary={}
var checkpoint: String="Base"
var checkpoint_clock: float=0
var both_reported: bool=false
var materials: Dictionary={}

func section(tower: String,title: String) -> Node3D:
	var key: String=tower+"_"+title
	if sections.has(key): return sections[key]
	var node:=Node3D.new()
	node.name=title
	towers[tower].add_child(node)
	sections[key]=node
	return node

func material(color: Color) -> StandardMaterial3D:
	if not materials.has(color):
		var result:=StandardMaterial3D.new()
		result.albedo_color=color; result.roughness=.9
		materials[color]=result
	return materials[color]

func box(body: StaticBody3D,group: Node3D,title: String,at: Vector3,size: Vector3,color: Color=LEDGE,yaw: float=0) -> void:
	var collision:=CollisionShape3D.new()
	collision.name=title+"_Collision"
	var shape:=BoxShape3D.new()
	shape.size=size; collision.shape=shape
	body.add_child(collision); collision.position=at; collision.rotation.y=yaw
	var visual:=MeshInstance3D.new()
	visual.name=title
	var mesh:=BoxMesh.new()
	mesh.size=size; visual.mesh=mesh
	visual.material_override=material(color)
	group.add_child(visual); visual.position=at; visual.rotation.y=yaw

func sign_at(group: Node3D,at: Vector3,title: String) -> void:
	var label:=Label3D.new()
	label.position=at; label.text=title
	label.font_size=28; label.pixel_size=.007
	label.billboard=BaseMaterial3D.BILLBOARD_ENABLED
	group.add_child(label)

func quad(surface: SurfaceTool,faces: Array[Vector3],a: Vector3,b: Vector3,c: Vector3,d: Vector3,normal: Vector3) -> void:
	var vertices: Array[Vector3]=[a,b,c,a,c,d]
	if (b-a).cross(c-a).dot(normal)>0: vertices=[a,c,b,a,d,c]
	surface.set_normal(normal)
	for p in vertices: surface.add_vertex(p); faces.append(p)

func arc(tower: String,group: Node3D,title: String,r0: float,r1: float,start: float,finish: float,bottom: float,top: float,color: Color,lead_length: float=0) -> void:
	var body: StaticBody3D=towers[tower]
	var side: float=-1 if tower=="A" else 1
	var center:=Vector3(side*2.7,0,0)
	var count: int=ceili((finish-start)/1.8)
	var surface:=SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var faces: Array[Vector3]=[]
	for i in count:
		var a: float=deg_to_rad(lerpf(start,finish,float(i)/count))
		var b: float=deg_to_rad(lerpf(start,finish,float(i+1)/count))
		var na:=Vector3(side*sin(a),0,cos(a))
		var nb:=Vector3(side*sin(b),0,cos(b))
		var low_a: Vector3=center+na*r1+Vector3.UP*bottom
		var low_b: Vector3=center+nb*r1+Vector3.UP*bottom
		var high_a: Vector3=center+na*r1+Vector3.UP*top
		var high_b: Vector3=center+nb*r1+Vector3.UP*top
		var inner_a: Vector3=center+na*r0
		var inner_b: Vector3=center+nb*r0
		quad(surface,faces,low_a,low_b,high_b,high_a,(na+nb).normalized())
		if r0>.001: quad(surface,faces,inner_a+Vector3.UP*bottom,inner_b+Vector3.UP*bottom,inner_b+Vector3.UP*top,inner_a+Vector3.UP*top,-(na+nb).normalized())
		quad(surface,faces,high_a,high_b,inner_b+Vector3.UP*top,inner_a+Vector3.UP*top,Vector3.UP)
		quad(surface,faces,low_a,low_b,inner_b+Vector3.UP*bottom,inner_a+Vector3.UP*bottom,Vector3.DOWN)
		if i==0:
			var before:=Vector3(-side*cos(a),0,sin(a))
			var lead:=before*lead_length
			if lead_length>0:
				# A continuous tangent face, not overlapping boxes with exposed end caps.
				quad(surface,faces,low_a+lead,low_a,high_a,high_a+lead,na)
				quad(surface,faces,inner_a+lead+Vector3.UP*bottom,inner_a+Vector3.UP*bottom,inner_a+Vector3.UP*top,inner_a+lead+Vector3.UP*top,-na)
				quad(surface,faces,high_a+lead,high_a,inner_a+Vector3.UP*top,inner_a+lead+Vector3.UP*top,Vector3.UP)
				quad(surface,faces,low_a+lead,low_a,inner_a+Vector3.UP*bottom,inner_a+lead+Vector3.UP*bottom,Vector3.DOWN)
			quad(surface,faces,low_a+lead,high_a+lead,inner_a+lead+Vector3.UP*top,inner_a+lead+Vector3.UP*bottom,before)
		if i==count-1: quad(surface,faces,low_b,high_b,inner_b+Vector3.UP*top,inner_b+Vector3.UP*bottom,Vector3(side*cos(b),0,-sin(b)))
	var collision:=CollisionShape3D.new()
	collision.name=title+"_Collision"
	var shape:=ConcavePolygonShape3D.new()
	shape.set_faces(PackedVector3Array(faces)); shape.backface_collision=true
	collision.shape=shape; body.add_child(collision)
	var visual:=MeshInstance3D.new()
	visual.name=title; visual.mesh=surface.commit(); visual.material_override=material(color)
	group.add_child(visual)

func core(tower: String) -> void:
	var group:=section(tower,"Structure")
	# A solid D prism: flat inner face, a 100-facet rounded exterior.
	arc(tower,group,tower+"_Core",0,5,0,180,0,HEIGHTS[tower],STONE)

func face_x(tower: String) -> float: return -1.54 if tower=="A" else 1.54
func normal(tower: String) -> Vector3: return Vector3.RIGHT if tower=="A" else Vector3.LEFT

func flat_ledge(tower: String,group: Node3D,title: String,height: float,z0: float,z1: float) -> void:
	var side: float=-1 if tower=="A" else 1
	# Flush collision avoids a protruding lip snagging the existing hoist path.
	box(towers[tower],group,title,Vector3(side*2.12,height-.09,(z0+z1)*.5),Vector3(1.16,.18,z1-z0))
	group.get_node(NodePath(title)).position+=normal(tower)*.002
	anchors[title]={"edge":Vector3(face_x(tower),height,(z0+z1)*.5),"normal":normal(tower),"tower":tower,"span":Vector2(z0,z1)}

func facade(tower: String,holes: Array) -> void:
	var group:=section(tower,"Structure")
	var boundaries: Array[float]=[-5.2,5.2]
	for hole in holes: boundaries.append(hole.x); boundaries.append(hole.y)
	boundaries.sort()
	var side: float=-1 if tower=="A" else 1
	for i in range(boundaries.size()-1):
		var z0: float=boundaries[i]
		var z1: float=boundaries[i+1]
		if z1-z0<.001: continue
		var intervals: Array[Vector2]=[]
		for hole in holes:
			if (z0+z1)*.5>hole.x and (z0+z1)*.5<hole.y: intervals.append(Vector2(hole.z,hole.w))
		intervals.sort_custom(func(a: Vector2,b: Vector2)->bool:return a.x<b.x)
		var bottom: float=0
		for gap in intervals+[Vector2(HEIGHTS[tower],HEIGHTS[tower])]:
			if gap.x>bottom:
				box(towers[tower],group,"Facade_%d_%.1f"%[i,bottom],Vector3(side*2.12,(bottom+gap.x)*.5,(z0+z1)*.5),Vector3(1.16,gap.x-bottom,z1-z0),STONE)
			bottom=maxf(bottom,gap.y)

func checkpoint_at(title: String,at: Vector3,group: Node3D) -> void:
	var marker:=Marker3D.new()
	marker.name="Checkpoint_"+title; marker.position=at
	group.add_child(marker)
	checkpoints[title]=marker
	var disc:=MeshInstance3D.new()
	var mesh:=CylinderMesh.new()
	mesh.top_radius=.38; mesh.bottom_radius=.38; mesh.height=.02
	disc.mesh=mesh; disc.material_override=material(Color(.3,.6,.95))
	marker.add_child(disc); disc.position.y=-.07
	sign_at(group,at+Vector3.UP*.5,title+" checkpoint\nR: retry / 5: tower base")

func curve_section(tower: String,height: float,chapter: String,start: float=0) -> void:
	var group:=section(tower,chapter)
	arc(tower,group,tower+"_Curve_Back",5,5.96,start,150,height-2,height+4,STONE,1.6)
	arc(tower,group,tower+"_Curve_Landing",5,6,150,180,height-2,height,REST)
	arc(tower,group,tower+"_Curve_Ledge",5,6,start,170,height-.18,height,LEDGE,1.6)
	var side: float=-1 if tower=="A" else 1
	# Flat tangent lead-in gives the existing airborne detector a stable normal;
	# traversal then enters the fine-faceted curve without a hard corner.
	var n:=Vector3(side*sin(deg_to_rad(start)),0,cos(deg_to_rad(start)))
	var travel:=Vector3(side*cos(deg_to_rad(start)),0,-sin(deg_to_rad(start)))
	var lead: Vector3=Vector3(side*2.7,height,0)+n*6-travel*.8
	anchors[tower+"_Curve_Start"]={"edge":lead,"normal":n,"tower":tower}
	var end_n:=Vector3(side*sin(deg_to_rad(157)),0,cos(deg_to_rad(157)))
	checkpoint_at(tower+"_CurveRest",Vector3(side*2.7,height+.08,0)+end_n*5.5,group)
	box(towers[tower],group,tower+"_BackWalk",Vector3(side*2.0,height-.12,-6.0),Vector3(4,.24,1.5),REST)
	box(towers[tower],group,tower+"_BackInnerWalk",Vector3(side*1.5,height-.12,-4.9),Vector3(2.4,.24,2),REST)
	box(towers[tower],group,tower+"_BackJumpApron",Vector3(side*.8,height-.12,-3.3),Vector3(1.4,.24,3.2),REST)
	sign_at(group,Vector3(side*8,height+1,0),chapter+"\nShimmy / full hop / partial hop near end\nNo W shortcut: follow the rounded wall")

func build_a() -> void:
	facade("A",[Vector4(-.5,.5,3,6.4),Vector4(2.8,5.2,8.6,11.0),Vector4(-5.2,-3,11,13.4),Vector4(-5.2,-3,16.8,19.2),Vector4(-5.2,-3,27.4,29.8)])
	var entry:=section("A","Section_01_Entry")
	box(towers.A,entry,"A_JumpStep",Vector3(-.6,.3,8.6),Vector3(2,.6,2),REST)
	box(towers.A,entry,"A_Mantle",Vector3(-.6,1.3,6.8),Vector3(2,2.6,1.5),REST)
	box(towers.A,entry,"A_EntryBridge",Vector3(-.6,2.48,5.4),Vector3(2,.24,1.4),REST)
	sign_at(entry,Vector3(-2,3,8.8),"A1 ENTRY\nJump .6m step -> E mantle 2m\nJump toward inner wall: catch 5m ledge")
	var lateral:=section("A","Section_02_Lateral")
	for spec in [["A_FullHop",5.0,.5,5.2],["A_GapLanding",5.0,-5.2,-.5],["A_UpperLeft",6.2,-5.2,-.5],["A_ReturnGap",6.2,.5,5.2],["A_UpperRight",7.4,3.0,5.2],["A_Rest",8.6,2.8,5.2]]:
		flat_ledge("A",lateral,spec[0],spec[1],spec[2],spec[3])
	checkpoint_at("A_Lower",Vector3(-2.05,8.68,3.5),lateral)
	anchors.A_Rest.edge.z=3.5
	box(towers.A,lateral,"A_FrontWalk",Vector3(-2,8.48,6.8),Vector3(4,.24,1.6),REST)
	box(towers.A,lateral,"A_FrontInnerWalk",Vector3(-1.25,8.48,5.35),Vector3(2.9,.24,2.3),REST)
	sign_at(lateral,Vector3(-.5,6.6,0),"A2 BROKEN LEDGES\nFull -> partial -> gap hop\nW at left end; cross back; climb right")
	curve_section("A",11,"Section_03_Curve")
	var mixed:=section("A","Section_04_VerticalMix")
	for spec in [["A_MixStart",13.4,-5.2,0],["A_MixRight",14.6,-.5,5.2],["A_MixRightUp",15.8,3.5,5.2],["A_MixLeft",16.8,-5.2,5.2]]:
		flat_ledge("A",mixed,spec[0],spec[1],spec[2],spec[3])
	var jump_off:=section("A","Section_05_JumpOff")
	# Match this continuous grip's existing 2mm visual offset in collision too.
	# Otherwise coplanar facade-box seams can return a perpendicular end face
	# when probing sideways out of the rest opening.
	towers.A.get_node("A_MixLeft_Collision").position+=normal("A")*.002
	anchors.A_MixLeft.edge+=normal("A")*.002
	flat_ledge("A",jump_off,"A_JumpOff",18.2,-.8,.8)
	# Landing from Tower B's lower crossing joins A's center launch via hanging.
	# One continuous 16.8m grip: the former 20cm step between these sections
	# was below vertical-hop range but too large for ordinary sideways travel.
	anchors.A_CrossReentry=anchors.A_MixLeft.duplicate()
	anchors.A_CrossReentry.edge.z=-2.6
	anchors.A_CrossReentry.span=Vector2(-5.2,0)
	anchors.A_CrossLanding=anchors.A_CrossReentry.duplicate()
	anchors.A_CrossLanding.edge.z=-4.1
	checkpoint_at("A_CrossRest",Vector3(-2.05,16.88,-4),mixed)
	sign_at(jump_off,Vector3(-.4,18.9,0),"A5 CROSS SHAFT\nSpace: jump freely to B 19.2m\nAuto-targeting is NOT required")
	var topdown:=section("A","Section_06_TopDown")
	flat_ledge("A",topdown,"A_TopDownEntry",27.4,-5.2,5.2)
	checkpoint_at("A_Upper",Vector3(-2.05,27.48,-4),topdown)
	sign_at(topdown,Vector3(-.5,28,-4),"A6 TOP-DOWN REENTRY\nE at lip, then traverse toward +Z\nStanding route is blocked; go below it")
	var summit:=section("A","Section_07_Summit")
	for spec in [["A_FinalUp",28.6,3.5,5.2],["A_FinalLeft",29.8,-.8,5.2],["A_FinalCenter",31.0,-.8,.8],["A_SummitLedge",32.2,-5.2,5.2]]:
		flat_ledge("A",summit,spec[0],spec[1],spec[2],spec[3])
	add_orb("A",summit,Vector3(-4,33.2,0))

func build_b() -> void:
	facade("B",[Vector4(-5.2,-3,7.2,9.6),Vector4(3.5,5.2,12,14.4),Vector4(-1.2,2.7,19.2,21.6)])
	var entry:=section("B","Section_01_OffsetEntry")
	box(towers.B,entry,"B_Jump01",Vector3(4.2,.4,10.3),Vector3(1.7,.8,1.7),REST)
	box(towers.B,entry,"B_Jump02",Vector3(5.8,.8,8.8),Vector3(1.7,1.6,1.7),REST)
	box(towers.B,entry,"B_Mantle",Vector3(5.1,1.8,8.0),Vector3(2.1,3.6,1.5),REST)
	# Front face: high starting pocket, lower ledge continues east.
	box(towers.B,entry,"B_DescentPocket",Vector3(3.45,3,5.5),Vector3(1.5,6,1.16),REST)
	box(towers.B,entry,"B_DescentWall",Vector3(5.85,4.6,5.46),Vector3(3.3,9.2,1.08),STONE)
	box(towers.B,entry,"B_LowerRest",Vector3(8.2,2.4,5.5),Vector3(1.4,4.8,1.16),REST)
	box(towers.B,entry,"B_HopDown",Vector3(5.8,4.71,5.5),Vector3(6.2,.18,1.16))
	anchors.B_HopDown={"edge":Vector3(3.45,6,6.08),"normal":Vector3.BACK,"tower":"B"}
	checkpoint_at("B_Descent",Vector3(3.45,6.08,5.5),entry)
	box(towers.B,entry,"B_CurveApproach",Vector3(8.2,4.68,3.465),Vector3(2,.24,2.93),REST)
	sign_at(entry,Vector3(5,7,7),"B1 / B2 DESCENT\nJump steps -> mantle -> catch 6m pocket\nE down, S to 4.8m, shimmy east; pull up")
	curve_section("B",7.2,"Section_03_CurvedExterior",65)
	var inner:=section("B","Section_04_InnerAscent")
	for spec in [["B_InnerStart",9.6,-5.2,0],["B_InnerRight",10.8,-.5,5.2],["B_LowerCheckpoint",12.0,2.5,5.2],["B_InnerLeft",13.2,-.5,3.2],["B_InnerBack",14.4,-5.2,0],["B_FreeJump",15.6,-5.2,-3]]:
		flat_ledge("B",inner,spec[0],spec[1],spec[2],spec[3])
	checkpoint_at("B_Lower",Vector3(2.05,12.08,4.3),inner)
	sign_at(inner,Vector3(.4,16.3,-4),"B4 FREE CROSSING\nSpace to A 16.8m / normal catch\nThen shimmy toward A's center launch")
	var crossing:=section("B","Section_05_ReturnAndUpper")
	for spec in [["B_CatchA",19.2,-1.2,1.2],["B_UpperStart",21.6,-1.2,5.2],["B_UpperRight",22.8,3.5,5.2],["B_UpperLeft",24.0,-.5,5.2],["B_UpperBack",25.2,-5.2,0],["B_ReturnLaunch",26.4,-5.2,-3]]:
		flat_ledge("B",crossing,spec[0],spec[1],spec[2],spec[3])
	checkpoint_at("B_Mid",Vector3(2.05,19.28,0),crossing)
	# This bar crosses the rest opening, but acquisition belongs beyond it.
	anchors.B_UpperStart.edge.z=3.05
	box(towers.B,crossing,"B_UpperJumpApron",Vector3(1.5,19.08,2.7),Vector3(2.4,.24,3.0),REST)
	sign_at(crossing,Vector3(.6,20.1,2),"B MID LANDING\nWalk onto side apron\nJump back toward 21.6m green lip")
	sign_at(crossing,Vector3(.4,27.2,-4),"B5 RETURN CROSSING\nFree jump to A 27.4m\nPull up, checkpoint, E back down")
	var summit:=section("B","Section_07_Summit")
	flat_ledge("B",summit,"B_SummitCatch",30.8,3.5,5.2)
	flat_ledge("B",summit,"B_SummitLedge",32,-5.2,5.2)
	sign_at(summit,Vector3(.4,31.2,4.2),"B SUMMIT BRANCH\nJump across from A 29.8m near +Z end\nW to summit / E orb")
	add_orb("B",summit,Vector3(4,33,0))

func add_orb(tower: String,group: Node3D,at: Vector3) -> void:
	var orb=ORB.new()
	orb.name="Tower"+tower+"SummitOrb"; orb.tower_id=tower; orb.position=at
	group.add_child(orb); orbs[tower]=orb
	orb.activated.connect(_orb_activated)

func _orb_activated(_tower: String) -> void:
	if orbs.A.lit and orbs.B.lit and not both_reported:
		both_reported=true; print("TWIN TOWER TRAVERSAL COMPLETE")

func reset_test_state() -> void:
	both_reported=false
	for orb in orbs.values(): orb.reset_activation()

func reset_checkpoint() -> void: checkpoint="Base"
func get_reset_marker() -> Marker3D: return checkpoints.get(checkpoint,$Start)

func _ready() -> void:
	for tower in ["A","B"]:
		var body:=StaticBody3D.new()
		body.name="TraversalTwinTower_"+tower; add_child(body); towers[tower]=body
		core(tower)
	build_a(); build_b()
	# Five metres between inner faces matches the existing free-jump catch
	# fixture; no optional committed wall-to-wall action is needed.
	for tower in ["A","B"]: towers[tower].position.x=-1 if tower=="A" else 1
	for anchor in anchors.values(): anchor.edge.x+=-1 if anchor.tower=="A" else 1
	var recovery:=StaticBody3D.new()
	recovery.name="Recovery"; add_child(recovery)
	box(recovery,recovery,"Base",Vector3(0,-.27,1),Vector3(24,.5,24),Color(.2,.26,.31))
	# Deliberately below, not through, nearby hang/capsule corridors.
	for spec in [Vector2(10,-4),Vector2(12.5,0),Vector2(22,-4),Vector2(25.2,4)]:
		box(recovery,recovery,"Recovery_%.1f_%.0f"%[spec.x,spec.y],Vector3(0,spec.x-.15,spec.y),Vector3(2.8,.3,2.7),Color(.25,.4,.55))
	checkpoint_at("Base",$Start.position,recovery)
	sign_at(recovery,Vector3(0,2.5,10),"TWIN TOWERS / 32m\nAmber rests / Blue checkpoints / Green grips\n5: base / R: latest checkpoint / Home: hub\nNo auto-target transfer required")

func _physics_process(delta: float) -> void:
	checkpoint_clock-=delta
	if checkpoint_clock>0: return
	checkpoint_clock=.2
	var manager=get_parent().get_parent() if get_parent()!=null else null
	if manager==null or not manager.has_method("request_reset"): return
	var player=manager.player
	if not is_instance_valid(player) or not player.ground_support.has_ground_support: return
	for title in checkpoints:
		var offset: Vector3=player.global_position-checkpoints[title].global_position
		if absf(offset.y)<.3 and Vector2(offset.x,offset.z).length()<.65:
			manager.current_course=&"TwinTowers"
			if checkpoint!=title: checkpoint=title; print("Tower checkpoint: ",title)
			return
