extends RefCounted
## Local convex corner only. Same static collider, unchanged ledge elevation.
var active: bool=false
var progress: float=0
var elapsed: float=0
var state: StringName=&"HangCornerRight"
var committed: Dictionary={}
var last_query: Dictionary={"valid":false,"reason":"NOT_QUERIED","type":"NONE"}
var expected_position:=Vector3.ZERO
var poses: Dictionary={}
var source_grips: Dictionary={}
var settle_remaining: float=0

func prepare(h: Node,player: AnimationPlayer) -> void:
	var skeleton: Skeleton3D=h.motor.get_node("AnimationController").rig.get_node("Base Armature and Mesh/Skeleton3D")
	for side in [-1,1]:
		var clip_name: StringName=h.lateral.CLIPS["HangShimmyLeft" if side<0 else "HangShimmyRight"]
		var clip: Animation=player.get_animation(clip_name)
		var samples: Array=[]
		player.play(clip_name)
		for i in range(65):
			player.seek(clip.length*i/64.0,true)
			player.advance(0)
			var sample: Dictionary={}
			for hand in ["Left","Right"]:
				var points: Array[Vector3]=[]
				for suffix in ["Arm","ForeArm","Hand"]:
					var bone: int=skeleton.find_bone("mixamorig_"+hand+suffix)
					points.append(h.motor.get_node("VisualRoot").to_local(skeleton.global_transform*skeleton.get_bone_global_pose(bone).origin)+Vector3.UP*h.braced_hang_visual_vertical_offset+Vector3.FORWARD*h.braced_hang_chest_wall_offset)
				sample[hand]={"shoulder":points[0],"wrist":points[2],"reach":points[0].distance_to(points[1])+points[1].distance_to(points[2])}
			samples.append(sample)
		poses[side]=samples
		player.stop()

func path(h: Node,q: Dictionary,p: float) -> Dictionary:
	var normal: Vector3=q.source_normal
	var point: Vector3
	var height: Vector3=Vector3.UP*h.hang_vertical_offset
	var first: Vector3=q.corner+normal*q.radius-height
	var last: Vector3=q.corner+Vector3(q.normal)*q.radius-height
	if p<.25:
		point=Vector3(q.start).lerp(first,smoothstep(0,.25,p))
	elif p<.75:
		var turn: float=smoothstep(.25,.75,p)
		normal=normal.rotated(Vector3.UP,q.turn*turn)
		point=q.corner+normal*q.radius-height
	else:
		normal=q.normal
		point=last.lerp(q.anchor,smoothstep(.75,1,p))
	return {"position":point,"normal":normal,"yaw":atan2(normal.x,normal.z)}

func hand(h: Node,q: Dictionary,hand_side: String,p: float) -> Dictionary:
	var leading: bool=(hand_side=="Right")== (q.side>0)
	var side_value: float=-.25 if hand_side=="Left" else .25
	var source_grip: Vector3=q.source_edge+Vector3(q.source_tangent)*side_value
	var pivot: Vector3=q.corner-Vector3(q.travel)*.02
	var destination_grip: Vector3=q.edge+Vector3(q.destination_tangent)*side_value
	var near_destination: Vector3=q.corner+Vector3(q.destination_travel)*.01
	var target: Vector3=source_grip.lerp(pivot,smoothstep(0,.25,p))
	var normal: Vector3=q.source_normal
	var weight: float=1
	if leading:
		weight=(1-smoothstep(.02,.15,p))+smoothstep(.56,.64,p)
		if p>=.32:
			target=near_destination.lerp(destination_grip,smoothstep(.65,1,p))
			normal=q.normal
	else:
		weight=1-smoothstep(.62,.74,p)+smoothstep(.82,.96,p)
		if p>=.76:
			target=near_destination.lerp(destination_grip,smoothstep(.76,1,p))
			normal=q.normal
	target+=Vector3.UP*(h.braced_hang_hand_vertical_offset-h.braced_hang_corner_grip_drop)+normal*h.braced_hang_hand_wall_offset
	return {"target":target,"weight":clampf(weight,0,1)}

