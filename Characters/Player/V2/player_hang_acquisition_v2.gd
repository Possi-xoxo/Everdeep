extends RefCounted
## Acquisition only. Animation, alignment, controls and exit stay in the hang profile.
var candidates: Array[Dictionary]=[]
var selected: Dictionary={}
var base:=Vector3.ZERO
var prediction:=Vector3.ZERO
var intent:=Vector3.ZERO
var motion:=Vector3.ZERO
var forward:=Vector3.FORWARD
var search_direction:=Vector3.FORWARD
var reference_height: float=0
var threshold: float=1.7
var query_serial: int=0
var recent_start:=Vector3.INF
var previous_position:=Vector3.INF
var previous_airborne: bool=false
var history_base:=Vector3.INF
var travel_velocity:=Vector3.ZERO
var clock: float=0
var grace_until: float=0
var grace_source_id: int=0
var grace_edge:=Vector3.ZERO
var grace_direction:=Vector3.FORWARD

func reset_history() -> void:
	previous_position=Vector3.INF
	recent_start=Vector3.INF
	history_base=Vector3.INF
	previous_airborne=false
	travel_velocity=Vector3.ZERO
	grace_until=0
	grace_source_id=0

## Called once at the motor input boundary, never by rendering/debug queries.
## Observes motion/input without altering locomotion or animation-state values.
func prepare_tick(h: Node,delta: float,stick: Vector2) -> Vector3:
	clock+=delta
	var m=h.motor
	var position: Vector3=m.global_position
	var airborne: bool=not m.ground_support.has_ground_support and not m.is_on_floor()
	if not airborne or h.running or not h.enabled or not h.owner_controller.can_begin(false):
		reset_history()
	recent_start=position
	travel_velocity=Vector3.ZERO
	if airborne and previous_airborne and previous_position.is_finite():
		var displacement:=position-previous_position
		# Discard teleports; never turn a reset into a swept remote catch.
		if displacement.length()<=maxf(.05,m.max_fall_speed*delta*1.5+.1):
			recent_start=position-displacement.limit_length(h.recent_sweep_distance)
			travel_velocity=(position-recent_start)/maxf(delta,.001)
			travel_velocity.y=0
		else:
			grace_until=0
			grace_source_id=0
	previous_position=position
	previous_airborne=airborne
	history_base=position
	var camera_forward: Vector3=-m.camera.global_basis.z
	camera_forward.y=0
	camera_forward=camera_forward.normalized()
	var right: Vector3=m.camera.global_basis.x
	right.y=0
	if m.lock_on.is_locked():
		camera_forward=m.lock_on.direction()
		right=camera_forward.cross(Vector3.UP)
	return (right.normalized()*stick.x-camera_forward*stick.y).normalized()*minf(stick.length(),1)

func jump_threshold(motor: Node) -> float:
	# No existing direct-jump design threshold. Round ballistic apex UP to the
	# next decimetre: current 8 m/s and 19.6 m/s² produce 1.7 m. Physics untouched.
	return ceilf(motor.jump_velocity*motor.jump_velocity/(2.0*maxf(.01,motor.rise_gravity))*10.0)/10.0

