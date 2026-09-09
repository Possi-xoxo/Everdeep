extends RefCounted
## Lateral-hop fallback only. Static, near-coplanar ledges across a real gap.
var active: bool=false
var input_latched: bool=false
var origin: Dictionary={}
var destination: Dictionary={}
var candidates: Array[Dictionary]=[]
var previews: Dictionary={}
var candidate_sets: Dictionary={}
var continuous: Dictionary={}
var last_result: Dictionary={"valid":false,"reason":"NOT_QUERIED"}
var last_resolution: String="NONE"
var search_side: int=0

func path(h: Node,action: StringName,p: float,a: Dictionary,b: Dictionary) -> Vector3:
	var sample: Vector3=h.lateral.motion.sample(action,p)
	# Same unsigned lateral profile (including source overshoot), real endpoint
	# displacement, authored rise/retreat; height bias starts after departure.
	var point: Vector3=Vector3(a.anchor).lerp(b.anchor,sample.x)
	point.y=a.anchor.y+sample.y+(b.anchor.y-a.anchor.y)*smoothstep(.20,.94,p)
	return point+Vector3(a.normal).slerp(b.normal,smoothstep(.4,.95,p))*sample.z

func gap_width(h: Node,edge: Vector3) -> float:
	var delta: Vector3=edge-h.ledge_edge
	var distance: float=Vector2(delta.x,delta.z).length()
	var steps: int=maxi(1,ceili(distance/.025))
	var run: float=0
	var longest: float=0
	# Probe below BOTH tops. A step, collider seam or raised continuous wall
	# is not empty space and must not masquerade as a ledge transfer.
	for i in range(steps+1):
		var point: Vector3=h.ledge_edge.lerp(edge,float(i)/steps)
		point.y=minf(h.ledge_edge.y,edge.y)-.4
		var hit: Dictionary=h.ray(point+h.wall_normal*(h.braced_hang_transfer_forward_back_tolerance+.12),point-h.wall_normal*(h.braced_hang_transfer_forward_back_tolerance+.12))
		if hit.is_empty(): run+=distance/steps; longest=maxf(longest,run)
		else: run=0
	return maxf(0,longest-distance/steps)

func validate_target(h: Node,hit: Dictionary,side: int) -> Dictionary:
	var r: Dictionary={"valid":false,"reason":"INVALID_TOP","edge":hit.position,"path_clear":false}
	if hit.normal.y<.98 or not hit.collider is StaticBody3D or hit.collider is AnimatableBody3D: return r
	var edge: Vector3=hit.position
	var reach: float=h.braced_hang_transfer_forward_back_tolerance+.12
	var face: Dictionary=h.ray(edge-Vector3.UP*.08+h.wall_normal*reach,edge-Vector3.UP*.08-h.wall_normal*reach)
	if face.is_empty() or face.collider!=hit.collider: r.reason="NO_FACE"; return r
	var normal: Vector3=face.normal
	edge=Vector3(face.position.x,edge.y,face.position.z)
	var delta: Vector3=edge-h.ledge_edge
	var tangent: Vector3=h.facing.cross(Vector3.UP).normalized()*side
	var distance: float=delta.dot(tangent)
	var forward: float=absf(delta.dot(h.wall_normal))
	var normal_angle: float=rad_to_deg(acos(clampf(normal.dot(h.wall_normal),-1,1)))
	var angle: float=rad_to_deg(atan2(forward,maxf(.001,distance)))
	var scale: float=Vector2(delta.x,delta.z).length()/maxf(.01,h.lateral.travel_distance(h,side,true))
	r.merge({"edge":edge,"distance":distance,"vertical":delta.y,"forward":forward,"normal_angle":normal_angle,"angle":angle,"motion_scale":scale},true)
	if distance<.35 or Vector2(delta.x,delta.z).length()>h.braced_hang_transfer_max_horizontal_distance+.001: r.reason="DISTANCE"; return r
	if absf(delta.y)>h.braced_hang_transfer_max_vertical_difference+.001: r.reason="HEIGHT"; return r
	if forward>h.braced_hang_transfer_forward_back_tolerance+.001 or angle>h.braced_hang_transfer_facing_tolerance: r.reason="NOT_LATERAL"; return r
	if normal_angle>h.braced_hang_transfer_wall_normal_tolerance: r.reason="WALL_ANGLE_OR_CORNER"; return r
	if scale>h.braced_hang_transfer_max_motion_scale: r.reason="MOTION_SCALE"; return r
	if not h.validate_contacts(hit.collider,edge,hit.position,normal,hit.normal): r.reason="HAND_SPAN_OR_BRACE"; return r
	# Also require continuous local wall support under both hands, as the
	# existing lateral validator does; this is not a weaker remote hang type.
	for offset in [-.28,0.0,.28]:
		for depth in [.35,.8,1.15,1.5]:
			var point: Vector3=edge+(-normal).cross(Vector3.UP)*offset-Vector3.UP*depth
			var brace: Dictionary=h.ray(point+normal*.12,point-normal*h.lateral_brace_recess)
			if brace.is_empty() or brace.collider!=hit.collider or brace.normal.dot(normal)<.98: r.reason="NO_CONTINUOUS_BRACE"; return r
	var anchor: Vector3=edge+normal*h.body_distance_from_wall-Vector3.UP*h.hang_vertical_offset
	if not h.clear_segment(anchor,anchor,h.motor.crouch.standing_capsule_height): r.reason="ANCHOR_BLOCKED"; return r
	r.merge({"valid":true,"reason":"TARGET_VALID","source":hit.collider,"transform":hit.collider.global_transform,"top":hit.position,"top_normal":hit.normal,"normal":normal,"facing":-normal,"anchor":anchor},true)
	return r

