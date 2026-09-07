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

func jump_threshold(motor: Node) -> float:
	# No existing direct-jump design threshold. Round ballistic apex UP to the
	# next decimetre: current 8 m/s and 19.6 m/s² produce 1.7 m. Physics untouched.
	return ceilf(motor.jump_velocity*motor.jump_velocity/(2.0*maxf(.01,motor.rise_gravity))*10.0)/10.0

func query(h: Node,delta: float) -> Dictionary:
	query_serial+=1
	candidates.clear()
	var m=h.motor
	base=m.global_position
	forward=-m.visual.global_basis.z
	forward.y=0
	forward=forward.normalized()
	motion=Vector3(m.velocity.x,0,m.velocity.z)
	intent=m.animation_state.move_direction_world*m.animation_state.move_input_magnitude
	intent.y=0
	var approach:=motion if motion.length()>=.1 else intent
	search_direction=approach.normalized() if approach.length()>=.1 else forward
	prediction=(m.velocity*delta).limit_length(h.predictive_distance)
	threshold=jump_threshold(m)
	var support_y: float=m.ground_support.last_supported_height
	# Freeze launch support while rising. Below launch level, use current feet:
	# falling from a high platform must not disqualify every lower ledge forever.
	reference_height=minf(support_y,base.y) if is_finite(support_y) else base.y
	var steps: int=maxi(1,ceili(prediction.length()/.15))
	for sample_index in range(steps+1):
		var sample:=base+prediction*float(sample_index)/steps
		var directions: Array[Vector3]=[]
		for fraction in [0.0,-.25,.25,-.5,.5,-.75,.75,-1.0,1.0]:
			directions.append(search_direction.rotated(Vector3.UP,deg_to_rad(h.braced_hang_forward_cone_degrees*.5*fraction)))
		# Supporting rays also expose behind/away candidates in diagnostics.
		directions.append(forward)
		directions.append(-forward)
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
			var dot: float=approach.normalized().dot(to_edge.normalized()) if approach.length()>=.1 else -1.0
			var angle:=rad_to_deg(acos(clampf(forward.dot(to_edge.normalized()),-1,1)))
			var tangent:=inward.cross(Vector3.UP)
			var c: Dictionary={"valid":true,"reason":"NONE","classification":"BRACED","braced_hang":true,"requires_grounded":false,
				"source":front.collider,"edge":edge,"top":surface.position,"normal":front.normal,"top_normal":surface.normal,
				"facing":inward,"anchor":anchor,"angle":angle,"distance":to_edge.length(),"height":edge.y-reference_height,
				"approach":dot,"hands":[],"braces":[],"checks":{}}
			check(c,"Height",c.height>threshold+.00001,"BELOW_JUMP_HEIGHT")
			check(c,"Facing",angle<=h.facing_acceptance_half_angle+.001,"BEHIND")
			check(c,"Approach",dot>=h.approach_direction_dot,"NO_APPROACH" if approach.length()<.1 else "MOVING_AWAY")
			# Distance to the whole predictive segment; commitment still sweeps
			# the actual current capsule to the anchor, never the predicted body.
			var closest:=Geometry3D.get_closest_point_to_segment(edge-Vector3.UP*h.hang_vertical_offset,base,base+prediction)
			var vertical: float=edge.y-(closest.y+h.hang_vertical_offset)
			check(c,"Vertical reach",vertical<=h.vertical_reach_allowance and vertical>=-h.vertical_reach_below,"VERTICAL_REACH")
			check(c,"Horizontal reach",to_edge.length()<=h.max_grab_distance and Vector2(anchor.x-base.x,anchor.z-base.z).length()<=h.horizontal_reach_allowance,"HORIZONTAL_REACH")
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
	return selected

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
		text+="\nHeight %.2f m | Distance %.2f m\nApproach %.2f | Facing %.1f deg" % [c.height,c.distance,c.approach,c.angle]
		for key in c.checks: text+="\n%s: %s" % [key,"PASS" if c.checks[key] else "FAIL"]
	if persisted: text+="\nLast candidate (short persistence)"
	return text+"\nReason: "+str(c.get("reason","NONE"))+"\nGreen accepted / Cyan valid / Red rejected"
