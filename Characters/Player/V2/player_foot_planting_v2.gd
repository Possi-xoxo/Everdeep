extends RefCounted
## Per-leg presentation state, sampled exclusively from the pre-IK pose.
var support_confidence: float = 0.0
var idle_forced_support: bool = false
var raw_support: float = 0.0
var height_error: float = 0.0
var vertical_speed: float = 0.0
var horizontal_speed: float = 0.0
var swing_speed: float = 0.0
var locked: bool = false
var locked_world_position := Vector3.ZERO
var lock_blend: float = 0.0
var lock_armed: bool = true
var release_reason: String = "NONE"
var lock_count: int = 0
var support_queries: int = 0
var _previous_local := Vector3.ZERO
var _have_previous: bool = false
var _previous_body := Vector3.ZERO
var _collider_id: int = 0
var _collider_transform := Transform3D.IDENTITY

func update(c: Node, data: RefCounted, pose: Transform3D, delta: float, usable: bool) -> Vector3:
	var idle_now: bool=usable and c.idle_support_allowed(data)
	var leaving_idle: bool=idle_forced_support and not idle_now
	idle_forced_support=idle_now
	if _have_previous and c.motor.global_position.distance_to(_previous_body)>0.75:
		release_lock("TELEPORT")
		support_confidence=0
		lock_blend=0
		lock_armed=true
		_have_previous=false
	_previous_body=c.motor.global_position
	var local: Vector3=c.motor.visual.to_local(pose.origin)
	var velocity:=Vector3.ZERO
	if _have_previous and delta>0: velocity=(local-_previous_local)/delta
	_previous_local=local
	_have_previous=true
	vertical_speed=velocity.y
	horizontal_speed=Vector2(velocity.x,velocity.z).length()
	var movement: Vector3=c.motor.velocity
	movement.y=0
	var moving: bool=c.motor.animation_state.move_input_magnitude>0.01 and movement.length()>0.1
	# A stance foot travels BACKWARD in root space. Only forward stride/lateral
	# motion is swing evidence; raw relative speed remains available in debug.
	var local_direction: Vector3=c.motor.visual.global_basis.inverse()*movement.normalized()
	var horizontal:=Vector3(velocity.x,0,velocity.z)
	var forward_speed:=horizontal.dot(local_direction)
	var sideways:=horizontal-local_direction*forward_speed
	swing_speed=maxf(maxf(0,forward_speed),sideways.length()) if moving else horizontal_speed
	var terrain_target: Vector3=data.ankle_target_transform.origin if data.valid else pose.origin
	height_error=pose.origin.y-terrain_target.y
	# Separate animated stride lift from a body elevated above the lower stair.
	# The existing pelvis budget may cover terrain separation, never stride lift.
	var pelvis_allowance: float=c.max_pelvis_drop*c.pelvis_ik_weight if c.pelvis_enabled else 0.0
	var height:=maxf(0,maxf(local.y-c.feet.foot_sole_offset,height_error-pelvis_allowance))
	var height_weight:=1.0-smoothstep(c.plant_height_threshold,c.plant_height_threshold*2,height)
	var vertical_weight:=1.0-smoothstep(c.plant_max_vertical_speed,c.plant_max_vertical_speed*2,absf(vertical_speed))
	var horizontal_weight:=1.0-smoothstep(c.plant_max_horizontal_speed,c.plant_max_horizontal_speed*2,swing_speed)
	var animation=c.motor.get_node("AnimationController")
	var ordinary: bool=animation.current_state==&"Locomotion" and animation.grounded.transition==&"Loops" and not c.motor.turn_180.active
	raw_support=height_weight*vertical_weight*horizontal_weight if usable else 0.0
	if idle_forced_support: raw_support=1.0
	if not ordinary: raw_support=minf(raw_support,0.25)
	var speed: float=c.plant_confidence_rise_speed if raw_support>support_confidence else c.plant_confidence_fall_speed
	support_confidence=lerpf(support_confidence,raw_support,1-exp(-speed*delta))
	if support_confidence<0.001: support_confidence=0
	var release: String=""
	if not usable: release="NO_SUPPORT_OR_AIRBORNE"
	elif leaving_idle: release="IDLE_EXIT"
	elif not c.foot_lock_enabled or not ordinary or c.grounded_contact_weight()<0.001: release="ACTION_OR_DISABLED"
	elif not idle_forced_support and vertical_speed>c.plant_max_vertical_speed: release="RISING"
	elif not idle_forced_support and swing_speed>c.plant_max_horizontal_speed: release="SWING"
	elif not idle_forced_support and support_confidence<c.foot_unlock_threshold: release="CONFIDENCE"
	elif locked:
		var distance: Vector3=locked_world_position-pose.origin
		if idle_forced_support: distance-=Vector3.UP*c.pelvis.applied_offset
		if distance.length()>c.max_foot_lock_distance or Vector2(distance.x,distance.z).length()>c.max_foot_ik_horizontal_correction:
			release="REACH_BUDGET"
		elif not _lock_supported(c): release="LOCK_SUPPORT_LOST"
	if locked and not release.is_empty():
		release_lock(release)
	# One acquisition per support phase; reaching a limit cannot cause chatter.
	if raw_support<0.2: lock_armed=true
	var collider=instance_from_id(data.collider_id) if data.valid else null
	if not locked and lock_armed and not leaving_idle and c.foot_lock_enabled and c.grounded_contact_weight()>0.001 and ordinary and usable and support_confidence>=c.foot_lock_threshold and raw_support>=c.foot_lock_threshold and (idle_forced_support or (vertical_speed<=c.plant_max_vertical_speed and swing_speed<=c.plant_max_horizontal_speed)) and collider is StaticBody3D and not collider is AnimatableBody3D:
		locked=true
		locked_world_position=terrain_target
		_collider_id=data.collider_id
		_collider_transform=collider.global_transform
		lock_count+=1
		release_reason="NONE"
	lock_blend=lerpf(lock_blend,1.0 if locked else 0.0,1-exp(-(c.plant_confidence_rise_speed if locked else c.plant_confidence_fall_speed)*delta))
	if lock_blend<0.001: lock_blend=0
	# Unsupported/world-invalid anchors never drive targets during release.
	if not usable or not ordinary or release=="LOCK_SUPPORT_LOST" or leaving_idle: lock_blend=0
	if locked: terrain_target.y=locked_world_position.y
	return terrain_target.lerp(locked_world_position,lock_blend)

