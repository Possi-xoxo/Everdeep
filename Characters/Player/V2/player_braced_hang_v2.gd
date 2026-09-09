extends Node
## Automatic braced hang and committed static-ledge traversal. No Free Hang.
enum HangPhase { NONE, CATCH, SETTLE, IDLE, TO_CROUCH, RELEASE, LATERAL, VERTICAL, JUMP_OFF, TOP_ENTRY, OUTWARD }
@export_group("Outward Hang Transfer")
## False uses the normal wall-jump impulse and ordinary airborne ledge catch.
## Changing this during a committed transfer affects the next jump only.
@export var automatic_ledge_to_ledge_jump_enabled: bool=false
@export_range(1,5,.1) var braced_hang_transfer_outward_max_distance: float=3.3
@export_range(.1,1,.05) var braced_hang_transfer_outward_max_vertical_difference: float=.5
@export_range(5,45,1) var braced_hang_transfer_outward_horizontal_angle: float=30
@export_range(5,40,1) var braced_hang_transfer_outward_vertical_angle: float=25
@export_range(0,1,.05) var braced_hang_transfer_directional_input_bias: float=.6
@export_range(1,2.5,.05) var braced_hang_outward_transfer_max_motion_scale: float=1.8
@export_range(.5,2,.1) var outward_min_distance: float=1
@export_range(5,45,1) var outward_destination_wall_angle: float=35
@export_range(1,8,.1) var outward_alignment_score_weight: float=4
@export_range(0,1,.05) var outward_distance_score_weight: float=.15
@export_range(0,1,.05) var outward_height_score_weight: float=.1
@export_range(.05,.5,.01) var outward_pose_arrival_blend_time: float=.30
@export_range(.5,2,.005) var outward_playback_speed: float=1.375
@export_range(.5,2,.0025) var outward_catch_playback_speed: float=1.0625
@export_range(9,30,1) var outward_catch_start_frame: float=16
@export_range(.65,.95,.01) var outward_hand_arrival: float=.78
@export_range(.7,.95,.01) var outward_foot_arrival: float=.86
var outward=preload("res://Characters/Player/V2/player_hang_outward_v2.gd").new()
var top_entry: Node3D
@export_group("Top-Down Hang Entry")
@export_range(.5,2,.05) var top_down_hang_playback_speed: float=.9
@export_range(.3,1,.05) var top_down_hang_prompt_distance: float=.7
@export_range(0,.3,.01) var top_down_hang_lateral_tolerance: float=.15
@export_range(10,70,5) var top_down_hang_facing_tolerance: float=50
@export_range(6,18,1) var top_down_hang_contact_frame: float=9
@export_range(1,14,1) var top_down_hang_hand_blend_frame: float=12
@export_range(.1,.6,.05) var top_down_hang_max_hand_correction: float=.45
@export_group("Hang Navigation")
@export_range(.5,3,.05) var braced_hang_safe_release_distance: float=1.75
@export_range(1,8,.1) var braced_hang_jump_outward_speed: float=4.5
@export_range(4,12,.1) var braced_hang_jump_up_speed: float=9.0
@export_range(0,3,.1) var braced_hang_jump_lateral_influence: float=1.5
@export_range(.3,1,.05) var braced_hang_interact_range: float=.75
@export_range(.08,.2,.01) var lateral_brace_recess: float=.12
@export_range(.5,8,.5) var lateral_max_normal_change: float=3.0
@export_range(5,60,1) var lateral_max_total_turn: float=35.0
var navigation=preload("res://Characters/Player/V2/player_hang_navigation_v2.gd").new()
@export_group("Vertical Hang")
@export_range(.5,2,.05) var braced_hang_vertical_playback_speed: float=1.1
@export_range(.5,2.5,.05) var vertical_up_range: float=1.4
@export_range(.5,3,.05) var vertical_down_range: float=1.6
@export_range(.2,.8,.05) var vertical_min_separation: float=.45
@export_range(0,.5,.05) var vertical_horizontal_tolerance: float=.3
@export_range(.05,.3,.01) var vertical_wall_tolerance: float=.2
@export_range(0,20,1) var vertical_angle_tolerance: float=10
@export_range(.001,.03,.001) var vertical_clearance_margin: float=.005
var vertical=preload("res://Characters/Player/V2/player_hang_vertical_v2.gd").new()
@export_group("Lateral Hang")
@export_range(.1,.8,.05) var braced_hang_shimmy_distance: float=.7
@export_range(.5,3,.05) var braced_hang_hop_distance: float=3.0
@export var braced_hang_hop_use_authored_distance: bool=false
## Prepared at scene load. Disable and restart play to restore authored Right Hop movement.
@export var braced_hang_right_hop_mirror_left_curve: bool=false
## Runtime movement only. Disable and restart to restore the original settling slide.
@export var braced_hang_right_hop_reduce_tail_slide: bool=true
@export_range(.06,.15,.01) var braced_hang_right_hop_tail_overshoot: float=.08
@export_range(.5,2,.05) var braced_hang_lateral_playback_speed: float=1.1
@export_range(.01,.05,.005) var lateral_query_spacing: float=.025
@export_range(.005,.04,.005) var lateral_height_tolerance: float=.02
@export_range(.98,1,.001) var lateral_normal_dot: float=.995
var lateral=preload("res://Characters/Player/V2/player_hang_lateral_v2.gd").new()
@export_group("Horizontal Gap Transfer")
@export_range(1,6,.1) var braced_hang_transfer_max_horizontal_distance: float=4.5
@export_range(.05,.5,.05) var braced_hang_transfer_max_vertical_difference: float=.35
@export_range(.05,.5,.025) var braced_hang_transfer_min_gap: float=.15
@export_range(.05,.3,.025) var braced_hang_transfer_forward_back_tolerance: float=.2
@export_range(0,15,1) var braced_hang_transfer_wall_normal_tolerance: float=10
@export_range(0,15,1) var braced_hang_transfer_facing_tolerance: float=10
@export_range(1,2,.05) var braced_hang_transfer_max_motion_scale: float=1.5
@export_range(.5,.85,.01) var braced_hang_transfer_hand_arrival: float=.70
@export_range(.6,.9,.01) var braced_hang_transfer_foot_arrival: float=.80
var transfer=preload("res://Characters/Player/V2/player_hang_transfer_v2.gd").new()
const RELEASE_CLIP: StringName=&"TRV_BRACED_HANG_DROP_AND_LAND"
const RELEASE_START: float=9.0/30.0
const RELEASE_END: float=18.0/30.0
@export_group("Release")
@export_range(0,1,.05) var release_outward_speed: float = .35
@export_range(0,1,.05) var release_downward_speed: float = .20
@export_range(.5,3,.1) var release_regrab_timeout: float = 1.5
@export_range(.1,.5,.05) var release_separation_margin: float = .20
var release_active: bool = false
var release_elapsed: float = 0
var release_velocity:=Vector3.ZERO
var release_suppression_active: bool = false
var release_suppression_remaining: float = 0
var climb_destination_valid: bool = false
var entry_gait: int = 0
var entry_run_time: float = 0
var entry_crouched: bool = false
var exit_elapsed: float = 0
@export_group("Catch")
@export var enabled: bool = true
@export_range(60,170,1) var braced_hang_forward_cone_degrees: float = 160
@export_range(.5,1,.01) var max_grab_distance: float = .85
@export_range(.1,.5,.01) var vertical_reach_allowance: float = .40
@export_range(.1,.5,.01) var vertical_reach_below: float = .40
@export_range(.1,.6,.01) var horizontal_reach_allowance: float = .40
@export_range(0,.8,.01) var approach_direction_dot: float = .05
@export_range(80,120,1) var facing_acceptance_half_angle: float = 100
@export_range(0,.5,.01) var predictive_distance: float = .45
@export_range(0,.6,.01) var recent_sweep_distance: float = .45
@export_range(0,.20,.01) var candidate_grace_time: float = .15
@export_range(.001,.05,.001) var approach_speed_tolerance: float = .005
@export_range(0,.25,.01) var debug_persistence: float = .20
var acquisition=preload("res://Characters/Player/V2/player_hang_acquisition_v2.gd").new()
var detection_visual: Node3D
@export_group("Idle Visual Polish")
@export_range(-.35,0,.005) var braced_hang_visual_vertical_offset: float = -.23
@export_range(0,.12,.005) var braced_hang_chest_wall_offset: float = .08
@export_range(-.10,.03,.005) var braced_hang_hand_vertical_offset: float = -.01
@export_range(0,.04,.005) var braced_hang_hand_wall_offset: float = .03
@export_range(0,1,.05) var braced_hang_hand_ik_weight: float = 1.0
@export_range(.10,.30,.01) var braced_hang_max_hand_correction: float = .16
@export_range(.01,.03,.005) var braced_hang_foot_wall_clearance: float = .02
@export_range(.03,.15,.01) var braced_hang_max_foot_correction: float = .12
@export_range(.05,.2,.01) var braced_hang_visual_blend_out: float = .12
var idle_pose=preload("res://Characters/Player/V2/player_hang_idle_pose_v2.gd").new()
@export_group("Existing Hang Contact")
@export_range(.46,.6,.01) var body_distance_from_wall: float = .50
@export_range(1.7,2.1,.01) var hang_vertical_offset: float = 1.75
@export_range(.15,.25,.01) var settle_duration: float = .20
@export_range(.0,.30,.01) var landing_setback: float = .15
@export_range(.2,2,.1) var regrab_cooldown: float = 1.0
@export var hang_debug: bool = false
@export_range(.01,.05,.005) var foot_wall_clearance: float = .03
@export_range(.05,.15,.01) var max_foot_correction: float = .15
@export_range(10,60,1) var foot_contact_response: float = 50
const UP_MATCH_FRAME: float = 10.0
const SPRINT_MATCH_FRAME: float = 27.0
var mantle_debug: bool:
	get: return hang_debug
