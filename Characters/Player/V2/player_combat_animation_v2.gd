extends RefCounted
## Canonical directional clips from the corrected master rig.
const CLIPS := {
	"Idle":"IDL_IDLE_D", "WalkForward":"LOC_WALKING",
	"WalkBack":"LOC_WALKING_BACKWARDS", "WalkLeft":"LOC_LEFT_STRAFE_WALKING", "WalkRight":"LOC_RIGHT_STRAFE_WALKING",
	"RunForward":"LOC_RUNNING_FOWARD_A", "RunBack":"LOC_RUNNING_BACKWARDS",
	"RunLeft":"LOC_LEFT_STRAFE", "RunRight":"LOC_RIGHT_STRAFE"}
var gait_blend: float = 0.0
var move_blend := Vector2(0,1)
var raw_combat_move_input := Vector2.ZERO
var _gait_target: float = 0.0
var _gait_start: float = 0.0
var _gait_time: float = 0.0
var _gait_duration: float = 0.15
var _direction_space: AnimationNodeBlendSpace2D

func prepare(player: AnimationPlayer,reference: Vector3) -> bool:
	for name: String in CLIPS.values():
		if not player.has_animation(name):
			push_error("Combat missing canonical clip: "+name)
			return false
		var clip:=player.get_animation(name)
		clip.loop_mode=Animation.LOOP_LINEAR
		# Same instance-local, in-place policy as Free. Keep authored vertical motion.
		for track in clip.get_track_count():
			if clip.track_get_type(track)!=Animation.TYPE_POSITION_3D or not String(clip.track_get_path(track)).ends_with(":mixamorig_Hips"): continue
			for key in clip.track_get_key_count(track):
				var value: Vector3=clip.track_get_key_value(track,key)
				value.x=reference.x
				value.y=reference.y
				clip.track_set_key_value(track,key,value)
	return true

func clip(name: String) -> AnimationNodeAnimation:
	var node:=AnimationNodeAnimation.new()
	node.animation=CLIPS[name]
	return node

func directional(prefix: String) -> AnimationNodeBlendSpace2D:
	var space:=AnimationNodeBlendSpace2D.new()
	space.sync_mode=AnimationNodeBlendSpace2D.SYNC_MODE_CYCLIC_MUTABLE
	var directions:={"Forward":Vector2(0,1),"Back":Vector2(0,-1),"Left":Vector2(-1,0),"Right":Vector2(1,0)}
	for side in directions:
		var position: Vector2=directions[side]
		space.add_blend_point(clip(prefix+side),position,-1,StringName(side))
	if prefix=="Walk": _direction_space=space
	return space

func direction_weights() -> Vector4:
	# Read the actual auto-triangulation. Outside the cardinal diamond, the
	# BlendSpace uses the closest edge; do not invent weights from raw input.
	var point:=move_blend
	if absf(point.x)+absf(point.y)>1:
		var corners:=[Vector2(0,1),Vector2(1,0),Vector2(0,-1),Vector2(-1,0)]
		var nearest:=Vector2.ZERO
		var best:=INF
		for i in 4:
			var candidate:=Geometry2D.get_closest_point_to_segment(point,corners[i],corners[(i+1)%4])
			if point.distance_squared_to(candidate)<best:
				best=point.distance_squared_to(candidate)
				nearest=candidate
		point=nearest
	if _direction_space==null: return Vector4.ZERO
	for t in _direction_space.get_triangle_count():
		var indices:=[_direction_space.get_triangle_point(t,0),_direction_space.get_triangle_point(t,1),_direction_space.get_triangle_point(t,2)]
		var a:=_direction_space.get_blend_point_position(indices[0])
		var b:=_direction_space.get_blend_point_position(indices[1])
		var c:=_direction_space.get_blend_point_position(indices[2])
		var area:=(b-a).cross(c-a)
		if absf(area)<0.00001: continue
		var wb:=(point-a).cross(c-a)/area
		var wc:=(b-a).cross(point-a)/area
		var wa:=1-wb-wc
		if minf(wa,minf(wb,wc))< -0.0001: continue
		var weights:=Vector4.ZERO
		weights[indices[0]]=maxf(wa,0)
		weights[indices[1]]=maxf(wb,0)
		weights[indices[2]]=maxf(wc,0)
		return weights
	return Vector4.ZERO

func build() -> AnimationNodeBlendSpace1D:
	var space:=AnimationNodeBlendSpace1D.new()
	space.min_space=0
	space.max_space=2
	space.sync_mode=AnimationNodeBlendSpace1D.SYNC_MODE_INDEPENDENT
	space.add_blend_point(clip("Idle"),0,-1,&"Idle")
	space.add_blend_point(directional("Walk"),1,-1,&"Walk")
	space.add_blend_point(directional("Run"),2,-1,&"Run")
	return space

func update(tree: AnimationTree,s,delta: float,tuning: Node=null) -> void:
	var target: float=0.0 if s.combat_input.length()<0.01 else (2.0 if s.gait==1 else 1.0)
	if tuning!=null and tuning.motor.crouch.standing_handoff():
		var crouch=tuning.motor.crouch
		target=(2.0 if crouch.current_shift else 1.0) if crouch.moving_requested() else 0.0
		if crouch.handoff_this_tick:
			# The outgoing crouch clip supplies the blend, not an Idle bridge.
			gait_blend=target
			_gait_target=target
			_gait_start=target
			_gait_time=0.0
			move_blend=s.combat_input.normalized() if crouch.moving_requested() else Vector2(0,1)
	raw_combat_move_input=s.combat_input
	if target!=_gait_target:
		_gait_start=gait_blend
		_gait_time=0.0
		_gait_duration=0.2
		if tuning!=null:
			if target==0: _gait_duration=tuning.lock_move_to_idle_blend
			elif _gait_target==0: _gait_duration=tuning.lock_idle_to_move_blend
			elif target>_gait_target: _gait_duration=tuning.lock_walk_to_run_blend
			else: _gait_duration=tuning.lock_run_to_walk_blend
		_gait_target=target
	_gait_time+=delta
	gait_blend=lerpf(_gait_start,_gait_target,smoothstep(0,1,clampf(_gait_time/maxf(_gait_duration,0.001),0,1)))
	if s.combat_input.length()>0.01:
		var speed: float=tuning.lock_direction_blend_speed if tuning!=null else 15.0
		move_blend=move_blend.lerp(s.combat_input.normalized(),1-exp(-speed*delta))
	tree.set("parameters/Locomotion/Locked/blend_position",gait_blend)
	tree.set("parameters/Locomotion/Locked/Walk/blend_position",move_blend)
	tree.set("parameters/Locomotion/Locked/Run/blend_position",move_blend)

func label(s) -> String:
	if s.combat_input.length()<0.01: return CLIPS.Idle
	var prefix: String="Run" if s.gait==1 else "Walk"
	var side: String=("Right" if s.combat_input.x>0 else "Left") if absf(s.combat_input.x)>absf(s.combat_input.y) else ("Forward" if s.combat_input.y>0 else "Back")
	return CLIPS[prefix+side]+" (directional blend)"
