extends Node3D
const Modifier=preload("res://Characters/Player/V2/player_environment_hand_modifier_v2.gd")
@export var enabled: bool = true
@export var environment_hand_ik_debug: bool = false
@export_group("Environmental Hand Interaction")
@export_subgroup("Contact Pose")
@export_range(0,1,0.05) var environment_hand_contact_weight: float = 0.90
@export_range(0.75,1,0.05) var environment_hand_contact_rotation_weight: float = 0.90
## Degrees, applied in bone-local space after the geometric contact frame.
@export var left_hand_contact_rotation_offset := Vector3.ZERO
@export var right_hand_contact_rotation_offset := Vector3.ZERO
# Compatibility aliases share one positional control, not competing multipliers.
@export_range(0,1,0.05) var environment_hand_position_weight: float:
	get: return environment_hand_contact_weight
	set(value): environment_hand_contact_weight=value
var environment_hand_ik_weight: float:
	get: return environment_hand_contact_weight
	set(value): environment_hand_contact_weight=value
@export_subgroup("Reach")
@export_range(0.40,0.80,0.01) var hand_reach_total_duration: float = 0.55
@export_range(0.20,0.60,0.01) var hand_reach_prep_fraction: float = 0.40
@export_range(0.10,0.70,0.01) var hand_rotation_start_fraction: float = 0.35
var hand_reach_in_duration: float:
	get: return hand_reach_total_duration
	set(value): hand_reach_total_duration=value
@export_subgroup("Release")
@export_range(0.15,0.35,0.01) var hand_release_duration: float = 0.22
@export_range(1,3,0.05) var hand_contact_reacquire_cooldown: float = 1.75
## Legacy Phase 2 setting; persistent contacts never score-switch sides.
var hand_switch_score_margin: float = 0.20
var hand_reach_blend_in_speed: float = 6.0 # Legacy; durations now own fades.
## Legacy alias retained for old resource compatibility; use contact release speed.
var hand_reach_blend_out_speed: float = 9.0
@export_range(0.35,0.70,0.01) var max_environment_hand_reach: float = 0.60
@export var elbow_pole_forward_offset: float = 0.10
@export var elbow_pole_outward_offset: float = 0.30
@export var elbow_pole_vertical_offset: float = -0.25
@export_group("Persistent Surface Contact")
@export_range(0.03,0.10,0.005) var hand_palm_clearance: float = 0.05
## Meters along hand-local axes: +Y fingers, +Z palm-facing (user visual correction).
@export var hand_palm_local_offset := Vector3(0,0.0477,0.012)
@export_range(90,150,5) var hand_max_wrist_rotation: float = 150.0
@export_range(6,15,0.5) var hand_wall_drag_follow_speed: float = 12.0
@export_range(3,8,0.5) var hand_idle_hold_follow_speed: float = 5.0
var hand_contact_release_speed: float = 9.0 # Legacy; use release duration.
@export_range(60,90,1) var hand_contact_max_body_angle: float = 75.0
@export_range(30,60,1) var hand_max_surface_normal_change: float = 45.0
var environment_hand_contact_active: bool = false
var contact_acquired_while_walking: bool = false
var contact_surface: Object
var contact_world_position := Vector3.ZERO
var contact_surface_normal := Vector3.ZERO
var contact_hit_position := Vector3.ZERO
var contact_initial_normal := Vector3.ZERO
var persistence: String = "NONE"
var contact_release_reason: String = ""
var contact_tangent_speed: float = 0.0
var contact_acquisitions: int = 0
enum ContactState { INACTIVE, REACHING, CONTACT, IDLE_HOLD, RELEASING, COOLDOWN }
var contact_state: ContactState = ContactState.INACTIVE
var environment_hand_cooldown_remaining: float = 0.0
var reach_elapsed: float = 0.0
var release_elapsed: float = 0.0
var reach_start_hand_transform := Transform3D.IDENTITY
var reach_target_transform := Transform3D.IDENTITY
var contact_wall_tangent := Vector3.ZERO
var reach_alpha: float = 0.0
var rotation_alpha: float = 0.0
var reach_start_local_transform := Transform3D.IDENTITY
var release_alpha: float = 1.0
var skeleton: Skeleton3D
var arms: Array[Dictionary]=[]
var active_side: int = -1
var switching: bool = false
var bound: bool = false
var _modifiers: Array[Node]=[]
var _debug: MeshInstance3D
var _mesh:=ImmediateMesh.new()
@onready var motor=get_parent()
@onready var sensing=motor.get_node("EnvironmentalHandInteraction")