var running: bool = false
var hang_phase: HangPhase = HangPhase.NONE
var elapsed: float = 0
var progress: float = 0
var up_length: float = 35.0/30.0
var result: Dictionary = {"valid":false,"reason":"NONE","classification":"NONE"}
var source: Node3D
var source_transform := Transform3D.IDENTITY
var wall_point := Vector3.ZERO
var wall_normal := Vector3.BACK
var landing_plane_normal := Vector3.UP
var ledge_edge := Vector3.ZERO
var top := Vector3.ZERO
var alignment := Vector3.ZERO
var landing := Vector3.ZERO
var facing := Vector3.FORWARD
var catch_start := Vector3.ZERO
var entry_yaw: float = 0
var cooldown: float = 0
var last_source_id: int = 0
var last_edge := Vector3.ZERO
var exit_reason: String = ""
var up_elapsed: float = 0
@onready var owner_controller=get_parent()
@onready var motor=get_parent().get_parent()

func _ready() -> void:
	top_entry=preload("res://Characters/Player/V2/player_hang_top_entry_v2.gd").new()
	top_entry.name="TopDownEntry"
	add_child(top_entry)
	detection_visual=preload("res://Characters/Player/V2/player_hang_debug_v2.gd").new()
	add_child(detection_visual)

func is_attached() -> bool: return running and owner_controller.phase!=owner_controller.Phase.EXIT
func pose_owned() -> bool: return is_attached() or (release_active and release_elapsed<.10)

