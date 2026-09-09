extends RefCounted
## Contextual Jump destination, committed motion and private presentation only.
const CLIP: StringName=&"HangOutward_Runtime"
const STATE: StringName=&"HangOutward"
const COUNT: int=240
var active: bool=false
var origin: Dictionary={}
var destination: Dictionary={}
var candidates: Array[Dictionary]=[]
var last_result: Dictionary={"valid":false,"reason":"NOT_QUERIED"}
var decision: String="NONE"
var direction:=Vector3.ZERO
var input_bias: float=0
var preview_side: float=0
var profile: Array[Vector3]=[]
var source_turn: Array[float]=[]
var duration: float=0
var flight_duration: float=0
var playback_duration: float=0
var playback_time: float=0
var authored_distance: float=0
var progress: float=0
var elapsed: float=0
var expected_position:=Vector3.ZERO

func prepare(h: Node,player: AnimationPlayer,reference: Vector3,idle_z: float) -> void:
	var source: Animation=player.get_animation(h.navigation.JUMP_CLIP)
	profile.clear()
	source_turn.clear()
	# Independent copy of the full prepared drop clip: never mutate that alias
	# or the short automatic-catch clip. Skip its grounded takeoff/turn section.
	var catch_clip: Animation=player.get_animation(&"HangTopEntry_Full").duplicate(true)
	var clip: Animation=source.duplicate(true)
	duration=source.length
	flight_duration=duration/h.outward_playback_speed
	var catch_start: float=h.outward_catch_start_frame/30.0
	var overlap_start: float=(duration-h.outward_pose_arrival_blend_time)/h.outward_playback_speed
	playback_duration=overlap_start+(catch_clip.length-catch_start)/h.outward_catch_playback_speed
	var hip: int=h.hip_track(source)
	var first: Vector3=source.position_track_interpolate(hip,0)
	var last: Vector3=(source.position_track_interpolate(hip,duration)-first)/100.0
	authored_distance=absf(last.y)
	var hip_rotation: int=source.find_track(source.track_get_path(hip),Animation.TYPE_ROTATION_3D)
	var yaw_start: float=0
	var previous_yaw: float=0
	var accumulated_yaw: float=0
	for i in range(COUNT+1):
		var p: float=float(i)/COUNT
		var delta: Vector3=(source.position_track_interpolate(hip,duration*p)-first)/100.0
		var x: float=clampf(-delta.y/maxf(.01,authored_distance),0,1)
		# Preserve authored acceleration; soften only the final approach speed.
		if x>.7:
			var u: float=(x-.7)/.3
			x=.7+.3*(u+u*u-u*u*u)
		profile.append(Vector3(x,-delta.z+last.z*smoothstep(.25,1,p),0))
		var q: Quaternion=source.rotation_track_interpolate(hip_rotation,duration*p)
		var axis: Vector3=Basis(q).x
		var yaw: float=atan2(axis.y,axis.x)
		if i==0: yaw_start=yaw; previous_yaw=yaw
		accumulated_yaw+=wrapf(yaw-previous_yaw,-PI,PI)
		source_turn.append(accumulated_yaw)
		previous_yaw=yaw
	profile[0]=Vector3.ZERO
	profile[COUNT]=Vector3(1,0,0)
	# Extract yaw only to transfer it to the visual root without retiming or
	# mirroring the authored jump. The final short catch is the only pose edit.
	for track in clip.get_track_count():
		var type: int=clip.track_get_type(track)
		if type not in [Animation.TYPE_POSITION_3D,Animation.TYPE_ROTATION_3D,Animation.TYPE_SCALE_3D]: continue
		var idle_track: int=catch_clip.find_track(clip.track_get_path(track),type)
		var values: Array=[]
		# Retain source key times as well as the dense catch samples, so the
		# original frame poses do not drift from resampling between source keys.
		var times: Array[float]=[]
		for key in source.track_get_key_count(track): times.append(source.track_get_key_time(track,key)/h.outward_playback_speed)
		if idle_track>=0:
			for key in catch_clip.track_get_key_count(idle_track):
				var mapped: float=overlap_start+(catch_clip.track_get_key_time(idle_track,key)-catch_start)/h.outward_catch_playback_speed
				if mapped>=overlap_start and mapped not in times: times.append(mapped)
		for i in range(COUNT+1):
			var time: float=playback_duration*i/COUNT
			if time not in times: times.append(time)
		times.sort()
		for runtime in times:
			var time: float=minf(runtime*h.outward_playback_speed,duration)
			var catch_time: float=clampf(catch_start+(runtime-overlap_start)*h.outward_catch_playback_speed,catch_start,catch_clip.length)
			var p: float=time/duration
			var blend: float=arrival_weight(h,p)
			if type==Animation.TYPE_ROTATION_3D:
				var q: Quaternion=source.rotation_track_interpolate(track,time)
				if track==hip_rotation:
					var axis: Vector3=Basis(q).x
					q=Quaternion(Vector3.BACK,-wrapf(atan2(axis.y,axis.x)-yaw_start,-PI,PI))*q
				if idle_track>=0: q=q.slerp(catch_clip.rotation_track_interpolate(idle_track,catch_time),blend)
				values.append(q)
			elif type==Animation.TYPE_POSITION_3D:
				var value: Vector3=source.position_track_interpolate(track,time)
				if track==hip: value=Vector3(reference.x,reference.y,idle_z)
				elif idle_track>=0: value=value.lerp(catch_clip.position_track_interpolate(idle_track,catch_time),blend)
				values.append(value)
			else:
				var value: Vector3=source.scale_track_interpolate(track,time)
				if idle_track>=0: value=value.lerp(catch_clip.scale_track_interpolate(idle_track,catch_time),blend)
				values.append(value)
		for key in range(clip.track_get_key_count(track)-1,-1,-1): clip.track_remove_key(track,key)
		for i in values.size(): clip.track_insert_key(track,times[i],values[i])
	clip.loop_mode=Animation.LOOP_NONE
	clip.length=playback_duration
	player.get_animation_library(&"").add_animation(CLIP,clip)

