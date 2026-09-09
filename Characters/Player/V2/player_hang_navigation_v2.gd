extends RefCounted
## Central stable-hang input policy, context preview, jump and modest interaction.
const JUMP_CLIP: StringName=&"TRV_JUMP_FROM_BRACED_HANG"
const Context=preload("res://interaction/context_interactable.gd")
const LAUNCH_TIME: float=12.0/30.0
var clock: float=0
var context_id: String=""
var targets: Dictionary={}
var safe_ground: Dictionary={"valid":false,"reason":"NONE","distance":0.0}
var selected: Node3D
var hand_side: String=""
var interacting: bool=false
var interact_time: float=0
var fired: bool=false
var reach_safe: bool=false
var jumping: bool=false
var jump_visual: bool=false
var jump_time: float=0
var jump_pose_time: float=0
var jump_length: float=0
var launch_velocity:=Vector3.ZERO
var departure_start:=Vector3.ZERO
var departure: Array[Vector3]=[]
var jump_root_delta:=Vector3.ZERO
var jump_turn: Array[float]=[]
var last_input: String="NONE"

func invalidate() -> void: clock=0

func prepare(h: Node,player: AnimationPlayer,reference: Vector3,idle_z: float) -> void:
	var clip: Animation=player.get_animation(JUMP_CLIP)
	h.outward.prepare(h,player,reference,idle_z)
	# Preserve the original jump's unwrapped root turn independently of the
	# optional transfer toggle, runtime catch blend and transfer playback rate.
	jump_turn.assign(h.outward.source_turn)
	jump_length=clip.length
	var track: int=h.hip_track(clip)
	var first: Vector3=clip.position_track_interpolate(track,0)
	jump_root_delta=(clip.position_track_interpolate(track,clip.length)-first)/100.0
	for i in 33:
		var delta: Vector3=(clip.position_track_interpolate(track,LAUNCH_TIME*i/32.0)-first)/100.0
		# Source wrists stay planted through ~frame 12. Preserve the authored
		# .46m rise / .18m retreat before that release, then apply ballistics.
		departure.append(Vector3(0,-delta.z,maxf(0,-delta.y)))
	clip.loop_mode=Animation.LOOP_NONE
	for key in clip.track_get_key_count(track): clip.track_set_key_value(track,key,Vector3(reference.x,reference.y,idle_z))

func release_query(h: Node) -> Dictionary:
	var result: Dictionary={"valid":false,"reason":"NO_SAFE_GROUND","distance":0.0}
	var start: Vector3=h.motor.global_position
	var duration: float=sqrt(2*h.braced_hang_safe_release_distance/h.motor.fall_gravity)
	var drift: Vector3=h.wall_normal*h.release_outward_speed*duration
	var hit: Dictionary=h.ray(start+drift+Vector3.UP*.03,start+drift-Vector3.UP*h.braced_hang_safe_release_distance)
	if hit.is_empty(): return result
	var normal: Vector3=hit.normal
	var distance: float=start.y-hit.position.y
	result.distance=distance
	if distance<0 or normal.dot(Vector3.UP)<cos(h.motor.floor_max_angle): result.reason="UNWALKABLE"; return result
	var landing: Vector3=hit.position+Vector3.UP*.015
	var support: Dictionary=h.motor.ground_support.evaluate(landing,Basis.IDENTITY,null,normal)
	if not support.supported: result.reason="INSUFFICIENT_SUPPORT"; return result
	# Cover the small uncertainty in release drift and the whole footprint,
	# not just a convenient ray hit at the furthest projected point.
	for fraction in [0.0,.5]:
		var point: Vector3=landing-drift*(1-fraction)
		point.y=landing.y-(normal.x*(point.x-landing.x)+normal.z*(point.z-landing.z))/normal.y
		if not h.motor.ground_support.evaluate(point,Basis.IDENTITY,null,normal).supported:
			result.reason="INCOMPLETE_LANDING_CORRIDOR"
			return result
	if not h.clear_segment(start,landing,h.motor.crouch.standing_capsule_height): result.reason="DROP_BLOCKED"; return result
	result.merge({"valid":true,"reason":"SAFE","landing":landing},true)
	return result

func hand_world(h: Node,side: String) -> Vector3:
	var hands=h.motor.get_node("MantleHandIK")
	return hands.world(hands.skeleton.find_bone("mixamorig_"+side+"Hand")).origin

func eligible(h: Node,target: Node3D,check_available: bool=true) -> bool:
	if not is_instance_valid(target) or target.is_queued_for_deletion() or not target.is_in_group("context_interactable"): return false
	if target.get_interaction_type()!=Context.Type.GENERIC_INTERACT or target.requires_grounded or (check_available and not target.can_interact(h.motor)): return false
	var point: Vector3=target.get_interaction_point()
	var center: Vector3=h.ledge_edge+h.wall_normal*.1
	if (point-center).dot(h.facing)<-.25: return false
	for side in ["Left","Right"]:
		var hand:=hand_world(h,side)
		if hand.distance_to(point)>h.braced_hang_interact_range: continue
		var hit: Dictionary=h.ray(hand,point)
		if hit.is_empty() or hit.collider==target or target.is_ancestor_of(hit.collider): return true
	return false

