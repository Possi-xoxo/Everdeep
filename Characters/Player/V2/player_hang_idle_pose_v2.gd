extends RefCounted
## Render-only polish. Never writes CharacterBody, anchor or collision transforms.
var weight: float=0
var blend: float=0
var offset: float=0
var rig_base:=Vector3.ZERO
var bound: bool=false
var feet: Dictionary={}

func update(h: Node,animation: Node,delta: float) -> void:
	var idle_owned: bool=h.is_attached() and h.hang_phase!=h.HangPhase.TO_CROUCH
	if not bound and not idle_owned: return
	if not bound:
		rig_base=animation.rig.position
		bound=true
	if idle_owned:
		blend=move_toward(blend,clampf(h.elapsed/h.settle_duration,0,1),delta/h.settle_duration)
	else:
		blend=move_toward(blend,0,delta/maxf(.001,h.braced_hang_visual_blend_out))
	weight=smoothstep(0,1,blend)
	offset=h.braced_hang_visual_vertical_offset*weight
	# Dedicated rig instance position avoids fighting locomotion's VisualRoot
	# compression/offset writers. Always reconstruct from the saved base.
	animation.rig.position=rig_base+Vector3.UP*offset
	if weight==0:
		feet.clear()
		bound=false

func hand_target(h: Node,arm: Dictionary,animated: Vector3) -> Vector3:
	var tangent: Vector3=h.facing.cross(Vector3.UP).normalized()
	# Follow the authored lateral wrist pose inside the already validated span.
	var baseline: float=(Vector3(arm.base_grip)-h.ledge_edge).dot(tangent)
	var lateral: float=clampf((animated-h.ledge_edge).dot(tangent),maxf(-.28,baseline-.005),minf(.28,baseline+.005))
	lateral=minf(lateral,-.10) if arm.side=="Left" else maxf(lateral,.10)
	var edge: Vector3=h.ledge_edge+tangent*lateral
	var n: Vector3=h.landing_plane_normal
	edge.y=h.top.y-(n.x*(edge.x-h.top.x)+n.z*(edge.z-h.top.z))/n.y
	return edge+Vector3.UP*h.braced_hang_hand_vertical_offset+h.wall_normal*h.braced_hang_hand_wall_offset

func foot_contact(h: Node,controller: Node,leg: Dictionary,pose: Transform3D,samples: Array,legacy: Dictionary) -> Dictionary:
	var result: Dictionary=legacy.duplicate()
	var raw: Vector3=samples[1] # Toe/base-of-toes is the closest authored wall point.
	var normal: Vector3=h.wall_normal.normalized()
	if (pose.origin-h.wall_point).dot(normal)<(raw-h.wall_point).dot(normal): raw=pose.origin
	var gap: float=(raw-h.wall_point).dot(normal)
	var projected:=raw-normal*gap
	var hit: Dictionary=h.ray(projected+normal*.08,projected-normal*.08)
	var valid: bool=controller.enabled and controller.climb_foot_ik_enabled and not hit.is_empty() and hit.collider==h.source and hit.normal.dot(normal)>.98
	if valid: gap=(raw-Vector3(hit.position)).dot(normal)
	var amount: float=h.braced_hang_foot_wall_clearance-gap
	var correction: Vector3=normal*amount
	var target:=pose.origin+correction
	var hip: Vector3=controller._world(leg.bones[0]).origin
	var knee: Vector3=controller._world(leg.bones[1]).origin
	var reach: float=hip.distance_to(knee)+knee.distance_to(pose.origin)
	var limited: bool=absf(amount)>h.braced_hang_max_foot_correction or hip.distance_to(target)>reach*.995
	var reason: String="NONE" if valid else "NO_LOCAL_WALL"
	if limited:
		valid=false
		reason="CORRECTION_OR_REACH_LIMIT"
	# Do not chase a distant wall or rotate the ankle flat. Keep the authored
	# lateral/vertical placement and existing authored knee-pole solver.
	var idle_target: Vector3=target if valid else pose.origin
	result.target=Vector3(legacy.target).lerp(idle_target,weight)
	result.weight=lerpf(legacy.weight,1.0 if valid else 0.0,weight)
	result.valid=legacy.valid or valid
	result.mode="HANG_IDLE_WALL"
	result.hit=hit.get("position",projected)
	result.normal=normal
	result.amount=pose.origin.distance_to(result.target)
	result.limited=limited
	result.blend_speed=h.foot_contact_response
	feet[leg.side]={"raw":pose.origin,"sample":raw,"target":idle_target,"hit":result.hit,"gap":gap,"weight":result.weight,"limited":limited,"reason":reason}
	return result

func debug_text(h: Node) -> String:
	var text: String="HANG IDLE POSE\nRender offset %.3f m | Blend %.2f\nAnchor %s\nVisualRoot %s | Rig %s" % [offset,weight,str(h.alignment),str(h.motor.visual.global_position),str(h.motor.get_node("AnimationController").rig.global_position)]
	for side in feet:
		var foot: Dictionary=feet[side]
		var actual_weight: float=foot.weight
		for leg in h.motor.get_node("FootIKController").legs:
			if leg.side==side: actual_weight=leg.weight
		text+="\n%s foot: weight %.2f | %s" % [side,actual_weight,foot.reason]
	for arm in h.motor.get_node("MantleHandIK").arms:
		text+="\n%s hand: weight %.2f | error %.3fm | limited %s" % [arm.side,arm.weight,arm.error,arm.limited]
	text+="\nYellow: animated | Green: hands | Cyan: feet\nRed: foot reach limit | Gray: known wall"
	return text