func query(h: Node,side: int,validate_path: bool=true) -> Dictionary:
	var q: Dictionary={"valid":false,"found":false,"type":"NONE","reason":"NO_LOCAL_CORNER","path_clear":false,"hand_reach":false,"anchor_valid":false,"side":side,"angle":0.0}
	if not h.braced_hang_corners_enabled: q.reason="DISABLED"; return q
	if not is_instance_valid(h.source) or not h.source is StaticBody3D or h.source is AnimatableBody3D: q.reason="UNSUPPORTED_SOURCE"; return q
	var n: Vector3=h.wall_normal
	var t: Vector3=h.facing.cross(Vector3.UP).normalized()*side
	var low: float=0
	var high: float=0
	for i in range(1,ceili(h.braced_hang_corner_detection_distance/.025)+1):
		var d: float=minf(i*.025,h.braced_hang_corner_detection_distance)
		var point: Vector3=h.ledge_edge+t*d-Vector3.UP*.08
		var face: Dictionary=h.ray(point+n*.16,point-n*.16)
		if face.is_empty() or face.collider!=h.source or face.normal.dot(n)<.98:
			high=d
			break
		low=d
	if high==0: return q
	for i in 10:
		var mid: float=(low+high)*.5
		var point: Vector3=h.ledge_edge+t*mid-Vector3.UP*.08
		var face: Dictionary=h.ray(point+n*.16,point-n*.16)
		if not face.is_empty() and face.collider==h.source and face.normal.dot(n)>.98: low=mid
		else: high=mid
	var corner: Vector3=h.ledge_edge+t*((low+high)*.5)
	var point: Vector3=corner-n*.35-Vector3.UP*.08
	var face: Dictionary=h.ray(point+t*.55,point-t*.55)
	if face.is_empty() or face.collider!=h.source:
		point=corner+n*.35-Vector3.UP*.08
		face=h.ray(point-t*.55,point+t*.55)
		if not face.is_empty(): q.type="INSIDE"; q.found=true; q.reason="INSIDE_UNSUPPORTED"
		return q
	var dest_normal: Vector3=face.normal
	q.angle=rad_to_deg(acos(clampf(n.dot(dest_normal),-1,1)))
	q.found=true
	q.type="OUTSIDE" if dest_normal.dot(t)>.5 else "INSIDE"
	if q.type!="OUTSIDE": q.reason="INSIDE_UNSUPPORTED"; return q
	if absf(dest_normal.y)>.02 or q.angle<h.braced_hang_corner_angle_min or q.angle>h.braced_hang_corner_angle_max: q.reason="CORNER_ANGLE"; return q
	# Intersect the two face planes; do not infer an arc across disconnected space.
	var along: float=(Vector3(face.position)-h.ledge_edge).dot(dest_normal)/t.dot(dest_normal)
	if along<0 or along>h.braced_hang_corner_detection_distance: q.reason="NONLOCAL_CORNER"; return q
	corner=h.ledge_edge+t*along
	var turn: float=atan2(n.cross(dest_normal).y,n.dot(dest_normal))
	var dest_travel: Vector3=t.rotated(Vector3.UP,turn)
	var edge: Vector3=corner+dest_travel*h.braced_hang_corner_destination_inset
	var top: Dictionary=h.ray(edge-dest_normal*.04+Vector3.UP*.08,edge-dest_normal*.04-Vector3.UP*.08)
	if top.is_empty() or top.collider!=h.source or top.normal.dot(h.landing_plane_normal)<.98 or absf(top.position.y-corner.y)>h.lateral_height_tolerance: q.reason="DESTINATION_TOP"; return q
	edge.y=top.position.y
	var anchor: Vector3=edge+dest_normal*h.body_distance_from_wall-Vector3.UP*h.hang_vertical_offset
	var radius: float=maxf(h.braced_hang_corner_path_radius,h.motor.crouch.standing_capsule_radius+h.braced_hang_corner_clearance)
	q.merge({"corner":corner,"source":h.source,"transform":h.source.global_transform,"source_normal":n,"source_edge":h.ledge_edge,"source_tangent":h.facing.cross(Vector3.UP),"travel":t,"start":h.alignment,"normal":dest_normal,"edge":edge,"top":top.position,"top_normal":top.normal,"anchor":anchor,"turn":turn,"radius":radius,"destination_travel":dest_travel,"destination_tangent":(-dest_normal).cross(Vector3.UP)},true)
	# Check both faces right up to the shared vertex and the top across it.
	for amount in [.025,.08,.15]:
		for spec in [[corner-t*amount,n],[corner+dest_travel*amount,dest_normal]]:
			var wall: Dictionary=h.ray(spec[0]-Vector3.UP*.08+spec[1]*.08,spec[0]-Vector3.UP*.08-spec[1]*.08)
			var cap: Dictionary=h.ray(spec[0]-spec[1]*.04+Vector3.UP*.06,spec[0]-spec[1]*.04-Vector3.UP*.06)
			if wall.is_empty() or cap.is_empty() or wall.collider!=h.source or cap.collider!=h.source or wall.normal.dot(spec[1])<.98: q.reason="NOT_CONTIGUOUS"; return q
	if not h.validate_contacts(h.source,edge,top.position,dest_normal,top.normal): q.reason="DESTINATION_CONTACT"; return q
	var destination_check: Dictionary=h.lateral.curve.probe(h,edge,dest_normal)
	if not destination_check.valid: q.reason="DESTINATION_BRACE"; return q
	q.anchor_valid=true
	if not validate_path: q.reason="CORNER_FOUND"; return q
	if not poses.has(side): q.reason="POSE_NOT_READY"; return q
	var previous: Vector3=h.alignment
	q["path"]=[]
	q["max_reach_ratio"]=0.0
	q["max_correction"]=0.0
	for i in range(h.braced_hang_corner_path_samples+1):
		var p: float=float(i)/h.braced_hang_corner_path_samples
		var sample:=path(h,q,p)
		q.path.append(sample.position)
		if not h.clear_segment(previous,sample.position,h.motor.crouch.standing_capsule_height): q.reason="CORNER_PATH_BLOCKED"; return q
		previous=sample.position
	q.path_clear=true
	for i in range(h.braced_hang_corner_path_samples+1):
		var p: float=float(i)/h.braced_hang_corner_path_samples
		var sample:=path(h,q,p)
		var pose_index: int=clampi(roundi(p*64),0,64)
		for hand_side in ["Left","Right"]:
			var contact:=hand(h,q,hand_side,p)
			if contact.weight<.5: continue
			var pose: Dictionary=poses[side][pose_index][hand_side]
			var basis:=Basis(Vector3.UP,sample.yaw)
			var shoulder: Vector3=sample.position+basis*Vector3(pose.shoulder)
			var wrist: Vector3=sample.position+basis*Vector3(pose.wrist)
			var ratio: float=shoulder.distance_to(contact.target)/pose.reach
			var correction: float=wrist.distance_to(contact.target)
			q.max_reach_ratio=maxf(q.max_reach_ratio,ratio)
			q.max_correction=maxf(q.max_correction,correction)
			if ratio>h.braced_hang_corner_reach_ratio or correction>h.braced_hang_corner_hand_correction: q.reason="CORNER_HAND_REACH"; q["failed_progress"]=p; q["failed_hand"]=hand_side; q["shoulder"]=shoulder; q["target"]=contact.target; q["reach"]=pose.reach; return q
	q.valid=true; q.path_clear=true; q.hand_reach=true; q.reason="VALID"
	return q