func query(h: Node,side: int) -> Dictionary:
	candidates.clear()
	var failure: Dictionary={"valid":false,"reason":"NO_REMOTE_LEDGE","path_clear":false}
	if not is_instance_valid(h.source) or not h.source is StaticBody3D or h.source is AnimatableBody3D: return failure
	var tangent: Vector3=h.facing.cross(Vector3.UP).normalized()*side
	var seen: Dictionary={}
	var limit: float=h.braced_hang_transfer_max_horizontal_distance
	var height: float=h.braced_hang_transfer_max_vertical_difference
	for step in range(4,ceili(limit/.1)+1):
		var distance: float=minf(step*.1,limit)
		for depth in [0.0,-h.braced_hang_transfer_forward_back_tolerance,h.braced_hang_transfer_forward_back_tolerance]:
			var point: Vector3=h.ledge_edge+tangent*distance+h.wall_normal*(depth-.04)
			var hit: Dictionary=h.ray(point+Vector3.UP*(height+.06),point-Vector3.UP*(height+.06))
			if hit.is_empty(): continue
			var candidate:=validate_target(h,hit,side)
			candidate["source_candidate"]=hit.collider==h.source
			var key: String="%s/%s" % [hit.collider.get_instance_id(),Vector3(candidate.edge).snapped(Vector3.ONE*.05)]
			if seen.has(key): continue
			seen[key]=true
			candidates.append(candidate)
	candidate_sets[side]=candidates.duplicate()
	# Search nearest ledge first. Within a .1m band prefer lateral alignment,
	# then smallest height delta. Never skip a reachable near ledge for a far one.
	candidates.sort_custom(func(a: Dictionary,b: Dictionary) -> bool:
		var band_a: int=roundi(float(a.get("distance",1000000))*10)
		var band_b: int=roundi(float(b.get("distance",1000000))*10)
		if band_a!=band_b: return band_a<band_b
		if not is_equal_approx(a.get("forward",0.0),b.get("forward",0.0)): return a.get("forward",0.0)<b.get("forward",0.0)
		return absf(a.get("vertical",0.0))<absf(b.get("vertical",0.0)))
	var action: StringName=&"HangHopLeft" if side<0 else &"HangHopRight"
	var start: Dictionary=h.vertical.snapshot(h)
	for candidate in candidates:
		if not candidate.valid:
			failure=prefer_failure(failure,candidate)
			continue
		candidate["gap"]=gap_width(h,candidate.edge)
		if candidate.gap<h.braced_hang_transfer_min_gap:
			candidate.valid=false; candidate.reason="NO_REAL_GAP"; failure=prefer_failure(failure,candidate); continue
		var previous: Vector3=start.anchor
		var samples: Array[Vector3]=[previous]
		for i in range(1,h.lateral.motion.SAMPLE_COUNT+1):
			var next: Vector3=path(h,action,float(i)/h.lateral.motion.SAMPLE_COUNT,start,candidate)
			samples.append(next)
			if not h.clear_segment(previous,next,h.motor.crouch.standing_capsule_height):
				candidate.valid=false; candidate.reason="TRANSFER_ARC_BLOCKED"; break
			previous=next
		candidate["path"]=samples
		candidate.path_clear=candidate.valid
		if candidate.valid:
			candidate.reason="ACCEPT"
			last_result=candidate
			previews[side]=candidate
			return candidate
		failure=prefer_failure(failure,candidate)
	last_result=failure
	previews[side]=failure
	return failure