func query(h: Node,delta: float,current_intent: Vector3=Vector3.INF) -> Dictionary:
	query_serial+=1
	candidates.clear()
	var m=h.motor
	base=m.global_position
	forward=h.navigation.catch_forward(h)
	forward.y=0
	forward=forward.normalized()
	motion=Vector3(m.velocity.x,0,m.velocity.z)
	intent=current_intent if current_intent.is_finite() else m.animation_state.move_direction_world*m.animation_state.move_input_magnitude
	intent.y=0
	# Real slow momentum is not replaced by an empty input vector at .1 m/s.
	var history_valid: bool=history_base.is_finite() and history_base.distance_to(base)<.001
	if not history_valid:
		recent_start=base
		travel_velocity=Vector3.ZERO
	var approach:=motion if motion.length()>h.approach_speed_tolerance else travel_velocity
	if approach.length()<=h.approach_speed_tolerance: approach=intent
	search_direction=approach.normalized() if not approach.is_zero_approx() else (grace_direction if clock<grace_until else forward)
	prediction=(m.velocity*delta).limit_length(h.predictive_distance)
	threshold=jump_threshold(m)
	var support_y: float=m.ground_support.last_supported_height
	# Freeze launch support while rising. Below launch level, use current feet:
	# falling from a high platform must not disqualify every lower ledge forever.
	reference_height=minf(support_y,base.y) if is_finite(support_y) else base.y
	var sample_positions: Array[Vector3]=[base]
	for endpoint in [recent_start,base+prediction]:
		var offset: Vector3=endpoint-base
		var steps: int=maxi(1,ceili(offset.length()/.15))
		for sample_index in range(1,steps+1):
			sample_positions.append(base+offset*float(sample_index)/steps)
	for sample in sample_positions:
		var directions: Array[Vector3]=[]
		for fraction in [0.0,-.25,.25,-.5,.5,-.75,.75,-1.0,1.0]:
			directions.append(search_direction.rotated(Vector3.UP,deg_to_rad(h.braced_hang_forward_cone_degrees*.5*fraction)))
		# Supporting rays also expose behind/away candidates in diagnostics.
		directions.append(forward)
		directions.append(-forward)
		if not intent.is_zero_approx(): directions.append(intent.normalized())
		for direction in directions:
			var hand_y: float=sample.y+h.hang_vertical_offset
			var front: Dictionary={}
			for offset in [-h.vertical_reach_below-.10,-.20,0.0,.20,h.vertical_reach_allowance]:
				var origin:=Vector3(sample.x,hand_y+offset,sample.z)
				front=h.ray(origin,origin+direction*(h.max_grab_distance+.15))
				if not front.is_empty(): break
			if front.is_empty(): continue
			if absf(front.normal.y)>.15 or not front.collider is Node3D:
				candidates.append({"valid":false,"reason":"INVALID_WALL","classification":"NONE","edge":front.position,"normal":front.normal,"distance":base.distance_to(front.position)})
				continue
			var inward:=Vector3(-front.normal.x,0,-front.normal.z).normalized()
			var point: Vector3=sample+inward*(front.position-sample).dot(inward)
			var search:=point+inward*.04
			var surface: Dictionary=h.ray(Vector3(search.x,hand_y+h.vertical_reach_allowance+.15,search.z),Vector3(search.x,hand_y-h.vertical_reach_below-.15,search.z))
			if surface.is_empty() or surface.collider!=front.collider or surface.normal.y<.85:
				candidates.append({"valid":false,"reason":"NO_USABLE_TOP","classification":"NONE","edge":front.position,"normal":front.normal,"distance":base.distance_to(front.position)})
				continue
			var edge:=Vector3(point.x,surface.position.y,point.z)
			# Same geometric candidate may appear in several rays/sweep samples.
			var duplicate:=false
			for existing in candidates:
				if existing.get("source")==front.collider and existing.edge.distance_to(edge)<.025:
					duplicate=true
					break
			if duplicate: continue
			var anchor: Vector3=edge-inward*h.body_distance_from_wall-Vector3.UP*h.hang_vertical_offset
			var to_edge:=Vector3(edge.x-base.x,0,edge.z-base.z)
			var direction_to_edge:=to_edge.normalized()
			var radial_speed: float=motion.dot(direction_to_edge)
			var dot: float=approach.normalized().dot(direction_to_edge) if not approach.is_zero_approx() else 0.0
			var moving_away: bool=radial_speed < -h.approach_speed_tolerance
			if moving_away and grace_source_id==front.collider.get_instance_id(): grace_until=0
			var direct_approach: bool=not moving_away and dot>=h.approach_direction_dot and approach.dot(direction_to_edge)>h.approach_speed_tolerance
			var approach_source: String="VELOCITY" if motion.length()>h.approach_speed_tolerance else ("RECENT MOTION" if travel_velocity.length()>h.approach_speed_tolerance else "INPUT")
			var wall_contact: bool=touching_wall(m,front.collider,front.normal)
			var intent_assist: bool=motion.length()<.1 or (wall_contact and absf(radial_speed)<=h.approach_speed_tolerance)
			if not direct_approach and not moving_away and intent_assist and intent.dot(direction_to_edge)>h.approach_speed_tolerance and intent.normalized().dot(direction_to_edge)>=h.approach_direction_dot:
				direct_approach=true
				dot=intent.normalized().dot(direction_to_edge)
				approach_source="INPUT"
			var grace: bool=not moving_away and clock<grace_until and grace_source_id==front.collider.get_instance_id() and edge.distance_to(grace_edge)<.25 and intent.dot(direction_to_edge)>=-.01
			var angle:=rad_to_deg(acos(clampf(forward.dot(to_edge.normalized()),-1,1)))
			var tangent:=inward.cross(Vector3.UP)
			var c: Dictionary={"valid":true,"reason":"NONE","classification":"BRACED","braced_hang":true,"requires_grounded":false,
				"source":front.collider,"edge":edge,"top":surface.position,"normal":front.normal,"top_normal":surface.normal,
				"facing":inward,"anchor":anchor,"angle":angle,"distance":to_edge.length(),"height":edge.y-reference_height,
				"approach":dot,"approach_source":"GRACE" if grace and not direct_approach else approach_source,"radial_speed":radial_speed,"velocity":motion,"intent":intent,"to_ledge":direction_to_edge,
				"hand_y":base.y+h.hang_vertical_offset,"vertical_delta":edge.y-base.y-h.hang_vertical_offset,
				"grace":grace and not direct_approach,"grace_remaining":maxf(0,grace_until-clock),"wall_contact":wall_contact,
				"hands":[],"braces":[],"checks":{}}
			check(c,"Height",c.height>threshold+.00001,"BELOW_JUMP_HEIGHT")
			check(c,"Facing",angle<=h.facing_acceptance_half_angle+.001,"BEHIND")
			check(c,"Approach",direct_approach or grace,"MOVING_AWAY" if moving_away else "NO_APPROACH")
			# Distance to the whole predictive segment; commitment still sweeps
			# the actual current capsule to the anchor, never the predicted body.
			var recent_closest:=Geometry3D.get_closest_point_to_segment(anchor, recent_start,base)
			var predicted_closest:=Geometry3D.get_closest_point_to_segment(anchor,base,base+prediction)
			var current_reach: bool=in_vertical_band(h,c.vertical_delta)
			var recent_reach: bool=in_vertical_band(h,edge.y-recent_closest.y-h.hang_vertical_offset)
			var predicted_reach: bool=in_vertical_band(h,edge.y-predicted_closest.y-h.hang_vertical_offset)
			c.swept_intersection=recent_reach or predicted_reach
			c.sweep_required=not current_reach and c.swept_intersection
			check(c,"Vertical reach",current_reach or c.swept_intersection,"VERTICAL_REACH")
			check(c,"Horizontal reach",to_edge.length()<=h.max_grab_distance and Vector2(anchor.x-base.x,anchor.z-base.z).length()<=h.horizontal_reach_allowance,"HORIZONTAL_REACH")
			c.swept_intersection=c.swept_intersection and c.checks["Horizontal reach"]
			c.sweep_required=c.sweep_required and c.swept_intersection
			check(c,"Regrab",not ((h.cooldown>0 or h.release_suppression_active) and front.collider.get_instance_id()==h.last_source_id and edge.distance_to(h.last_edge)<1),"REGRAB_COOLDOWN")
			var width_ok:=true
			var hand_reach_ok:=true
			var brace_ok:=true
			for lateral in [-.28,.28]:
				var hand: Vector3=edge+tangent*lateral+inward*.04
				var n: Vector3=surface.normal
				hand.y=surface.position.y-(n.x*(hand.x-surface.position.x)+n.z*(hand.z-surface.position.z))/n.y
				c.hands.append(hand)
				var hit: Dictionary=h.ray(hand+Vector3.UP*.06,hand-Vector3.UP*.06)
				width_ok=width_ok and not hit.is_empty() and hit.collider==front.collider and hit.normal.dot(n)>.98
				var reach: Dictionary=h.ray(anchor+Vector3.UP*1.4+tangent*lateral,hand-Vector3.UP*.03)
				hand_reach_ok=hand_reach_ok and not reach.is_empty() and reach.collider==front.collider
				for drop in [.8,1.15]:
					var brace: Vector3=edge+tangent*lateral-Vector3.UP*drop
					c.braces.append(brace)
					var br: Dictionary=h.ray(brace-inward*.12,brace+inward*.12)
					brace_ok=brace_ok and not br.is_empty() and br.collider==front.collider and br.normal.dot(front.normal)>.98
			check(c,"Ledge width",width_ok,"HAND_WIDTH")
			check(c,"Hand reach",hand_reach_ok,"HAND_REACH")
			check(c,"Brace",brace_ok,"NO_BRACING_WALL")
			if not brace_ok: c.classification="FREE_HANG_CANDIDATE"
			var body_ok: bool=h.clear_segment(base,anchor,1.1)
			check(c,"Body",body_ok,"BODY_BLOCKED")
			check(c,"Head / full sweep",h.clear_segment(base,anchor,m.crouch.standing_capsule_height),"HEAD_BLOCKED")
			candidates.append(c)
	selected={"valid":false,"reason":"NO_LEDGE","classification":"NONE"}
	var score: float=INF
	for c in candidates:
		var rank: float=c.get("distance",INF)+(0 if c.valid else 100)+(0 if c.has("anchor") else 10)
		if rank<score:
			score=rank
			selected=c
	# Direction grace can be primed just before entering the vertical band,
	# but requires every physical check and current horizontal reach. It never
	# refreshes itself and never bypasses a failed body/brace/height/regrab test.
	if selected.has("checks") and not m.is_on_floor() and not m.ground_support.has_ground_support and not h.running and h.enabled and h.owner_controller.can_begin(false):
		var eligible: bool=selected.checks.Approach and not selected.grace
		for key in selected.checks:
			if key not in ["Approach","Vertical reach"]: eligible=eligible and selected.checks[key]
		if eligible:
			grace_until=clock+h.candidate_grace_time
			grace_source_id=selected.source.get_instance_id()
			grace_edge=selected.edge
			grace_direction=selected.to_ledge
	return selected

