extends Node
## Sibling of BracedHang. Shared acquisition, independent anchor, clock and pose.
enum HangPhase { NONE, CATCH, SETTLE, IDLE, RELEASE }
const CATCH_SOURCE: StringName = &"TRV_JUMP_TO_FREE_HANG"
const IDLE_SOURCE: StringName = &"TRV_FREE_HANG_IDLE_B"
const CATCH_CLIP: StringName = &"FreeHangCatch_Runtime"
const IDLE_CLIP: StringName = &"FreeHangIdle_Runtime"
var actions = preload("res://Characters/Player/V2/player_free_hang_actions_v2.gd").new()
@export_range(.30,.70,.01) var free_hang_minimum_hop_distance: float = .40
## Presentation only: keep validated handholds and gameplay anchors unchanged.
@export_range(0,.30,.01) var free_hang_visual_body_drop: float = .08
@export_range(.5,2,.05) var free_hang_lateral_playback_speed: float = 1.20
@export var enabled: bool = true
@export_range(0,.25,.01) var free_hang_momentum_retention: float = .10
@export_range(.01,.20,.01) var free_hang_max_swing_offset: float = .10
@export_range(4,20,.5) var free_hang_swing_damping: float = 10.0
@export_range(10,60,1) var free_hang_spring_strength: float = 36.0
@export_range(1,20,.5) var free_hang_max_catch_velocity: float = 12.0
@export var free_hang_body_vertical_offset: float = 2.20
@export var free_hang_body_wall_offset: float = .50
## Keep the mesh outside the wall independently of the gameplay capsule.
@export var free_hang_visual_wall_offset: float = .18
## Authored fingers curl ~10cm above the wrist: wrist sits below the lip.
@export var free_hang_hand_vertical_offset: float = -.08
@export var free_hang_hand_wall_offset: float = .015
@export_range(.15,.30,.01) var free_hang_input_lockout: float = .25
@export_range(.05,.30,.01) var free_hang_alignment_duration: float = .15
@export var free_hang_debug: bool = false
var mantle_debug: bool:
	get: return free_hang_debug
var running: bool = false
var clips_ready: bool = false
var hang_phase: HangPhase = HangPhase.NONE
var elapsed: float = 0.0
var catch_duration: float = .80
var source: Node3D
var source_transform: Transform3D
var ledge_edge := Vector3.ZERO
var top := Vector3.ZERO
var landing_plane_normal := Vector3.UP
var wall_normal := Vector3.BACK
var facing := Vector3.FORWARD
var alignment := Vector3.ZERO
var entry_position := Vector3.ZERO
var baseline := Vector3.ZERO
var incoming_velocity := Vector3.ZERO
var retained_momentum := Vector3.ZERO
var swing_offset := Vector3.ZERO
var swing_velocity := Vector3.ZERO
var hand_targets: Dictionary = {}
var candidate: Dictionary = {}
var exit_reason: String = ""
var release_visual_remaining: float = 0.0
var release_visual_offset := Vector3.ZERO
var rig_base_position := Vector3.ZERO
@onready var owner_controller = get_parent()
@onready var motor = get_parent().get_parent()
var shared: Node:
	get: return owner_controller.hang

func anchor_for(edge: Vector3,normal: Vector3) -> Vector3:
	return edge+normal*free_hang_body_wall_offset-Vector3.UP*free_hang_body_vertical_offset

func validate(data: Dictionary) -> bool:
	return enabled and clips_ready and data.get("valid",false) and data.get("free_hang",false) and is_instance_valid(data.get("source")) and shared.clear_segment(motor.global_position,data.anchor,motor.crouch.standing_capsule_height) and clear_visual_space(motor.global_position,data.anchor,data.normal)

func begin(data: Dictionary) -> void:
	actions.reset()
	candidate=data.duplicate(true)
	source=data.source
	source_transform=source.global_transform
	ledge_edge=data.edge
	top=data.top
	landing_plane_normal=data.top_normal
	wall_normal=data.normal
	facing=data.facing
	alignment=data.anchor
	entry_position=motor.global_position
	baseline=entry_position
	incoming_velocity=motor.velocity
	retained_momentum=incoming_velocity.limit_length(free_hang_max_catch_velocity)*free_hang_momentum_retention
	# Vertical energy gets a smaller bounded arc; not a hanging ballistic jump.
	retained_momentum.y*=.25
	swing_velocity=retained_momentum
	swing_offset=Vector3.ZERO
	elapsed=0
	release_visual_remaining=0
	running=true
	hang_phase=HangPhase.CATCH
	shared.navigation.jump_visual=false
	shared.end_release_visual()
	motor.ground_support.consume_jump()
	motor.velocity=Vector3.ZERO
	motor.visual.global_rotation.y=atan2(wall_normal.x,wall_normal.z)
	var tangent: Vector3=facing.cross(Vector3.UP).normalized()
	hand_targets.clear()
	for side in ["Left","Right"]:
		var target: Vector3=ledge_edge+tangent*(-.263 if side=="Left" else .277)+wall_normal*free_hang_hand_wall_offset
		target.y=top.y-(landing_plane_normal.x*(target.x-top.x)+landing_plane_normal.z*(target.z-top.z))/landing_plane_normal.y+free_hang_hand_vertical_offset
		hand_targets[side]=target
	owner_controller._set_phase(owner_controller.Phase.ACTIVE)
	var state=motor.animation_state
	state.is_grounded=false
	state.was_grounded=false
	state.is_airborne=true
	state.jump_started=false
	state.horizontal_speed=0
	state.move_input_magnitude=0
	motor.get_node("AnimationController")._enter(&"FreeHangCatch")

