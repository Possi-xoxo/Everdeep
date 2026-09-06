extends Node
## Phase 0 ownership only. No alignment, translation path or traversal animation.
const Context = preload("res://interaction/context_interactable.gd")
enum Phase { NONE, ENTRY, ACTIVE, EXIT }
enum Interrupt { DODGE, JUMP, DAMAGE, KNOCKBACK, PLAYER_CANCEL }
signal traversal_started(data)
signal traversal_phase_changed(phase)
signal traversal_finished(reason)
@export var traversal_debug: bool = false
@export var traversal_interruptible: bool = true
@export var traversal_interrupt_window_open: bool = true
## Explicit opt-in per action profile. Damage does not detach by default.
@export var allowed_interrupt_reasons: Array[int] = [Interrupt.PLAYER_CANCEL]
var active_traversal_type: int = Context.Type.NONE
var is_traversing: bool = false
var phase: Phase = Phase.NONE
var active_data: Dictionary = {}
var elapsed: float = 0.0
var last_end_reason: String = ""
@onready var motor=get_parent()

func can_begin(requires_grounded: bool=true) -> bool:
	if is_traversing or motor.dodge.is_dodging or motor.dodge.run_roll_recovery_visible: return false
	if motor.step_solver.active or motor.roll_traversal.active or motor.turn_180.active: return false
	var s=motor.animation_state
	if requires_grounded and (not motor.is_on_floor() or s.is_airborne or s.jump_started): return false
	return motor.get_node("AnimationController").current_state not in [&"Land",&"DodgeStand",&"DodgeRun",&"DodgeBack"]

func request_contextual_traversal(data: Dictionary) -> bool:
	return _begin(data,Context.Mode.CONTEXTUAL)

func request_automatic_traversal(type: int,candidate_data: Dictionary) -> bool:
	var data=candidate_data.duplicate()
	data["type"]=type
	return _begin(data,Context.Mode.AUTOMATIC)

func _begin(data: Dictionary,mode: int) -> bool:
	var type: int=int(data.get("type",Context.Type.NONE))
	if type<=Context.Type.NONE or type>=Context.Type.GENERIC_INTERACT: return false
	if not can_begin(bool(data.get("requires_grounded",true))): return false
	var source=data.get("source")
	if mode==Context.Mode.CONTEXTUAL and (not is_instance_valid(source) or not source.can_interact(motor)): return false
	active_data=data.duplicate()
	active_data["mode"]=mode
	active_traversal_type=type
	is_traversing=true
	elapsed=0.0
	motor.lock_on.clear()
	motor._run_time=0.0
	motor.turn_arc_active=false
	motor.turn_180.cancel()
	_set_phase(Phase.ENTRY)
	traversal_started.emit(active_data)
	if traversal_debug: print("Traversal started: ",Context.Type.keys()[type])
	return true

func advance(delta: float) -> void:
	if not is_traversing: return
	if active_data.has("source") and (not is_instance_valid(active_data.source) or active_data.source.is_queued_for_deletion()):
		finish("SOURCE_LOST")
		return
	elapsed+=delta
	var duration: float=maxf(.1,float(active_data.get("test_duration",.8)))
	if elapsed>=duration: finish("COMPLETED")
	elif elapsed>=duration*.8: _set_phase(Phase.EXIT)
	elif elapsed>=duration*.2: _set_phase(Phase.ACTIVE)

func _set_phase(next: Phase) -> void:
	if phase==next: return
	phase=next
	traversal_phase_changed.emit(phase)

func request_traversal_interrupt(reason: int) -> bool:
	if not is_traversing or not traversal_interruptible or not traversal_interrupt_window_open or reason not in allowed_interrupt_reasons: return false
	finish(Interrupt.keys()[reason])
	return true

func finish(reason: String="COMPLETED") -> void:
	if not is_traversing: return
	is_traversing=false
	active_traversal_type=Context.Type.NONE
	active_data={}
	last_end_reason=reason
	_set_phase(Phase.NONE)
	traversal_finished.emit(reason)

func debug_text() -> String:
	return "Active Traversal: %s\nPhase: %s\nInterruptible: %s / Window: %s\nLast End: %s" % [Context.Type.keys()[active_traversal_type],Phase.keys()[phase],traversal_interruptible,traversal_interrupt_window_open,last_end_reason]