func release_lock(why: String) -> void:
	locked=false
	lock_armed=false
	release_reason=why

func _lock_supported(c: Node) -> bool:
	var collider=instance_from_id(_collider_id)
	if not is_instance_valid(collider) or not collider.global_transform.is_equal_approx(_collider_transform): return false
	# The existing ray follows the animated foot, not the old anchor. One extra
	# short ray ONLY while locked is necessary to detect a removed/empty anchor.
	var q:=PhysicsRayQueryParameters3D.create(locked_world_position+Vector3.UP*0.03,locked_world_position-Vector3.UP*(c.feet.foot_sole_offset+0.04),c.feet.ground_collision_mask & c.motor.collision_mask,[c.motor.get_rid()])
	var hit: Dictionary=c.motor.get_world_3d().direct_space_state.intersect_ray(q)
	support_queries+=1
	return not hit.is_empty() and hit.collider_id==_collider_id and hit.normal.dot(Vector3.UP)>=cos(c.motor.floor_max_angle) and absf(hit.position.y+c.feet.foot_sole_offset-locked_world_position.y)<0.025

func debug_text() -> String:
	return "Support: %.2f / Idle Forced: %s / Locked: %s\nHeight: %+.3fm / Vertical: %+.2fm/s\nRelative H: %.2f / Swing: %.2f / %s" % [support_confidence,idle_forced_support,locked,height_error,vertical_speed,horizontal_speed,swing_speed,release_reason]