func project_foot(controller: Node,leg: Dictionary,pose: Transform3D) -> Dictionary:
	var contact=controller.ClimbContact
	var samples: Array=[pose.origin,controller._world(controller.skeleton.find_bone("mixamorig_"+leg.side+"ToeBase")).origin]
	if outward.active:
		var target: Dictionary=outward.contact_target()
		var weight: float=outward.contact_weight(self,true) if controller.enabled and controller.climb_foot_ik_enabled else 0.0
		return contact._surface(controller,leg,pose,samples,target.edge,target.normal,braced_hang_foot_wall_clearance,braced_hang_max_foot_correction,weight,"OUTWARD_WALL",foot_contact_response,self,target.source)
	if transfer.active:
		var target: Dictionary=transfer.contact_target(self)
		var weight: float=transfer.contact_weight(self,true) if controller.enabled and controller.climb_foot_ik_enabled else 0.0
		return contact._surface(controller,leg,pose,samples,target.edge,target.normal,braced_hang_foot_wall_clearance,braced_hang_max_foot_correction,weight,"TRANSFER_WALL",foot_contact_response,self,target.source)
	if vertical.active:
		var target: Dictionary=vertical.contact_target()
		var weight: float=vertical.contact_weight() if controller.enabled and controller.climb_foot_ik_enabled else 0.0
		return contact._surface(controller,leg,pose,samples,target.edge,target.normal,braced_hang_foot_wall_clearance,braced_hang_max_foot_correction,weight,"VERTICAL_WALL",foot_contact_response,self,target.source)
	var envelope: float=smoothstep(0,settle_duration,elapsed) if hang_phase!=HangPhase.TO_CROUCH else 1.0-smoothstep(.60,.75,progress)
	if top_entry.active: envelope=top_entry.foot_weight()
	if navigation.jumping: envelope*=1-smoothstep(.25,navigation.LAUNCH_TIME,navigation.jump_pose_time)
	if not controller.enabled or not controller.climb_foot_ik_enabled: envelope=0
	if controller.enabled and controller.climb_foot_ik_enabled and hang_phase==HangPhase.TO_CROUCH and progress>.65:
		return contact._surface(controller,leg,pose,[pose.origin-landing_plane_normal*controller.feet.foot_sole_offset,samples[1]],top,landing_plane_normal,foot_wall_clearance,max_foot_correction,1.0,"LEDGE_TOP",foot_contact_response,self)
	var legacy: Dictionary=contact._surface(controller,leg,pose,samples,wall_point,wall_normal,foot_wall_clearance,max_foot_correction,envelope,"WALL",foot_contact_response,self)
	return idle_pose.foot_contact(self,controller,leg,pose,samples,legacy) if idle_pose.weight>0 and not navigation.jumping and not top_entry.active else legacy

