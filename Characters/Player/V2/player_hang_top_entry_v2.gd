extends "res://interaction/context_interactable.gd"
## Deliberate E-only entry. Owns a private full clip; Catch keeps its short tail.
const ACTION: StringName=&"HangTopEntry_Full"
const SOURCE: StringName=&"TRV_JUMPING_TO_BRACED_HANG"
@export_range(.3,1,.05) var top_down_hang_prompt_distance: float=.7
@export_range(0,.3,.01) var top_down_hang_lateral_tolerance: float=.15
@export_range(10,70,5) var top_down_hang_facing_tolerance: float=50
@export_range(6,18,1) var animation_contact_frame: float=9
@export_range(1,14,1) var hand_blend_start_frame: float=12
@export_range(.1,.6,.05) var maximum_positional_correction: float=.45
var h: Node
var active: bool=false
var clock: float=0
var length: float=1.533333
var result: Dictionary={"valid":false,"reason":"NOT_QUERIED"}
var committed: Dictionary={}
var hips: Array[Vector3]=[]
var turns: Array[float]=[]
var launch_yaw: float=0

func _ready() -> void:
	h=get_parent()
	top_down_hang_prompt_distance=h.top_down_hang_prompt_distance
	top_down_hang_lateral_tolerance=h.top_down_hang_lateral_tolerance
	top_down_hang_facing_tolerance=h.top_down_hang_facing_tolerance
	animation_contact_frame=h.top_down_hang_contact_frame
	hand_blend_start_frame=h.top_down_hang_hand_blend_frame
	maximum_positional_correction=h.top_down_hang_max_hand_correction
	action_text="Drop into Braced Hang"
	interaction_type=Type.LEDGE
	priority=2
	requires_line_of_sight=false # Full capsule sweep + bilateral contacts replace LOS.
	super._ready()

func can_interact(player: Node) -> bool:
	return player==h.motor and not active and result.get("valid",false) and h.owner_controller.can_begin(true)

func get_interaction_point() -> Vector3:
	return result.get("edge",h.motor.global_position)

func begin_interaction(_player: Node) -> bool:
	refresh()
	if not result.get("valid",false): return false
	return h.owner_controller.request_contextual_traversal(result)

func refresh() -> void:
	if active: return
	result={"valid":false,"grounded":h.motor.is_on_floor(),"reason":"NOT_GROUNDED","path_valid":false}
	if not h.enabled or not h.owner_controller.can_begin(true): return
	if h.motor.crouch.active(): result.reason="STAND_FIRST"; return
	if hips.is_empty(): result.reason="CLIP_NOT_PREPARED"; return
	var start: Vector3=h.motor.global_position
	var forward: Vector3=-h.motor.visual.global_basis.z
	forward.y=0
	forward=forward.normalized()
	var ground: Dictionary=h.ray(start+Vector3.UP*.15,start-Vector3.UP*.15)
	if ground.is_empty() or ground.normal.y<.98: result.reason="NO_LEVEL_LAUNCH"; return
	# Search forward from the actual launch; no pre-alignment or teleport needed.
	for angle in [0.0,-25.0,25.0,-50.0,50.0]:
		if absf(angle)>top_down_hang_facing_tolerance: continue
		var direction:=forward.rotated(Vector3.UP,deg_to_rad(angle))
		var previous: float=0
		for step in range(1,ceili(top_down_hang_prompt_distance/.025)+1):
			var distance: float=minf(step*.025,top_down_hang_prompt_distance)
			var probe: Vector3=start+direction*distance
			var support: Dictionary=h.ray(probe+Vector3.UP*.12,probe-Vector3.UP*.12)
			if support.is_empty():
				var low: float=previous
				var high: float=distance
				for refine in 8:
					var mid: float=(low+high)*.5
					var p: Vector3=start+direction*mid
					if h.ray(p+Vector3.UP*.12,p-Vector3.UP*.12).is_empty(): high=mid
					else: low=mid
				var edge: Vector3=start+direction*((low+high)*.5)
				edge.y=ground.position.y
				var face: Dictionary=h.ray(edge-Vector3.UP*.08+direction*.16,edge-Vector3.UP*.08-direction*.16)
				if face.is_empty() or face.collider!=ground.collider or absf(face.normal.y)>.05: result.reason="NO_WALL"; break
				var normal: Vector3=face.normal
				var facing_angle: float=rad_to_deg(acos(clampf(forward.dot(normal),-1,1)))
				if facing_angle>top_down_hang_facing_tolerance: result.reason="FACING"; break
				edge=Vector3(face.position.x,edge.y,face.position.z)
				# Project launch onto the wall plane; tolerate only a small oblique offset.
				var tangent: Vector3=(-normal).cross(Vector3.UP).normalized()
				var lateral: float=(start-edge).dot(tangent)
				if absf(lateral)>top_down_hang_lateral_tolerance:
					if not result.has("edge"): result.reason="LATERAL_RANGE"
					break
				edge+=tangent*lateral
				var data: Dictionary={"valid":false,"grounded":true,"top_down_hang":true,"braced_hang":true,"type":Type.LEDGE,"requires_grounded":true,"source":face.collider,"edge":edge,"top":edge,"normal":normal,"top_normal":ground.normal,"facing":-normal,"anchor":edge+normal*h.body_distance_from_wall-Vector3.UP*h.hang_vertical_offset,"start":start,"distance":start.distance_to(edge),"angle":facing_angle,"path_valid":false,"reason":"CONTACT_INVALID","entry_gait":h.motor.animation_state.gait,"entry_run_time":h.motor._run_time}
				# Same local surface/brace predicate used by lateral traversal; read-only proxy.
				if not contacts(data): result=data; break
				data.valid=validate_path(data)
				data.path_valid=data.valid
				data.reason="VALID" if data.valid else "PATH_OR_ANCHOR_BLOCKED"
				result=data
				if data.valid: return
				break
			previous=distance
	if result.reason=="NOT_GROUNDED": result.reason="NO_LOCAL_EDGE"