func _ready() -> void:
	call_deferred("_bind")

func _bind() -> void:
	skeleton=sensing.skeleton
	if skeleton==null: return
	# Foot IK already owns skeleton.advance(). Append to that pass, never
	# advance a second time or change the skeleton's callback configuration.
	for side in ["Left","Right"]:
		var bones: Array[int]=[]
		for part in ["Arm","ForeArm","Hand"]: bones.append(skeleton.find_bone("mixamorig_"+side+part))
		if bones.has(-1) or skeleton.get_bone_parent(bones[1])!=bones[0] or skeleton.get_bone_parent(bones[2])!=bones[1]:
			push_error("Environmental hand IK: invalid "+side+" chain")
			return
		arms.append({"side":side,"bones":bones,"weight":0.0,"animated":Vector3.ZERO,"solved":Vector3.ZERO,"shoulder":Vector3.ZERO,"elbow":Vector3.ZERO,"reach":0.0,"clamped":false,"offset":Vector3.ZERO,"desired_basis":Basis.IDENTITY,"animated_basis":Basis.IDENTITY,"palm":Vector3.ZERO})
	var prepare:=Modifier.new()
	prepare.name="PrepareEnvironmentalArms"
	prepare.controller=self
	skeleton.add_child(prepare)
	_modifiers.append(prepare)
	for arm in arms:
		var target:=Marker3D.new()
		target.name=arm.side+"ArmIKTarget"
		add_child(target)
		var pole:=Marker3D.new()
		pole.name=arm.side+"ElbowPole"
		add_child(pole)
		var solver:=TwoBoneIK3D.new()
		solver.name=arm.side+"EnvironmentalArmIK"
		solver.influence=0
		skeleton.add_child(solver)
		_modifiers.append(solver)
		solver.setting_count=1
		solver.set_root_bone(0,arm.bones[0])
		solver.set_middle_bone(0,arm.bones[1])
		solver.set_end_bone(0,arm.bones[2])
		solver.set_target_node(0,solver.get_path_to(target))
		solver.set_pole_node(0,solver.get_path_to(pole))
		arm.target=target
		arm.pole=pole
		arm.solver=solver
	var capture:=Modifier.new()
	capture.name="OrientAndCaptureEnvironmentalArms"
	capture.controller=self
	capture.capture=true
	skeleton.add_child(capture)
	_modifiers.append(capture)
	# Sampling moves into the preparation modifier, exactly once per evaluated
	# pose. This preserves Phase 1 data without a duplicate pair of queries.
	sensing.set_physics_process(false)
	_debug=MeshInstance3D.new()
	_debug.mesh=_mesh
	add_child(_debug)
	_debug.top_level=true
	_debug.global_transform=Transform3D.IDENTITY
	var material:=StandardMaterial3D.new()
	material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo=true
	material.no_depth_test=true
	_debug.material_override=material
	bound=true
	motor.get_node("AnimationTree").mixer_applied.connect(_on_pose_evaluated)

func _on_pose_evaluated() -> void:
	# Modifier execution can be deferred by the engine; revoke contact authority
	# at the evaluated action boundary without a new query or skeleton advance.
	protect_non_walk_pose()