## Shared hand layer consumes this contact clock, not the source clip clock.
func current_frame() -> float:
	if top_entry.active: return lerpf(17,23,top_entry.hand_weight())
	if hang_phase==HangPhase.RELEASE: return lerpf(37,44,clampf(release_elapsed/.10,0,1))
	if hang_phase in [HangPhase.CATCH,HangPhase.SETTLE]: return lerpf(17,23,clampf(elapsed/settle_duration,0,1))
	if hang_phase==HangPhase.TO_CROUCH: return 30.0 if progress<=.45 else lerpf(37,44,clampf((progress-.45)/.25,0,1))
	return 30.0

func ray(a: Vector3,b: Vector3) -> Dictionary:
	return motor.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(a,b,motor.collision_mask,[motor.get_rid()]))

func clear_segment(a: Vector3,b: Vector3,height: float) -> bool:
	var shape:=CapsuleShape3D.new()
	shape.radius=motor.crouch.standing_capsule_radius
	shape.height=height
	var q:=PhysicsShapeQueryParameters3D.new()
	q.shape=shape
	q.collision_mask=motor.collision_mask
	q.exclude=[motor.get_rid()]
	# Stay below CharacterBody's contact skin. A larger query margin rejected
	# the first settle increment when retrying from an already-touching wall.
	q.margin=.0001
	q.transform=Transform3D(Basis.IDENTITY,b+Vector3.UP*(height*.5+.004))
	if not motor.get_world_3d().direct_space_state.intersect_shape(q,1).is_empty(): return false
	q.transform.origin=a+Vector3.UP*(height*.5+.004)
	q.motion=b-a
	var sweep=motor.get_world_3d().direct_space_state.cast_motion(q)
	return sweep.size()==2 and sweep[0]>=.999

func detect(delta: float=1.0/60.0,current_intent: Vector3=Vector3.INF) -> Dictionary:
	return acquisition.query(self,delta,current_intent)

func try_catch(delta: float,current_intent: Vector3=Vector3.INF) -> bool:
	cooldown=maxf(0,cooldown-delta)
	advance_release(delta)
	var available: bool=enabled and not running and owner_controller.can_begin(false) and not motor.ground_support.has_ground_support and not motor.is_on_floor()
	if not available:
		if debug_detection_enabled() and not running:
			result=detect(delta,current_intent)
			result.valid=false
			result.reason="STATE_NOT_AIRBORNE" if motor.ground_support.has_ground_support or motor.is_on_floor() else "STATE_BUSY"
		return false
	result=detect(delta,current_intent)
	if not result.valid: return false
	result.entry_gait=motor.animation_state.gait
	result.entry_run_time=motor._run_time
	return owner_controller.request_automatic_traversal(owner_controller.Context.Type.LEDGE,result)

func debug_detection_enabled() -> bool:
	return hang_debug or owner_controller.traversal_debug

func validate(data: Dictionary) -> bool:
	return data.get("valid",false) and is_instance_valid(data.get("source")) and clear_segment(motor.global_position,data.anchor,motor.crouch.standing_capsule_height)

func begin(data: Dictionary) -> void:
	navigation.invalidate()
	navigation.jump_visual=false
	entry_gait=int(data.get("entry_gait",motor.animation_state.gait))
	entry_run_time=float(data.get("entry_run_time",0))
	entry_crouched=motor.crouch.requested
	exit_elapsed=0
	release_active=false
	climb_destination_valid=false
	running=true
	hang_phase=HangPhase.CATCH
	elapsed=0
	progress=0
	source=data.source
	source_transform=source.global_transform
	wall_point=data.edge
	ledge_edge=data.edge
	top=data.top
	wall_normal=data.normal
	landing_plane_normal=data.top_normal
	facing=data.facing
	alignment=data.anchor
	catch_start=motor.global_position
	entry_yaw=motor.visual.rotation.y
	motor.velocity=Vector3.ZERO
	owner_controller._set_phase(owner_controller.Phase.ACTIVE)

func up_position(p: float) -> Vector3:
	return up_path(p,alignment,landing)

func up_path(p: float,from: Vector3,to: Vector3) -> Vector3:
	var mantle=owner_controller.mantle
	var reference_from:=Vector3(from.x,to.y-mantle.reference_climb_height,from.z)
	var match_p: float=UP_MATCH_FRAME/(30.0*up_length)
	if p>=match_p:
		return mantle.reference_profile_position(sprint_progress(p),reference_from,to)
	var first: Vector3=mantle.reference_profile_position(mantle.frame_progress(SPRINT_MATCH_FRAME),reference_from,to)
	return from.lerp(first,smoothstep(0,match_p,p))

