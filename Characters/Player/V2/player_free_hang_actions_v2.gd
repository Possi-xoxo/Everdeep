extends RefCounted
## Free-only traversal: raw clip timing, prevalidated handholds, no launch state.
const CLIPS = {
	"FreeHangShimmyLeft": &"TRV_FREE_HANG_SHIMMY_LEFT",
	"FreeHangShimmyRight": &"TRV_FREE_HANG_SHIMMY_RIGHT",
	"FreeHangHopLeft": &"TRV_FREE_HANG_HOP_LEFT",
	"FreeHangHopRight": &"TRV_FREE_HANG_HOP_RIGHT",
	"FreeHangClimb": &"TRV_FREE_HANG_CLIMB_LEDGE",
	"FreeHangRelease": &"TRV_FREE_HANG_DROP_TO_IDLE",
}
const SAMPLES = 160
var profiles: Dictionary = {}
var active: bool = false
var state: StringName = &"FreeHangIdle"
var progress: float = 0.0
var age: float = 0.0
var distance: float = 0.0
var origin := Vector3.ZERO
var destination: Dictionary = {}
var start_hands: Dictionary = {}
var end_hands: Dictionary = {}
var direction := Vector3.ZERO
var route: PackedVector3Array = []
var last_resolution: String = "NONE"
var previous_stick := Vector2.ZERO
var previous_shift: bool = false
var idle_delay: float = 0.0
var queries: Dictionary = {}

func prepare(f, player: AnimationPlayer, reference: Vector3) -> bool:
	for key: String in CLIPS:
		if not player.has_animation(CLIPS[key]):
			push_error("Missing Free Hang source: "+str(CLIPS[key]))
			return false
		var raw: Animation = player.get_animation(CLIPS[key])
		var clip: Animation = raw.duplicate(true)
		var track: int = f.shared.hip_track(raw)
		if track<0: return false
		var duration: float = raw.length
		# Release's authored landing tail cannot own an arbitrary airborne fall.
		if key=="FreeHangRelease": duration=.30
		# Finish in the planted crouched portion, before the source stands up.
		if key=="FreeHangClimb": duration=3.10
		var start: Vector3 = raw.position_track_interpolate(track,0)
		var end: Vector3 = raw.position_track_interpolate(track,duration)
		var sign_x: float = 1.0 if key.ends_with("Left") else -1.0
		var travel: float = absf(end.x-start.x)/100.0
		var samples := PackedVector3Array()
		var minimum_x: float=0
		var maximum_x: float=0
		for i in range(SAMPLES+1):
			var p: float = float(i)/SAMPLES
			var delta: Vector3 = (raw.position_track_interpolate(track,duration*p)-start)/100.0
			var residual: Vector3 = delta-(end-start)/100.0*p
			samples.append(Vector3(delta.x*sign_x/maxf(.001,travel),-residual.z,maxf(0,-residual.y)))
			minimum_x=minf(minimum_x,samples[-1].x)
			maximum_x=maxf(maximum_x,samples[-1].x)
		profiles[key]={"samples":samples,"distance":travel,"duration":duration,"min_x":minimum_x,"max_x":maximum_x}
		clip.length=duration
		clip.loop_mode=Animation.LOOP_NONE
		for k in clip.track_get_key_count(track):
			var value: Vector3 = reference
			if key=="FreeHangClimb":
				var t: float=clip.track_get_key_time(track,k)/duration
				value.z+=(1.320673-.65)*100.0*smoothstep(.45,1.0,t)
			clip.track_set_key_value(track,k,value)
		player.get_animation_library("").add_animation(StringName(key+"_Runtime"),clip)
		if key=="FreeHangClimb": align_climb_support(f,player,clip,track)
	return true

func align_climb_support(f,player: AnimationPlayer,clip: Animation,track: int) -> void:
	# Like Braced pull-up: cancel vertical wrist drift in the private pose,
	# independently of the collision capsule's safe route over the lip.
	var skeleton: Skeleton3D=f.motor.get_node("AnimationController").rig.get_node("Base Armature and Mesh/Skeleton3D")
	var visual: Node3D=f.motor.get_node("VisualRoot")
	var corrections: Array[Vector3]=[]
	player.play(&"FreeHangClimb_Runtime")
	for k in clip.track_get_key_count(track):
		var time: float=minf(clip.length,clip.track_get_key_time(track,k))
		var p: float=time/clip.length
		player.seek(time,true)
		player.advance(0)
		var center: Vector3=Vector3.ZERO
		for side in ["Left","Right"]:
			center+=visual.to_local(skeleton.global_transform*skeleton.get_bone_global_pose(skeleton.find_bone("mixamorig_"+side+"Hand")).origin)*.5
		var lift: float=(f.free_hang_body_vertical_offset+.015)*smoothstep(0,.64,p)
		var offset:=Vector3(0,(f.free_hang_body_vertical_offset+f.free_hang_hand_vertical_offset-lift-center.y)*(1-smoothstep(.76,1,p)),0)
		corrections.append(skeleton.global_basis.inverse()*visual.global_basis*offset)
	for k in corrections.size(): clip.track_set_key_value(track,k,clip.track_get_key_value(track,k)+corrections[k])
	player.stop()