func protect_non_walk_pose() -> void:
	if sensing.can_use_environment_hand_ik(): return
	var reason: String=sensing.eligibility()
	if reason=="IDLE":
		if environment_hand_contact_active: release_contact("IDLE")
	else:
		ensure_environment_hand_pose_released(reason)

func ensure_environment_hand_pose_released(reason: String) -> void:
	var had_authority: bool=active_side>=0 or environment_hand_contact_active
	for arm in arms:
		arm.weight=0.0
		arm.rotation_weight=0.0
		arm.solver.influence=0.0
		arm.override_active=false
		arm.offset=Vector3.ZERO
		arm.reach=0.0
		arm.clamped=false
		arm.prepared_target=Vector3.ZERO
		arm.release_weight=0.0
		arm.release_rotation=0.0
		arm.release_reach=0.0
		arm.release_offset=Vector3.ZERO
		arm.release_pole=Vector3.ZERO
		arm.release_basis=Basis.IDENTITY
		arm.desired_basis=Basis.IDENTITY
		arm.contact_basis=Basis.IDENTITY
		arm.reach_local_basis=Basis.IDENTITY
		arm.target.position=Vector3.ZERO
		arm.pole.position=Vector3.ZERO
	active_side=-1
	switching=false
	environment_hand_contact_active=false
	contact_acquired_while_walking=false
	contact_surface=null
	contact_world_position=Vector3.ZERO
	contact_hit_position=Vector3.ZERO
	contact_surface_normal=Vector3.ZERO
	contact_initial_normal=Vector3.ZERO
	contact_wall_tangent=Vector3.ZERO
	contact_tangent_speed=0
	reach_elapsed=0
	release_elapsed=0
	release_alpha=0
	reach_alpha=0
	rotation_alpha=0
	reach_start_hand_transform=Transform3D.IDENTITY
	reach_start_local_transform=Transform3D.IDENTITY
	reach_target_transform=Transform3D.IDENTITY
	if had_authority:
		contact_release_reason=reason
		environment_hand_cooldown_remaining=maxf(environment_hand_cooldown_remaining,hand_contact_reacquire_cooldown)
	contact_state=ContactState.COOLDOWN if environment_hand_cooldown_remaining>0 else ContactState.INACTIVE
	persistence="COOLDOWN" if environment_hand_cooldown_remaining>0 else "NONE"

func world(bone: int) -> Vector3:
	return skeleton.global_transform*skeleton.get_bone_global_pose(bone).origin

func candidate(index: int):
	return sensing.left if index==0 else sensing.right

func usable(index: int) -> bool:
	return sensing.can_acquire_environment_hand_contact() and candidate(index).valid

func choose_side() -> int:
	if usable(0) and usable(1): return 0 if sensing.left.score>=sensing.right.score else 1
	return 0 if usable(0) else (1 if usable(1) else -1)

