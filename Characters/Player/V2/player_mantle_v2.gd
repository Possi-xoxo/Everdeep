extends Node
## Real mantle profile owned by TraversalController. Source GLB stays untouched.
const ACTION: StringName=&"TRV_SPRINT_TO_WALL_CLIMB_02"
@export_group("Mantle")
@export_range(.10,.25,.01) var mantle_alignment_duration: float = .12
## Smoothstep peak speed; distance sets duration rather than rejecting entry.
@export_range(2.0,8.0,.1) var mantle_approach_speed: float = 4.5
@export_range(.25,.75,.01) var mantle_long_approach_distance: float = .55
@export_range(.03,.08,.01) var mantle_alignment_position_tolerance: float = .05
@export_range(3,8,.5) var mantle_alignment_angle_tolerance: float = 5.0
@export_group("Climb Launch and Contact")
@export_range(.50,1.0,.01) var moving_climb_launch_distance: float = .75
@export_range(.50,1.0,.01) var stationary_climb_launch_distance: float = .65
@export_range(.45,.65,.01) var wall_contact_distance: float = .50
## Smoothstep from the selected entry source frame to WALL_REACH. Hands are
## expected visually around frames 17-21; this is not a hand IK constraint.
@export_range(12,24,1) var launch_contact_frame: int = 17
@export_group("Mantle Polish")
## Existing source-compensation reference, now explicit. Never skeleton scale.
@export_range(1.75,3.0,.01) var reference_climb_height: float = 2.54
@export_group("Mantle Height Retarget")
@export_range(0,.2,.01) var reach_height_difference_weight: float = .05
@export_range(.3,.9,.05) var hoist_height_difference_weight: float = .65
@export_range(30,45,1) var height_difference_full_frame: int = 37
var actual_climb_height: float = 0.0
var vertical_retarget_offset: float = 0.0
@export_group("Mantle Polish")
@export_range(.80,1.00,.01) var mantle_playback_speed: float = .88
@export_range(20,30,1) var mantle_hoist_start_frame: int = 25
@export_range(45,50,1) var mantle_hoist_end_frame: int = 50
@export_range(.25,.65,.01) var mantle_hoist_arc_height: float = .40
@export_range(.35,.60,.01) var mantle_hoist_arc_forward_bias: float = .50
@export_range(3,8,.1) var mantle_camera_follow_speed: float = 5.0
@export_range(4,10,.1) var mantle_camera_return_speed: float = 6.0
@export_range(.2,.6,.01) var mantle_camera_top_offset: float = .4
@export var mantle_vertical_curve: Curve
@export var mantle_forward_curve: Curve
@export var mantle_debug: bool = false
@export_group("Mantle Sync")
@export_range(1,50,1) var mantle_idle_start_frame: int = 10
@export_range(1,50,1) var mantle_moving_start_frame: int = 1
@export_range(50,55,1) var mantle_exit_handoff_frame: int = 51
@export_range(.5,1.0,.05) var mantle_moving_entry_speed_threshold: float = .75
@export_group("Mantle Exit")
@export_range(.08,.30,.01) var mantle_landing_edge_setback: float = .15
@export_range(.18,.35,.01) var mantle_exit_blend_time: float = .30
@export_range(90,160,1) var mantle_interaction_cone_angle: float = 140.0
const SOURCE_FPS: float = 30.0
var clip_length: float = 55.0/30.0
var playback_start_frame: int = 10
var entry_source: String = "IDLE"
var input_at_exit := Vector2.ZERO
var running: bool = false
var progress: float = 0.0
var alignment_elapsed: float = 0.0
var effective_alignment_duration: float = .12
var long_approach: bool = false
var wall_point := Vector3.ZERO
var wall_normal := Vector3.BACK
var landing_plane_normal := Vector3.UP
var exit_elapsed: float = 0.0
var stalled_elapsed: float = 0.0
var start := Vector3.ZERO
var landing := Vector3.ZERO
var ledge_edge := Vector3.ZERO
var previous_landing := Vector3.ZERO
var minimum_safe_setback: float = 0.0
var safe_edge_setback: float = 0.0
var landing_support_samples: Array = []
var top := Vector3.ZERO
var candidate_height: float = 0.0
var alignment := Vector3.ZERO
var wall_contact := Vector3.ZERO
var selected_launch_distance: float = .65
var facing := Vector3.FORWARD
var current_target := Vector3.ZERO
var collision_blocked: bool = false
var last_reject: String = ""
var source: Node3D
var source_transform := Transform3D.IDENTITY
var source_hips: Array = []
var source_track: int = -1
var entry_yaw: float = 0.0
var original_crouch: bool = false
var debug_mesh: MeshInstance3D
@onready var owner_controller=get_parent()
@onready var motor=get_parent().get_parent()

