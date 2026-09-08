extends RefCounted
## Static, compatible-wall vertical transfers. Acquisition/lateral queries stay separate.
const CLIPS={"HangHopUp":&"TRV_BRACED_HANG_HOP_UP","HangHopDown":&"TRV_BRACED_HANG_HOP_DOWN"}
const SAMPLES: int=120
var profiles: Dictionary={}
var lengths: Dictionary={}
var measurements: Dictionary={}
var upper: Dictionary={"valid":false,"reason":"NONE"}
var lower: Dictionary={"valid":false,"reason":"NONE"}
var candidates: Array[Dictionary]=[]
var active: bool=false
var state: StringName=&"HangHopUp"
var progress: float=0
var elapsed: float=0
var preview_clock: float=0
var origin: Dictionary={}
var destination: Dictionary={}
var expected_position:=Vector3.ZERO
var last_resolution: String="NONE"

func snapshot(h: Node) -> Dictionary:
	return {"valid":true,"source":h.source,"transform":h.source_transform,"edge":h.ledge_edge,"top":h.top,"normal":h.wall_normal,"top_normal":h.landing_plane_normal,"anchor":h.alignment,"facing":h.facing}

func prepare(h: Node,player: AnimationPlayer,reference: Vector3,idle_z: float) -> void:
	for name in CLIPS:
		var clip: Animation=player.get_animation(CLIPS[name])
		var track: int=h.hip_track(clip)
		assert(track>=0,"Vertical hop requires hip translation")
		var first: Vector3=clip.position_track_interpolate(track,0)
		var last: Vector3=clip.position_track_interpolate(track,clip.length)
		var travel: Vector3=(last-first)/100.0
		assert(absf(travel.z)>.1,"Vertical hop requires authored vertical travel")
		var points: Array[Vector3]=[]
		for i in range(SAMPLES+1):
			var p: float=float(i)/SAMPLES
			var delta: Vector3=(clip.position_track_interpolate(track,p*clip.length)-first)/100.0
			# Imported rig uses -Z as world up, -Y as outward wall motion.
			# Remove endpoint drift only from the two secondary axes.
			points.append(Vector3(delta.z/travel.z,delta.x-travel.x*p,maxf(0,-(delta.y-travel.y*p))))
		points[0]=Vector3.ZERO
		points[SAMPLES]=Vector3(1,0,0)
		profiles[StringName(name)]=points
		lengths[StringName(name)]=clip.length
		measurements[name]={"duration":clip.length,"root_delta_m":travel}
		clip.loop_mode=Animation.LOOP_NONE
		for key in clip.track_get_key_count(track): clip.track_set_key_value(track,key,Vector3(reference.x,reference.y,idle_z))

func sample(action: StringName,p: float) -> Vector3:
	var index: float=clampf(p,0,1)*SAMPLES
	var low: int=mini(int(index),SAMPLES-1)
	return Vector3(profiles[action][low]).lerp(profiles[action][low+1],index-low)

func path(action: StringName,p: float,start: Dictionary,finish: Dictionary) -> Vector3:
	var value:=sample(action,p)
	var tangent: Vector3=start.facing.cross(Vector3.UP)
	return Vector3(start.anchor).lerp(finish.anchor,value.x)+tangent*value.y+Vector3(start.normal)*value.z

func clear(h: Node,a: Vector3,b: Vector3) -> bool:
	var shape:=CapsuleShape3D.new()
	shape.radius=h.motor.crouch.standing_capsule_radius
	shape.height=h.motor.crouch.standing_capsule_height
	var q:=PhysicsShapeQueryParameters3D.new()
	q.shape=shape
	q.collision_mask=h.motor.collision_mask
	q.exclude=[h.motor.get_rid()]
	q.margin=h.vertical_clearance_margin
	q.transform=Transform3D(Basis.IDENTITY,a+Vector3.UP*(shape.height*.5+.004))
	var space: PhysicsDirectSpaceState3D=h.motor.get_world_3d().direct_space_state
	if not space.intersect_shape(q,1).is_empty(): return false
	q.motion=b-a
	var sweep:=space.cast_motion(q)
	if sweep.size()!=2 or sweep[0]<.999: return false
	q.motion=Vector3.ZERO
	q.transform.origin=b+Vector3.UP*(shape.height*.5+.004)
	return space.intersect_shape(q,1).is_empty()