func prepare_targets(delta: float) -> void:
	if not bound: return
	sensing.sample(delta)
	for arm in arms:
		arm.animated=world(arm.bones[2])
		arm.animated_basis=(skeleton.global_basis*skeleton.get_bone_global_pose(arm.bones[2]).basis).orthonormalized()
		arm.animation_chain=[]
		for bone in arm.bones: arm.animation_chain.append(skeleton.get_bone_global_pose(bone))
	if contact_state==ContactState.COOLDOWN:
		environment_hand_cooldown_remaining=maxf(0,environment_hand_cooldown_remaining-delta)
		if environment_hand_cooldown_remaining<=0: contact_state=ContactState.INACTIVE
	protect_non_walk_pose()
	# Walk-acquired Idle Hold retains ownership; incompatible actions still
	# skip target preparation and manual wrist writes immediately.
	if not sensing.can_use_environment_hand_ik() and not (sensing.eligibility()=="IDLE" and contact_state==ContactState.RELEASING):
		ensure_environment_hand_pose_released(sensing.eligibility())
		return
	if contact_state==ContactState.RELEASING:
		release_elapsed+=delta
		release_alpha=1-smoothstep(0,hand_release_duration,release_elapsed)
	update_contact(delta)
	for index in 2:
		var arm=arms[index]
		var origin:=world(arm.bones[0])
		var middle:=world(arm.bones[1])
		var natural_length: float=origin.distance_to(middle)+middle.distance_to(arm.animated)
		var limit: float=minf(max_environment_hand_reach,natural_length*.95)
		var outward: Vector3=motor.visual.global_basis.x.normalized()*(-1.0 if index==0 else 1.0)
		var forward: Vector3=-motor.visual.global_basis.z.normalized()
		var target_weight: float=0
		if index==active_side and environment_hand_contact_active:
			arm.desired_basis=palm_basis(arm.animated_basis,contact_surface_normal)
			var desired: Vector3=contact_world_position-arm.desired_basis*hand_palm_local_offset
			var offset:=desired-origin
			arm.reach=offset.length()
			arm.clamped=arm.reach>limit
			var safety: float=1.0-smoothstep(natural_length*.85,natural_length*.98,arm.reach)
			# Never pull the upper arm across the torso or to an overhead target.
			if offset.dot(outward)<.03 or offset.y>.25 or offset.y<-.5 or arm.reach>limit:
				safety=0
				release_contact("UNSAFE_REACH")
			target_weight=environment_hand_contact_weight*safety*reach_alpha
			arm.offset=motor.visual.global_basis.inverse()*(offset.limit_length(limit))
		# During release the fading target follows the body, never stays pinned
		# to a stale world-space wall point while running, rolling or airborne.
		arm.target.global_position=origin+motor.visual.global_basis*arm.offset
		var pole_forward: Vector3=-contact_wall_tangent if index==active_side else forward
		arm.pole.global_position=origin+outward*elbow_pole_outward_offset+pole_forward*elbow_pole_forward_offset+Vector3.UP*elbow_pole_vertical_offset
		if index==active_side and contact_state==ContactState.RELEASING:
			arm.weight=arm.get("release_weight",0.0)*release_alpha
		else:
			arm.weight=target_weight
		# Blend in position space rather than joint-angle space: rotation blends
		# can arc the wrist through a wall despite an outside target.
		var target_alpha: float=reach_alpha if environment_hand_contact_active else arm.get("release_reach",0.0)
		var reach_start: Vector3=arm.animated
		if index==active_side and environment_hand_contact_active:
			reach_start=motor.visual.global_transform*reach_start_local_transform.origin
		var reach_goal: Vector3=reach_start.lerp(arm.target.global_position,target_alpha)
		arm.target.global_position=arm.animated.lerp(reach_goal,arm.weight)
		arm.pole.global_position=middle.lerp(arm.pole.global_position,arm.weight)
		arm.rotation_weight=environment_hand_contact_rotation_weight*rotation_alpha if index==active_side and environment_hand_contact_active else arm.get("release_rotation",0.0)*release_alpha
		var rotation_source: Basis=arm.animated_basis
		if index==active_side and environment_hand_contact_active:
			# The residual pose is the acquired wrist pose in body space, not the
			# swinging Walk wrist. Shoulder/upper-arm animation remains untouched.
			rotation_source=rotation_source.slerp(motor.visual.global_basis*arm.reach_local_basis,rotation_alpha)
			# Use the prepared elbow pole rather than the old animated elbow: the
			# latter has not followed the IK reach yet and reports false inversion.
			var forearm_direction: Vector3=(arm.target.global_position-arm.pole.global_position).normalized()
			var bend: float=rad_to_deg(forearm_direction.angle_to(arm.desired_basis.y))
			arm.rotation_weight*=1-smoothstep(hand_max_wrist_rotation,180,bend)
		arm.contact_basis=rotation_source.slerp(arm.desired_basis,arm.rotation_weight)
		if index==active_side and contact_state==ContactState.RELEASING:
			arm.contact_basis=arm.animated_basis.slerp(motor.visual.global_basis*arm.release_basis,release_alpha)
			arm.target.global_position=arm.animated.lerp(origin+motor.visual.global_basis*arm.release_offset,release_alpha)
			arm.pole.global_position=middle.lerp(origin+motor.visual.global_basis*arm.release_pole,release_alpha)
		if index==active_side and environment_hand_contact_active and arm.weight>0:
			var palm_offset: Vector3=arm.contact_basis*hand_palm_local_offset
			var distance: float=(arm.target.global_position+palm_offset-contact_hit_position).dot(contact_surface_normal)
			var start_distance: float=(reach_start+palm_offset-contact_hit_position).dot(contact_surface_normal)
			var animated_distance: float=(arm.animated+palm_offset-contact_hit_position).dot(contact_surface_normal)
			var staged_distance: float=lerpf(start_distance,hand_palm_clearance,reach_alpha)
			# Early prep remains animation dominated, even in the plane-normal
			# correction. Final contact still reaches the exact clearance plane.
			var separation: float=lerpf(animated_distance,staged_distance,reach_alpha)
			# Do not snap to the clearance plane on the first reach frame. Once
			# established, normal contact is exact independently of tangent weight.
			arm.target.global_position+=contact_surface_normal*(separation-distance)
		arm.solver.influence=1.0 if arm.weight>0 else 0.0
		arm.prepared_target=arm.target.global_position
	if active_side>=0 and switching and release_elapsed>=hand_release_duration:
		ensure_environment_hand_pose_released(contact_release_reason)