func _ready() -> void:
	if mantle_vertical_curve==null:
		mantle_vertical_curve=Curve.new()
		mantle_vertical_curve.max_value=1.1
		for p in [Vector2(0,0),Vector2(11,0),Vector2(12,.015),Vector2(17,.15),Vector2(25,.50),Vector2(38,1.04),Vector2(45,1.04),Vector2(50,1),Vector2(55,1)]: mantle_vertical_curve.add_point(Vector2(p.x/55.0,p.y))
	if mantle_forward_curve==null:
		mantle_forward_curve=Curve.new()
		# Standing capsule must clear the face before crossing it.
		for p in [Vector2(0,0),Vector2(25,0),Vector2(38,0),Vector2(45,.8),Vector2(50,1),Vector2(55,1)]: mantle_forward_curve.add_point(Vector2(p.x/55.0,p.y))
	debug_mesh=MeshInstance3D.new()
	add_child(debug_mesh)
	debug_mesh.top_level=true
	debug_mesh.global_transform=Transform3D.IDENTITY
	var material:=StandardMaterial3D.new()
	material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo=true
	material.no_depth_test=true
	debug_mesh.material_override=material

func pose_owned() -> bool:
	return running and owner_controller.phase!=owner_controller.Phase.EXIT

func frame_progress(frame: float) -> float:
	return (frame/SOURCE_FPS)/clip_length

func current_frame() -> float:
	return progress*clip_length*SOURCE_FPS

func sync_phase() -> String:
	var frame:=current_frame()
	if frame>=mantle_exit_handoff_frame: return "EXIT"
	if frame>=mantle_hoist_start_frame: return "HOIST_ARC"
	if frame>=17: return "WALL_REACH"
	if frame>=12: return "INITIAL_LIFT"
	return "APPROACH"

func trajectory(p: float) -> Vector3:
	# Preserve the old contact-to-hoist path and its vertical compensation.
	# Only the opening horizontal position is displaced out toward launch.
	var contact_start:=Vector3(wall_contact.x,start.y,wall_contact.z)
	var value:=profile_position(p,contact_start,landing)
	var weight:=smoothstep(float(playback_start_frame),float(maxi(playback_start_frame+1,launch_contact_frame)),p*clip_length*SOURCE_FPS)
	var launch_offset:=start-contact_start
	launch_offset.y=0
	return value+launch_offset*(1.0-weight)

func pre_hoist(p: float,from: Vector3,to: Vector3) -> Vector3:
	var value:=from.lerp(to,clampf(mantle_forward_curve.sample(p),0,1))
	value.y=lerpf(from.y,to.y,clampf(mantle_vertical_curve.sample(p),0,1.1))
	return value

func arc_points(from: Vector3,to: Vector3) -> Array[Vector3]:
	var first:=pre_hoist(frame_progress(mantle_hoist_start_frame),from,to)
	var control_a:=Vector3(first.x,to.y+mantle_hoist_arc_height,first.z)
	var control_b:=first.lerp(to,mantle_hoist_arc_forward_bias)
	control_b.y=control_a.y
	return [first,control_a,control_b,to]

func reference_profile_position(p: float,from: Vector3,to: Vector3) -> Vector3:
	var begin_p:=frame_progress(mantle_hoist_start_frame)
	var end_p:=frame_progress(mantle_hoist_end_frame)
	if p<begin_p: return pre_hoist(p,from,to)
	if p>=end_p: return to
	var t:=smoothstep(0,1,inverse_lerp(begin_p,end_p,p))
	var points:=arc_points(from,to)
	return points[0].bezier_interpolate(points[1],points[2],points[3],t)

func height_difference_weight(p: float) -> float:
	var frame:=p*clip_length*SOURCE_FPS
	if frame<=11: return 0.0
	if frame<launch_contact_frame: return reach_height_difference_weight*smoothstep(11,launch_contact_frame,frame)
	if frame<mantle_hoist_start_frame: return lerpf(reach_height_difference_weight,hoist_height_difference_weight,smoothstep(launch_contact_frame,mantle_hoist_start_frame,frame))
	return lerpf(hoist_height_difference_weight,1.0,smoothstep(mantle_hoist_start_frame,height_difference_full_frame,frame))

