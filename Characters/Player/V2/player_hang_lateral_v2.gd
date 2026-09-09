extends RefCounted
## Continuous lateral actions with a validated gap-transfer request fallback.
## Does not use or modify automatic catch acquisition.
const CLIPS={"HangShimmyLeft":&"TRV_BRACED_HANG_SHIMMY_LEFT","HangShimmyRight":&"TRV_BRACED_HANG_SHIMMY_RIGHT","HangHopLeft":&"TRV_BRACED_HANG_HOP_LEFT","HangHopRight":&"TRV_BRACED_HANG_HOP_RIGHT"}
var curve=preload("res://Characters/Player/V2/player_hang_curve_v2.gd").new()
var route: Array=[]
var route_length: float=0
var action_distance: float=0
var active: bool=false
var hopping: bool=false
var direction: int=0
var state: StringName=&"HangIdle"
var progress: float=0
var elapsed: float=0
var lengths: Dictionary={}
var start:=Vector3.ZERO
var edge_start:=Vector3.ZERO
var top_start:=Vector3.ZERO
var wall_start:=Vector3.ZERO
var displacement:=Vector3.ZERO
var last_query: Dictionary={}
var motion=preload("res://Characters/Player/V2/player_hang_motion_v2.gd").new()
var expected_position:=Vector3.ZERO

func path(p: float) -> Vector3:
	var sample: Vector3=motion.sample(state,p)
	var local: Dictionary=curve.at_distance(route,action_distance*sample.x,route_length)
	return Vector3(local.anchor)+Vector3.UP*sample.y+Vector3(local.normal)*sample.z

var wall_normal:=Vector3.ZERO

func travel_distance(h: Node,side: int,hop: bool) -> float:
	if not hop: return h.braced_hang_shimmy_distance
	if h.braced_hang_hop_use_authored_distance:
		var name: String="HangHopLeft" if side<0 else "HangHopRight"
		return float(motion.measurements[name].derived_distance_m)
	return h.braced_hang_hop_distance

func query(h: Node,side: int,distance: float) -> Dictionary:
	return curve.query(h,side,distance)

func preview(h: Node,side: int,hop: bool) -> Dictionary:
	var action: StringName=StringName("Hang"+("Hop" if hop else "Shimmy")+("Left" if side<0 else "Right"))
	var distance: float=travel_distance(h,side,hop)
	var peak: float=1.0
	for value in motion.profiles[action]: peak=maxf(peak,value.x)
	var result: Dictionary=query(h,side,distance*peak)
	if not result.valid: return result
	var previous: Vector3=h.alignment
	for i in range(1,motion.SAMPLE_COUNT+1):
		var value: Vector3=motion.sample(action,float(i)/motion.SAMPLE_COUNT)
		var local: Dictionary=curve.at_distance(result.samples,distance*value.x,distance*peak)
		var point: Vector3=local.anchor+Vector3.UP*value.y+Vector3(local.normal)*value.z
		if not h.clear_segment(previous,point,h.motor.crouch.standing_capsule_height):
			result.valid=false
			result.reason="AUTHORED_ARC_BLOCKED"
			return result
		previous=point
	return result

func request(h: Node,side: int,shift: bool) -> bool:
	if not h.is_attached() or h.hang_phase!=h.HangPhase.IDLE or h.navigation.interacting or side==0: return false
	if h.transfer.input_latched: return false
	# Full continuous path, including authored arc/overshoot, takes priority.
	if shift:
		h.transfer.search_side=side
		last_query=preview(h,side,true)
		h.transfer.continuous[side]=last_query.valid
		if not last_query.valid: return h.transfer.request(h,side)
		h.transfer.last_resolution="CONTINUOUS_HOP"
	var distance: float=travel_distance(h,side,shift)
	action_distance=distance
	last_query=query(h,side,distance)
	if not last_query.valid: return false
	direction=side
	hopping=shift
	state=StringName("Hang"+("Hop" if shift else "Shimmy")+("Left" if side<0 else "Right"))
	if not lengths.has(state): last_query.reason="MISSING_CLIP"; return false
	start=h.alignment
	edge_start=h.ledge_edge
	top_start=h.top
	wall_start=h.wall_point
	displacement=Vector3(last_query.target)-start
	wall_normal=h.wall_normal
	expected_position=start
	# Preserve source overshoot/settling, including the right hop's overshoot.
	var peak: float=1
	for sample in motion.profiles[state]: peak=maxf(peak,sample.x)
	last_query=query(h,side,distance*peak)
	if not last_query.valid: return false
	route=last_query.samples
	route_length=distance*peak
	var previous:=start
	for i in range(1,motion.SAMPLE_COUNT+1):
		var point:=path(float(i)/motion.SAMPLE_COUNT)
		if not h.clear_segment(previous,point,h.motor.crouch.standing_capsule_height):
			last_query.valid=false
			last_query.reason="AUTHORED_ARC_BLOCKED"
			return false
		previous=point
	progress=0
	elapsed=0
	active=true
	h.hang_phase=h.HangPhase.LATERAL
	return true