func validate(h: Node,hit: Dictionary,side: int) -> Dictionary:
	var edge: Vector3=hit.position
	var result: Dictionary={"valid":false,"reason":"INVALID_TOP","edge":edge}
	if hit.normal.dot(Vector3.UP)<.98 or not hit.collider is StaticBody3D or hit.collider is AnimatableBody3D: return result
	var wall: Dictionary=h.ray(edge+Vector3.UP*-.08+h.wall_normal*.4,edge+Vector3.UP*-.08-h.wall_normal*.4)
	if wall.is_empty() or wall.collider!=hit.collider: result.reason="NO_FACE"; return result
	var n: Vector3=wall.normal
	if n.dot(h.wall_normal)<cos(deg_to_rad(h.vertical_angle_tolerance)): result.reason="WALL_ANGLE"; return result
	edge.x=wall.position.x
	edge.z=wall.position.z
	var delta: Vector3=edge-h.ledge_edge
	var tangent: Vector3=h.facing.cross(Vector3.UP)
	var height: float=delta.y*side
	var limit: float=h.vertical_up_range if side>0 else h.vertical_down_range
	if height<h.vertical_min_separation-.005 or height>limit+.005: result.reason="RANGE"; return result
	if absf(delta.dot(tangent))>h.vertical_horizontal_tolerance+.005 or absf(delta.dot(h.wall_normal))>h.vertical_wall_tolerance+.005: result.reason="WALL_OFFSET"; return result
	var facing: Vector3=-n
	for offset in [-.28,0.0,.28]:
		var hand: Vector3=edge+facing.cross(Vector3.UP)*offset+facing*.04
		var top_hit: Dictionary=h.ray(hand+Vector3.UP*.05,hand-Vector3.UP*.05)
		if top_hit.is_empty() or top_hit.collider!=hit.collider or top_hit.normal.dot(Vector3.UP)<.98: result.reason="HAND_WIDTH"; return result
		for depth in [.35,.8,1.15,1.5]:
			var brace: Vector3=edge+facing.cross(Vector3.UP)*offset-Vector3.UP*depth
			var brace_hit: Dictionary=h.ray(brace+n*.12,brace-n*.12)
			if brace_hit.is_empty() or brace_hit.collider!=hit.collider or brace_hit.normal.dot(n)<.98: result.reason="NO_BRACE"; return result
	var anchor: Vector3=edge+n*h.body_distance_from_wall-Vector3.UP*h.hang_vertical_offset
	result.merge({"source":hit.collider,"transform":hit.collider.global_transform,"edge":edge,"top":hit.position,"normal":n,"top_normal":hit.normal,"anchor":anchor,"facing":facing,"vertical":delta.y,"horizontal":absf(delta.dot(tangent)),"distance":anchor.distance_to(h.alignment)},true)
	# Compatible static pieces are allowed, but not an unsupported transfer
	# across a gap to an unrelated wall. Confirm the intervening wall band.
	for i in range(1,ceili(absf(delta.y)/.08)):
		var p: float=float(i)/ceili(absf(delta.y)/.08)
		var point: Vector3=Vector3(h.ledge_edge).lerp(edge,p)-Vector3.UP*.12
		var bridge: Dictionary=h.ray(point+h.wall_normal*.25,point-h.wall_normal*.25)
		if bridge.is_empty() or not (bridge.collider==h.source or bridge.collider==hit.collider) or bridge.normal.dot(n)<cos(deg_to_rad(h.vertical_angle_tolerance)):
			result.reason="NO_COMPATIBLE_WALL_CONTINUITY"
			return result
	if not clear(h,anchor,anchor): result.reason="ANCHOR_BLOCKED"; return result
	result.valid=true
	result.reason="VALID"
	return result