func request(h: Node,side: int) -> bool:
	last_query=query(h,side)
	if not last_query.valid: return false
	committed=last_query.duplicate(true)
	source_grips.clear()
	for arm in h.motor.get_node("MantleHandIK").arms: source_grips[arm.side]=arm.solved
	settle_remaining=0
	state=&"HangCornerLeft" if side<0 else &"HangCornerRight"
	progress=0; elapsed=0; active=true
	expected_position=h.alignment
	h.hang_phase=h.HangPhase.CORNER
	return true

func advance(h: Node,delta: float) -> bool:
	if not is_instance_valid(committed.source) or committed.source.is_queued_for_deletion() or not committed.source.global_transform.is_equal_approx(committed.transform): h.owner_controller.finish("CORNER_SOURCE_LOST"); return false
	elapsed+=delta
	var playback=h.motor.get_node("AnimationController")._playback
	if playback.get_current_node()==state: progress=clampf(playback.get_current_play_position()/h.braced_hang_corner_duration,0,1)
	if elapsed>h.braced_hang_corner_duration+2: h.owner_controller.finish("CORNER_TIMEOUT"); return false
	if progress>=.995: progress=1
	var sample:=path(h,committed,progress)
	expected_position=sample.position
	h.motor.visual.rotation.y=sample.yaw
	h.wall_normal=sample.normal
	h.facing=-sample.normal
	return true