func sample(name: StringName,p: float) -> Vector3:
	var samples: PackedVector3Array=profiles[name].samples
	var at: float=clampf(p,0,1)*SAMPLES
	return samples[int(at)].lerp(samples[mini(SAMPLES,int(at)+1)],fmod(at,1.0))

func playback_rate(f,name: StringName) -> float:
	return f.free_hang_lateral_playback_speed if str(name).begins_with("FreeHangShimmy") or str(name).begins_with("FreeHangHop") else 1.0

func hands(f,edge: Vector3,normal: Vector3) -> Dictionary:
	var tangent: Vector3=(-normal).cross(Vector3.UP)
	return {"Left":edge-tangent*.263+normal*f.free_hang_hand_wall_offset+Vector3.UP*f.free_hang_hand_vertical_offset,
		"Right":edge+tangent*.277+normal*f.free_hang_hand_wall_offset+Vector3.UP*f.free_hang_hand_vertical_offset}

func probe(f,edge: Vector3) -> Dictionary:
	# Local ledge query deliberately omits all foot/bracing checks.
	var n: Vector3=f.wall_normal
	var front: Dictionary=f.shared.ray(edge+n*.12-Vector3.UP*.08,edge-n*.12-Vector3.UP*.08)
	if front.is_empty() or front.normal.dot(n)<.995: return {}
	var hit: Dictionary=f.shared.ray(edge-n*.04+Vector3.UP*.12,edge-n*.04-Vector3.UP*.12)
	if hit.is_empty() or hit.collider!=front.collider or hit.normal.dot(Vector3.UP)<.98: return {}
	var actual: Vector3=edge
	actual.y=hit.position.y
	if absf(actual.y-f.ledge_edge.y)>.025: return {}
	var targets: Dictionary=hands(f,actual,n)
	for target: Vector3 in targets.values():
		var q: Vector3=target-n*(f.free_hang_hand_wall_offset+.04)-Vector3.UP*f.free_hang_hand_vertical_offset
		var contact: Dictionary=f.shared.ray(q+Vector3.UP*.06,q-Vector3.UP*.06)
		if contact.is_empty() or contact.collider!=hit.collider: return {}
	var anchor: Vector3=f.anchor_for(actual,n)
	if not f.shared.clear_segment(anchor,anchor,f.motor.crouch.standing_capsule_height): return {}
	if not f.clear_visual_space(anchor,anchor,n): return {}
	return {"edge":actual,"anchor":anchor,"source":hit.collider,"transform":hit.collider.global_transform,"normal":n,"top":hit.position,"top_normal":hit.normal,"hands":targets}

func position_at(f,name: StringName,p: float,start: Vector3,dir: Vector3,travel: float) -> Vector3:
	var shape: Vector3=sample(name,p)
	return start+dir*travel*shape.x+Vector3.UP*shape.y+f.wall_normal*shape.z

func query(f,name: StringName,travel: float,remote: bool=false) -> Dictionary:
	var dir: Vector3=(-f.wall_normal).cross(Vector3.UP)*(-1 if str(name).ends_with("Left") else 1)
	var target: Dictionary=probe(f,f.ledge_edge+dir*travel)
	if target.is_empty(): return {}
	if remote and target.source==f.source: return {}
	if not remote and target.source!=f.source: return {}
	if not remote:
		# Reject unavailable wind-up/overshoot before the expensive full sweep.
		# This is only an early-out; the complete path is still validated below.
		for extent in [profiles[name].min_x,profiles[name].max_x]:
			var extreme: Dictionary=probe(f,f.ledge_edge+dir*travel*extent)
			if extreme.is_empty() or extreme.source!=f.source: return {}
	var previous: Vector3=f.alignment
	var points:=PackedVector3Array([previous])
	for i in range(1,SAMPLES+1):
		var p: float=float(i)/SAMPLES
		var shape: Vector3=sample(name,p)
		if not remote:
			var support: Dictionary=probe(f,f.ledge_edge+dir*travel*shape.x)
			if support.is_empty() or support.source!=f.source: return {}
		var point: Vector3=position_at(f,name,p,f.alignment,dir,travel)
		if not f.shared.clear_segment(previous,point,f.motor.crouch.standing_capsule_height) or not f.clear_visual_space(previous,point,f.wall_normal): return {}
		points.append(point)
		previous=point
	# Separate ledges must be parallel/coplanar and within the authored reach.
	# Both anchors fit full hand width; never turn this into an outward jump.
	target.merge({"distance":travel,"direction":dir,"route":points,"remote":remote})
	return target