func query(h: Node,side: int) -> Dictionary:
	var best: Dictionary={"valid":false,"reason":"NO_LEDGE"}
	var valid_candidates: Array[Dictionary]=[]
	var seen: Array[Vector3]=[]
	var limit: float=h.vertical_up_range if side>0 else h.vertical_down_range
	var tangent: Vector3=h.facing.cross(Vector3.UP)
	# Short descending rays enumerate tops rather than hiding lower shelves
	# behind the first top encountered by one long downward ray.
	for lateral in [0.0,-h.vertical_horizontal_tolerance*.5,h.vertical_horizontal_tolerance*.5,-h.vertical_horizontal_tolerance,h.vertical_horizontal_tolerance]:
		for depth in [0.0,-h.vertical_wall_tolerance*.5,h.vertical_wall_tolerance*.5,-h.vertical_wall_tolerance,h.vertical_wall_tolerance]:
			for i in range(ceili((limit-h.vertical_min_separation)/.05)+1):
				var height: float=minf(limit,h.vertical_min_separation+i*.05)
				var probe: Vector3=h.ledge_edge+Vector3.UP*height*side+tangent*lateral+h.wall_normal*depth+h.facing*.04
				var hit: Dictionary=h.ray(probe+Vector3.UP*.03,probe-Vector3.UP*.03)
				if hit.is_empty(): continue
				var duplicate: bool=false
				for previous in seen:
					if previous.distance_to(hit.position)<.04: duplicate=true; break
				if duplicate: continue
				seen.append(hit.position)
				var candidate:=validate(h,hit,side)
				candidate["side"]=side
				candidates.append(candidate)
				if candidate.valid: valid_candidates.append(candidate)
				elif not best.valid: best=candidate
	valid_candidates.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return absf(a.vertical)+a.horizontal*.25 < absf(b.vertical)+b.horizontal*.25)
	var action: StringName=&"HangHopUp" if side>0 else &"HangHopDown"
	var start:=snapshot(h)
	for candidate in valid_candidates:
		var previous: Vector3=h.alignment
		var safe: bool=true
		for i in range(1,SAMPLES+1):
			var point:=path(action,float(i)/SAMPLES,start,candidate)
			if not clear(h,previous,point): safe=false; break
			previous=point
		if safe: return candidate
		candidate.valid=false
		candidate.reason="PATH_BLOCKED"
		best=candidate
	return best

func refresh(h: Node,delta: float=0,force: bool=false) -> void:
	if active or h.hang_phase!=h.HangPhase.IDLE: return
	preview_clock-=delta
	if not force and preview_clock>0: return
	preview_clock=.2
	candidates.clear()
	upper=query(h,1)
	lower=query(h,-1)
	h.check_pull_up()

func resolve(h: Node,side: int) -> bool:
	if not h.is_attached() or h.hang_phase!=h.HangPhase.IDLE or h.navigation.interacting: return false
	refresh(h,0,true)
	var target: Dictionary=upper if side>0 else lower
	if target.valid:
		origin=snapshot(h)
		destination=target.duplicate()
		state=&"HangHopUp" if side>0 else &"HangHopDown"
		last_resolution="W → HOP_UP" if side>0 else "S → HOP_DOWN"
		progress=0
		elapsed=0
		expected_position=h.alignment
		active=true
		h.hang_phase=h.HangPhase.VERTICAL
		return true
	if side>0:
		var accepted: bool=h.request_up()
		last_resolution="W → TO_CROUCH" if accepted else "W → NONE"
		return accepted
	h.navigation.safe_ground=h.navigation.release_query(h)
	if h.navigation.safe_ground.valid:
		last_resolution="S → RELEASE"
		return h.request_release()
	last_resolution="S → NONE (unsafe drop)"
	return false

