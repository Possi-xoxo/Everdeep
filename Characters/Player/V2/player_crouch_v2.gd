extends Node
## Shared Free/Locked physical crouch mode. AnimationTree owns clip progress.
enum Phase { STANDING, ENTER, CROUCHED, EXIT }
@export_category("Crouch")
## Zero inherits the motor's current Walk speed.
@export_range(0,5,.05) var crouch_move_speed: float = 0.0
## Zero inherits the standing Run starting speed; crouch never builds Sprint.
@export_range(0,8,.05) var crouch_run_speed: float = 0.0
@export_range(.8,1.2,.05) var crouch_enter_playback_speed: float = 1.0
@export_range(.8,1.2,.05) var crouch_exit_playback_speed: float = 1.0
## Presentation only: blends idle, movement and run-stop poses without delaying input.
@export_range(.10,.60,.01) var crouch_locomotion_blend_time: float = .30
@export_range(.9,1.6,.01) var crouch_capsule_height: float = 1.10
@export_range(.10,.30,.01) var crouch_enter_blend_time: float = .15
@export_range(.10,.30,.01) var crouch_exit_blend_time: float = .15
@export_range(.8,1,.01) var crouch_enter_exit_progress: float = 1.0
@export_range(.8,1,.01) var crouch_exit_exit_progress: float = 1.0
@export var crouch_debug: bool = false
@export_subgroup("Transitions")
@export_range(.80,.95,.01) var crouch_enter_handoff_progress: float = .88
@export_range(.80,.95,.01) var crouch_exit_handoff_progress: float = .88
@export_range(.05,.15,.01) var crouch_transition_handoff_blend: float = .08
@export_range(.10,.20,.01) var crouch_transition_move_threshold: float = .15
var transition_progress: float = 0.0
@export_subgroup("Moving Transitions")
@export_range(.10,.20,.01) var moving_crouch_enter_blend_time: float = .15
@export_range(.10,.20,.01) var moving_crouch_exit_blend_time: float = .15
@export_range(.5,8,.1) var crouch_collider_transition_speed: float = 4.0
var moving_transition: bool = false
@export_subgroup("Locomotion Continuity")
@export_range(.08,.20,.01) var crouch_move_input_threshold: float = .12
@export_range(.10,.25,.01) var crouch_idle_entry_delay: float = .15
## Shared by locomotion and posture transitions involving crouched Idle.
@export_range(.10,.60,.01) var crouch_move_to_idle_blend: float = .30
@export_range(.08,.60,.01) var crouch_idle_to_move_blend: float = .30
@export_range(1,25,.5) var crouch_direction_blend_speed: float = 12.0
var crouch_has_move_intent: bool = false
var idle_grace_timer: float = 0.0
var animation_moving: bool = false
var animation_running: bool = false
var current_crouch_input_direction := Vector2(0,1)
var previous_gait: int = 0
var handoff_active: bool = false
var handoff_this_tick: bool = false
var handoff_phase: Phase = Phase.STANDING
var current_input := Vector2.ZERO
var current_shift: bool = false
var chosen_destination: String = ""
var phase: Phase = Phase.STANDING
var requested: bool = false
var standing_capsule_height: float
var standing_capsule_radius: float
var base_y: float
var can_stand: bool = true
var stand_blocked_by: String = ""
var transition_count: int = 0
var direction_blend := Vector2.ZERO
var running: bool = false
var collision: CollisionShape3D
var standing_shape: CapsuleShape3D
@onready var motor=get_parent()

func _ready() -> void:
	collision=motor.get_node("CollisionShape3D")
	collision.shape=collision.shape.duplicate()
	standing_shape=collision.shape.duplicate()
	standing_capsule_height=standing_shape.height
	standing_capsule_radius=standing_shape.radius
	base_y=collision.position.y-standing_capsule_height*.5

func active() -> bool: return phase!=Phase.STANDING

