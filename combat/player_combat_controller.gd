class_name PlayerCombatController
extends Node

signal attack_started
signal attack_phase_changed(phase: AttackPhase)
signal attack_ended
signal hit_landed(hit: DamagePacket, hurtbox: Hurtbox)

enum CombatState {
	NEUTRAL,
	LIGHT_ATTACK,
}

enum AttackPhase {
	NONE,
	STARTUP,
	ACTIVE,
	RECOVERY,
}

enum AttackMotionMode {
	INHERIT_MOMENTUM,
}

@export_category("Light Attack")
@export_range(0.01, 2.0, 0.01) var startup_duration: float = 0.18
@export_range(0.01, 2.0, 0.01) var active_duration: float = 0.12
@export_range(0.01, 3.0, 0.01) var recovery_duration: float = 0.30
@export_range(0.0, 0.2, 0.01) var hit_stop_duration: float = 0.05

@export_category("Attack Motion")
@export var attack_motion_mode: AttackMotionMode = AttackMotionMode.INHERIT_MOMENTUM
@export_range(0.0, 1.0, 0.05) var attack_momentum_retention: float = 0.85
@export_range(0.0, 20.0, 0.1) var attack_momentum_decay: float = 3.0
@export_range(0.0, 1.0, 0.05) var attack_steering_strength: float = 0.20
@export_range(0.0, 1.0, 0.05) var attack_rotation_multiplier: float = 0.30

@export_category("References")
@export var actor: Node
@export var weapon_socket: Node3D
@export var hitbox: MeleeHitbox

@export_category("Debug")
@export var debug_combat_events: bool = false

var combat_state: CombatState = CombatState.NEUTRAL
var attack_phase: AttackPhase = AttackPhase.NONE
var _phase_time_remaining: float = 0.0
var _phase_duration: float = 0.0
var _hit_stop_remaining: float = 0.0
var _weapon_rest_rotation: Vector3 = Vector3.ZERO
var _mouse_was_captured: bool = true
var attack_start_velocity: Vector3 = Vector3.ZERO
var attack_start_direction: Vector3 = Vector3.ZERO
var attack_start_speed: float = 0.0
var _attack_motion_velocity: Vector3 = Vector3.ZERO
var _attack_facing_direction: Vector3 = Vector3.FORWARD


func _ready() -> void:
	_mouse_was_captured = Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	if weapon_socket != null:
		_weapon_rest_rotation = weapon_socket.rotation
	if hitbox != null:
		hitbox.end_attack()
		hitbox.hit_confirmed.connect(_on_hit_confirmed)


func _physics_process(delta: float) -> void:
	var mouse_is_captured := Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	if (
		combat_state == CombatState.NEUTRAL
		and Input.is_action_just_pressed("light_attack")
		and _mouse_was_captured
		and mouse_is_captured
	):
		try_begin_light_attack()
	_mouse_was_captured = mouse_is_captured

	if combat_state == CombatState.NEUTRAL:
		return
	if _hit_stop_remaining > 0.0:
		_hit_stop_remaining = maxf(_hit_stop_remaining - delta, 0.0)
		return

	_phase_time_remaining -= delta
	_update_weapon_visual()
	if _phase_time_remaining <= 0.0:
		_advance_attack_phase()


func try_begin_light_attack() -> bool:
	if combat_state != CombatState.NEUTRAL:
		return false
	if actor == null or not actor.has_method("can_begin_light_attack"):
		return false
	if not actor.call("can_begin_light_attack"):
		return false

	combat_state = CombatState.LIGHT_ATTACK
	_capture_attack_motion()
	_set_attack_phase(AttackPhase.STARTUP, startup_duration)
	if debug_combat_events:
		print("Combat: light attack started")
	attack_started.emit()
	return true


func is_attacking() -> bool:
	return combat_state == CombatState.LIGHT_ATTACK


func calculate_attack_velocity(input_direction: Vector3, delta: float) -> Vector3:
	if not is_attacking():
		return Vector3.ZERO
	if _hit_stop_remaining > 0.0:
		return Vector3.ZERO

	match attack_motion_mode:
		AttackMotionMode.INHERIT_MOMENTUM:
			_update_inherited_momentum(input_direction, delta)
	return _attack_motion_velocity


func get_attack_facing_direction() -> Vector3:
	return _attack_facing_direction


