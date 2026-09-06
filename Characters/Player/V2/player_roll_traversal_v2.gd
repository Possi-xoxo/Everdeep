extends "res://Characters/Player/V2/player_step_solver_v2.gd"
## Dedicated state/configuration. Reuses support, swept clearance, bounded lift,
## and debug drawing; never mutates the ordinary StepSolver instance.
@export_category("Roll Traversal")
@export_range(0.50,0.80,0.01) var roll_max_step_height: float = 0.70
@export_range(5,10,0.1) var roll_step_up_speed: float = 8.0
@export_range(0.30,0.60,0.01) var roll_step_forward_check_distance: float = 0.45
@export_range(0.15,0.30,0.01) var roll_step_min_curve_value: float = 0.20
var direction_match: bool = false
var last_lift_rise: float = 0.0
const RUN_STEP_FRAMES := Vector2(15,30)
const SPRINT_STEP_FRAMES := Vector2(9,24)
const WALK_STEP_FRAMES := Vector2(20,40)

func source_frame() -> float:
	var dodge=body.dodge
	return dodge.dodge_elapsed*dodge.playback_speed*dodge.SOURCE_FPS

func traversal_window_open() -> bool:
	if not body.dodge.is_rolling(): return false
	var window: Vector2=step_frame_window()
	var frame:=source_frame()
	return frame>=window.x-.0001 and frame<=window.y+.0001

func step_frame_window() -> Vector2:
	if body.dodge.clip==body.dodge.SPRINT: return SPRINT_STEP_FRAMES
	return RUN_STEP_FRAMES if body.dodge.clip==body.dodge.RUN else WALK_STEP_FRAMES

func _validate_property(property: Dictionary) -> void:
	if property.name in ["max_step_height","min_step_height","step_up_speed","minimum_lift_duration","candidate_lateral_offset"]:
		property.usage=PROPERTY_USAGE_NO_EDITOR

func prepare_roll(delta: float, horizontal: Vector3) -> bool:
	last_lift_rise=0.0
	# These inherited fields belong only to THIS dedicated helper.
	max_step_height=roll_max_step_height
	step_up_speed=roll_step_up_speed
	var dodge=body.dodge
	if not enabled:
		cancel("DISABLED")
		return false
	if active:
		_elapsed+=delta
		# Finish an already accepted bounded lift even if the movement curve
		# enters its zero phase. Never remain suspended waiting for forward input.
		if _elapsed>.4:
			cancel("TIMEOUT")
			return false
		if not _supported_at(_goal,_direction,collision.shape.radius):
			cancel("SUPPORT_LOST")
			return false
		if not _clear_destination(body.global_position,_goal):
			cancel("CLEARANCE_LOST")
			return false
		return true
	_lines.clear()
	_hits.clear()
	candidate=false
	top_walkable=false
	head_clearance=false
	support_valid=false
	direction_match=false
	if not dodge.is_rolling() or dodge.speed_multiplier<=roll_step_min_curve_value or horizontal.length()<.1:
		reason="NO_ACTIVE_ROLL_MOTION"
		return false
	if not traversal_window_open():
		reason="OUTSIDE_ROLL_FRAME_WINDOW"
		return false
	if not body.is_on_floor():
		reason="NO_GROUND_START"
		return false
	var direction: Vector3=dodge.dodge_direction
	direction_match=horizontal.normalized().dot(direction)>.99
	if not direction_match:
		reason="DIRECTION_MISMATCH"
		return false
	var base: Vector3=body.global_position
	var floor_hit:=_ray(base+Vector3.UP*.025,base-Vector3.UP*.08)
	if floor_hit.is_empty() or floor_hit.normal.dot(Vector3.UP)<cos(body.floor_max_angle):
		reason="NO_FLOOR_REFERENCE"
		return false
	var floor_y: float=floor_hit.position.y
	var radius: float=collision.shape.radius
	var origin:=Vector3(base.x,floor_y+.025,base.z)
	var low:=_ray(origin,origin+direction*(radius+roll_step_forward_check_distance))
	if low.is_empty():
		reason="NO_FORWARD_CONTACT"
		return false
	if low.normal.dot(direction)>-.25 or low.normal.dot(Vector3.UP)>=cos(body.floor_max_angle):
		reason="NOT_ROLLING_INTO_FACE"
		return false
	var point: Vector3=low.position
	var distance: float=(point-base).dot(direction)
	if distance<=0:
		reason="NOT_FORWARD"
		return false
	var beyond: Vector3=point+direction*.065
	var top:=_ray(Vector3(beyond.x,floor_y+roll_max_step_height+.015,beyond.z),Vector3(beyond.x,floor_y+.02,beyond.z))
	if top.is_empty():
		reason="NO_TOP_OR_TOO_TALL"
		return false
	step_height=top.position.y-floor_y
	if step_height<min_step_height or step_height>roll_max_step_height+.002:
		reason="HEIGHT_REJECTED"
		return false
	top_walkable=top.normal.dot(Vector3.UP)>=cos(body.floor_max_angle)
	if not top_walkable:
		reason="TOP_TOO_STEEP"
		return false
	for inset in [radius*.45,radius*.65]:
		var goal: Vector3=base+direction*(distance+inset)
		goal.y=top.position.y+.006
		support_valid=_supported_at(goal,direction,radius)
		if not support_valid:
			reason="NO_TOP_SUPPORT"
			continue
		if debug_steps: _draw_destination(goal)
		if not _clear_destination(base,goal): continue
		_goal=goal
		step_target_y=goal.y
		_start_y=base.y
		_direction=direction
		_duration=_lift_duration(goal.y-base.y)
		_elapsed=0
		_lift_time=0
		steps_started+=1
		active=true
		candidate=true
		reason="VALID"
		return true
	return false