func speed() -> float:
	if running: return crouch_run_speed if crouch_run_speed>0 else motor.run_start_speed
	return crouch_move_speed if crouch_move_speed>0 else motor.walk_speed

func motion_request(stick: Vector2,shift: bool,delta: float=1.0/60.0) -> void:
	var moving:=stick.length()>crouch_transition_move_threshold
	running=(phase==Phase.CROUCHED or (phase==Phase.ENTER and moving_transition)) and shift and moving and not motor.dodge.is_dodging
	# Presentation grace never changes motor input, running speed or braking.
	crouch_has_move_intent=stick.length()>crouch_move_input_threshold
	if not active() or motor.dodge.is_dodging or motor.dodge.run_roll_recovery_visible or not (motor.is_on_floor() or motor.step_solver.active):
		animation_moving=false
		animation_running=false
		idle_grace_timer=0.0
	elif crouch_has_move_intent:
		animation_moving=true
		animation_running=shift
		idle_grace_timer=0.0
		current_crouch_input_direction=Vector2(stick.x,-stick.y).normalized()
	else:
		idle_grace_timer=minf(idle_grace_timer+delta,crouch_idle_entry_delay)
		if idle_grace_timer>=crouch_idle_entry_delay:
			animation_moving=false
			animation_running=false

func update_direction_blend(delta: float) -> void:
	# Stay on the cardinal diamond while moving: Cartesian reversal would
	# cross its Idle center. Radius alone controls the genuine Idle blend.
	var weight: float=absf(direction_blend.x)+absf(direction_blend.y)
	var angle: float=current_crouch_input_direction.angle() if weight<.001 else direction_blend.angle()
	angle=lerp_angle(angle,current_crouch_input_direction.angle(),1.0-exp(-crouch_direction_blend_speed*delta))
	var duration: float=crouch_idle_to_move_blend if animation_moving else crouch_move_to_idle_blend
	weight=move_toward(weight,1.0 if animation_moving else 0.0,delta/duration)
	var direction:=Vector2.from_angle(angle)
	direction_blend=direction/(absf(direction.x)+absf(direction.y))*weight

func resize(height: float) -> void:
	collision.shape.height=clampf(height,standing_capsule_radius*2,standing_capsule_height)
	collision.position.y=base_y+collision.shape.height*.5

func standing_clear() -> bool:
	var q:=PhysicsShapeQueryParameters3D.new()
	q.shape=standing_shape
	q.transform=collision.global_transform
	q.transform.origin=motor.global_transform*Vector3(collision.position.x,base_y+standing_capsule_height*.5+.002,collision.position.z)
	q.collision_mask=motor.collision_mask
	q.exclude=[motor.get_rid()]
	q.margin=0
	var hits: Array=motor.get_world_3d().direct_space_state.intersect_shape(q,1)
	can_stand=hits.is_empty()
	stand_blocked_by="" if can_stand else str(hits[0].collider.name)
	return can_stand

func begin(next: Phase) -> void:
	clear_handoff()
	previous_gait=motor.animation_state.gait
	phase=next
	transition_count+=1
	motor._run_time=0
	if motor.turn_180!=null: motor.turn_180.cancel()
	if moving_requested(): begin_moving_handoff()

func begin_moving_handoff() -> void:
	# Physical resize owns ENTER/EXIT completion; no posture clip is required.
	moving_transition=true
	handoff_active=true
	handoff_this_tick=true
	handoff_phase=phase
	chosen_destination=destination_label(phase==Phase.ENTER)

func lock_attempt() -> bool:
	return true # Lock-On modifies crouch locomotion; it does not require standing.

func clear_handoff() -> void:
	moving_transition=false
	handoff_active=false
	handoff_this_tick=false
	handoff_phase=Phase.STANDING
	transition_progress=0.0
	chosen_destination=""

func moving_requested() -> bool:
	return current_input.length()>crouch_transition_move_threshold

func standing_handoff() -> bool:
	return phase==Phase.EXIT and handoff_active