func in_vertical_band(h: Node,value: float) -> bool:
	return value<=h.vertical_reach_allowance and value>=-h.vertical_reach_below

func touching_wall(m: CharacterBody3D,source: Object,normal: Vector3) -> bool:
	for index in m.get_slide_collision_count():
		var hit:=m.get_slide_collision(index)
		if hit.get_collider()==source and hit.get_normal().dot(normal)>.95: return true
	return false

func check(c: Dictionary,label: String,passed: bool,reason: String) -> void:
	c.checks[label]=passed
	if not passed and c.valid:
		c.valid=false
		c.reason=reason

func debug_text(h: Node) -> String:
	var airborne: bool=not h.motor.ground_support.has_ground_support and not h.motor.is_on_floor()
	var c: Dictionary=h.result
	var persisted:=false
	if not c.has("edge") and not h.detection_visual.retained_result.is_empty():
		c=h.detection_visual.retained_result
		persisted=true
	var text: String="Hang Detection (Ctrl+F3)\nAirborne: %s | %s\nCandidate: %s | %s\nReference Y: %.2f | Jump threshold: %.2f m" % [airborne,"RISING" if h.motor.velocity.y>0 else "FALLING",c.has("edge"),"ACCEPT" if c.get("valid",false) else "REJECT",reference_height,threshold]
	if c.has("anchor"):
		text+="\nLedge top Y %.2f | Category height %.2f\nHand Y %.2f | Vertical delta %+.3f m\nHorizontal distance %.3f m\nVelocity %s\nInput %s\nTo ledge %s\nApproach dot %.3f | Toward speed %+.3f m/s\nFacing %.1f deg | Grace %s (%.2fs)\nSwept intersection %s | Required %s" % [c.edge.y,c.height,c.hand_y,c.vertical_delta,c.distance,str(c.velocity),str(c.intent),str(c.to_ledge),c.approach,c.radial_speed,c.angle,c.grace,c.grace_remaining,c.swept_intersection,c.sweep_required]
		text+="\nHeight %s | Direction %s | Reach %s" % [flag(c.checks.Height),flag(c.checks.Facing and c.checks.Approach),flag(c.checks["Vertical reach"] and c.checks["Horizontal reach"])]
		text+="\nDirection source: "+c.approach_source+" | Wall contact: "+str(c.wall_contact)
		text+="\nBrace: %s | Body: %s | Head: %s\nWidth: %s | Hand reach: %s | Regrab: %s" % [flag(c.checks.Brace),flag(c.checks.Body),flag(c.checks["Head / full sweep"]),flag(c.checks["Ledge width"]),flag(c.checks["Hand reach"]),flag(c.checks.Regrab)]
	if persisted: text+="\nLast candidate (short persistence)"
	return text+"\nReason: "+str(c.get("reason","NONE"))+"\nGreen accepted / Cyan valid / Red rejected"

func flag(value: bool) -> String: return "PASS" if value else "FAIL"