func sample(p: float) -> Vector3:
	var index: float=clampf(p,0,1)*COUNT
	var low: int=mini(int(index),COUNT-1)
	return profile[low].lerp(profile[low+1],index-low)

func path(p: float,a: Dictionary,b: Dictionary) -> Vector3:
	var value:=sample(p)
	var point: Vector3=Vector3(a.anchor).lerp(b.anchor,value.x)
	point.y=a.anchor.y+value.y+(b.anchor.y-a.anchor.y)*smoothstep(.25,1,p)
	return point

func arrival_weight(h: Node,p: float) -> float:
	return smoothstep(maxf(0,duration-h.outward_pose_arrival_blend_time),duration,p*duration)

func authored_yaw(p: float) -> float:
	var index: float=clampf(p,0,1)*COUNT
	var low: int=mini(int(index),COUNT-1)
	# Imported skeleton +Z points DOWN in visual space: source yaw therefore
	# maps to negative world Y yaw. Positive yaw reversed the normal jump twist.
	return -lerpf(source_turn[low],source_turn[low+1],index-low)

func rotation_angle(h: Node,p: float,target_turn: float) -> float:
	var authored_end: float=authored_yaw(1)
	var correction: float=wrapf(target_turn-authored_end,-PI,PI)
	return authored_yaw(p)+correction*arrival_weight(h,p)