func destination_label(entering: bool) -> String:
	var moving:=moving_requested()
	var prefix: String="CROUCH" if entering else "STANDING"
	if not motor.lock_on.is_locked():
		return prefix+("_RUN" if entering and current_shift else "_WALK") if moving else prefix+"_IDLE"
	if not moving: return "LOCKED_"+prefix+"_IDLE"
	var side: String=("LEFT" if current_input.x<0 else "RIGHT") if absf(current_input.x)>absf(current_input.y) else ("FORWARD" if current_input.y<0 else "BACK")
	return "LOCKED_"+prefix+("_RUN_" if current_shift else "_WALK_")+side

func update(wants_crouch: bool,delta: float=1.0/60.0,stick: Vector2=Vector2.ZERO,shift: bool=false) -> void:
	handoff_this_tick=false
	current_input=stick
	current_shift=shift
	requested=wants_crouch
	var a=motor.get_node("AnimationController")
	if motor.dodge.is_dodging or motor.dodge.run_roll_recovery_visible:
		clear_handoff()
		return
	if not motor.is_on_floor() and not motor.step_solver.active:
		clear_handoff()
		return
	if active():
		if phase==Phase.EXIT and not standing_clear():
			clear_handoff()
			phase=Phase.CROUCHED
			resize(crouch_capsule_height)
		if phase==Phase.EXIT and requested:
			begin(Phase.ENTER)
		elif phase in [Phase.CROUCHED,Phase.ENTER] and not requested:
			if standing_clear(): begin(Phase.EXIT)
		if phase in [Phase.ENTER,Phase.EXIT] and not moving_transition and moving_requested():
			if phase==Phase.EXIT or collision.shape.height<=crouch_capsule_height+.01:
				begin_moving_handoff()
		if phase in [Phase.ENTER,Phase.EXIT] and not moving_transition:
			var state: StringName=&"CrouchEnter" if phase==Phase.ENTER else &"CrouchExit"
			var threshold: float=crouch_enter_exit_progress if phase==Phase.ENTER else crouch_exit_exit_progress
			var playback_speed: float=crouch_enter_playback_speed if phase==Phase.ENTER else crouch_exit_playback_speed
			var length: float=a.player.get_animation(a.CLIPS[String(state)]).length/playback_speed
			if handoff_active:
				# Keep the original physical phase/clearance window through the tail.
				transition_progress=minf(1.0,transition_progress+delta/length)
			elif a.current_state==state and a._playback.get_current_node()==state:
				transition_progress=a._playback.get_current_play_position()/length
			var handoff: float=crouch_enter_handoff_progress if phase==Phase.ENTER else crouch_exit_handoff_progress
			if not handoff_active and transition_progress>=minf(handoff,threshold):
				handoff_active=true
				handoff_this_tick=true
				handoff_phase=phase
				chosen_destination=destination_label(phase==Phase.ENTER)
			if transition_progress>=threshold:
				phase=Phase.CROUCHED if phase==Phase.ENTER else Phase.STANDING
		var height: float=standing_capsule_height if phase in [Phase.EXIT,Phase.STANDING] else crouch_capsule_height
		resize(move_toward(collision.shape.height,height,crouch_collider_transition_speed*delta))
		if moving_transition and phase in [Phase.ENTER,Phase.EXIT] and is_equal_approx(collision.shape.height,height):
			phase=Phase.CROUCHED if phase==Phase.ENTER else Phase.STANDING
		return
	if requested and a.current_state==&"Locomotion" and a.grounded.transition==&"Loops" and not motor.step_solver.active and not motor.roll_traversal.active and not (motor.turn_180!=null and motor.turn_180.active):
		begin(Phase.ENTER)
		resize(move_toward(collision.shape.height,crouch_capsule_height,crouch_collider_transition_speed*delta))