func release_contact(reason: String) -> void:
	if not environment_hand_contact_active: return
	var arm=arms[active_side]
	arm.release_weight=arm.weight
	arm.release_rotation=arm.get("rotation_weight",0.0)
	arm.release_reach=reach_alpha
	arm.release_basis=motor.visual.global_basis.inverse()*arm.get("contact_basis",arm.animated_basis)
	var shoulder:=world(arm.bones[0])
	arm.release_offset=motor.visual.global_basis.inverse()*(arm.target.global_position-shoulder)
	arm.release_pole=motor.visual.global_basis.inverse()*(arm.pole.global_position-shoulder)
	release_elapsed=0
	release_alpha=1
	contact_state=ContactState.RELEASING
	environment_hand_contact_active=false
	contact_acquired_while_walking=false
	contact_surface=null
	contact_release_reason=reason
	persistence="RELEASING"
	switching=true

func update_contact(delta: float) -> void:
	if environment_hand_contact_active:
		if not sensing.can_use_environment_hand_ik():
			protect_non_walk_pose()
			return
		var data=candidate(active_side)
		if not is_instance_valid(contact_surface) or not data.valid:
			release_contact("SURFACE_LOST")
			return
		var n: Vector3=data.raw_normal
		var outward: Vector3=motor.visual.global_basis.x.normalized()*(-1.0 if active_side==0 else 1.0)
		if rad_to_deg(outward.angle_to(-n))>hand_contact_max_body_angle:
			release_contact("BODY_ANGLE")
			return
		if rad_to_deg(contact_initial_normal.angle_to(n))>hand_max_surface_normal_change or rad_to_deg(contact_surface_normal.angle_to(n))>hand_max_surface_normal_change:
			release_contact("SURFACE_CORNER")
			return
		# Coplanar seams can change collider without changing the selected hand.
		contact_surface=data.collider
		contact_surface_normal=n
		contact_hit_position=data.surface
		update_tangent(delta)
		if contact_state==ContactState.REACHING:
			reach_elapsed+=delta
			var progress: float=clampf(reach_elapsed/maxf(hand_reach_total_duration,.001),0,1)
			reach_alpha=position_reach_easing(progress)
			rotation_alpha=smoothstep(hand_rotation_start_fraction,1,progress)
			if progress>=1: contact_state=ContactState.CONTACT
		if contact_state!=ContactState.REACHING:
			contact_state=ContactState.IDLE_HOLD if sensing.state_reason=="IDLE_HOLD" else ContactState.CONTACT
		persistence="IDLE_HOLD" if sensing.state_reason=="IDLE_HOLD" else "WALL_DRAG"
		var speed: float=hand_idle_hold_follow_speed if persistence=="IDLE_HOLD" else hand_wall_drag_follow_speed
		var before:=contact_world_position
		contact_world_position=contact_world_position.lerp(data.surface+n*hand_palm_clearance,1-exp(-speed*delta))
		# Preserve tangent smoothing, but project normal separation every frame.
		contact_world_position+=n*(hand_palm_clearance-(contact_world_position-data.surface).dot(n))
		contact_tangent_speed=(contact_world_position-before).slide(n).length()/maxf(delta,.0001)
		if world(arms[active_side].bones[0]).distance_to(contact_world_position)>max_environment_hand_reach:
			release_contact("OUT_OF_REACH")
	elif contact_state==ContactState.INACTIVE and sensing.can_acquire_environment_hand_contact():
		var chosen:=choose_side()
		if chosen<0: return
		active_side=chosen
		var data=candidate(chosen)
		environment_hand_contact_active=true
		contact_acquired_while_walking=true
		contact_surface=data.collider
		contact_surface_normal=data.raw_normal
		contact_initial_normal=contact_surface_normal
		contact_hit_position=data.surface
		contact_world_position=data.surface+contact_surface_normal*hand_palm_clearance
		contact_state=ContactState.REACHING
		reach_elapsed=0
		reach_alpha=0
		rotation_alpha=0
		contact_wall_tangent=Vector3.ZERO
		update_tangent(delta)
		reach_start_hand_transform=Transform3D(arms[chosen].animated_basis,arms[chosen].animated)
		reach_start_local_transform=motor.visual.global_transform.affine_inverse()*reach_start_hand_transform
		arms[chosen].reach_local_basis=motor.visual.global_basis.inverse()*arms[chosen].animated_basis
		persistence="WALL_DRAG"
		contact_release_reason=""
		contact_acquisitions+=1
		switching=false