func contacts(data: Dictionary) -> bool:
	# Use shared contact validation without changing the active hang's state.
	return h.validate_contacts(data.source,data.edge,data.top,data.normal,data.top_normal)

func sample(frame: float) -> Vector3:
	var f: float=clampf(frame,0,hips.size()-1)
	var i: int=mini(int(f),hips.size()-2)
	return hips[i].lerp(hips[i+1],f-i)

func position_at(data: Dictionary,frame: float) -> Vector3:
	var contact: float=animation_contact_frame
	# Compact turn/drop: no takeoff rise, overshoot or return arc. Clear the
	# lip first, then descend. Preflight and execution use this identical path.
	var clearance_frame: float=contact*.375
	var horizontal: float=smoothstep(0,clearance_frame,frame)
	var drop: float=smoothstep(clearance_frame,contact,frame)
	var point: Vector3=Vector3(data.start).lerp(data.anchor,horizontal)
	point.y=lerpf(data.start.y,data.anchor.y,drop)
	return point

func validate_path(data: Dictionary) -> bool:
	var previous: Vector3=data.start
	var path: Array[Vector3]=[previous]
	for i in range(1,97):
		var target:=position_at(data,animation_contact_frame*i/96.0)
		path.append(target)
		if not h.clear_segment(previous,target,h.motor.crouch.standing_capsule_height): data["path"]=path; return false
		previous=target
	data["path"]=path
	return true

func visual_position_at(data: Dictionary,source_frame: float) -> Vector3:
	# Linear MODEL origin only; physics continues to sweep around the lip.
	return Vector3(data.start).lerp(data.anchor,clampf(source_frame/animation_contact_frame,0,1))

func visual_offset() -> Vector3:
	if not active: return Vector3.ZERO
	return visual_position_at(committed,frame())-h.motor.global_position

func validate(data: Dictionary) -> bool:
	return data.get("valid",false) and is_instance_valid(data.get("source")) and h.motor.global_position.distance_to(data.start)<.01 and contacts(data) and validate_path(data)

func begin(data: Dictionary) -> void:
	committed=data.duplicate(true)
	launch_yaw=h.motor.visual.rotation.y
	h.begin(data)
	active=true
	clock=0
	h.hang_phase=h.HangPhase.TOP_ENTRY
	h.motor.get_node("AnimationController")._enter(&"HangTopEntry")

func frame() -> float: return clock*30
func hand_weight() -> float: return smoothstep(hand_blend_start_frame,maxf(16,hand_blend_start_frame+1),frame())
func foot_weight() -> float: return smoothstep(16,30,frame())

func step(delta: float) -> bool:
	if not is_instance_valid(h.source) or not h.source.global_transform.is_equal_approx(h.source_transform) or not contacts(committed):
		h.owner_controller.finish("TOP_ENTRY_SOURCE_LOST")
		return false
	var a=h.motor.get_node("AnimationController")
	if a._playback.get_current_node()==&"HangTopEntry": clock=a._playback.get_current_play_position()*h.top_down_hang_playback_speed
	else: clock+=delta*h.top_down_hang_playback_speed
	var target:=position_at(committed,frame())
	if not h.clear_segment(h.motor.global_position,target,h.motor.crouch.standing_capsule_height):
		h.owner_controller.finish("TOP_ENTRY_BLOCKED")
		return false
	if h.motor.move_and_collide(target-h.motor.global_position)!=null and h.motor.global_position.distance_to(target)>.02:
		h.owner_controller.finish("TOP_ENTRY_COLLISION")
		return false
	# One direct eased twist, not the source's looping/reversing yaw profile.
	var turn: float=smoothstep(0,animation_contact_frame,frame())
	h.motor.visual.rotation.y=lerp_angle(launch_yaw,atan2(-h.facing.x,-h.facing.z),turn)
	h.motor.velocity=Vector3.ZERO
	h.elapsed=h.settle_duration*hand_weight()
	var s=h.motor.animation_state
	s.is_grounded=false
	s.is_airborne=true
	s.jump_started=false
	s.horizontal_speed=0
	s.vertical_velocity=0
	s.move_input_magnitude=0
	if clock>=length-.0001:
		active=false
		h.elapsed=h.settle_duration
		h.hang_phase=h.HangPhase.IDLE
		h.navigation.invalidate()
	return true