func sprint_progress(p: float) -> float:
	var mantle=owner_controller.mantle
	var match_p: float=UP_MATCH_FRAME/(30.0*up_length)
	return lerpf(mantle.frame_progress(SPRINT_MATCH_FRAME),1.0,clampf(inverse_lerp(match_p,1.0,p),0,1))

func up_rise(p: float) -> float:
	var height: float=hang_vertical_offset+.015
	return up_path(p,Vector3.ZERO,Vector3(0,height,1)).y/height

func hip_track(clip: Animation) -> int:
	for t in clip.get_track_count():
		if clip.track_get_type(t)==Animation.TYPE_POSITION_3D and str(clip.track_get_path(t)).ends_with(":mixamorig_Hips"): return t
	return -1

func prepare_clips(player: AnimationPlayer,root_reference: Vector3) -> void:
	var idle:=player.get_animation(&"TRV_BRACED_HANG_IDLE")
	var up:=player.get_animation(&"TRV_BRACED_HANG_TO_CROUCH")
	var catch_clip:=player.get_animation(&"TRV_JUMPING_TO_BRACED_HANG")
	var idle_z: float=idle.track_get_key_value(hip_track(idle),0).z
	top_entry.prepare(player,root_reference,idle_z)
	var crouch:=player.get_animation(&"CRC_CROUCH_IDLE")
	var crouch_z: float=crouch.track_get_key_value(hip_track(crouch),0).z
	# Only the final six source frames provide the small settled catch, not
	# the clip's long authored forward jump. Original imported clips untouched.
	var tail: float=catch_clip.length-.2
	for t in catch_clip.get_track_count():
		var values: Array=[]
		for i in 7:
			var time: float=tail+float(i)/30
			match catch_clip.track_get_type(t):
				Animation.TYPE_POSITION_3D: values.append(catch_clip.position_track_interpolate(t,time))
				Animation.TYPE_ROTATION_3D: values.append(catch_clip.rotation_track_interpolate(t,time))
				Animation.TYPE_SCALE_3D: values.append(catch_clip.scale_track_interpolate(t,time))
		for k in range(catch_clip.track_get_key_count(t)-1,-1,-1): catch_clip.track_remove_key(t,k)
		for i in values.size(): catch_clip.track_insert_key(t,float(i)/30,values[i])
	catch_clip.length=.2
	for clip in [idle,up,catch_clip]:
		clip.loop_mode=Animation.LOOP_LINEAR if clip==idle else Animation.LOOP_NONE
		var track:=hip_track(clip)
		var first: Vector3=clip.track_get_key_value(track,0)
		var last: Vector3=clip.track_get_key_value(track,clip.track_get_key_count(track)-1)
		for k in clip.track_get_key_count(track):
			var value: Vector3=clip.track_get_key_value(track,k)
			var p: float=clip.track_get_key_time(track,k)/clip.length
			value.x=root_reference.x
			value.y=root_reference.y
			if clip==catch_clip: value.z+=idle_z-last.z
			if clip==up:
				var normalization: float=idle_z-first.z
				var rise: float=(hang_vertical_offset+.015)*100
				value.z+=normalization+rise*up_rise(p)
				value.z+=(crouch_z-(last.z+normalization+rise))*smoothstep(.65,1,p)
			clip.track_set_key_value(track,k,value)
	up_length=up.length
	align_up_support(player,up)
	match_sprint_tail(player,up)
	prepare_release(player,root_reference,idle_z)
	lateral.prepare(self,player,root_reference,idle_z)
	vertical.prepare(self,player,root_reference,idle_z)
	navigation.prepare(self,player,root_reference,idle_z)

## Share the compensated sprint root translation as well as its body path.
## Only translation is transferred; braced joint rotations remain authored.
func match_sprint_tail(player: AnimationPlayer,clip: Animation) -> void:
	var sprint: Animation=player.get_animation(owner_controller.mantle.ACTION)
	var track:=hip_track(clip)
	var sprint_track:=hip_track(sprint)
	var original: Animation=clip.duplicate(true)
	var times: Array[float]=[UP_MATCH_FRAME/30.0,clip.length]
	for key in clip.track_get_key_count(track): times.append(clip.track_get_key_time(track,key))
	# Preserve every mapped sprint key, including the precise splice boundary.
	for key in sprint.track_get_key_count(sprint_track):
		var time: float=sprint.track_get_key_time(sprint_track,key)
		if time>SPRINT_MATCH_FRAME/30.0:
			times.append(lerpf(UP_MATCH_FRAME/30.0,clip.length,inverse_lerp(SPRINT_MATCH_FRAME/30.0,sprint.length,time)))
	for key in range(clip.track_get_key_count(track)-1,-1,-1): clip.track_remove_key(track,key)
	times.sort()
	for time in times:
		var p: float=time/clip.length
		var target: Vector3=sprint.position_track_interpolate(sprint_track,sprint_progress(p)*sprint.length)
		var existing: Vector3=original.position_track_interpolate(track,time)
		clip.track_insert_key(track,time,existing.lerp(target,smoothstep(5.0,UP_MATCH_FRAME,time*30.0)))