func complete(h: Node) -> void:
	if progress<1: return
	if not h.validate_contacts(committed.source,committed.edge,committed.top,committed.normal,committed.top_normal): h.owner_controller.finish("CORNER_DESTINATION_LOST"); return
	h.source=committed.source; h.source_transform=committed.transform
	h.ledge_edge=committed.edge; h.wall_point=committed.edge; h.top=committed.top
	h.wall_normal=committed.normal; h.facing=-committed.normal
	h.landing_plane_normal=committed.top_normal; h.alignment=committed.anchor
	h.motor.visual.rotation.y=atan2(h.wall_normal.x,h.wall_normal.z)
	active=false; settle_remaining=.30; h.hang_phase=h.HangPhase.IDLE
	h.navigation.targets.clear(); h.navigation.context_id=""; h.navigation.invalidate()
	h.lateral.idle_previews.clear(); h.vertical.preview_clock=0
	h.transfer.previews.clear(); h.transfer.candidate_sets.clear()
	h.climb_destination_valid=false
	h.navigation.refresh(h,0,true)

func hand_contact(h: Node,arm: Dictionary) -> Dictionary:
	var result:=hand(h,committed,arm.side,progress)
	result.target=Vector3(source_grips.get(arm.side,result.target)).lerp(result.target,smoothstep(0,.08,progress))
	return result
func foot_target() -> Dictionary:
	return {"edge":committed.source_edge,"normal":committed.source_normal,"source":committed.source} if progress<.5 else {"edge":committed.edge,"normal":committed.normal,"source":committed.source}
func foot_weight() -> float: return 1-smoothstep(.18,.40,progress) if progress<.5 else smoothstep(.68,.95,progress)
func debug_text() -> String:
	var q: Dictionary=committed if active else last_query
	return "\nCORNER %s / %s / %.1f deg / %s\nAnchor %s / Path %s / Hand reach %s\nNormals %s -> %s / progress %.2f\nCorner A/D: %s | Shift: NEVER CORNER"%["FOUND" if q.get("found",false) else "NONE",q.get("type","NONE"),q.get("angle",0),"CORNER_SHIMMY" if active else q.get("reason","NONE"),q.get("anchor_valid",false),q.get("path_clear",false),q.get("hand_reach",false),q.get("source_normal",Vector3.ZERO),q.get("normal",Vector3.ZERO),progress,"CORNER_SHIMMY" if q.get("valid",false) else "NONE"]
func draw(view: Node,h: Node) -> void:
	var q: Dictionary=committed if active else last_query
	if not q.has("corner"): return
	var color: Color=Color.GREEN if q.valid else (Color.ORANGE if q.get("reason","")=="CORNER_PATH_BLOCKED" else Color.RED)
	view.cross_at(q.corner,color,.15); view.cross_at(q.anchor,Color.CYAN,.1)
	view.arrow(q.source_edge,q.source_edge+q.source_normal,Color.YELLOW)
	view.arrow(q.edge,q.edge+q.normal,Color.CYAN)
	view.line(q.source_edge-q.source_tangent*.28,q.source_edge+q.source_tangent*.28,Color.YELLOW)
	view.line(q.edge-q.destination_tangent*.28,q.edge+q.destination_tangent*.28,Color.CYAN)
	for spec in [[q.source_edge,q.source_tangent],[q.edge,q.destination_tangent]]:
		view.line(spec[0]-spec[1]*.3,spec[0]-spec[1]*.3-Vector3.UP*1.5,Color.GRAY)
		view.line(spec[0]+spec[1]*.3,spec[0]+spec[1]*.3-Vector3.UP*1.5,Color.GRAY)
	var points: Array=q.get("path",[])
	for i in range(1,points.size()):
		view.line(points[i-1],points[i],color)
		if i%8==0:
			view.line(points[i],points[i]+Vector3.UP*h.motor.crouch.standing_capsule_height,color)
			for j in 12:
				var a: Vector3=Vector3(cos(j*TAU/12),0,sin(j*TAU/12))*h.motor.crouch.standing_capsule_radius
				var b: Vector3=Vector3(cos((j+1)*TAU/12),0,sin((j+1)*TAU/12))*h.motor.crouch.standing_capsule_radius
				view.line(points[i]+Vector3.UP*.9+a,points[i]+Vector3.UP*.9+b,color)
	for side in ["Left","Right"]:
		view.cross_at(hand(h,q,side,progress if active else .5).target,Color.ORANGE if side=="Left" else Color.MAGENTA,.08)
		view.cross_at(hand(h,q,side,1).target,Color.CYAN,.045)
