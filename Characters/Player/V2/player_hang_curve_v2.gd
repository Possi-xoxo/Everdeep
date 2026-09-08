extends RefCounted
## Piecewise local geometry, not explicit corner transitions.
func probe(h: Node,edge: Vector3,normal: Vector3) -> Dictionary:
	var result: Dictionary={"valid":false,"reason":"LEDGE_END_GAP_OR_CORNER","edge":edge,"normal":normal}
	var face: Dictionary=h.ray(edge-Vector3.UP*.08+normal*.16,edge-Vector3.UP*.08-normal*.16)
	if face.is_empty() or face.collider!=h.source: return result
	var n: Vector3=face.normal
	var angle: float=rad_to_deg(acos(clampf(n.dot(normal),-1,1)))
	result["angle"]=angle
	if angle>h.lateral_max_normal_change: result.reason="SHARP_CORNER"; return result
	edge=Vector3(face.position.x,edge.y,face.position.z)
	var tangent:=(-n).cross(Vector3.UP).normalized()
	for offset in [-.28,0.0,.28]:
		var hand: Vector3=edge+tangent*offset-n*.04
		var hit: Dictionary=h.ray(hand+Vector3.UP*.06,hand-Vector3.UP*.06)
		if hit.is_empty() or hit.collider!=h.source or hit.normal.dot(h.landing_plane_normal)<.98 or absf(hit.position.y-edge.y)>h.lateral_height_tolerance: return result
		for depth in [.35,.8,1.15,1.5]:
			var brace: Vector3=edge+tangent*offset-Vector3.UP*depth
			hit=h.ray(brace+n*.12,brace-n*h.lateral_brace_recess)
			if hit.is_empty() or hit.collider!=h.source or hit.normal.dot(n)<.98:
				result.reason="NO_CONTINUOUS_BRACE"
				return result
	result.merge({"valid":true,"reason":"VALID","edge":edge,"normal":n,"anchor":edge+n*h.body_distance_from_wall-Vector3.UP*h.hang_vertical_offset},true)
	return result

func query(h: Node,side: int,distance: float) -> Dictionary:
	var result: Dictionary={"valid":false,"reason":"NO_SOURCE","direction":side,"distance":distance,"target":h.alignment,"tangent":h.facing.cross(Vector3.UP),"brace":false,"clearance":false,"blocker":"","samples":[],"curve_delta":0.0}
	if not is_instance_valid(h.source) or h.source.is_queued_for_deletion() or not h.source.global_transform.is_equal_approx(h.source_transform): return result
	var edge: Vector3=h.ledge_edge
	var normal: Vector3=h.wall_normal
	var previous: Vector3=h.alignment
	var steps: int=maxi(1,ceili(distance/h.lateral_query_spacing))
	for i in range(steps+1):
		if i>0:
			if normal.is_equal_approx(h.wall_normal): edge=h.ledge_edge+(-normal).cross(Vector3.UP).normalized()*side*distance*float(i)/steps
			else: edge+=(-normal).cross(Vector3.UP).normalized()*side*distance/steps
		var point:=probe(h,edge,normal)
		result.samples.append(point)
		if not point.valid: result.reason=point.reason; return result
		var total: float=rad_to_deg(acos(clampf(Vector3(point.normal).dot(h.wall_normal),-1,1)))
		result.curve_delta=maxf(result.curve_delta,total)
		if total>h.lateral_max_total_turn: result.reason="CURVE_TOO_TIGHT"; return result
		edge=point.edge
		normal=point.normal
		# Retain the exact starting anchor, including existing catch alignment.
		if i==0: point.anchor=h.alignment
		if not h.clear_segment(previous,point.anchor,h.motor.crouch.standing_capsule_height): result.reason="BODY_OR_HEAD_BLOCKED"; return result
		previous=point.anchor
	result.target=previous
	result.valid=true
	result.reason="VALID"
	result.brace=true
	result.clearance=true
	return result

func at_distance(points: Array,distance: float,total: float) -> Dictionary:
	var index: float=clampf(distance/maxf(.00001,total),0,1)*(points.size()-1)
	var low: int=mini(int(index),points.size()-2)
	var p: float=index-low
	return {"edge":Vector3(points[low].edge).lerp(points[low+1].edge,p),"anchor":Vector3(points[low].anchor).lerp(points[low+1].anchor,p),"normal":Vector3(points[low].normal).slerp(points[low+1].normal,p).normalized()}