func prepare_release(player: AnimationPlayer,root_reference: Vector3,idle_z: float) -> void:
	var clip:=player.get_animation(RELEASE_CLIP)
	# Source inspection: hands let go around .3-.6s; feet land near .85s.
	# Keep only frames 9-18. Physics owns every drop distance and landing.
	for track in clip.get_track_count():
		var values: Array=[]
		for key in 10:
			var time: float=RELEASE_START+float(key)/30.0
			match clip.track_get_type(track):
				Animation.TYPE_POSITION_3D: values.append(clip.position_track_interpolate(track,time))
				Animation.TYPE_ROTATION_3D: values.append(clip.rotation_track_interpolate(track,time))
				Animation.TYPE_SCALE_3D: values.append(clip.scale_track_interpolate(track,time))
		for key in range(clip.track_get_key_count(track)-1,-1,-1): clip.track_remove_key(track,key)
		for key in values.size(): clip.track_insert_key(track,float(key)/30,values[key])
	clip.length=RELEASE_END-RELEASE_START
	clip.loop_mode=Animation.LOOP_NONE
	var hip:=hip_track(clip)
	for key in clip.track_get_key_count(hip):
		clip.track_set_key_value(hip,key,Vector3(root_reference.x,root_reference.y,idle_z))

func advance_release(delta: float) -> void:
	if release_active:
		release_elapsed+=delta
		if release_elapsed>=RELEASE_END-RELEASE_START: end_release_visual()
	if release_suppression_active:
		release_suppression_remaining=maxf(0,release_suppression_remaining-delta)
		var offset: Vector3=motor.global_position-last_edge
		var separated: bool=Vector2(offset.x,offset.z).length()>max_grab_distance+release_separation_margin or absf(offset.y+hang_vertical_offset)>vertical_reach_allowance+release_separation_margin
		# A completed physical landing is also a safe retry boundary: catch is
		# airborne-only, so it cannot snap back until the next deliberate jump.
		if separated or motor.ground_support.has_ground_support or release_suppression_remaining<=0: release_suppression_active=false

func end_release_visual() -> void:
	release_active=false
	if not running: hang_phase=HangPhase.NONE

func request_release() -> bool:
	if not running or hang_phase!=HangPhase.IDLE: return false
	var outward: Vector3=wall_normal.normalized()*release_outward_speed
	owner_controller.finish("HANG_RELEASED")
	# Ownership and IK are detached immediately; no pre-catch momentum restored.
	release_active=true
	release_elapsed=0
	hang_phase=HangPhase.RELEASE
	release_suppression_active=true
	release_suppression_remaining=release_regrab_timeout
	cooldown=0 # Explicit release uses separation, not a global hanging lockout.
	release_velocity=outward-Vector3.UP*release_downward_speed
	motor.velocity=release_velocity
	motor.ground_support.reset_coyote()
	var s=motor.animation_state
	s.is_grounded=false
	s.was_grounded=false
	s.is_airborne=true
	s.jump_started=false
	s.air_time=0
	var a=motor.get_node("AnimationController")
	a._episode_visible=true
	a.fall_visual_committed=true
	a._intentional_jump_episode=false
	a._standing_jump_episode=false
	a._has_ground_contact=true
	a._enter(&"HangRelease")
	return true