func profile_position(p: float,from: Vector3,to: Vector3) -> Vector3:
	var value:=reference_profile_position(p,from,to)
	var reference_to:=Vector3(to.x,from.y+reference_climb_height,to.z)
	value.y=reference_profile_position(p,from,reference_to).y+(to.y-from.y-reference_climb_height)*height_difference_weight(p)
	if p>=frame_progress(mantle_hoist_end_frame): return to
	return value

func volume_clear(point: Vector3) -> bool:
	var q:=PhysicsShapeQueryParameters3D.new()
	q.shape=motor.crouch.standing_shape
	q.transform=Transform3D(Basis.IDENTITY,point+Vector3.UP*(motor.crouch.standing_capsule_height*.5+.003))
	q.collision_mask=motor.collision_mask
	q.exclude=[motor.get_rid()]
	q.margin=.001
	return motor.get_world_3d().direct_space_state.intersect_shape(q,1).is_empty()

func segment_clear(from: Vector3,to: Vector3) -> bool:
	if not volume_clear(to): return false
	var q:=PhysicsShapeQueryParameters3D.new()
	q.shape=motor.crouch.standing_shape
	q.transform=Transform3D(Basis.IDENTITY,from+Vector3.UP*(motor.crouch.standing_capsule_height*.5+.003))
	q.motion=to-from
	q.collision_mask=motor.collision_mask
	q.exclude=[motor.get_rid()]
	q.margin=.001
	var result=motor.get_world_3d().direct_space_state.cast_motion(q)
	return result.size()==2 and result[0]>=.999

func validate(data: Dictionary) -> bool:
	last_reject=""
	if not data.get("valid",false) or not is_instance_valid(data.get("obstacle_source")): return false
	if not motor.crouch.standing_clear(): last_reject="ENTRY_CLEARANCE"; return false
	var speed:=Vector2(motor.velocity.x,motor.velocity.z).length()
	entry_source="MOVING" if speed>=mantle_moving_entry_speed_threshold else "IDLE"
	playback_start_frame=mantle_moving_start_frame if entry_source=="MOVING" else mantle_idle_start_frame
	selected_launch_distance=maxf(wall_contact_distance,moving_climb_launch_distance if entry_source=="MOVING" else stationary_climb_launch_distance)
	wall_contact=data.player_alignment_position
	alignment=wall_contact-data.player_alignment_facing*(selected_launch_distance-wall_contact_distance)
	data["launch_position"]=alignment
	data["wall_contact_position"]=wall_contact
	landing=data.landing_position
	facing=data.player_alignment_facing
	top=data.top_position
	candidate_height=data.ledge_height
	previous_landing=landing
	# Keep detector depth rules intact; this profile owns the final settle.
	minimum_safe_setback=motor.ground_support.minimum_landing_setback()
	safe_edge_setback=maxf(mantle_landing_edge_setback,minimum_safe_setback)
	ledge_edge=Vector3(data.obstacle_position.x,top.y,data.obstacle_position.z)
	var normal: Vector3=data.top_normal
	ledge_edge.y=top.y-(normal.x*(ledge_edge.x-top.x)+normal.z*(ledge_edge.z-top.z))/normal.y
	landing=ledge_edge+facing*safe_edge_setback
	landing.y=top.y-(normal.x*(landing.x-top.x)+normal.z*(landing.z-top.z))/normal.y+.015
	var support_basis:=Basis(Vector3.UP,atan2(-facing.x,-facing.z))
	var landing_support: Dictionary=motor.ground_support.evaluate(landing,support_basis,data.obstacle_source,normal)
	landing_support_samples=landing_support.samples
	if not landing_support.supported:
		last_reject="EDGE_SUPPORT_MISSING"
		return false
	start=alignment
	actual_climb_height=landing.y-alignment.y
	vertical_retarget_offset=actual_climb_height-reference_climb_height
	# Distance is already owned by the detector. Never add a closer entry gate.
	if not segment_clear(motor.global_position,alignment): last_reject="ALIGNMENT_BLOCKED"; return false
	# Do not pull across a pit at a constant height. This checks the existing
	# support footprint without changing its rules or coyote state.
	var approach_from: Vector3=motor.global_position
	var samples:=maxi(1,ceili(approach_from.distance_to(alignment)/.10))
	for i in range(1,samples+1):
		if not motor.ground_support.evaluate(approach_from.lerp(alignment,float(i)/samples),support_basis).supported:
			last_reject="APPROACH_UNSUPPORTED"
			return false
	var previous:=start
	for i in range(1,81):
		var target:=trajectory(float(i)/80)
		if not segment_clear(previous,target): last_reject="TRAJECTORY_BLOCKED"; return false
		previous=target
	data["landing_position"]=landing
	data["target_position"]=landing
	return true