func update_tangent(delta: float = 1.0/60.0) -> void:
	var tangent: Vector3=Vector3(motor.velocity.x,0,motor.velocity.z).slide(contact_surface_normal)
	if sensing.state_reason=="IDLE_HOLD" or tangent.length_squared()<.01:
		tangent=contact_wall_tangent.slide(contact_surface_normal)
	if tangent.length_squared()<.0001:
		tangent=(-motor.visual.global_basis.z).slide(contact_surface_normal)
	if tangent.length_squared()<.0001: tangent=Vector3.UP.cross(contact_surface_normal)
	tangent=tangent.normalized()
	var previous: Vector3=contact_wall_tangent.slide(contact_surface_normal).normalized()
	if previous.length_squared()>.0001:
		if tangent.dot(previous)<0: tangent=-tangent
		# Bound angular speed; sign continuity takes precedence
		# over pointing down a suddenly reversed direction of travel.
		var angle: float=previous.angle_to(tangent)
		tangent=previous.slerp(tangent,minf(1,deg_to_rad(300)*delta/maxf(angle,.0001)))
	contact_wall_tangent=tangent.normalized()

func position_reach_easing(progress: float) -> float:
	var split: float=clampf(hand_reach_prep_fraction,.01,.99)
	# .35 positional authority at prep end with the .90 contact default.
	var prep_authority: float=.35/.90
	if progress<=split: return prep_authority*smoothstep(0,split,progress)
	return lerpf(prep_authority,1,smoothstep(split,1,progress))

func reach_stage() -> String:
	if contact_state!=ContactState.REACHING: return ContactState.keys()[contact_state]
	return "REACHING_PREP" if reach_elapsed/maxf(hand_reach_total_duration,.001)<hand_reach_prep_fraction else "REACHING_CONTACT"