func prepare(player: AnimationPlayer,reference: Vector3,idle_z: float) -> void:
	var clip: Animation=player.get_animation(SOURCE).duplicate(true)
	player.get_animation_library(player.find_animation_library(player.get_animation(SOURCE))).add_animation(ACTION,clip)
	clip.loop_mode=Animation.LOOP_NONE
	length=clip.length
	var track: int=h.hip_track(clip)
	var rotation_track: int=-1
	for t in clip.get_track_count():
		if clip.track_get_type(t)==Animation.TYPE_ROTATION_3D and str(clip.track_get_path(t)).ends_with(":mixamorig_Hips"): rotation_track=t
	var skeleton: Skeleton3D=h.motor.get_node("AnimationController").rig.get_node("Base Armature and Mesh/Skeleton3D")
	var import_basis: Basis=skeleton.global_basis
	var angles: Array[float]=[]
	for i in range(ceili(length*30)+1):
		hips.append(clip.position_track_interpolate(track,minf(i/30.0,length)))
		var q: Quaternion=clip.rotation_track_interpolate(rotation_track,minf(i/30.0,length))
		var right: Vector3=import_basis*(q*Vector3.RIGHT)
		var yaw: float=atan2(-right.z,right.x)
		if not angles.is_empty(): yaw=angles.back()+wrapf(yaw-angles.back(),-PI,PI)
		angles.append(yaw)
	var contact_index: int=int(animation_contact_frame)
	var span: float=angles[contact_index]-angles[0]
	for i in angles.size(): turns.append(clampf((angles[i]-angles[0])/span,0,1) if absf(span)>.1 else smoothstep(0,animation_contact_frame,i))
	# Remove only authored world-yaw from the private pelvis rotation. Motor
	# applies the sampled turn once, retargeted from actual launch orientation.
	var axis: Vector3=(import_basis.inverse()*Vector3.UP).normalized()
	var idle: Animation=player.get_animation(&"TRV_BRACED_HANG_IDLE")
	var idle_track: int=idle.find_track(clip.track_get_path(rotation_track),Animation.TYPE_ROTATION_3D)
	var idle_rotation: Quaternion=idle.rotation_track_interpolate(idle_track,0)
	var idle_right: Vector3=import_basis*(idle_rotation*Vector3.RIGHT)
	var idle_yaw: float=atan2(-idle_right.z,idle_right.x)
	for k in clip.track_get_key_count(rotation_track):
		var time: float=clip.track_get_key_time(rotation_track,k)
		var index: int=mini(roundi(time*30),angles.size()-1)
		var q: Quaternion=clip.track_get_key_value(rotation_track,k)
		clip.track_set_key_value(rotation_track,k,Quaternion(axis,idle_yaw-angles[index])*q)
	var last: Vector3=hips.back()
	for k in clip.track_get_key_count(track):
		var value: Vector3=clip.track_get_key_value(track,k)
		value.x=reference.x
		value.y=reference.y
		value.z+=idle_z-last.z
		clip.track_set_key_value(track,k,value)

func debug_text() -> String:
	return "TOP DOWN: grounded %s / candidate %s / prompt %s\nDistance %.3f / Angle %.1f / Path %s / %s\nAnchor %s / Normal %s\nSource frame %.1f / Hand %.2f / %s" % [h.motor.is_on_floor(),result.has("edge"),result.get("valid",false),result.get("distance",0.0),result.get("angle",0.0),result.get("path_valid",false),result.get("reason","NONE"),result.get("anchor",Vector3.ZERO),result.get("normal",Vector3.ZERO),frame(),hand_weight(),"COMMITTED" if active else "QUERY"]

func draw(debug: Node) -> void:
	var data: Dictionary=committed if active else result
	if not data.has("edge"): return
	var color: Color=Color.GREEN if data.get("valid",false) else Color.RED
	var tangent: Vector3=Vector3(data.facing).cross(Vector3.UP)
	debug.line(data.edge-tangent*.28,data.edge+tangent*.28,color)
	debug.line(data.edge,data.edge-Vector3.UP*1.5,Color.GRAY)
	debug.cross_at(data.start,Color.YELLOW)
	debug.cross_at(data.anchor,Color.CYAN)
	debug.arrow(data.anchor,data.anchor+data.facing*.5,Color.BLUE)
	debug.cross_at(position_at(data,animation_contact_frame),Color.MAGENTA,.12)
	for side in [-1,1]: debug.cross_at(data.edge+tangent*.25*side+Vector3.UP*h.braced_hang_hand_vertical_offset+data.normal*h.braced_hang_hand_wall_offset,Color.GREEN)
	var path: Array=data.get("path",[])
	for i in range(1,path.size()): debug.line(path[i-1],path[i],color)
