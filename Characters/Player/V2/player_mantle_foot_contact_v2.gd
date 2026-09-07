extends RefCounted
## Penetration-only visual offsets. No controller, collision or source-pose writes.
static func project(controller: Node,leg: Dictionary,pose: Transform3D) -> Dictionary:
	if controller.motor.traversal.hang.is_attached(): return controller.motor.traversal.hang.project_foot(controller,leg,pose)
	var mantle=controller.motor.traversal.mantle
	var result: Dictionary={"valid":false,"target":pose.origin,"hit":pose.origin,"weight":0.0,"mode":"NONE","normal":Vector3.ZERO,"penetration":0.0,"amount":0.0,"limited":false,"blend_speed":controller.wall_ik_blend_speed}
	if not controller.climb_foot_ik_enabled or not controller.enabled or not mantle.pose_owned(): return result
	if mantle.owner_controller.phase!=mantle.owner_controller.Phase.ACTIVE: return result
	if not is_instance_valid(mantle.source): return result
	var frame: float=mantle.current_frame()
	var toe_index: int=controller.skeleton.find_bone("mixamorig_"+leg.side+"ToeBase")
	var toe: Vector3=controller._world(toe_index).origin if toe_index>=0 else pose.origin
	# Top timing is relative to the existing hoist, not a second animation clock.
	var hoist: float=inverse_lerp(mantle.mantle_hoist_start_frame,mantle.mantle_hoist_end_frame,frame)
	var top_envelope: float=smoothstep(controller.top_foot_phase_start,controller.top_foot_phase_full,hoist)
	if top_envelope>0:
		var top_normal: Vector3=mantle.landing_plane_normal.normalized()
		# Reuse the existing ankle/sole estimate, plus the authored toe sample.
		var sole: Vector3=pose.origin-top_normal*controller.feet.foot_sole_offset
		result=_surface(controller,leg,pose,[sole,toe],mantle.top,top_normal,controller.top_surface_clearance,controller.max_top_foot_correction,top_envelope,"LEDGE_TOP",controller.top_ik_blend_speed)
		if result.valid: return result
	var envelope: float=smoothstep(controller.climb_foot_blend_in_start,controller.climb_foot_blend_in_end,frame)*(1.0-smoothstep(controller.climb_foot_blend_out_start,controller.climb_foot_blend_out_end,frame))
	if envelope>0:
		return _surface(controller,leg,pose,[pose.origin,toe],mantle.wall_point,mantle.wall_normal.normalized(),controller.climb_foot_wall_offset,controller.climb_foot_max_correction,envelope,"WALL",controller.wall_ik_blend_speed)
	return result

static func _surface(controller: Node,leg: Dictionary,pose: Transform3D,samples: Array,plane_point: Vector3,normal: Vector3,clearance: float,cap: float,envelope: float,mode: String,blend_speed: float,geometry: Node=null) -> Dictionary:
	var result: Dictionary={"valid":false,"target":pose.origin,"hit":pose.origin,"weight":0.0,"mode":"NONE","normal":normal,"penetration":0.0,"amount":0.0,"limited":false,"blend_speed":blend_speed}
	var mantle=geometry if geometry!=null else controller.motor.traversal.mantle
	for sample: Vector3 in samples:
		var depth: float=-(sample-plane_point).dot(normal)
		if depth<=0 or depth<=result.penetration: continue
		var projected: Vector3=sample+normal*depth
		# A short local ray only confirms that the known surface actually exists
		# under this sample: never lift a foot outside the finite ledge footprint.
		var query:=PhysicsRayQueryParameters3D.create(projected+normal*.05,projected-normal*.05,controller.motor.collision_mask,[controller.motor.get_rid()])
		var hit: Dictionary=controller.motor.get_world_3d().direct_space_state.intersect_ray(query)
		if hit.is_empty() or hit.collider!=mantle.source or hit.normal.dot(normal)<.98: continue
		result.penetration=depth
		result.hit=projected
	if result.penetration<=0: return result
	var amount: float=minf(result.penetration+clearance,cap)
	var correction: Vector3=normal*amount
	var hip: Vector3=controller._world(leg.bones[0]).origin
	var knee: Vector3=controller._world(leg.bones[1]).origin
	var reach: float=hip.distance_to(knee)+knee.distance_to(pose.origin)
	var target: Vector3=pose.origin+correction
	# Reduce along the correction normal rather than redirecting toward the hip.
	if hip.distance_to(target)>reach*.995:
		if hip.distance_to(pose.origin)>reach*.995: return result
		var low: float=0
		var high: float=1
		for i in 10:
			var mid: float=(low+high)*.5
			if hip.distance_to(pose.origin+correction*mid)<=reach*.995: low=mid
			else: high=mid
		correction*=low
		target=pose.origin+correction
	# Keep the authored side of the leg and its knee pole; no lateral crossing.
	var lateral: Vector3=controller.motor.visual.global_basis.x.normalized()
	var authored_side: float=(pose.origin-hip).dot(lateral)
	if absf(authored_side)>.02 and authored_side*(target-hip).dot(lateral)<0: return result
	if correction.length()<.001: return result
	result.valid=true
	result.mode=mode
	result.target=target
	result.amount=correction.length()
	result.limited=result.amount+.001<result.penetration+clearance
	result.weight=envelope*smoothstep(0,controller.climb_penetration_full_weight_depth,result.penetration)*controller.climb_foot_strength
	return result