func begin(data: Dictionary) -> void:
	var speed:=Vector2(motor.velocity.x,motor.velocity.z).length()
	entry_source="MOVING" if speed>=mantle_moving_entry_speed_threshold else "IDLE"
	playback_start_frame=mantle_moving_start_frame if entry_source=="MOVING" else mantle_idle_start_frame
	running=true
	progress=frame_progress(playback_start_frame)
	input_at_exit=Vector2.ZERO
	alignment_elapsed=0
	exit_elapsed=0
	stalled_elapsed=0
	collision_blocked=false
	source=data.obstacle_source
	wall_point=data.obstacle_position
	wall_normal=data.obstacle_normal.normalized()
	landing_plane_normal=data.top_normal
	source_transform=source.global_transform
	start=motor.global_position
	var distance:=start.distance_to(alignment)
	long_approach=distance>mantle_long_approach_distance
	effective_alignment_duration=maxf(.25,1.5*distance/mantle_approach_speed) if long_approach else maxf(mantle_alignment_duration,minf(.25,distance/2.0))
	entry_yaw=motor.visual.rotation.y
	original_crouch=motor.crouch.requested
	motor.crouch.clear_handoff()
	motor.crouch.requested=false
	motor.crouch.phase=motor.crouch.Phase.STANDING
	motor.crouch.resize(motor.crouch.standing_capsule_height)
	motor.velocity=Vector3.ZERO
	var a=motor.get_node("AnimationController")
	prepare_clip(a.player.get_animation(ACTION))
	var node: AnimationNodeAnimation=a.tree.tree_root.get_node("Mantle")
	# Godot applies stretch to the offset too: offset is in timeline seconds.
	node.start_offset=float(playback_start_frame)/SOURCE_FPS/mantle_playback_speed
	node.timeline_length=clip_length/mantle_playback_speed

func prepare_clip(clip: Animation) -> void:
	clip_length=clip.length
	clip.loop_mode=Animation.LOOP_NONE
	if source_hips.is_empty():
		for t in clip.get_track_count():
			if clip.track_get_type(t)==Animation.TYPE_POSITION_3D and str(clip.track_get_path(t)).ends_with(":mixamorig_Hips"):
				source_track=t
				for k in clip.track_get_key_count(t): source_hips.append(clip.track_get_key_value(t,k))
	if source_track<0: return
	# Rig units are centimeters, local -Z is world up. Cancel trajectory
	# displacement, retaining authored joint poses and crouched top-out.
	for k in source_hips.size():
		var value: Vector3=source_hips[k]
		value.x=source_hips[0].x
		value.y=source_hips[0].y
		value.z+=100.0*reference_profile_position(clip.track_get_key_time(source_track,k)/clip.length,Vector3.ZERO,Vector3(0,reference_climb_height,-1)).y
		clip.track_set_key_value(source_track,k,value)

func safe_move(target: Vector3) -> bool:
	current_target=target
	var collision=motor.move_and_collide(target-motor.global_position)
	if collision!=null and motor.global_position.distance_to(target)>.02:
		collision_blocked=true
		return false
	return true