func choose(f,name: StringName) -> Dictionary:
	var full: float=profiles[name].distance
	var found: Dictionary=query(f,name,full)
	if not found.is_empty(): return found
	var hop: bool=str(name).contains("Hop")
	var minimum: float=f.free_hang_minimum_hop_distance if hop else .12
	# Continuous partial movement takes priority, same as Braced Hang.
	var travel: float=full-.025
	while travel>=minimum:
		found=query(f,name,travel)
		if not found.is_empty(): return found
		travel-=.025
	if hop:
		travel=full
		while travel>=minimum:
			found=query(f,name,travel,true)
			if not found.is_empty(): return found
			travel-=.025
	return {}

func reset() -> void:
	active=false
	state=&"FreeHangIdle"
	progress=0
	previous_stick=Vector2.ZERO
	previous_shift=false
	idle_delay=0
	queries.clear()
	destination.clear()
	route.clear()
	start_hands.clear()
	end_hands.clear()

func input_tick(f,dt: float,stick: Vector2,shift: bool,jump: bool) -> void:
	var fresh_y: bool=absf(stick.y)>.5 and (absf(previous_stick.y)<.5 or signf(stick.y)!=signf(previous_stick.y))
	var fresh_x: bool=absf(stick.x)>.5 and (absf(previous_stick.x)<.5 or signf(stick.x)!=signf(previous_stick.x) or shift!=previous_shift)
	previous_stick=stick
	previous_shift=shift
	idle_delay=maxf(0,idle_delay-dt)
	if jump: last_resolution="Jump: NO_FREE_HANG_ACTION"
	if active or f.hang_phase!=f.HangPhase.IDLE or idle_delay>0: return
	if fresh_y and stick.y>.5 and absf(stick.x)<.5:
		begin(f,&"FreeHangRelease",{})
		last_resolution="S: RELEASE (no vertical hops)"
	elif fresh_y and stick.y<-.5 and absf(stick.x)<.5:
		var top: Dictionary=query_climb(f)
		queries["TOP"]=top
		if not top.is_empty(): begin(f,&"FreeHangClimb",top)
		last_resolution="W: CLIMB_UP" if active else "W: NO_CLEAR_TOP"
	elif absf(stick.x)>.5 and absf(stick.y)<.5 and (not shift or fresh_x):
		var name: StringName=StringName("FreeHang"+("Hop" if shift else "Shimmy")+("Left" if stick.x<0 else "Right"))
		var result: Dictionary=choose(f,name)
		queries[name]=result
		if result.is_empty():
			last_resolution=str(name)+": BLOCKED"
			idle_delay=.15
		else:
			begin(f,name,result)
			last_resolution=str(name)+(": GAP_TRANSFER" if result.remote else ": CONTINUOUS")

func begin(f,name: StringName,data: Dictionary) -> void:
	state=name
	active=true
	progress=0
	age=0
	origin=f.motor.global_position
	destination=data
	start_hands=f.hand_targets.duplicate()
	end_hands=data.get("hands",start_hands)
	distance=data.get("distance",0.0)
	direction=data.get("direction",Vector3.ZERO)
	route=data.get("route",PackedVector3Array())
	f.swing_offset=Vector3.ZERO
	f.swing_velocity=Vector3.ZERO
	f.retained_momentum=Vector3.ZERO
	if name==&"FreeHangClimb":
		f.motor.crouch.clear_handoff()
		f.motor.crouch.requested=true
		f.motor.crouch.phase=f.motor.crouch.Phase.CROUCHED
		f.motor.crouch.resize(f.motor.crouch.crouch_capsule_height)
	f.motor.get_node("AnimationController")._enter(state)

func climb_at(f,p: float,start: Vector3,end: Vector3) -> Vector3:
	# Raise outside the lip before crossing it: no collision bypass or early snap.
	var rise: float=smoothstep(0,.64,p)
	var cross: float=smoothstep(.64,1,p)
	return Vector3(lerpf(start.x,end.x,cross),lerpf(start.y,end.y,rise),lerpf(start.z,end.z,cross))

func query_climb(f) -> Dictionary:
	var landing: Vector3=f.ledge_edge+f.facing*maxf(.32,f.motor.ground_support.minimum_landing_setback())+Vector3.UP*.015
	if not f.motor.ground_support.evaluate(landing,Basis(Vector3.UP,atan2(-f.facing.x,-f.facing.z)),f.source,f.landing_plane_normal).supported: return {}
	var previous: Vector3=f.alignment
	var points:=PackedVector3Array([previous])
	for i in range(1,SAMPLES+1):
		var point: Vector3=climb_at(f,float(i)/SAMPLES,f.alignment,landing)
		if not f.shared.clear_segment(previous,point,f.motor.crouch.crouch_capsule_height): return {}
		previous=point
		points.append(point)
	return {"anchor":landing,"source":f.source,"transform":f.source_transform,"route":points}