func scan_interaction(h: Node) -> void:
	if interacting: return
	selected=null
	var best: float=INF
	for candidate in h.motor.get_tree().get_nodes_in_group("context_interactable"):
		if not eligible(h,candidate): continue
		for side in ["Left","Right"]:
			var distance: float=hand_world(h,side).distance_to(candidate.get_interaction_point())
			var hit: Dictionary=h.ray(hand_world(h,side),candidate.get_interaction_point())
			if distance>h.braced_hang_interact_range or (not hit.is_empty() and hit.collider!=candidate and not candidate.is_ancestor_of(hit.collider)): continue
			if distance<best:
				best=distance
				selected=candidate
				hand_side=side

func refresh(h: Node,delta: float=0,force: bool=false) -> void:
	if not h.is_attached() or h.hang_phase!=h.HangPhase.IDLE or interacting: return
	clock-=delta
	if not force and clock>0: return
	clock=.25
	var next_context: String="%s/%s/%s" % [h.source.get_instance_id(),h.ledge_edge.snapped(Vector3.ONE*.01),h.wall_normal.snapped(Vector3.ONE*.01)]
	if context_id!=next_context:
		h.transfer.previews.clear()
		h.transfer.candidate_sets.clear()
	context_id=next_context
	h.vertical.refresh(h,0,true)
	safe_ground=release_query(h)
	for side in [-1,1]:
		for hop in [false,true]:
			var key: String=("LEFT" if side<0 else "RIGHT")+(" HOP" if hop else " SHIMMY")
			targets[key]=h.lateral.preview_idle(h,side,hop)
			if hop:
				h.transfer.continuous[side]=targets[key].valid
				if targets[key].valid:
					h.transfer.previews.erase(side)
					h.transfer.candidate_sets.erase(side)
				elif h.debug_detection_enabled(): h.transfer.previews[side]=h.transfer.query(h,side)
	scan_interaction(h)
	if h.debug_detection_enabled(): h.outward.query(h,h.outward.preview_side)

func resolve(h: Node,action: String,side: float=0,shift: bool=false) -> bool:
	if not h.is_attached() or h.hang_phase!=h.HangPhase.IDLE or interacting: return false
	if action=="UP": return h.vertical.resolve(h,1)
	if action=="DOWN": return h.vertical.resolve(h,-1)
	if action=="LATERAL": return h.lateral.request(h,int(side),shift)
	if action=="INTERACT":
		scan_interaction(h)
		if not eligible(h,selected): return false
		interacting=true
		interact_time=0
		fired=false
		reach_safe=true
		last_input="E → INTERACT"
		return true
	if action=="JUMP":
		if h.outward.request(h,side):
			last_input="SPACE → OUTWARD_TRANSFER"
			return true
		launch_velocity=h.wall_normal*h.braced_hang_jump_outward_speed+Vector3.UP*h.braced_hang_jump_up_speed+h.facing.cross(Vector3.UP)*clampf(side,-1,1)*h.braced_hang_jump_lateral_influence
		departure_start=h.motor.global_position
		jump_time=0
		jump_pose_time=0
		jumping=true
		jump_visual=true
		h.hang_phase=h.HangPhase.JUMP_OFF
		last_input="SPACE → JUMP_OFF"
		return true
	return false

func advance(h: Node,delta: float) -> void:
	refresh(h,delta)
	if interacting:
		interact_time+=delta
		if not eligible(h,selected,not fired): interacting=false; invalidate(); return
		if interact_time>=.3 and not fired:
			fired=true
			selected.begin_interaction(h.motor)
		if interact_time>=.7: interacting=false; invalidate()

func reach(h: Node,arm: Dictionary) -> Dictionary:
	if not interacting or arm.side!=hand_side or not eligible(h,selected,not fired): return {}
	var target: Vector3=selected.get_interaction_point()
	var shoulder: Vector3=h.motor.get_node("MantleHandIK").world(arm.bones[0]).origin
	if shoulder.distance_to(target)>(arm.upper_length+arm.lower_length)*.98: reach_safe=false; return {}
	var hit: Dictionary=h.ray(arm.animated,target)
	if not hit.is_empty() and hit.collider!=selected and not selected.is_ancestor_of(hit.collider): reach_safe=false; return {}
	return {"target":target,"weight":smoothstep(0,.25,interact_time)*(1-smoothstep(.4,.7,interact_time))}