func advance(h: Node,delta: float) -> bool:
	elapsed+=delta
	for target in [origin,destination]:
		if not is_instance_valid(target.source) or target.source.is_queued_for_deletion() or not target.source.global_transform.is_equal_approx(target.transform):
			h.owner_controller.finish("VERTICAL_SOURCE_LOST")
			return false
	var playback=h.motor.get_node("AnimationController")._playback
	if playback.get_current_node()==state: progress=clampf(playback.get_current_play_position()*h.braced_hang_vertical_playback_speed/float(lengths[state]),0,1)
	if elapsed>float(lengths[state])/h.braced_hang_vertical_playback_speed+2: h.owner_controller.finish("VERTICAL_TIMEOUT"); return false
	if progress>=.995: progress=1
	expected_position=path(state,progress,origin,destination)
	if not clear(h,h.motor.global_position,expected_position): h.owner_controller.finish("VERTICAL_BLOCKED"); return false
	return true

func complete(h: Node) -> void:
	if progress<1: return
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
	active=false
	preview_clock=0
	h.navigation.invalidate()

func contact_weight() -> float:
	return 1.0-smoothstep(.05,.25,progress)*(1.0-smoothstep(.72,.95,progress))

func contact_target() -> Dictionary:
	return origin if progress<.5 else destination

func hand_contact(h: Node,arm: Dictionary) -> Dictionary:
	var target:=contact_target()
	var tangent: Vector3=target.facing.cross(Vector3.UP)
	var spacing: float=-.25 if arm.side=="Left" else .25
	return {"target":Vector3(target.edge)+tangent*spacing+Vector3.UP*h.braced_hang_hand_vertical_offset+Vector3(target.normal)*h.braced_hang_hand_wall_offset,"weight":contact_weight()}

func debug_text(h: Node) -> String:
	var text: String="\nVERTICAL: %s / Last %s" % [str(state) if active else "IDLE",last_resolution]
	for pair in [["Upper",upper],["Lower",lower]]:
		var target: Dictionary=pair[1]
		text+="\n%s: %s / %s / d %.2f y %.2f x %.2f" % [pair[0],"FOUND" if target.valid else "NONE",target.reason,target.get("distance",0),target.get("vertical",0),target.get("horizontal",0)]
	text+="\nTop: %s | W → %s | S → %s" % [h.climb_destination_valid,"HOP_UP" if upper.valid else ("TO_CROUCH" if h.climb_destination_valid else "NONE"),"HOP_DOWN" if lower.valid else ("RELEASE" if h.navigation.safe_ground.valid else "NONE")]
	return text

func draw(view: Node,h: Node) -> void:
	view.cross_at(h.alignment,Color.WHITE,.12)
	var tangent: Vector3=h.facing.cross(Vector3.UP)
	for side in [1,-1]:
		var color: Color=Color.CYAN if side>0 else Color.ORANGE
		var limit: float=h.vertical_up_range if side>0 else h.vertical_down_range
		for x in [-1,1]:
			for z in [-1,1]:
				var offset: Vector3=tangent*x*h.vertical_horizontal_tolerance+h.wall_normal*z*h.vertical_wall_tolerance
				var a: Vector3=h.ledge_edge+offset+Vector3.UP*side*h.vertical_min_separation
				var b: Vector3=h.ledge_edge+offset+Vector3.UP*side*limit
				view.line(a,b,color)
				for y in [h.vertical_min_separation,limit]:
					var point: Vector3=h.ledge_edge+offset+Vector3.UP*side*y
					view.line(point,point-tangent*2*x*h.vertical_horizontal_tolerance,color)
					view.line(point,point-h.wall_normal*2*z*h.vertical_wall_tolerance,color)
		var target: Dictionary=upper if side>0 else lower
		if target.valid:
			view.cross_at(target.edge,Color.GREEN,.12)
			view.cross_at(target.anchor,color,.15)
			var start: Dictionary=origin if active else snapshot(h)
			var action: StringName=&"HangHopUp" if side>0 else &"HangHopDown"
			for i in 32: view.line(path(action,float(i)/32,start,target),path(action,float(i+1)/32,start,target),color)
	for candidate in candidates:
		view.cross_at(candidate.edge,Color.GREEN_YELLOW if candidate.valid else Color.RED,.045)
