extends RefCounted
## Visual contact projection only. Reuses the existing native leg chains.
static func project(controller: Node,leg: Dictionary,pose: Transform3D) -> Dictionary:
	var mantle=controller.motor.traversal.mantle
	var result: Dictionary={"valid":false,"target":pose.origin,"hit":pose.origin,"weight":0.0}
	if not controller.climb_foot_ik_enabled or not controller.enabled or not mantle.pose_owned(): return result
	if mantle.owner_controller.phase!=mantle.owner_controller.Phase.ACTIVE: return result
	var frame: float=mantle.current_frame()
	var envelope: float=smoothstep(controller.climb_foot_blend_in_start,controller.climb_foot_blend_in_end,frame)*(1.0-smoothstep(controller.climb_foot_blend_out_start,controller.climb_foot_blend_out_end,frame))
	if envelope<=0: return result
	var normal: Vector3=mantle.wall_normal
	var toe_index: int=controller.skeleton.find_bone("mixamorig_"+leg.side+"ToeBase")
	var toe: Vector3=controller._world(toe_index).origin if toe_index>=0 else pose.origin
	# Project the deepest authored ankle/toe sample. Preserve authored rotation,
	# moving the complete foot outward enough to protect its toe as well.
	var sample: Vector3=toe if (toe-mantle.wall_point).dot(normal)<(pose.origin-mantle.wall_point).dot(normal) else pose.origin
	var signed_distance: float=(sample-mantle.wall_point).dot(normal)
	if absf(signed_distance)>controller.climb_foot_projection_distance: return result
	var plane: Vector3=sample-normal*signed_distance
	var query:=PhysicsRayQueryParameters3D.create(plane+normal*controller.climb_foot_projection_distance,plane-normal*controller.climb_foot_projection_distance,controller.motor.collision_mask,[controller.motor.get_rid()])
	var hit: Dictionary=controller.motor.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty() or hit.collider!=mantle.source or hit.normal.dot(normal)<.9: return result
	result.hit=hit.position
	var amount: float=controller.climb_foot_wall_offset-(sample-hit.position).dot(normal)
	var correction: Vector3=normal*clampf(amount,-controller.climb_foot_max_correction,controller.climb_foot_max_correction)
	var target: Vector3=pose.origin+correction
	var hip: Vector3=controller._world(leg.bones[0]).origin
	var knee: Vector3=controller._world(leg.bones[1]).origin
	var reach: float=hip.distance_to(knee)+knee.distance_to(pose.origin)
	# Reject unreachable contacts, never stretch or push the foot across the body.
	if hip.distance_to(target)>reach*.995: return result
	var lateral: Vector3=normal.cross(Vector3.UP).normalized()
	if absf(correction.dot(lateral))>.001: return result
	result.valid=true
	result.target=target
	result.weight=envelope*controller.climb_foot_strength
	return result