func validate_target(h: Node,face: Dictionary) -> Dictionary:
	var r: Dictionary={"valid":false,"reason":"INVALID_FACE","edge":face.position,"path_clear":false}
	if not face.collider is StaticBody3D or face.collider is AnimatableBody3D or face.collider==h.source: return r
	var normal: Vector3=face.normal
	if absf(normal.y)>.02: return r
	var inset: Vector3=face.position-normal*.04
	var band: float=h.braced_hang_transfer_outward_max_vertical_difference
	var hit: Dictionary=h.ray(Vector3(inset.x,h.ledge_edge.y+band+.06,inset.z),Vector3(inset.x,h.ledge_edge.y-band-.06,inset.z))
	if hit.is_empty() or hit.collider!=face.collider or hit.normal.y<.98: r.reason="NO_ELIGIBLE_TOP"; return r
	var edge:=Vector3(face.position.x,hit.position.y,face.position.z)
	var anchor: Vector3=edge+normal*h.body_distance_from_wall-Vector3.UP*h.hang_vertical_offset
	var delta: Vector3=anchor-h.alignment
	var horizontal:=Vector3(delta.x,0,delta.z)
	var distance: float=delta.length()
	var aim: float=horizontal.normalized().dot(direction)
	var angle: float=rad_to_deg(acos(clampf(aim,-1,1)))
	var elevation: float=rad_to_deg(atan2(absf(delta.y),horizontal.length()))
	var wall_angle: float=rad_to_deg(acos(clampf(normal.dot(-horizontal.normalized()),-1,1)))
	r.merge({"edge":edge,"anchor":anchor,"distance":distance,"vertical":delta.y,"angle":angle,"wall_angle":wall_angle,"alignment":aim,"motion_scale":horizontal.length()/maxf(.01,authored_distance)},true)
	if distance<h.outward_min_distance or distance>h.braced_hang_transfer_outward_max_distance: r.reason="DISTANCE"; return r
	if absf(delta.y)>band or elevation>h.braced_hang_transfer_outward_vertical_angle: r.reason="HEIGHT_OR_ELEVATION"; return r
	if angle>h.braced_hang_transfer_outward_horizontal_angle or horizontal.normalized().dot(h.wall_normal)<.5: r.reason="OUTSIDE_INTENT_CONE"; return r
	if wall_angle>h.outward_destination_wall_angle: r.reason="DESTINATION_FACING"; return r
	# This first outward mode crosses to an opposing wall, not around a
	# perpendicular corner. Local gentle curvature can still satisfy this.
	if normal.dot(h.wall_normal)>-.5: r.reason="NON_OPPOSING_WALL_OR_CORNER"; return r
	if r.motion_scale>h.braced_hang_outward_transfer_max_motion_scale: r.reason="MOTION_SCALE"; return r
	if not h.validate_contacts(face.collider,edge,hit.position,normal,hit.normal): r.reason="HAND_SPAN_OR_BRACE"; return r
	for offset in [-.28,0.0,.28]:
		for depth in [.35,.8,1.15,1.5]:
			var point: Vector3=edge+(-normal).cross(Vector3.UP)*offset-Vector3.UP*depth
			var brace: Dictionary=h.ray(point+normal*.12,point-normal*h.lateral_brace_recess)
			if brace.is_empty() or brace.collider!=face.collider or brace.normal.dot(normal)<.98: r.reason="NO_CONTINUOUS_BRACE"; return r
	if not h.clear_segment(anchor,anchor,h.motor.crouch.standing_capsule_height): r.reason="ANCHOR_BLOCKED"; return r
	r.merge({"valid":true,"reason":"TARGET_VALID","source":face.collider,"transform":face.collider.global_transform,"normal":normal,"facing":-normal,"top":hit.position,"top_normal":hit.normal},true)
	r["score"]=h.outward_alignment_score_weight*(1-aim)+h.outward_distance_score_weight*distance/h.braced_hang_transfer_outward_max_distance+h.outward_height_score_weight*absf(delta.y)/maxf(.01,band)+.05*wall_angle/maxf(1,h.outward_destination_wall_angle)
	return r