func advance(h: Node,delta: float) -> void:
	elapsed+=delta
	var playback=h.motor.get_node("AnimationController")._playback
	if playback.get_current_node()==state: progress=clampf(playback.get_current_play_position()/float(lengths[state]),0,1)
	if progress>=.995: progress=1.0
	var travel: float=motion.sample(state,progress).x
	var local: Dictionary=curve.at_distance(route,action_distance*travel,route_length)
	var target: Vector3=local.anchor
	expected_position=path(progress)
	var result: Dictionary=curve.probe(h,local.edge,local.normal)
	if not h.clear_segment(h.motor.global_position,expected_position,h.motor.crouch.standing_capsule_height):
		result.valid=false
		result.reason="AUTHORED_ARC_BLOCKED"
	if not result.valid or elapsed>float(lengths[state])+2:
		last_query=result
		last_query.reason="LATERAL_INTERRUPTED_"+str(result.reason)
		active=false
		h.hang_phase=h.HangPhase.IDLE
		return
	h.alignment=target
	h.ledge_edge=local.edge
	h.top=local.edge
	h.wall_point=local.edge
	h.wall_normal=local.normal
	h.facing=-h.wall_normal
	h.motor.visual.rotation.y=atan2(-h.facing.x,-h.facing.z)
	if progress>=.995:
		active=false
		h.hang_phase=h.HangPhase.IDLE
		h.navigation.invalidate()

func prepare(h: Node,player: AnimationPlayer,reference: Vector3,idle_z: float) -> void:
	for name in CLIPS:
		if not player.has_animation(CLIPS[name]): push_error("Missing lateral hang clip: "+str(CLIPS[name])); continue
		var clip: Animation=player.get_animation(CLIPS[name])
		motion.capture(h,player,name,clip)
		lengths[StringName(name)]=clip.length/h.braced_hang_lateral_playback_speed
		clip.loop_mode=Animation.LOOP_NONE
		var track: int=h.hip_track(clip)
		for key in clip.track_get_key_count(track):
			# All sampled translation is now applied once by the controller.
			clip.track_set_key_value(track,key,Vector3(reference.x,reference.y,idle_z))
	motion.configure_right_hop(h.braced_hang_right_hop_mirror_left_curve)
	if h.braced_hang_right_hop_reduce_tail_slide and not h.braced_hang_right_hop_mirror_left_curve:
		motion.compress_right_tail(travel_distance(h,1,true),h.braced_hang_right_hop_tail_overshoot)

func hand_contact(h: Node,arm: Dictionary,animated: Vector3) -> Dictionary:
	var tangent: Vector3=h.facing.cross(Vector3.UP).normalized()
	var lateral: float=clampf((animated-h.ledge_edge).dot(tangent),-.28,.28)
	var target: Vector3=h.ledge_edge+tangent*lateral+Vector3.UP*h.braced_hang_hand_vertical_offset+h.wall_normal*h.braced_hang_hand_wall_offset
	var weight: float=1.0
	if hopping:
		weight=1.0-smoothstep(.08,.25,progress)*(1.0-smoothstep(.70,.94,progress))
	else:
		# Direction-side hand reaches first, trailing hand follows. Do not use
		# absolute wrist height here: the intentional below-lip idle target
		# would otherwise weaken BOTH arms throughout the entire action.
		var leading: bool=(arm.side=="Left")== (direction<0)
		weight=1.0-smoothstep(.05,.20,progress)*(1-smoothstep(.40,.55,progress)) if leading else 1.0-smoothstep(.45,.60,progress)*(1-smoothstep(.80,.95,progress))
	return {"target":target,"weight":weight}

func debug_text(h: Node) -> String:
	if h.transfer.active: return h.transfer.debug_text()
	var sample: Vector3=motion.sample(state,progress) if motion.profiles.has(state) else Vector3.ZERO
	return "LATERAL %s | progress %.2f | %s\nShimmy %.2fm / Hop L %.3fm R %.3fm\nAuthored lateral %.3f / rise %.3fm / retreat %.3fm\nExpected %s / Actual %s / Error %.4fm\nFinal anchor %s / Tangent %s / Query %s" % [state if active else &"IDLE",progress,"RELEASE/REGRAB" if hopping else "LEDGE CONTACT",h.braced_hang_shimmy_distance,travel_distance(h,-1,true),travel_distance(h,1,true),sample.x,sample.y,sample.z,expected_position,h.motor.global_position,expected_position.distance_to(h.motor.global_position),start+displacement,h.facing.cross(Vector3.UP),str(last_query.get("reason","NONE"))]