func palm_basis(_animated: Basis,normal: Vector3) -> Basis:
	# Reverse the prior contact pose 180 degrees around local +Y: fingers
	# stay up, while X/Z reverse so the visible palm faces into the wall.
	var z: Vector3=-normal.normalized()
	# Fingers point up the wall, independently of travel/drag direction.
	var y: Vector3=Vector3.UP.slide(z).normalized()
	if y.length_squared()<.0001: y=contact_wall_tangent.slide(z).normalized()
	var frame:=Basis(y.cross(z).normalized(),y,z).orthonormalized()
	var offset: Vector3=left_hand_contact_rotation_offset if active_side==0 else right_hand_contact_rotation_offset
	frame=(frame*Basis.from_euler(offset*PI/180)).orthonormalized()
	reach_target_transform=Transform3D(frame,contact_world_position-frame*hand_palm_local_offset)
	# Global animation-to-wall angle is NOT anatomical wrist bend (it includes
	# the old arm pose). Bend safety is checked against the prepared forearm.
	return frame

func capture_result() -> void:
	if not bound: return
	protect_non_walk_pose()
	for arm in arms:
		arm.override_active=false
		if arm.weight>0 and (sensing.can_use_environment_hand_ik() or (sensing.eligibility()=="IDLE" and contact_state==ContactState.RELEASING)):
			var pose: Transform3D=skeleton.get_bone_global_pose(arm.bones[2])
			var blended: Basis=arm.contact_basis
			pose.basis=skeleton.global_basis.inverse()*blended.scaled((skeleton.global_basis*pose.basis).get_scale())
			skeleton.set_bone_global_pose(arm.bones[2],pose)
			arm.override_active=true
		arm.solved_chain=[]
		for bone in arm.bones: arm.solved_chain.append(skeleton.get_bone_global_pose(bone))
		arm.solved=world(arm.bones[2])
		arm.final_basis=(skeleton.global_basis*skeleton.get_bone_global_pose(arm.bones[2]).basis).orthonormalized()
		arm.palm=arm.solved+(skeleton.global_basis*skeleton.get_bone_global_pose(arm.bones[2]).basis).orthonormalized()*hand_palm_local_offset
		arm.shoulder=world(arm.bones[0])
		arm.elbow=world(arm.bones[1])

func _process(_delta: float) -> void:
	if not bound: return
	_debug.visible=environment_hand_ik_debug or sensing.environment_hand_debug
	if not _debug.visible: return
	_mesh.clear_surfaces()
	_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	if environment_hand_contact_active:
		cross_at(contact_hit_position,Color.YELLOW)
		cross_at(contact_world_position,Color.CYAN)
		line(contact_hit_position,contact_hit_position+contact_surface_normal*.2,Color.YELLOW)
		line(contact_world_position,contact_world_position+contact_wall_tangent*.2,Color.CYAN)
		cross_at(reach_target_transform.origin,Color.BLUE)
		draw_basis(reach_target_transform.origin,reach_target_transform.basis,.24)
		line(contact_world_position,contact_world_position-contact_surface_normal*.25,Color.ORANGE)
	for arm in arms:
		line(arm.shoulder,arm.elbow,Color.GREEN)
		line(arm.elbow,arm.solved,Color.GREEN)
		cross_at(arm.animated,Color.WHITE)
		line(arm.animated,arm.animated+arm.animated_basis.y*.12,Color.WHITE)
		cross_at(arm.solved,Color.ORANGE)
		if arm.weight>0:
			draw_basis(arm.solved,arm.final_basis,.16)
			line(arm.solved,arm.solved+arm.contact_basis.z*.18,Color.ORANGE)
			cross_at(arm.target.global_position,Color.MAGENTA)
			cross_at(arm.pole.global_position,Color.CYAN)
			line(arm.elbow,arm.pole.global_position,Color.CYAN)
	_mesh.surface_end()

