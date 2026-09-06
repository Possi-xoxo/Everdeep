extends Node
## Shared Free/Locked physical crouch mode. AnimationTree owns clip progress.
enum Phase { STANDING, ENTER, CROUCHED, EXIT }
@export_category("Crouch")
## Zero inherits the motor's current Walk speed.
@export_range(0,5,.05) var crouch_move_speed: float = 0.0
## Zero inherits the standing Run starting speed; crouch never builds Sprint.
@export_range(0,8,.05) var crouch_run_speed: float = 0.0
@export_range(.5,8,.1) var crouch_collider_transition_speed: float = 4.0
@export_range(.8,1.2,.05) var crouch_enter_playback_speed: float = 1.0
@export_range(.8,1.2,.05) var crouch_exit_playback_speed: float = 1.0
@export_range(1,25,.5) var crouch_direction_blend_speed: float = 12.0
## Presentation only: blends idle, movement and run-stop poses without delaying input.
@export_range(.10,.60,.01) var crouch_locomotion_blend_time: float = .30
@export_range(.9,1.6,.01) var crouch_capsule_height: float = 1.10
@export_range(.10,.30,.01) var crouch_enter_blend_time: float = .15
@export_range(.10,.30,.01) var crouch_exit_blend_time: float = .15
@export_range(.8,1,.01) var crouch_enter_exit_progress: float = 1.0
@export_range(.8,1,.01) var crouch_exit_exit_progress: float = 1.0
@export var crouch_debug: bool = false
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
var run_stop_active: bool = false
var previous_input := Vector2.ZERO
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

func motion_request(stick: Vector2,shift: bool) -> void:
	var moving:=stick.length()>.01
	if running and not moving and (not motor.lock_on.is_locked() or previous_input.y< -absf(previous_input.x)):
		run_stop_active=true
	if not active() or phase!=Phase.CROUCHED or moving or motor.dodge.is_dodging:
		run_stop_active=false
	running=phase==Phase.CROUCHED and shift and moving and not motor.dodge.is_dodging
	previous_input=stick

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
	phase=next
	transition_count+=1
	motor._run_time=0
	if motor.turn_180!=null: motor.turn_180.cancel()

func lock_attempt() -> bool:
	return true # Lock-On modifies crouch locomotion; it does not require standing.

func update(wants_crouch: bool,delta: float=1.0/60.0) -> void:
	requested=wants_crouch
	var a=motor.get_node("AnimationController")
	if motor.dodge.is_dodging or motor.dodge.run_roll_recovery_visible: return
	if not motor.is_on_floor() and not motor.step_solver.active: return
	if active():
		if phase==Phase.EXIT and not standing_clear():
			phase=Phase.CROUCHED
			resize(crouch_capsule_height)
		if phase==Phase.EXIT and requested:
			begin(Phase.ENTER)
		elif phase in [Phase.CROUCHED,Phase.ENTER] and not requested:
			if standing_clear(): begin(Phase.EXIT)
		if phase in [Phase.ENTER,Phase.EXIT]:
			var state: StringName=&"CrouchEnter" if phase==Phase.ENTER else &"CrouchExit"
			var threshold: float=crouch_enter_exit_progress if phase==Phase.ENTER else crouch_exit_exit_progress
			if a.current_state==state and a._playback.get_current_node()==state:
				var playback_speed: float=crouch_enter_playback_speed if phase==Phase.ENTER else crouch_exit_playback_speed
				var length: float=a.player.get_animation(a.CLIPS[String(state)]).length/playback_speed
				if a._playback.get_current_play_position()>=length*threshold:
					phase=Phase.CROUCHED if phase==Phase.ENTER else Phase.STANDING
		var height: float=standing_capsule_height if phase in [Phase.EXIT,Phase.STANDING] else crouch_capsule_height
		resize(move_toward(collision.shape.height,height,crouch_collider_transition_speed*delta))
		return
	if requested and a.current_state==&"Locomotion" and a.grounded.transition==&"Loops" and not motor.step_solver.active and not motor.roll_traversal.active and not (motor.turn_180!=null and motor.turn_180.active):
		begin(Phase.ENTER)
		resize(move_toward(collision.shape.height,crouch_capsule_height,crouch_collider_transition_speed*delta))

func animation_node() -> StringName:
	if phase==Phase.ENTER: return &"CrouchEnter"
	if phase==Phase.EXIT: return &"CrouchExit"
	if run_stop_active:
		var a=motor.get_node("AnimationController")
		if a.current_state==&"CrouchRunStop" and a._playback.get_current_play_position()>=a.player.get_animation(a.CLIPS.CrouchRunStop).length-.001:
			run_stop_active=false
		else: return &"CrouchRunStop"
	if motor.lock_on.is_locked(): return &"CrouchLockedRun" if running else &"CrouchLocked"
	if running: return &"CrouchRun"
	return &"CrouchWalk" if motor.animation_state.move_input_magnitude>.01 else &"CrouchIdle"

func debug_text() -> String:
	var a=motor.get_node("AnimationController")
	var node: String=String(animation_node())
	if node in ["CrouchLocked","CrouchLockedRun"]:
		if direction_blend.length()<.1: node="CrouchIdle"
		elif absf(direction_blend.x)>absf(direction_blend.y): node="CrouchLeft" if direction_blend.x<0 else "CrouchRight"
		else: node="CrouchWalk" if direction_blend.y>0 else "CrouchBack"
		if running and node!="CrouchIdle": node={"CrouchWalk":"CrouchRun","CrouchLeft":"CrouchRunLeft","CrouchRight":"CrouchRunRight","CrouchBack":"CrouchRunBack"}[node]
	var clip: String=String(a.CLIPS.get(node,"Standing")) if active() else "Standing"
	return "CROUCH\nToggle On: %s / Mode: %s\nCrouched: %s / Phase: %s\nCapsule: %.2f / Standing: %.2f / Radius: %.2f\nCan Stand: %s / Blocker: %s\nMovement: %s / Speed: %.2f\nDominant Action: %s\nTarget-relative Input: %s / Blend: %s" % [requested,"LOCKED" if motor.lock_on.is_locked() else "FREE",active(),Phase.keys()[phase],collision.shape.height,standing_capsule_height,standing_capsule_radius,can_stand,stand_blocked_by,animation_node() if active() else &"Standing",motor.animation_state.horizontal_speed,clip,motor.animation_state.combat_input,direction_blend]