func prefer_failure(previous: Dictionary,next: Dictionary) -> Dictionary:
	# Keep the most useful rejection, not the last far-away scan ray.
	var score:=func(r: Dictionary) -> int:
		if r.has("path"): return 4
		if r.get("source_candidate",false): return -1
		if r.reason in ["HAND_SPAN_OR_BRACE","NO_CONTINUOUS_BRACE","ANCHOR_BLOCKED"]: return 3
		if r.reason in ["NO_REMOTE_LEDGE","NO_REAL_GAP"]: return 0
		return 1
	return next if score.call(next)>score.call(previous) else previous

func request(h: Node,side: int) -> bool:
	if input_latched or not h.is_attached() or h.hang_phase!=h.HangPhase.IDLE: return false
	search_side=side
	# A failed discrete attempt also stays a no-op until release/reinput.
	input_latched=true
	var target:=query(h,side)
	last_resolution="GAP_TRANSFER" if target.valid else "NONE"
	if not target.valid: return false
	origin=h.vertical.snapshot(h)
	destination=target.duplicate(true)
	active=true
	var lateral=h.lateral
	lateral.active=true
	lateral.hopping=true
	lateral.direction=side
	lateral.state=&"HangHopLeft" if side<0 else &"HangHopRight"
	lateral.progress=0
	lateral.elapsed=0
	lateral.start=h.alignment
	lateral.displacement=Vector3(target.anchor)-h.alignment
	lateral.expected_position=h.alignment
	h.hang_phase=h.HangPhase.LATERAL
	return true

func advance(h: Node,delta: float) -> bool:
	for target in [origin,destination]:
		if not is_instance_valid(target.source) or target.source.is_queued_for_deletion() or not target.source.global_transform.is_equal_approx(target.transform):
			h.owner_controller.finish("TRANSFER_SOURCE_LOST"); return false
	var lateral=h.lateral
	lateral.elapsed+=delta
	var playback=h.motor.get_node("AnimationController")._playback
	if playback.get_current_node()==lateral.state: lateral.progress=clampf(playback.get_current_play_position()/float(lateral.lengths[lateral.state]),0,1)
	if lateral.elapsed>float(lateral.lengths[lateral.state])+2: h.owner_controller.finish("TRANSFER_TIMEOUT"); return false
	if lateral.progress>=.995: lateral.progress=1
	lateral.expected_position=path(h,lateral.state,lateral.progress,origin,destination)
	if not h.clear_segment(h.motor.global_position,lateral.expected_position,h.motor.crouch.standing_capsule_height): h.owner_controller.finish("TRANSFER_BLOCKED"); return false
	var facing: Vector3=Vector3(origin.facing).slerp(destination.facing,smoothstep(.4,.95,lateral.progress))
	h.motor.visual.rotation.y=atan2(-facing.x,-facing.z)
	return true

func complete(h: Node) -> void:
	if h.lateral.progress<1: return
	if not h.validate_contacts(destination.source,destination.edge,destination.top,destination.normal,destination.top_normal):
		h.owner_controller.finish("TRANSFER_DESTINATION_LOST")
		return
	# Atomic context switch only after actual collision-checked arrival.
	h.source=destination.source
	h.source_transform=destination.transform
	h.wall_point=destination.edge
	h.ledge_edge=destination.edge
	h.top=destination.top
	h.wall_normal=destination.normal
	h.landing_plane_normal=destination.top_normal
	h.facing=destination.facing
	h.alignment=destination.anchor
	h.motor.visual.rotation.y=atan2(-h.facing.x,-h.facing.z)
	h.hang_phase=h.HangPhase.IDLE
	h.lateral.active=false
	active=false
	h.navigation.invalidate()
	h.vertical.preview_clock=0

func contact_target(h: Node) -> Dictionary: return origin if h.lateral.progress<.5 else destination