func step(delta: float,stick: Vector2,jump: bool,dodge_pressed: bool) -> bool:
	if not running: return false
	if owner_controller.phase==owner_controller.Phase.EXIT:
		exit_elapsed+=delta
		if exit_elapsed>=mantle_exit_blend_time: owner_controller.finish("COMPLETED")
		return false
	if owner_controller.phase==owner_controller.Phase.ENTRY:
		if dodge_pressed and owner_controller.request_traversal_interrupt(owner_controller.Interrupt.DODGE): return false
		if jump and owner_controller.request_traversal_interrupt(owner_controller.Interrupt.JUMP): return false
	if not is_instance_valid(source) or source.is_queued_for_deletion() or not source.global_transform.is_equal_approx(source_transform):
		owner_controller.finish("SOURCE_LOST_OR_MOVED")
		return false
	if not volume_clear(landing): owner_controller.finish("DESTINATION_BLOCKED"); return false
	var landing_basis:=Basis(Vector3.UP,atan2(-facing.x,-facing.z))
	if not motor.ground_support.evaluate(landing,landing_basis,source,landing_plane_normal).supported:
		owner_controller.finish("NO_LANDING_SUPPORT")
		return false
	var a=motor.get_node("AnimationController")
	var s=motor.animation_state
	s.jump_started=false
	s.was_grounded=s.is_grounded
	s.is_airborne=false
	s.move_input_magnitude=0
	s.horizontal_speed=0
	s.vertical_velocity=0
	s.locked_on=false
	s.gait=0
	s.run_buildup_ratio=0
	motor.velocity=Vector3.ZERO
	if owner_controller.phase==owner_controller.Phase.ENTRY:
		alignment_elapsed+=delta
		var weight:=smoothstep(0,1,alignment_elapsed/effective_alignment_duration)
		var next_position:=start.lerp(alignment,weight)
		var support_basis:=Basis(Vector3.UP,atan2(-facing.x,-facing.z))
		if not motor.ground_support.evaluate(next_position,support_basis).supported: owner_controller.finish("APPROACH_UNSUPPORTED"); return false
		var previous_position: Vector3=motor.global_position
		if not safe_move(next_position): owner_controller.finish("ALIGNMENT_BLOCKED"); return false
		if long_approach:
			s.horizontal_speed=motor.global_position.distance_to(previous_position)/maxf(delta,.001)
			s.move_input_magnitude=clampf(s.horizontal_speed/motor.walk_speed,0,1)
			s.move_direction_world=facing
			s.move_local=Vector2(0,1)
			s.gait=1 if s.horizontal_speed>motor.walk_speed else 0
		var yaw:=atan2(-facing.x,-facing.z)
		motor.visual.rotation.y=lerp_angle(entry_yaw,yaw,weight)
		if alignment_elapsed>=effective_alignment_duration:
			if motor.global_position.distance_to(alignment)>mantle_alignment_position_tolerance or absf(wrapf(motor.visual.rotation.y-yaw,-PI,PI))>deg_to_rad(mantle_alignment_angle_tolerance):
				owner_controller.finish("ALIGNMENT_FAILED")
				return false
			start=motor.global_position
			owner_controller._set_phase(owner_controller.Phase.ACTIVE)
	elif owner_controller.phase==owner_controller.Phase.ACTIVE:
		s.is_grounded=false
		var previous_progress:=progress
		if a._playback.get_current_node()==&"Mantle":
			var node: AnimationNodeAnimation=a.tree.tree_root.get_node("Mantle")
			progress=clampf((node.start_offset+a._playback.get_current_play_position())*mantle_playback_speed/clip_length,0,1)
		stalled_elapsed=0.0 if progress>previous_progress+.00001 else stalled_elapsed+delta
		if stalled_elapsed>1.0: owner_controller.finish("ANIMATION_STALLED"); return false
		if not safe_move(trajectory(progress)): owner_controller.finish("TRAJECTORY_BLOCKED"); return false
		if progress>=frame_progress(mantle_exit_handoff_frame)-.00001:
			motor.velocity=Vector3(0,-.5,0)
			motor.move_and_slide()
			motor.apply_floor_snap()
			motor.ground_support.refresh(0)
			motor.ground_support.reset_coyote()
			if not motor.ground_support.has_ground_support: owner_controller.finish("NO_LANDING_SUPPORT"); return false
			s.is_grounded=true
			s.was_grounded=true
			s.move_input_magnitude=stick.length()
			input_at_exit=stick
			owner_controller._set_phase(owner_controller.Phase.EXIT)
			return false # Normal motor chooses destination using current input.
	return true

func restore(reason: String) -> void:
	if not running: return
	var was_entry: bool=owner_controller.phase==owner_controller.Phase.ENTRY
	running=false
	if reason!="COMPLETED": motor.velocity=Vector3.ZERO
	if was_entry and original_crouch:
		motor.crouch.requested=true
		motor.crouch.phase=motor.crouch.Phase.CROUCHED
		motor.crouch.resize(motor.crouch.crouch_capsule_height)
	var a=motor.get_node("AnimationController")
	a._episode_visible=false
	a._intentional_jump_episode=false
	a.fall_visual_committed=false
	if reason!="COMPLETED": a._enter(&"Locomotion")