func line(a: Vector3,b: Vector3,color: Color) -> void:
	_mesh.surface_set_color(color)
	_mesh.surface_add_vertex(a)
	_mesh.surface_set_color(color)
	_mesh.surface_add_vertex(b)

func draw_basis(origin: Vector3,basis: Basis,size: float) -> void:
	line(origin,origin+basis.x*size,Color.RED)
	line(origin,origin+basis.y*size,Color.GREEN)
	line(origin,origin+basis.z*size,Color.BLUE)

func cross_at(point: Vector3,color: Color) -> void:
	for axis in [Vector3.RIGHT,Vector3.UP,Vector3.FORWARD]: line(point-axis*.035,point+axis*.035,color)

func debug_text() -> String:
	var position_weight: float=arms[active_side].weight if active_side>=0 else 0.0
	var rotation_weight: float=arms[active_side].get("rotation_weight",0.0) if active_side>=0 else 0.0
	var palm_axis: Vector3=arms[active_side].get("contact_basis",Basis.IDENTITY).z if active_side>=0 else Vector3.ZERO
	var result: String="ENVIRONMENT HAND IK\nActive Side: %s / Switching: %s\nLeft/Right Valid: %s / %s / Scores: %.2f / %.2f" % ["NONE" if active_side<0 else arms[active_side].side,switching,sensing.left.valid,sensing.right.valid,sensing.left.score,sensing.right.score]
	result="ENV HAND ISOLATION\nEligible: %s / Reason: %s\n" % [sensing.can_use_environment_hand_ik(),sensing.eligibility()]+result
	result+="\nAcquisition Eligible: %s / Persistence Eligible: %s\nAcquired From: %s" % [sensing.can_acquire_environment_hand_contact(),sensing.can_persist_environment_hand_contact(),"WALK" if contact_acquired_while_walking else "NONE"]
	for arm in arms:
		result+="\n%s Native IK: %.2f / Pole Weight: %.2f / Bone Write: %s" % [arm.side,arm.solver.influence,arm.weight,arm.get("override_active",false)]
	result+="\nState: %s / Reach Progress: %.2f / Prep: %.2f\nPosition Weight: %.2f / Rotation Weight: %.2f\nCooldown Remaining: %.2f / Can Acquire: %s\nWall Tangent: %s\nPalm Contact Axis: %s / Rotation Error: %.1f degrees\nMapping: Palm +Z / Fingers +Y / Thumb Left -X, Right +X\nAxes: X red / Y green / Z blue" % [reach_stage(),clampf(reach_elapsed/maxf(hand_reach_total_duration,.001),0,1),hand_reach_prep_fraction,position_weight,rotation_weight,environment_hand_cooldown_remaining,contact_state==ContactState.INACTIVE and choose_side()>=0,contact_wall_tangent,palm_axis,rad_to_deg(palm_axis.angle_to(-contact_surface_normal)) if active_side>=0 else 0.0]
	if bound:
		for arm in arms: result+="\n%s Weight: %.2f / Reach: %.3f m / Clamped: %s\nElbow Pole: %s" % [arm.side,arm.weight,arm.reach,arm.clamped,"valid" if arm.pole.global_position.is_finite() else "invalid"]
	var separation: float=(arms[active_side].palm-contact_hit_position).dot(contact_surface_normal) if active_side>=0 else 0.0
	result+="\nENVIRONMENT HAND CONTACT\nActive: %s / Acquired Walking: %s\nPersistence: %s / Release: %s\nPalm Clearance: %.3f / Actual Palm Distance: %.3f\nTarget: %s\nNormal: %s / Tangent Speed: %.2f" % [environment_hand_contact_active,contact_acquired_while_walking,persistence,contact_release_reason,hand_palm_clearance,separation,contact_world_position,contact_surface_normal,contact_tangent_speed]
	return result

func _exit_tree() -> void:
	for modifier in _modifiers:
		if is_instance_valid(modifier): modifier.queue_free()
	if is_instance_valid(sensing): sensing.set_physics_process(true)