func query(h: Node,side: float) -> Dictionary:
	input_bias=clampf(side,-1,1)
	direction=(h.wall_normal+h.facing.cross(Vector3.UP)*input_bias*h.braced_hang_transfer_directional_input_bias).normalized()
	candidates.clear()
	last_result={"valid":false,"reason":"NO_TARGET","path_clear":false}
	if not h.automatic_ledge_to_ledge_jump_enabled:
		last_result.reason="DISABLED"
		return last_result
	if not is_instance_valid(h.source) or not h.source is StaticBody3D or h.source is AnimatableBody3D:
		last_result.reason="UNSUPPORTED_SOURCE"
		return last_result
	var seen: Dictionary={}
	var cone: float=h.braced_hang_transfer_outward_horizontal_angle
	for i in 25:
		var ray_direction: Vector3=direction.rotated(Vector3.UP,deg_to_rad(lerpf(-cone,cone,float(i)/24)))
		for fraction in [-1.0,-.5,0.0,.5,1.0]:
			var band: float=fraction*h.braced_hang_transfer_outward_max_vertical_difference
			var start: Vector3=h.ledge_edge+h.wall_normal*.51+Vector3.UP*(band-.08)
			var hit: Dictionary=h.ray(start,start+ray_direction*(h.braced_hang_transfer_outward_max_distance+.6))
			if hit.is_empty(): continue
			var r:=validate_target(h,hit)
			var key: String="%s/%s"%[hit.collider.get_instance_id(),Vector3(r.edge).snapped(Vector3.ONE*.05)]
			if seen.has(key): continue
			seen[key]=true
			candidates.append(r)
			if not r.valid and rejection_rank(r)>rejection_rank(last_result): last_result=r
	candidates.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return a.get("score",INF)<b.get("score",INF))
	var a: Dictionary=h.vertical.snapshot(h)
	for r in candidates:
		if not r.valid: continue
		var previous: Vector3=a.anchor
		var points: Array[Vector3]=[previous]
		for i in range(1,COUNT+1):
			var next: Vector3=path(float(i)/COUNT,a,r)
			points.append(next)
			if not h.clear_segment(previous,next,h.motor.crouch.standing_capsule_height): r.valid=false; r.reason="ARC_BLOCKED"; break
			previous=next
		r["path"]=points
		r.path_clear=r.valid
		last_result=r
		if r.valid: r.reason="ACCEPT"; break
	return last_result

func rejection_rank(r: Dictionary) -> int:
	if r.has("path"): return 4
	if r.reason in ["HAND_SPAN_OR_BRACE","NO_CONTINUOUS_BRACE","ANCHOR_BLOCKED"]: return 3
	if r.reason in ["MOTION_SCALE","DESTINATION_FACING","HEIGHT_OR_ELEVATION","NON_OPPOSING_WALL_OR_CORNER"]: return 2
	if r.reason in ["DISTANCE","OUTSIDE_INTENT_CONE"]: return 1
	return 0

func request(h: Node,side: float) -> bool:
	var target:=query(h,side)
	decision="TRANSFER" if target.valid else "JUMP_OFF"
	if not target.valid: return false
	origin=h.vertical.snapshot(h)
	destination=target.duplicate(true)
	progress=0
	playback_time=0
	elapsed=0
	expected_position=origin.anchor
	active=true
	h.hang_phase=h.HangPhase.OUTWARD
	return true

func advance(h: Node,delta: float) -> bool:
	for target in [origin,destination]:
		if not is_instance_valid(target.source) or target.source.is_queued_for_deletion() or not target.source.global_transform.is_equal_approx(target.transform):
			h.owner_controller.finish("OUTWARD_SOURCE_LOST"); return false
	elapsed+=delta
	var playback=h.motor.get_node("AnimationController")._playback
	if playback.get_current_node()==STATE:
		playback_time=playback.get_current_play_position()
		progress=clampf(playback_time/flight_duration,0,1)
	if elapsed>playback_duration+2: h.owner_controller.finish("OUTWARD_TIMEOUT"); return false
	if progress>=.995: progress=1
	expected_position=path(progress,origin,destination)
	var start_yaw: float=atan2(-origin.facing.x,-origin.facing.z)
	var end_yaw: float=atan2(-destination.facing.x,-destination.facing.z)
	# Keep the actual jump's turn direction and timing, even with A/D intent.
	# Only the final catch aligns the remaining angle with the destination.
	var turn: float=wrapf(end_yaw-start_yaw,-PI,PI)
	h.motor.visual.rotation.y=start_yaw+rotation_angle(h,progress,turn)
	return true