func pose_owned() -> bool: return running
func current_frame() -> float: return 30.0
func hand_weight() -> float: return smoothstep(0,.15,elapsed)
func visual_offset() -> Vector3:
	var weight: float=1.0
	if actions.active and actions.state==&"FreeHangClimb": weight=1-smoothstep(0,.64,actions.progress)
	return (facing*(free_hang_body_wall_offset-free_hang_visual_wall_offset)-Vector3.UP*free_hang_visual_body_drop)*smoothstep(0,free_hang_alignment_duration,elapsed)*weight

func animation_name() -> StringName:
	if actions.active: return actions.state
	return &"FreeHangIdle" if elapsed>=catch_duration else &"FreeHangCatch"

func advance_exit(delta: float) -> void:
	if owner_controller.is_traversing: release_visual_remaining=0
	else: release_visual_remaining=maxf(0,release_visual_remaining-delta)

func exit_offset() -> Vector3:
	return release_visual_offset*smoothstep(0,.15,release_visual_remaining)

func clear_visual_space(a: Vector3,b: Vector3,normal: Vector3) -> bool:
	# Conservative free-hanging torso/head/leg proxy, excluding the gripping arms.
	# The gameplay capsule still receives its independent full sweep.
	var shape:=CapsuleShape3D.new()
	shape.radius=.16
	shape.height=1.90
	var query:=PhysicsShapeQueryParameters3D.new()
	query.shape=shape
	query.collision_mask=motor.collision_mask
	query.exclude=[motor.get_rid()]
	query.margin=.001
	var offset: Vector3=-normal*(free_hang_body_wall_offset-free_hang_visual_wall_offset)+Vector3.UP*(1.10-free_hang_visual_body_drop)
	query.transform=Transform3D(Basis.IDENTITY,b+offset)
	var space= motor.get_world_3d().direct_space_state
	if not space.intersect_shape(query,1).is_empty(): return false
	query.transform.origin=a+offset
	query.motion=b-a
	var fractions: PackedFloat32Array=space.cast_motion(query)
	return fractions.size()==2 and fractions[0]>=.999

func contacts_valid() -> bool:
	if not is_instance_valid(source) or source.is_queued_for_deletion(): return false
	if not source.global_transform.is_equal_approx(source_transform): return false
	for target: Vector3 in hand_targets.values():
		var probe: Vector3=target-wall_normal*(free_hang_hand_wall_offset+.04)-Vector3.UP*free_hang_hand_vertical_offset
		var hit: Dictionary=shared.ray(probe+Vector3.UP*.06,probe-Vector3.UP*.06)
		if hit.is_empty() or hit.collider!=source or hit.normal.dot(landing_plane_normal)<.98: return false
	return true

func step(delta: float,jump: bool=false,stick: Vector2=Vector2.ZERO,shift: bool=false) -> bool:
	if not running: return false
	if not is_instance_valid(source) or source.is_queued_for_deletion() or not source.global_transform.is_equal_approx(source_transform):
		owner_controller.finish("FREE_SOURCE_LOST")
		return true
	# Consume inputs during actions too, preventing a held conflicting command
	# from firing when the action finishes. Jump is intentionally a no-op.
	actions.input_tick(self,delta,stick,shift,jump)
	if actions.active:
		actions.advance(self,delta)
		return true
	if not contacts_valid():
		owner_controller.finish("FREE_CONTACT_LOST")
		return true
	elapsed+=delta
	baseline=entry_position.lerp(alignment,smoothstep(0,free_hang_alignment_duration,elapsed))
	# Substeps keep the damped spring bounded even on a long render/physics frame.
	var count: int=maxi(1,ceili(delta*120))
	var dt: float=delta/count
	for index in count:
		swing_velocity+=(-swing_offset*free_hang_spring_strength-swing_velocity*free_hang_swing_damping)*dt
		swing_offset=(swing_offset+swing_velocity*dt).limit_length(free_hang_max_swing_offset)
	var target: Vector3=baseline+swing_offset
	if shared.clear_segment(motor.global_position,target,motor.crouch.standing_capsule_height) and clear_visual_space(motor.global_position,target,wall_normal):
		motor.global_position=target
	else:
		swing_offset=Vector3.ZERO
		swing_velocity=Vector3.ZERO
		if shared.clear_segment(motor.global_position,baseline,motor.crouch.standing_capsule_height) and clear_visual_space(motor.global_position,baseline,wall_normal): motor.global_position=baseline
		else:
			owner_controller.finish("FREE_SPACE_BLOCKED")
			return true
	motor.velocity=Vector3.ZERO
	hang_phase=HangPhase.CATCH if elapsed<.15 else HangPhase.SETTLE
	if elapsed>=catch_duration and swing_offset.length()<.005 and swing_velocity.length()<.025:
		hang_phase=HangPhase.IDLE
	return true