func lift(delta: float) -> void:
	var before: float=body.global_position.y
	super.lift(delta)
	last_lift_rise=body.global_position.y-before

func finish() -> void:
	# Upward correction stops at the verified height even if the curve has
	# stopped forward movement. No positive launch velocity is stored.
	if active and body.global_position.y>=step_target_y-.002:
		cancel("COMPLETE")

func _draw_destination(base: Vector3) -> void:
	var radius: float=collision.shape.radius
	var height: float=collision.shape.height
	for i in 16:
		var a:=Vector3(cos(TAU*i/16),0,sin(TAU*i/16))*radius
		var b:=Vector3(cos(TAU*(i+1)/16),0,sin(TAU*(i+1)/16))*radius
		for y in [radius,height-radius]:
			_lines.append_array([base+a+Vector3.UP*y,base+b+Vector3.UP*y])
		if i%4==0: _lines.append_array([base+a+Vector3.UP*radius,base+a+Vector3.UP*(height-radius)])
	_lines.append_array([base,base+Vector3.UP*height])

func debug_text() -> String:
	var window: Vector2=step_frame_window()
	var timing: String="Source Frame: %.2f / Assist Window: %.0f–%.0f / Open: %s\n" % [source_frame(),window.x,window.y,traversal_window_open()]
	return timing+"ROLL TRAVERSAL\nDodge Active: %s / Airborne: %s / Curve: %.2f\nCandidate: %s / Step Height: %.3f / Max: %.2f\nTop Walkable: %s / Body Clearance: %s / Support: %s\nDirection Match: %s / Active: %s / Target Y: %.3f\nVertical Velocity: %.2f / Roll Progress: %.2f\nReason: %s" % [body.dodge.is_rolling(),body.dodge.dodge_airborne,body.dodge.speed_multiplier,candidate,step_height,roll_max_step_height,top_walkable,head_clearance,support_valid,direction_match,active,step_target_y,body.velocity.y,body.dodge.dodge_progress,reason]