func complete(h: Node) -> void:
	if progress<1 or playback_time<playback_duration-.005: return
	if not h.validate_contacts(destination.source,destination.edge,destination.top,destination.normal,destination.top_normal):
		h.owner_controller.finish("OUTWARD_DESTINATION_LOST"); return
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
	h.navigation.invalidate()
	h.vertical.preview_clock=0

func contact_target() -> Dictionary: return origin if progress<.5 else destination
func contact_weight(h: Node,foot: bool=false) -> float:
	var release: float=1-smoothstep(.23,.36,progress)
	var arrival: float=smoothstep(h.outward_foot_arrival if foot else h.outward_hand_arrival,1,progress)
	return release if progress<.5 else arrival
func hand_contact(h: Node,arm: Dictionary) -> Dictionary:
	var target:=contact_target()
	var tangent: Vector3=Vector3(target.facing).cross(Vector3.UP)
	return {"target":Vector3(target.edge)+tangent*(-.28 if arm.side=="Left" else .25)+Vector3.UP*h.braced_hang_hand_vertical_offset+Vector3(target.normal)*h.braced_hang_hand_wall_offset,"weight":contact_weight(h)}

func debug_text(h: Node) -> String:
	var r: Dictionary=destination if active else last_result
	return "OUTWARD %s / %.2f\nNormal %s / Aim %s / input %.2f / candidates %d\nTarget %s / %s / distance %.2f / dy %.2f\nAlignment %.3f / wall angle %.1f / scale %.2f / clear %s"%[decision,progress,h.wall_normal,direction,input_bias,candidates.size(),r.get("edge",Vector3.ZERO),r.get("reason","NONE"),r.get("distance",0.0),r.get("vertical",0.0),r.get("alignment",0.0),r.get("wall_angle",0.0),r.get("motion_scale",0.0),r.get("path_clear",false)]

func draw(view: Node,h: Node) -> void:
	view.arrow(h.alignment,h.alignment+h.wall_normal,Color.YELLOW)
	view.arrow(h.alignment,h.alignment+direction,Color.CYAN)
	for side in [-1,1]:
		for up in [-1,1]:
			var aim:=direction.rotated(Vector3.UP,deg_to_rad(side*h.braced_hang_transfer_outward_horizontal_angle))
			var previous: Vector3=h.alignment
			for i in range(1,9):
				var distance: float=h.braced_hang_transfer_outward_max_distance*i/8.0
				var height: float=minf(h.braced_hang_transfer_outward_max_vertical_difference,distance*tan(deg_to_rad(h.braced_hang_transfer_outward_vertical_angle)))
				var point: Vector3=h.alignment+aim*distance+Vector3.UP*up*height
				view.line(previous,point,Color.PURPLE)
				previous=point
	for r in candidates: view.cross_at(r.edge,Color.GREEN if r.valid else Color.RED,.05)
	var r: Dictionary=destination if active else last_result
	if r.has("normal"): view.arrow(r.anchor,r.anchor+r.normal,Color.MAGENTA)
	var points: Array=r.get("path",[])
	for i in range(1,points.size()): view.line(points[i-1],points[i],Color.MAGENTA if r.get("path_clear",false) else Color.RED)
	for i in range(0,points.size(),12):
		view.line(points[i],points[i]+Vector3.UP*h.motor.crouch.standing_capsule_height,Color(.5,.3,.8))
		var radius: float=h.motor.crouch.collision.shape.radius
		for y in [radius,h.motor.crouch.standing_capsule_height-radius]:
			for k in 12:
				var a: float=TAU*k/12
				var b: float=TAU*(k+1)/12
				view.line(points[i]+Vector3(cos(a)*radius,y,sin(a)*radius),points[i]+Vector3(cos(b)*radius,y,sin(b)*radius),Color(.5,.3,.8))
	if active:
		for target in [origin,destination]:
			for side in [-.28,.25]: view.cross_at(target.edge+Vector3(target.facing).cross(Vector3.UP)*side+Vector3.UP*h.braced_hang_hand_vertical_offset+Vector3(target.normal)*h.braced_hang_hand_wall_offset,Color.GREEN,.07)