## Retarget the supporting portion around its actual bilateral hand center.
## This is a private clip translation curve, not an IK-driven controller move.
## Without it the source's rising/drifting wrists exceed arm reach at mid-hoist.
func align_up_support(player: AnimationPlayer,clip: Animation) -> void:
	var skeleton: Skeleton3D=motor.get_node("AnimationController").rig.get_node("Base Armature and Mesh/Skeleton3D")
	var visual: Node3D=motor.get_node("VisualRoot")
	var track:=hip_track(clip)
	var corrections: Array[Vector3]=[]
	var hands=motor.get_node("MantleHandIK")
	var grip_center:=Vector3((hands.right_grip_spacing-hands.left_grip_spacing)*.5,hang_vertical_offset+hands.hand_vertical_offset,-body_distance_from_wall+hands.hand_wall_normal_offset)
	player.play(&"TRV_BRACED_HANG_TO_CROUCH")
	for key in clip.track_get_key_count(track):
		var time: float=clip.track_get_key_time(track,key)
		var p: float=time/clip.length
		player.seek(time,true)
		player.advance(0)
		var center:=Vector3.ZERO
		for side in ["Left","Right"]:
			center+=visual.to_local(skeleton.global_transform*skeleton.get_bone_global_pose(skeleton.find_bone("mixamorig_"+side+"Hand")).origin)*.5
		var controller_delta:=up_path(p,Vector3.ZERO,Vector3(0,hang_vertical_offset+.015,-(body_distance_from_wall+landing_setback)))
		var envelope: float=smoothstep(0,.12,p)*(1-smoothstep(.45,.70,p))
		var offset: Vector3=(grip_center-controller_delta-center)*envelope
		# Correct source hand-height drift only. Translating the entire pose
		# toward the lip would push the supporting feet through the wall.
		# Existing hand IK can safely cover the remaining horizontal mismatch.
		offset.x=0
		offset.z=0
		corrections.append(skeleton.global_basis.inverse()*visual.global_basis*offset)
	for key in corrections.size():
		clip.track_set_key_value(track,key,clip.track_get_key_value(track,key)+corrections[key])
	player.stop()

func request_up() -> bool:
	if not running or hang_phase!=HangPhase.IDLE: return false
	if not check_pull_up(): return false
	motor.crouch.clear_handoff()
	motor.crouch.requested=true
	motor.crouch.phase=motor.crouch.Phase.CROUCHED
	motor.crouch.resize(motor.crouch.crouch_capsule_height)
	hang_phase=HangPhase.TO_CROUCH
	progress=0
	up_elapsed=0
	return true

func check_pull_up() -> bool:
	climb_destination_valid=false
	if not is_instance_valid(source) or source.is_queued_for_deletion() or not source.global_transform.is_equal_approx(source_transform): return false
	# Match standard climb's near-edge finish without sacrificing support.
	var safe_setback: float=maxf(landing_setback,motor.ground_support.minimum_landing_setback())
	landing=ledge_edge+facing*safe_setback
	landing.y=top.y-(landing_plane_normal.x*(landing.x-top.x)+landing_plane_normal.z*(landing.z-top.z))/landing_plane_normal.y+.015
	if not motor.ground_support.evaluate(landing,Basis(Vector3.UP,atan2(-facing.x,-facing.z)),source,landing_plane_normal).supported: exit_reason="NO_TOP_SUPPORT"; return false
	var previous:=alignment
	for i in range(1,81):
		var target:=up_position(float(i)/80)
		if not clear_segment(previous,target,motor.crouch.crouch_capsule_height): exit_reason="TOP_OR_PATH_BLOCKED"; return false
		previous=target
	climb_destination_valid=true
	return true

func contact_still_exists() -> bool:
	return validate_contacts(source,ledge_edge,top,wall_normal,landing_plane_normal)

func validate_contacts(contact_source: Node3D,edge: Vector3,plane: Vector3,normal: Vector3,plane_normal: Vector3) -> bool:
	var into_wall: Vector3=-normal
	var tangent:=into_wall.cross(Vector3.UP)
	for lateral in [-.28,.28]:
		var hand: Vector3=edge+tangent*lateral+into_wall*.04
		hand.y=plane.y-(plane_normal.x*(hand.x-plane.x)+plane_normal.z*(hand.z-plane.z))/plane_normal.y
		var hit:=ray(hand+Vector3.UP*.06,hand-Vector3.UP*.06)
		if hit.is_empty() or hit.collider!=contact_source or hit.normal.dot(plane_normal)<.98: return false
		var brace: Vector3=edge+tangent*lateral-Vector3.UP*1.15
		hit=ray(brace-into_wall*.12,brace+into_wall*.12)
		if hit.is_empty() or hit.collider!=contact_source or hit.normal.dot(normal)<.98: return false
	return true