func advance(f,dt: float) -> void:
	age+=dt
	var duration: float=profiles[state].duration/playback_rate(f,state)
	var playback=f.motor.get_node("AnimationController")._playback
	if playback.get_current_node()==state: progress=clampf(playback.get_current_play_position()/duration,0,1)
	if age>duration+2:
		f.owner_controller.finish("FREE_ACTION_TIMEOUT")
		return
	if state==&"FreeHangRelease":
		if progress>=.98: f.owner_controller.finish("FREE_RELEASED")
		return
	if not is_instance_valid(destination.source) or destination.source.is_queued_for_deletion() or not destination.source.global_transform.is_equal_approx(destination.transform):
		f.owner_controller.finish("FREE_DESTINATION_LOST")
		return
	var target: Vector3
	if state==&"FreeHangClimb": target=climb_at(f,progress,origin,destination.anchor)
	else: target=position_at(f,state,progress,origin,direction,distance)
	var height: float=f.motor.crouch.collision.shape.height
	if not f.shared.clear_segment(f.motor.global_position,target,height) or (state!=&"FreeHangClimb" and not f.clear_visual_space(f.motor.global_position,target,f.wall_normal)):
		f.owner_controller.finish("FREE_ACTION_BLOCKED")
		return
	f.motor.move_and_collide(target-f.motor.global_position)
	if f.motor.global_position.distance_to(target)>.02:
		f.owner_controller.finish("FREE_ACTION_COLLISION")
		return
	f.baseline=target
	f.motor.velocity=Vector3.ZERO
	if progress<.999: return
	if state==&"FreeHangClimb":
		f.motor.velocity.y=-.5
		f.motor.move_and_slide()
		f.motor.apply_floor_snap()
		f.motor.ground_support.refresh(0)
		f.owner_controller.finish("FREE_CLIMB_COMPLETED" if f.motor.ground_support.has_ground_support else "FREE_NO_LANDING")
		return
	f.source=destination.source
	f.source_transform=destination.transform
	f.ledge_edge=destination.edge
	f.top=destination.top
	f.landing_plane_normal=destination.top_normal
	f.alignment=destination.anchor
	f.entry_position=f.alignment
	f.baseline=f.alignment
	f.hand_targets=end_hands.duplicate()
	# Publish the committed destination to shared context/debug consumers too.
	for key in ["source","edge","anchor","normal","top","top_normal"]:
		f.candidate[key]=destination[key]
		f.owner_controller.active_data[key]=destination[key]
	f.candidate["hands"]=f.hand_targets.values()
	f.candidate["braces"]=[]
	f.candidate["classification"]="FREE"
	f.elapsed=f.catch_duration
	f.hang_phase=f.HangPhase.IDLE
	active=false
	state=&"FreeHangIdle"
	idle_delay=.12

func contact(side: String,current: Vector3) -> Dictionary:
	if not active: return {"target":current,"weight":1.0}
	if state==&"FreeHangRelease": return {"target":start_hands[side],"weight":1-smoothstep(.1,.8,progress)}
	if state==&"FreeHangClimb": return {"target":start_hands[side],"weight":1-smoothstep(.76,.95,progress)}
	var hop: bool=str(state).contains("Hop")
	# Both authored shimmies move the left hand first; hops mirror their lead.
	var lead: bool=side==("Right" if state==&"FreeHangHopRight" else "Left")
	var release_start: float=(.20 if lead else .28) if hop else (.12 if lead else .62)
	var release_end: float=(.30 if lead else .40) if hop else (.25 if lead else .74)
	var catch_start: float=(.34 if lead else .52) if hop else (.38 if lead else .84)
	var catch_end: float=(.44 if lead else .66) if hop else (.52 if lead else .98)
	if progress<release_end:
		return {"target":start_hands[side],"weight":1-smoothstep(release_start,release_end,progress)}
	return {"target":end_hands[side],"weight":smoothstep(catch_start,catch_end,progress)}

func query_debug() -> String:
	var status: Array[String]=[]
	for label in ["FreeHangShimmyLeft","FreeHangHopLeft","FreeHangShimmyRight","FreeHangHopRight","TOP"]:
		var value: String="not queried"
		if queries.has(label):
			value="BLOCKED" if queries[label].is_empty() else ("GAP valid" if queries[label].get("remote",false) else "valid")
		status.append(label.trim_prefix("FreeHang")+": "+value)
	return "Last requested targets: "+" | ".join(status)