func animation_node() -> StringName:
	if phase==Phase.ENTER and not handoff_active: return &"CrouchEnter"
	if phase==Phase.EXIT: return &"Locomotion" if handoff_active else &"CrouchExit"
	if handoff_active and phase==Phase.ENTER:
		if motor.lock_on.is_locked(): return &"CrouchLockedRun" if animation_running else &"CrouchLocked"
		if not animation_moving: return &"CrouchIdle"
		return &"CrouchRun" if animation_running else &"CrouchWalk"
	if motor.lock_on.is_locked(): return &"CrouchLockedRun" if animation_running else &"CrouchLocked"
	if animation_running: return &"CrouchRun"
	return &"CrouchWalk" if animation_moving else &"CrouchIdle"

func debug_text() -> String:
	var a=motor.get_node("AnimationController")
	var node: String=String(animation_node())
	if node in ["CrouchLocked","CrouchLockedRun"]:
		if direction_blend.length()<.1: node="CrouchIdle"
		elif absf(direction_blend.x)>absf(direction_blend.y): node="CrouchLeft" if direction_blend.x<0 else "CrouchRight"
		else: node="CrouchWalk" if direction_blend.y>0 else "CrouchBack"
		if animation_running and node!="CrouchIdle": node={"CrouchWalk":"CrouchRun","CrouchLeft":"CrouchRunLeft","CrouchRight":"CrouchRunRight","CrouchBack":"CrouchRunBack"}[node]
	var clip: String=String(a.CLIPS.get(node,"Standing")) if active() else "Standing"
	var continuity_debug: String="\n\nCROUCH CONTINUITY\nMove Intent: %s / Input Magnitude: %.2f\nHorizontal Speed: %.2f\nIdle Grace Active: %s / Timer: %.2f / %.2f\nAnimation Mode: %s\nInput Direction: %s\nStop Clip Enabled: false" % [crouch_has_move_intent,current_input.length(),motor.animation_state.horizontal_speed,animation_moving and not crouch_has_move_intent,idle_grace_timer,crouch_idle_entry_delay,"CROUCH_MOVE" if animation_moving else "CROUCH_IDLE",current_crouch_input_direction]
	var modifier_debug: String="\n\nCROUCH LOCOMOTION MODIFIER\nToggle On: %s / Physical Phase: %s\nMovement Input: %.2f / Animation: %s\nPosture Clip Active: %s / Direct Moving Transition: %s\nPrevious Gait: %s / Target Speed: %.2f" % [requested,Phase.keys()[phase],current_input.length(),clip,phase in [Phase.ENTER,Phase.EXIT] and not handoff_active,moving_transition and phase in [Phase.ENTER,Phase.EXIT],["WALK","RUN","SPRINT"][previous_gait],motor.target_speed]
	var handoff: float=crouch_enter_handoff_progress if phase==Phase.ENTER else crouch_exit_handoff_progress
	var transition_debug: String="\n\nCROUCH TRANSITION\nState: %s / Progress: %.2f / Handoff: %.2f\nCurrent Input: %s / Current Combat Input: %s\nCurrent Mode: %s\nPredicted Destination: %s\nChosen Destination: %s" % [Phase.keys()[phase],transition_progress,handoff,current_input,motor.animation_state.combat_input,"LOCKED" if motor.lock_on.is_locked() else "FREE",destination_label(phase==Phase.ENTER),chosen_destination]
	return "CROUCH\nToggle On: %s / Mode: %s\nCrouched: %s / Phase: %s\nCapsule: %.2f / Standing: %.2f / Radius: %.2f\nCan Stand: %s / Blocker: %s\nMovement: %s / Speed: %.2f\nDominant Action: %s\nTarget-relative Input: %s / Blend: %s" % [requested,"LOCKED" if motor.lock_on.is_locked() else "FREE",active(),Phase.keys()[phase],collision.shape.height,standing_capsule_height,standing_capsule_radius,can_stand,stand_blocked_by,animation_node() if active() else &"Standing",motor.animation_state.horizontal_speed,clip,motor.animation_state.combat_input,direction_blend]+transition_debug+modifier_debug+continuity_debug