func step(delta: float) -> bool:
	if not running: return false
	if top_entry.active: return top_entry.step(delta)
	if navigation.jumping: return navigation.jump_step(self,delta)
	if owner_controller.phase==owner_controller.Phase.EXIT:
		exit_elapsed+=delta
		if exit_elapsed>=owner_controller.mantle.mantle_exit_blend_time: owner_controller.finish("HANG_TO_CROUCH_COMPLETED")
		return false
	if not is_instance_valid(source) or source.is_queued_for_deletion() or not source.global_transform.is_equal_approx(source_transform): owner_controller.finish("HANG_SOURCE_LOST"); return false
	if not vertical.active and not transfer.active and not outward.active and not contact_still_exists(): owner_controller.finish("HANG_CONTACT_LOST"); return false
	navigation.advance(self,delta)
	if outward.active and not outward.advance(self,delta): return false
	if vertical.active and not vertical.advance(self,delta): return false
	if transfer.active:
		if not transfer.advance(self,delta): return false
	elif lateral.active: lateral.advance(self,delta)
	motor.velocity=Vector3.ZERO
	var target:=alignment
	if lateral.active: target=lateral.expected_position
	if vertical.active: target=vertical.expected_position
	if outward.active: target=outward.expected_position
	if hang_phase in [HangPhase.CATCH,HangPhase.SETTLE]:
		elapsed+=delta
		hang_phase=HangPhase.SETTLE
		var weight:=smoothstep(0,settle_duration,elapsed)
		target=catch_start.lerp(alignment,weight)
		motor.visual.rotation.y=lerp_angle(entry_yaw,atan2(-facing.x,-facing.z),weight)
		if elapsed>=settle_duration: hang_phase=HangPhase.IDLE
	elif hang_phase==HangPhase.TO_CROUCH:
		up_elapsed+=delta
		if up_elapsed>up_length+2: owner_controller.finish("HANG_ANIMATION_TIMEOUT"); return false
		var a=motor.get_node("AnimationController")
		if a._playback.get_current_node()==&"HangUp": progress=clampf(a._playback.get_current_play_position()/up_length,0,1)
		target=up_position(progress)
		if not motor.ground_support.evaluate(landing,Basis(Vector3.UP,atan2(-facing.x,-facing.z)),source,landing_plane_normal).supported: owner_controller.finish("HANG_DESTINATION_LOST"); return false
	if not clear_segment(motor.global_position,target,motor.crouch.collision.shape.height): owner_controller.finish("HANG_BLOCKED"); return false
	if motor.move_and_collide(target-motor.global_position)!=null and motor.global_position.distance_to(target)>.02: owner_controller.finish("HANG_BLOCKED"); return false
	if vertical.active: vertical.complete(self)
	if transfer.active: transfer.complete(self)
	if outward.active: outward.complete(self)
	var s=motor.animation_state
	s.is_grounded=false
	s.is_airborne=true
	s.jump_started=false
	s.move_input_magnitude=0
	s.horizontal_speed=0
	s.vertical_velocity=0
	if hang_phase==HangPhase.TO_CROUCH and progress>=.995:
		motor.velocity.y=-.5
		motor.move_and_slide()
		motor.apply_floor_snap()
		motor.ground_support.refresh(0)
		if not motor.ground_support.has_ground_support: owner_controller.finish("HANG_NO_LANDING"); return false
		s.is_grounded=true
		s.is_airborne=false
		s.was_grounded=true
		motor.crouch.clear_handoff()
		var stay_crouched: bool=entry_crouched or not motor.crouch.standing_clear()
		motor.crouch.requested=stay_crouched
		motor.crouch.phase=motor.crouch.Phase.CROUCHED if stay_crouched else motor.crouch.Phase.STANDING
		motor.crouch.resize(motor.crouch.crouch_capsule_height if stay_crouched else motor.crouch.standing_capsule_height)
		motor._run_time=entry_run_time
		s.gait=entry_gait
		owner_controller._set_phase(owner_controller.Phase.EXIT)
		return false # Normal motor resumes immediately, like standard mantle.
	return true

func restore(reason: String) -> void:
	if not running: return
	outward.active=false
	top_entry.active=false
	transfer.active=false
	lateral.active=false
	vertical.active=false
	navigation.interacting=false
	navigation.invalidate()
	release_suppression_active=false
	last_source_id=source.get_instance_id() if is_instance_valid(source) else 0
	last_edge=ledge_edge
	cooldown=regrab_cooldown
	running=false
	hang_phase=HangPhase.NONE
	exit_reason=reason
	if reason!="HANG_TO_CROUCH_COMPLETED": motor.velocity=Vector3.ZERO
	var a=motor.get_node("AnimationController")
	if reason not in ["HANG_TO_CROUCH_COMPLETED","HANG_JUMP_OFF"]: a._enter(&"Fall")

func debug_text() -> String:
	if top_entry.active: return top_entry.debug_text()
	return "HANG %s / %s\nW: Climb Up / S: Release\nSettle complete: %s / Last top check: %s\nCandidate %s / %s\nAngle %.1f / Distance %.2f / Settle %.2f\nAnchor %s / Last %s\nRegrab suppressed: %s / Ledge ID: %d\nRelease velocity: %s" % ["BRACED" if running else "NONE",HangPhase.keys()[hang_phase],elapsed>=settle_duration,climb_destination_valid,result.get("classification","NONE"),result.get("reason","NONE"),result.get("angle",0.0),result.get("distance",0.0),elapsed,alignment,exit_reason,release_suppression_active,last_source_id,release_velocity]