func jump_step(h: Node,delta: float) -> bool:
	if not is_instance_valid(h.source) or not h.source.global_transform.is_equal_approx(h.source_transform):
		jumping=false; jump_visual=false; h.owner_controller.finish("HANG_SOURCE_LOST"); return true
	jump_time+=delta
	var playback=h.motor.get_node("AnimationController")._playback
	var time: float=playback.get_current_play_position() if playback.get_current_node()==&"HangJumpOff" else 0.0
	jump_pose_time=time
	var index: float=clampf(time/LAUNCH_TIME,0,1)*32
	var low: int=mini(int(index),31)
	var offset: Vector3=departure[low].lerp(departure[low+1],index-low)
	var target: Vector3=departure_start+Vector3.UP*offset.y+h.wall_normal*offset.z
	if not h.clear_segment(h.motor.global_position,target,h.motor.crouch.standing_capsule_height):
		jumping=false; jump_visual=false; h.hang_phase=h.HangPhase.IDLE; return true
	h.motor.move_and_collide(target-h.motor.global_position)
	if time<LAUNCH_TIME and jump_time<2: return true
	h.owner_controller.finish("HANG_JUMP_OFF")
	jumping=false
	jump_visual=true
	jump_time=time
	h.cooldown=0
	h.release_suppression_active=true
	h.release_suppression_remaining=h.release_regrab_timeout
	h.motor.velocity=launch_velocity
	h.motor.ground_support.reset_coyote()
	h.motor.animation_state.is_grounded=false
	h.motor.animation_state.was_grounded=false
	h.motor.animation_state.is_airborne=true
	h.motor.animation_state.jump_started=false
	return true

func catch_forward(h: Node) -> Vector3:
	var forward: Vector3=-h.motor.visual.global_basis.z
	forward.y=0
	forward=forward.normalized()
	var playback=h.motor.get_node("AnimationController")._playback
	if h.running or h.motor.animation_state.is_grounded or playback==null or playback.get_current_node()!=&"HangJumpOff" or jump_turn.size()<2:
		return forward
	# Use the evaluated animation clock, not the motor's ahead-of-pose timer.
	# Skeleton +Z maps to DOWN: its authored turn is negative world Y yaw.
	var index: float=clampf(playback.get_current_play_position()/jump_length,0,1)*(jump_turn.size()-1)
	var low: int=mini(int(index),jump_turn.size()-2)
	return forward.rotated(Vector3.UP,-lerpf(jump_turn[low],jump_turn[low+1],index-low))

func air_tick(h: Node,delta: float) -> void:
	if jumping or not jump_visual: return
	jump_time+=delta
	if h.running or h.motor.ground_support.has_ground_support or jump_time>=jump_length:
		jump_visual=false

func debug_text(h: Node) -> String:
	var text: String="\nNAV %s\nNormal %s / Tangent %s" % [context_id,h.wall_normal,h.facing.cross(Vector3.UP)]
	for key in targets: text+="\n%s: %s / %s / curve %.1f°" % [key,targets[key].valid,targets[key].reason,targets[key].get("curve_delta",0)]
	return text+"\nSafe ground: %s %.2fm / %s\nInteract: %s / %s / safe reach %s\n%s / Jump impulse %s" % [safe_ground.valid,safe_ground.distance,safe_ground.reason,selected.name if is_instance_valid(selected) else "NONE",hand_side,reach_safe,last_input,launch_velocity]

func draw(view: Node,h: Node) -> void:
	var origin: Vector3=h.motor.global_position
	view.line(origin,origin-Vector3.UP*h.braced_hang_safe_release_distance,Color.GREEN if safe_ground.valid else Color.RED)
	if safe_ground.valid: view.cross_at(safe_ground.landing,Color.GREEN,.15)
	view.arrow(origin,origin+(h.wall_normal*h.braced_hang_jump_outward_speed+Vector3.UP*h.braced_hang_jump_up_speed)*.15,Color.MAGENTA)
	for key in targets:
		var points: Array=targets[key].get("samples",[])
		for i in range(0,points.size(),4):
			var p: Dictionary=points[i]
			view.cross_at(p.edge,Color.CYAN if p.valid else Color.RED,.025)
			view.line(p.edge,p.edge+Vector3(p.normal)*.2,Color.BLUE)
			view.line(p.edge,p.edge+(-Vector3(p.normal)).cross(Vector3.UP)*.2,Color.YELLOW)
			if i>0: view.line(points[i-4].edge,p.edge,Color.CYAN)
	for side in ["Left","Right"]:
		var hand:=hand_world(h,side)
		for i in 24:
			var a: float=TAU*i/24.0
			var b: float=TAU*(i+1)/24.0
			view.line(hand+Vector3(cos(a),sin(a),0)*h.braced_hang_interact_range,hand+Vector3(cos(b),sin(b),0)*h.braced_hang_interact_range,Color.YELLOW)
	if is_instance_valid(selected): view.arrow(hand_world(h,hand_side),selected.get_interaction_point(),Color.GREEN)