func polish_debug_text() -> String:
	var camera=motor.get_node("CameraRig")
	return "MANTLE POLISH\nPlayback %.2f / Frame %.2f / %s\nRetargeted hoist start %s / Target %s / End %s\nHoist Progress %.3f / Arc Height %.2f / Bias %.2f\nCamera %s / Target %s / Error %.3fm" % [mantle_playback_speed,current_frame(),sync_phase(),trajectory(frame_progress(mantle_hoist_start_frame)),current_target,landing,smoothstep(mantle_hoist_start_frame,mantle_hoist_end_frame,current_frame()),mantle_hoist_arc_height,mantle_hoist_arc_forward_bias,"MANTLE" if camera.mantle_camera_active else "FREE",camera.mantle_camera_target,camera.global_position.distance_to(camera.mantle_camera_target)]

func exit_debug_text() -> String:
	var a=motor.get_node("AnimationController")
	return "MANTLE EXIT\nEdge %s / Landing %s\nRequested %.3fm / Safe %.3fm / Minimum %.3fm\nTrajectory Complete %s / Handoff %d\nExit Blend %.2fs / Destination %s" % [ledge_edge,landing,mantle_landing_edge_setback,safe_edge_setback,minimum_safe_setback,current_frame()>=mantle_hoist_end_frame,mantle_exit_handoff_frame,mantle_exit_blend_time,a.current_state]

func debug_text() -> String:
	var angle:=rad_to_deg(absf(wrapf(motor.visual.rotation.y-atan2(-facing.x,-facing.z),-PI,PI)))
	var wall_distance: float=(motor.global_position-wall_contact).dot(-facing)+wall_contact_distance
	var retarget_text: String="\nHeight actual %.3f / Reference %.3f / Delta %+.3f / Ratio %.3f / Phase weight %.3f" % [actual_climb_height,reference_climb_height,vertical_retarget_offset,actual_climb_height/reference_climb_height,height_difference_weight(progress)]
	var hand_ik=motor.get_node_or_null("MantleHandIK")
	if hand_ik!=null: retarget_text+="\n"+hand_ik.debug_text()
	return exit_debug_text()+"\n"+polish_debug_text()+retarget_text+"\n%s / %s / Start %d\nAlignment %.3fm / %.2f degrees\nInput At Exit %s / Blend %.2fs\nCollision Blocked %s / Reject %s\nWall distance %.3fm / Launch %.2fm / Contact %.2fm\nLaunch frames %d-%d smoothstep / Phase %.3f" % [ACTION,entry_source,playback_start_frame,motor.global_position.distance_to(alignment),angle,input_at_exit,mantle_exit_blend_time,collision_blocked,last_reject,wall_distance,selected_launch_distance,wall_contact_distance,playback_start_frame,launch_contact_frame,progress]

func _process(_delta: float) -> void:
	debug_mesh.visible=(mantle_debug or owner_controller.traversal_debug) and running
	if not debug_mesh.visible: return
	var mesh:=ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	mesh.surface_set_color(Color.ORANGE)
	for i in 40:
		mesh.surface_add_vertex(trajectory(float(i)/40))
		mesh.surface_add_vertex(trajectory(float(i+1)/40))
	for point in [start,alignment,wall_contact,top,ledge_edge,previous_landing,landing,current_target,motor.global_position,trajectory(frame_progress(mantle_hoist_start_frame)),motor.get_node("CameraRig").mantle_camera_target]:
		for axis in [Vector3.RIGHT,Vector3.UP,Vector3.BACK]:
			mesh.surface_add_vertex(point-axis*.07)
			mesh.surface_add_vertex(point+axis*.07)
	for i in 32:
		mesh.surface_add_vertex(landing+Vector3(cos(TAU*i/32),0,sin(TAU*i/32))*motor.ground_support.ground_support_radius)
		mesh.surface_add_vertex(landing+Vector3(cos(TAU*(i+1)/32),0,sin(TAU*(i+1)/32))*motor.ground_support.ground_support_radius)
	for sample in landing_support_samples:
		mesh.surface_add_vertex(sample.from)
		mesh.surface_add_vertex(sample.to)
	# Cyan launch, magenta contact, green landing, white detected wall normal.
	for marker in [[alignment,Color.CYAN],[wall_contact,Color.MAGENTA],[landing,Color.GREEN],[wall_point,Color.WHITE]]:
		mesh.surface_set_color(marker[1])
		var point: Vector3=marker[0]
		mesh.surface_add_vertex(point)
		mesh.surface_add_vertex(point+Vector3.UP*.5)
	mesh.surface_set_color(Color.WHITE)
	mesh.surface_add_vertex(wall_point)
	mesh.surface_add_vertex(wall_point+wall_normal*.4)
	mesh.surface_end()
	debug_mesh.mesh=mesh