func _capture_attack_motion() -> void:
	attack_start_velocity = Vector3.ZERO
	if actor is CharacterBody3D:
		var body := actor as CharacterBody3D
		attack_start_velocity = Vector3(body.velocity.x, 0.0, body.velocity.z)
	attack_start_speed = attack_start_velocity.length()
	attack_start_direction = (
		attack_start_velocity.normalized()
		if attack_start_speed > 0.01
		else Vector3.ZERO
	)
	_attack_motion_velocity = attack_start_velocity * attack_momentum_retention
	_attack_facing_direction = Vector3.FORWARD
	if actor != null and actor.has_method("get_facing_direction"):
		_attack_facing_direction = actor.call("get_facing_direction")


func _update_inherited_momentum(input_direction: Vector3, delta: float) -> void:
	var decay_multiplier := 1.0
	var steering_multiplier := 1.0
	match attack_phase:
		AttackPhase.STARTUP:
			decay_multiplier = 0.5
			steering_multiplier = 1.0
		AttackPhase.ACTIVE:
			decay_multiplier = 1.0
			steering_multiplier = 0.5
		AttackPhase.RECOVERY:
			decay_multiplier = 0.75
			steering_multiplier = 2.0

	var speed := move_toward(
		_attack_motion_velocity.length(),
		0.0,
		attack_momentum_decay * decay_multiplier * delta
	)
	var current_direction := (
		_attack_motion_velocity.normalized()
		if not _attack_motion_velocity.is_zero_approx()
		else attack_start_direction
	)
	_attack_motion_velocity = current_direction * speed

	if not input_direction.is_zero_approx():
		var desired_speed := speed
		if desired_speed < 0.1 and actor != null:
			desired_speed = float(actor.get("walk_speed")) * 0.25
		var desired_velocity := input_direction * desired_speed
		var base_acceleration := float(actor.get("acceleration")) if actor != null else 20.0
		_attack_motion_velocity = _attack_motion_velocity.move_toward(
			desired_velocity,
			base_acceleration * attack_steering_strength * steering_multiplier * delta
		)

		# Facing receives only a small correction during startup, then remains
		# committed through Active and Recovery.
		if attack_phase == AttackPhase.STARTUP:
			var facing_weight := clampf(attack_rotation_multiplier * 4.0 * delta, 0.0, 1.0)
			_attack_facing_direction = _attack_facing_direction.slerp(
				input_direction,
				facing_weight
			).normalized()


func _advance_attack_phase() -> void:
	match attack_phase:
		AttackPhase.STARTUP:
			_set_attack_phase(AttackPhase.ACTIVE, active_duration)
			if hitbox != null:
				hitbox.begin_attack(actor)
			if debug_combat_events:
				print("Combat: hitbox active")
		AttackPhase.ACTIVE:
			if hitbox != null:
				hitbox.end_attack()
			_set_attack_phase(AttackPhase.RECOVERY, recovery_duration)
		AttackPhase.RECOVERY:
			_finish_attack()


func _set_attack_phase(next_phase: AttackPhase, duration: float) -> void:
	attack_phase = next_phase
	_phase_duration = duration
	_phase_time_remaining = duration
	attack_phase_changed.emit(next_phase)
	_update_weapon_visual()


func _finish_attack() -> void:
	if hitbox != null:
		hitbox.end_attack()
	combat_state = CombatState.NEUTRAL
	attack_phase = AttackPhase.NONE
	_phase_time_remaining = 0.0
	_phase_duration = 0.0
	_hit_stop_remaining = 0.0
	attack_start_velocity = Vector3.ZERO
	attack_start_direction = Vector3.ZERO
	attack_start_speed = 0.0
	_attack_motion_velocity = Vector3.ZERO
	if weapon_socket != null:
		weapon_socket.rotation = _weapon_rest_rotation
	if debug_combat_events:
		print("Combat: light attack ended")
	attack_ended.emit()


func _update_weapon_visual() -> void:
	if weapon_socket == null or attack_phase == AttackPhase.NONE:
		return
	var progress := 1.0 - clampf(_phase_time_remaining / maxf(_phase_duration, 0.001), 0.0, 1.0)
	var yaw_degrees := 0.0
	match attack_phase:
		AttackPhase.STARTUP:
			yaw_degrees = lerpf(0.0, 55.0, progress)
		AttackPhase.ACTIVE:
			yaw_degrees = lerpf(55.0, -65.0, progress)
		AttackPhase.RECOVERY:
			yaw_degrees = lerpf(-65.0, 0.0, progress)
	weapon_socket.rotation = _weapon_rest_rotation + Vector3(0.0, deg_to_rad(yaw_degrees), 0.0)


func _on_hit_confirmed(hit: DamagePacket, hurtbox: Hurtbox) -> void:
	_hit_stop_remaining = maxf(_hit_stop_remaining, hit_stop_duration)
	if debug_combat_events:
		print("Combat: confirmed ", hit.damage, " damage")
	hit_landed.emit(hit, hurtbox)