func restore(reason: String) -> void:
	if not running: return
	if reason=="FREE_CLIMB_COMPLETED":
		running=false
		actions.reset()
		hang_phase=HangPhase.NONE
		release_visual_remaining=0
		exit_reason=reason
		motor.velocity=Vector3.ZERO
		var grounded=motor.animation_state
		grounded.is_grounded=true
		grounded.was_grounded=true
		grounded.is_airborne=false
		grounded.jump_started=false
		grounded.air_time=0
		motor.get_node("AnimationController")._enter(&"CrouchIdle")
		return
	release_visual_offset=visual_offset()
	actions.reset()
	release_visual_remaining=.15
	running=false
	hang_phase=HangPhase.RELEASE
	exit_reason=reason
	shared.last_source_id=source.get_instance_id() if is_instance_valid(source) else 0
	shared.last_edge=ledge_edge
	shared.cooldown=shared.regrab_cooldown
	shared.release_suppression_active=true
	shared.release_suppression_remaining=shared.release_regrab_timeout
	shared.acquisition.reset_history()
	motor.ground_support.consume_jump()
	motor.velocity=wall_normal*.35-Vector3.UP*.2
	var state=motor.animation_state
	state.is_grounded=false
	state.was_grounded=false
	state.is_airborne=true
	state.jump_started=false
	state.air_time=0
	var animation=motor.get_node("AnimationController")
	animation.visual_root.position=animation.visual_root_base_position+motor.global_basis.inverse()*release_visual_offset
	animation._episode_visible=true
	animation.fall_visual_committed=true
	animation._intentional_jump_episode=false
	animation._standing_jump_episode=false
	animation._enter(&"Fall")

func prepare_clips(player: AnimationPlayer) -> void:
	rig_base_position=motor.get_node("AnimationController").rig.position
	if not player.has_animation(CATCH_SOURCE) or not player.has_animation(IDLE_SOURCE):
		push_error("Free Hang catch/idle source missing; fallback disabled")
		return
	var idle: Animation=player.get_animation(IDLE_SOURCE).duplicate(true)
	var catch_clip: Animation=player.get_animation(CATCH_SOURCE).duplicate(true)
	var reference:=Vector3.ZERO
	for track in idle.get_track_count():
		if idle.track_get_type(track)==Animation.TYPE_POSITION_3D and str(idle.track_get_path(track)).ends_with(":mixamorig_Hips"):
			reference=idle.track_get_key_value(track,0)
	# Only the post-contact tail: omit the source's airborne approach/root lunge.
	var start: float=1.233333333
	catch_duration=catch_clip.length-start
	for track in catch_clip.get_track_count():
		var samples: Array=[]
		var frames: int=roundi(catch_duration*30)
		for frame in range(frames+1):
			var time: float=minf(catch_clip.length,start+frame/30.0)
			match catch_clip.track_get_type(track):
				Animation.TYPE_POSITION_3D: samples.append(catch_clip.position_track_interpolate(track,time))
				Animation.TYPE_ROTATION_3D: samples.append(catch_clip.rotation_track_interpolate(track,time))
				Animation.TYPE_SCALE_3D: samples.append(catch_clip.scale_track_interpolate(track,time))
				_: push_error("Unsupported Free Hang catch track"); return
		for key in range(catch_clip.track_get_key_count(track)-1,-1,-1): catch_clip.track_remove_key(track,key)
		for frame in samples.size(): catch_clip.track_insert_key(track,frame/30.0,samples[frame])
	catch_clip.length=catch_duration
	for clip in [idle,catch_clip]:
		for track in clip.get_track_count():
			if clip.track_get_type(track)==Animation.TYPE_POSITION_3D and str(clip.track_get_path(track)).ends_with(":mixamorig_Hips"):
				for key in clip.track_get_key_count(track): clip.track_set_key_value(track,key,reference)
	idle.loop_mode=Animation.LOOP_LINEAR
	catch_clip.loop_mode=Animation.LOOP_NONE
	player.get_animation_library("").add_animation(IDLE_CLIP,idle)
	player.get_animation_library("").add_animation(CATCH_CLIP,catch_clip)
	clips_ready=actions.prepare(self,player,reference)

func debug_text() -> String:
	return "HANG FREE / %s\nA/D: Shimmy | Shift+A/D: Hop | W: Climb | S: Release\nSpace: NO ACTION | Vertical hops: DISABLED\n%s | Travel %.3fm / Progress %.0f%%\nIncoming %s | Swing %s\nBody anchor %s | Last exit %s\n%s" % [actions.state if actions.active else HangPhase.keys()[hang_phase],actions.last_resolution,actions.distance,actions.progress*100,incoming_velocity,swing_offset,alignment,exit_reason,actions.query_debug()]