func contact_weight(h: Node,foot: bool=false) -> float:
	var p: float=h.lateral.progress
	var arrival: float=h.braced_hang_transfer_foot_arrival if foot else h.braced_hang_transfer_hand_arrival
	var full: float=.98 if foot else .94
	return 1-smoothstep(.08,.25,p)*(1-smoothstep(arrival,full,p))

func hand_contact(h: Node,arm: Dictionary) -> Dictionary:
	var target:=contact_target(h)
	var tangent: Vector3=Vector3(target.facing).cross(Vector3.UP)
	var spacing: float=-.28 if arm.side=="Left" else .25
	return {"target":Vector3(target.edge)+tangent*spacing+Vector3.UP*h.braced_hang_hand_vertical_offset+Vector3(target.normal)*h.braced_hang_hand_wall_offset,"weight":contact_weight(h)}

func debug_text() -> String:
	var text: String="\nGAP requested %s / %s / input latch %s" % [("LEFT" if search_side<0 else "RIGHT") if search_side!=0 else "NONE",last_resolution,input_latched]
	for side in [-1,1]:
		var data: Dictionary=destination if active and search_side==side else previews.get(side,{})
		var found: bool=data.get("valid",false)
		var normal_hop: bool=continuous.get(side,false)
		text+="\nShift+%s: %s / continuous %s / remote %s %s\nDistance %.2f / dy %.2f / normal %.1f / angle %.1f / gap %.2f / scale %.2f / path %s" % ["A" if side<0 else "D","CONTINUOUS_HOP" if normal_hop else ("GAP_TRANSFER" if found else "NONE"),normal_hop,found,data.get("reason","NOT_QUERIED"),data.get("distance",0.0),data.get("vertical",0.0),data.get("normal_angle",0.0),data.get("angle",0.0),data.get("gap",0.0),data.get("motion_scale",0.0),data.get("path_clear",false)]
	return text

func draw(view: Node,h: Node) -> void:
	var tangent: Vector3=h.facing.cross(Vector3.UP)
	view.arrow(h.alignment,h.alignment+tangent*.7,Color.CYAN)
	for side in [-1,1]:
		for y in [-1,1]:
			for z in [-1,1]:
				var a: Vector3=h.ledge_edge+Vector3.UP*y*h.braced_hang_transfer_max_vertical_difference+h.wall_normal*z*h.braced_hang_transfer_forward_back_tolerance
				var b: Vector3=a+tangent*side*h.braced_hang_transfer_max_horizontal_distance
				view.line(a,b,Color.PURPLE)
	for distance in [-h.braced_hang_transfer_max_horizontal_distance,0.0,h.braced_hang_transfer_max_horizontal_distance]:
		var center: Vector3=h.ledge_edge+tangent*distance
		var up: Vector3=Vector3.UP*h.braced_hang_transfer_max_vertical_difference
		var depth: Vector3=h.wall_normal*h.braced_hang_transfer_forward_back_tolerance
		view.line(center-up-depth,center+up-depth,Color.PURPLE)
		view.line(center-up+depth,center+up+depth,Color.PURPLE)
		view.line(center-up-depth,center-up+depth,Color.PURPLE)
		view.line(center+up-depth,center+up+depth,Color.PURPLE)
	view.cross_at(h.alignment,Color.YELLOW,.10)
	for entries in candidate_sets.values():
		for candidate in entries: view.cross_at(candidate.edge,Color.GREEN if candidate.valid else Color.RED,.03)
	var data: Dictionary=destination if active else last_result
	if data.has("anchor"): view.cross_at(data.anchor,Color.MAGENTA,.13)
	var points: Array=data.get("path",[])
	for i in range(1,points.size()): view.line(points[i-1],points[i],Color.MAGENTA if data.get("path_clear",false) else Color.RED)
	# Capsule-sized corridor rings at representative samples; red marks the
	# exact failing swept segment, rather than just an invalid endpoint.
	var radius: float=h.motor.get_node("CollisionShape3D").shape.radius
	var height: float=h.motor.crouch.standing_capsule_height
	for i in range(0,points.size(),12):
		for y in [radius,height-radius]:
			for k in 12:
				var a: float=TAU*k/12.0
				var b: float=TAU*(k+1)/12.0
				view.line(points[i]+Vector3(cos(a)*radius,y,sin(a)*radius),points[i]+Vector3(cos(b)*radius,y,sin(b)*radius),Color(.5,.25,.8,.5))
	if not data.get("path_clear",false) and points.size()>1: view.arrow(points[-2],points[-1],Color.RED)
