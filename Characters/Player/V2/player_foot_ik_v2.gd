extends Node3D
const Orientation = preload("res://Characters/Player/V2/player_foot_ik_orientation_v2.gd")
const Pelvis = preload("res://Characters/Player/V2/player_pelvis_ik_v2.gd")
const Planting = preload("res://Characters/Player/V2/player_foot_planting_v2.gd")
const ClimbContact = preload("res://Characters/Player/V2/player_mantle_foot_contact_v2.gd")
@export_category("Climb Wall Foot Contact")
@export var climb_foot_ik_enabled: bool = true
## Wall surface clearance (existing export name retained).
@export_range(.01,.10,.005) var climb_foot_wall_offset: float = .02
@export_range(.05,.15,.01) var climb_foot_max_correction: float = .15
@export_range(5,40,1) var wall_ik_blend_speed: float = 25
@export_range(.005,.05,.005) var climb_penetration_full_weight_depth: float = .02
@export_range(0,1,.05) var climb_foot_strength: float = 1.0
@export_range(1,55,1) var climb_foot_blend_in_start: float = 10
@export_range(1,55,1) var climb_foot_blend_in_end: float = 15
@export_range(1,55,1) var climb_foot_blend_out_start: float = 30
@export_range(1,55,1) var climb_foot_blend_out_end: float = 40
@export var climb_foot_debug: bool = false
@export_category("Climb Ledge Top Penetration")
@export_range(.01,.03,.005) var top_surface_clearance: float = .02
@export_range(.05,.15,.01) var max_top_foot_correction: float = .15
@export_range(5,40,1) var top_ik_blend_speed: float = 25
## Relative to existing hoist start/end (25-50): defaults correspond to 40-45.
@export_range(0,1,.05) var top_foot_phase_start: float = .60
@export_range(0,1,.05) var top_foot_phase_full: float = .80
@export_category("Walk Knee Stabilization")
@export var walk_knee_stabilization_enabled: bool = true
@export_range(0.25,0.50,0.01) var knee_pole_forward_offset: float = 0.40
@export_range(0.08,0.20,0.01) var knee_pole_outward_offset: float = 0.10
@export_range(-0.10,0.10,0.01) var knee_pole_vertical_offset: float = 0.0
@export_range(10,20,0.5) var knee_pole_smoothing_speed: float = 15.0
@export_range(15,35,1) var walk_downhill_knee_stabilization_angle: float = 25.0
@export var knee_ik_debug: bool = false
var _pose_delta: float = 1.0/60.0
@export_category("Idle Foot Contact")
@export var idle_ik_override_enabled: bool = true
@export_range(0.2,0.4,0.01) var idle_max_pelvis_drop: float = 0.40
@export_range(0.9,1,0.01) var idle_foot_ik_weight: float = 1.0
@export_range(0.1,0.4,0.01) var idle_max_terrain_height_delta: float = 0.40
@export_range(0.2,0.4,0.01) var idle_max_foot_vertical_correction: float = 0.40
@export_category("Foot Planting")
@export var foot_planting_enabled: bool = true
@export var foot_lock_enabled: bool = true
@export_range(0.01,0.10,0.005) var plant_height_threshold: float = 0.05
@export_range(0.1,1,0.05) var plant_max_vertical_speed: float = 0.30
@export_range(0.1,1,0.05) var plant_max_horizontal_speed: float = 0.40
@export_range(1,25,0.5) var plant_confidence_rise_speed: float = 15.0
@export_range(1,30,0.5) var plant_confidence_fall_speed: float = 20.0
@export_range(0.6,0.95,0.05) var foot_lock_threshold: float = 0.80
@export_range(0.1,0.55,0.05) var foot_unlock_threshold: float = 0.45
@export_range(0.1,0.35,0.01) var max_foot_lock_distance: float = 0.25
@export_category("Pelvis Compensation")
@export var pelvis_enabled: bool = true
@export_range(0,0.3,0.01) var max_pelvis_drop: float = 0.20
@export_range(1,25,0.5) var pelvis_adjust_speed: float = 10.0
@export_range(0,1,0.01) var pelvis_ik_weight: float = 0.8
@export_category("Foot IK")
@export var enabled: bool = true
@export_range(0,1,0.01) var foot_ik_weight: float = 0.95
@export_range(0,1,0.01) var run_foot_ik_weight: float = 0.80
@export_range(0,1,0.01) var sprint_foot_ik_weight: float = 0.65
@export_range(1,25,0.5) var foot_ik_blend_in_speed: float = 10.0
@export_range(1,25,0.5) var foot_ik_blend_out_speed: float = 12.0
@export_range(0,0.3,0.01) var max_foot_ik_vertical_correction: float = 0.20
@export_range(0,0.2,0.01) var max_foot_ik_horizontal_correction: float = 0.15
@export var foot_ik_debug: bool = false
var legs: Array[Dictionary] = []
var skeleton: Skeleton3D
var pelvis: SkeletonModifier3D
var _orientation: SkeletonModifier3D
var _previous_callback: int
var _mesh := ImmediateMesh.new()
var _debug_node: MeshInstance3D
var _material := StandardMaterial3D.new()
var _planting_was_enabled: bool = true
@onready var motor = get_parent()
@onready var feet = $"../FootGrounding"
@onready var tree: AnimationTree = $"../AnimationTree"

func _ready() -> void:
	call_deferred("_bind")

func _bind() -> void:
	skeleton=feet.skeleton
	if skeleton==null or not feet._ready_to_sample:
		push_error("FootIK: valid FootGrounding binding required")
		return
	_previous_callback=skeleton.modifier_callback_mode_process
	skeleton.modifier_callback_mode_process=Skeleton3D.MODIFIER_CALLBACK_MODE_PROCESS_MANUAL
	_debug_node=MeshInstance3D.new()
	_debug_node.name="IKDebugGeometry"
	add_child(_debug_node)
	_debug_node.top_level=true
	_debug_node.global_transform=Transform3D.IDENTITY
	_debug_node.mesh=_mesh
	_material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.vertex_color_use_as_albedo=true
	_material.no_depth_test=true
	pelvis=Pelvis.new()
	pelvis.name="PelvisCompensation"
	pelvis.controller=self
	pelvis.bone=skeleton.find_bone("mixamorig_Hips")
	if pelvis.bone<0:
		push_error("Pelvis IK: mixamorig_Hips not found")
		pelvis.free()
		return
	skeleton.add_child(pelvis)
	for side in ["Left","Right"]:
		var bones: Array[int]=[]
		for part in ["UpLeg","Leg","Foot"]:
			bones.append(skeleton.find_bone("mixamorig_"+side+part))
		if bones.has(-1) or skeleton.get_bone_parent(bones[1])!=bones[0] or skeleton.get_bone_parent(bones[2])!=bones[1]:
			push_error("FootIK: invalid "+side+" chain")
			return
		var target:=Marker3D.new()
		target.name=side+"IKTarget"
		add_child(target)
		var pole:=Marker3D.new()
		pole.name=side+"KneePole"
		add_child(pole)
		var solver:=TwoBoneIK3D.new()
		solver.name=side+"FootIK"
		solver.influence=0
		skeleton.add_child(solver)
		solver.setting_count=1
		solver.set_root_bone(0,bones[0])
		solver.set_middle_bone(0,bones[1])
		solver.set_end_bone(0,bones[2])
		solver.set_target_node(0,solver.get_path_to(target))
		solver.set_pole_node(0,solver.get_path_to(pole))
		legs.append({"side":side,"bones":bones,"solver":solver,"target":target,"pole":pole,"weight":0.0,"correction":Vector3.ZERO,"clamped":false,"animated":Vector3.ZERO,"animated_basis":Basis.IDENTITY,"solved":Vector3.ZERO,"swing":1.0,"knee_stable":true,"length_error":0.0,"upper_length":0.0,"lower_length":0.0})
		legs.back().plant=Planting.new()
	_orientation=Orientation.new()
	_orientation.name="PreserveAnimatedAnkles"
	_orientation.controller=self
	skeleton.add_child(_orientation)
	skeleton.skeleton_updated.connect(_capture_result)
	# FootGrounding connected first. Its two queries finish before target prep.
	tree.mixer_applied.connect(_after_pose)

func _world(bone: int) -> Transform3D:
	return skeleton.global_transform*skeleton.get_bone_global_pose(bone)

func _after_pose() -> void:
	if foot_planting_enabled!=_planting_was_enabled:
		for leg in legs: leg.plant=Planting.new()
		_planting_was_enabled=foot_planting_enabled
	prepare_targets(get_physics_process_delta_time())
	pelvis.prepare(get_physics_process_delta_time())
	skeleton.advance(get_physics_process_delta_time())

func prepare_targets(delta: float) -> void:
	_pose_delta=delta
	for i in legs.size():
		var leg: Dictionary=legs[i]
		var data=feet.left if i==0 else feet.right
		var pose:=_world(leg.bones[2])
		leg.animated=pose.origin
		leg.animated_basis=pose.basis
		leg.climb_contact=ClimbContact.project(self,leg,pose)
		leg.climb_profile=motor.traversal.mantle.pose_owned() or motor.traversal.hang.is_attached()
		if leg.climb_profile:
			leg.plant.update(self,data,pose,delta,false)
			var contact: Dictionary=leg.climb_contact
			leg.weight=lerpf(leg.weight,contact.weight,1-exp(-contact.blend_speed*delta))
			var offset: Vector3=contact.target-pose.origin if contact.valid else Vector3.ZERO
			leg.correction=leg.correction.lerp(offset,1-exp(-contact.blend_speed*delta))
			var contact_cap: float=max_top_foot_correction if contact.mode=="LEDGE_TOP" else climb_foot_max_correction
			leg.correction=leg.correction.limit_length(contact_cap if contact.valid else maxf(climb_foot_max_correction,max_top_foot_correction))
			leg.desired_destination=pose.origin+leg.correction
			leg.swing=0.0
			leg.clamped=false
			continue
		var usable: bool=enabled and data.valid and motor.physical_ground_contact() and not motor.animation_state.jump_started and not motor.dodge.is_dodging
		usable=usable and not motor.traversal.mantle.pose_owned()
		var correction:=Vector3.ZERO
		var swing:=1.0
		if usable:
			correction=data.ankle_target_transform.origin-pose.origin
			# Terrain detection is not gait phase. Do not pin an elevated swing
			# foot downward merely because its long ray can still see the floor.
			if motor.animation_state.move_input_magnitude>0.01 and correction.y<0:
				var lift: float=pose.origin.y-motor.global_position.y-feet.foot_sole_offset
				swing=1.0-smoothstep(0.04,0.18,lift)
		if foot_planting_enabled:
			var plant_target: Vector3=leg.plant.update(self,data,pose,delta,usable)
			swing=leg.plant.support_confidence
			if usable: correction=plant_target-pose.origin
		else:
			leg.plant.locked=false
			leg.plant.lock_blend=0.0
		var capped:=Vector3(correction.x,0,correction.z).limit_length(max_foot_ik_horizontal_correction)
		var vertical_cap:=vertical_correction_limit(leg)
		capped.y=clampf(correction.y,-vertical_cap,vertical_cap)
		# Idle's vertical cap belongs to the residual correction AFTER pelvis
		# lowering, not the original ankle height plus that pelvis displacement.
		if leg.plant.idle_forced_support: capped.y=correction.y
		leg.clamped=not capped.is_equal_approx(correction)
		var desired_weight:=grounded_contact_weight()*swing if usable else 0.0
		var speed: float=foot_ik_blend_in_speed if desired_weight>leg.weight else foot_ik_blend_out_speed
		leg.weight=lerpf(leg.weight,desired_weight,1-exp(-speed*delta))
		if leg.weight<0.001: leg.weight=0.0
		# Fade an offset relative to CURRENT animation, never chase stale world
		# terrain during jump. Both influence and correction release smoothly.
		if not usable:
			capped=leg.correction*exp(-foot_ik_blend_out_speed*delta)
		elif swing<1.0:
			capped*=swing
		leg.desired_destination=pose.origin+capped
		leg.swing=swing
	# Reach and poles are evaluated by the first modifier AFTER lowering Hips.

func grounded_contact_weight() -> float:
	var s = motor.animation_state
	if is_grounded_idle(): return idle_foot_ik_weight
	if s.move_input_magnitude<=0.01: return foot_ik_weight
	if s.gait==2: return minf(foot_ik_weight,sprint_foot_ik_weight)
	if s.gait==1: return minf(foot_ik_weight,run_foot_ik_weight)
	return foot_ik_weight

func is_grounded_idle() -> bool:
	var s = motor.animation_state
	var animation = motor.get_node("AnimationController")
	# Gait enum contains Walk/Run/Sprint, not Idle. Mirror actual rest semantics,
	# and leave on input immediately rather than waiting for speed to build.
	return idle_ik_override_enabled and s.is_grounded and not s.is_airborne and not s.jump_started and s.move_input_magnitude<=0.01 and s.horizontal_speed<=0.1 and animation.current_state==&"Locomotion" and animation.grounded.transition==&"Loops" and not motor.turn_180.active

func idle_support_allowed(data: RefCounted) -> bool:
	return enabled and is_grounded_idle() and data.valid and (not (feet.left.valid and feet.right.valid) or absf(feet.left.ankle_target_transform.origin.y-feet.right.ankle_target_transform.origin.y)<=idle_max_terrain_height_delta+0.001)

func vertical_correction_limit(leg: Dictionary) -> float:
	return idle_max_foot_vertical_correction if leg.plant.idle_forced_support else max_foot_ik_vertical_correction

func pelvis_drop_limit() -> float:
	return idle_max_pelvis_drop if is_grounded_idle() else max_pelvis_drop

func place_targets() -> void:
	for leg in legs:
		if not leg.has("desired_destination"): continue
		var pose:=_world(leg.bones[2])
		var hip:=_world(leg.bones[0]).origin
		var knee:=_world(leg.bones[1]).origin
		var reach:=hip.distance_to(knee)+knee.distance_to(pose.origin)
		leg.upper_length=hip.distance_to(knee)
		leg.lower_length=knee.distance_to(pose.origin)
		var destination: Vector3=leg.desired_destination
		if leg.plant.idle_forced_support:
			var before_y:=destination.y
			destination.y=clampf(destination.y,pose.origin.y-idle_max_foot_vertical_correction,pose.origin.y+idle_max_foot_vertical_correction)
			leg.clamped=leg.clamped or not is_equal_approx(before_y,destination.y)
		if leg.plant.locked and hip.distance_to(leg.plant.locked_world_position)>reach*0.995:
			leg.plant.release_lock("CHAIN_REACH")
		if hip.distance_to(destination)>reach*0.995:
			# Climb fallback must not turn a normal-only offset into a different
			# procedural pose as animation changes underneath the smoothed target.
			destination=pose.origin if leg.get("climb_profile",false) else hip+(destination-hip).normalized()*reach*0.995
			# A target cannot be both within correction bounds and reachable in
			# every pose. Reduce influence instead of stretching the chain.
			if (leg.get("climb_profile",false) and destination.distance_to(pose.origin)>climb_foot_max_correction) or (not leg.get("climb_profile",false) and (absf(destination.y-pose.origin.y)>vertical_correction_limit(leg) or Vector2(destination.x-pose.origin.x,destination.z-pose.origin.z).length()>max_foot_ik_horizontal_correction)):
				destination=pose.origin
			leg.clamped=true
		leg.correction=destination-pose.origin
		leg.target.global_transform=Transform3D(pose.basis,destination)
		var axis: Vector3=(pose.origin-hip).normalized()
		var bend: Vector3=knee-hip-axis*(knee-hip).dot(axis)
		if bend.length()<0.015:
			bend=-motor.visual.global_basis.z
			bend-=axis*bend.dot(axis)
		leg.pole.global_position=knee+bend.normalized()*0.6
		_stabilize_knee(leg,hip,knee,destination)
		leg.solver.influence=leg.weight
		if motor.traversal.hang.is_attached():
			# Hang uses position-space blending (like its hand clamp). Partial
			# joint-rotation influence can arc a toe into the wall on entry.
			leg.target.global_position=pose.origin.lerp(destination,leg.weight)
			leg.solver.influence=1.0 if leg.weight>.001 else 0.0

func _stabilize_knee(leg: Dictionary,hip: Vector3,knee: Vector3,destination: Vector3) -> void:
	var data=feet.left if leg.side=="Left" else feet.right
	var basis: Basis=motor.visual.global_basis.orthonormalized()
	var outward: Vector3=basis.x*(-1.0 if leg.side=="Left" else 1.0)
	leg.slope_angle=rad_to_deg(acos(clampf(data.ground_normal.dot(Vector3.UP),-1,1))) if data.valid else 0.0
	leg.ik_multiplier=1.0 # Pole correction only; gait/pelvis weights are untouched.
	var movement:=Vector3(motor.velocity.x,0,motor.velocity.z)
	var downhill: bool=data.valid and movement.length()>0.1 and movement.normalized().dot(data.ground_normal)>0.02
	var s=motor.animation_state
	var animation=motor.get_node("AnimationController")
	var active: bool=walk_knee_stabilization_enabled and enabled and data.valid and s.is_grounded and not s.is_airborne and not s.jump_started and s.gait==0 and s.move_input_magnitude>0.01 and animation.current_state==&"Locomotion" and animation.grounded.transition==&"Loops" and not motor.turn_180.active
	leg.pole_guidance=0.0
	leg.outward=outward
	if active:
		# Hip-relative reference follows the body, not the animated foot/knee XZ.
		# Smooth in body space so translation/turns cannot leave a pole behind.
		var knee_height: float=clampf((knee-hip).dot(basis.y),-leg.upper_length,-leg.upper_length*0.3)
		var desired:=Vector3((-1.0 if leg.side=="Left" else 1.0)*knee_pole_outward_offset,knee_height+knee_pole_vertical_offset,-knee_pole_forward_offset)
		var local: Vector3=leg.get("pole_local",desired)
		local=local.lerp(desired,1-exp(-knee_pole_smoothing_speed*_pose_delta))
		leg.pole_local=local
		var preferred: Vector3=hip+basis*local
		var steep: float=smoothstep(walk_downhill_knee_stabilization_angle-5,walk_downhill_knee_stabilization_angle+5,leg.slope_angle) if downhill else 0.0
		var guidance: float=smoothstep(0.1,0.65,leg.swing)*lerpf(0.65,1.0,steep)
		var axis: Vector3=(destination-hip).normalized()
		var animated_bend: Vector3=knee-hip-axis*(knee-hip).dot(axis)
		# Near extension has no reliable animation plane; use the anatomical
		# reference rather than normalizing a tiny or sign-changing knee vector.
		if animated_bend.length()<0.015: guidance=smoothstep(0.1,0.65,leg.swing)
		leg.pole.global_position=leg.pole.global_position.lerp(preferred,guidance)
		leg.pole_guidance=guidance
	else:
		leg.erase("pole_local")
	var pole_axis: Vector3=(destination-hip).normalized()
	var pole_direction: Vector3=leg.pole.global_position-hip
	leg.pole_valid=leg.pole.global_position.is_finite() and pole_direction.cross(pole_axis).length()>0.001

func _capture_result() -> void:
	for leg in legs:
		leg.solved=_world(leg.bones[2]).origin
		# Capture during the modifier pass; Godot restores authored bones afterward.
		var toe_index: int=skeleton.find_bone("mixamorig_"+leg.side+"ToeBase")
		leg.solved_toe=_world(toe_index).origin if toe_index>=0 else leg.solved
		var data=feet.left if leg.side=="Left" else feet.right
		leg.terrain_error=leg.solved.distance_to(data.ankle_target_transform.origin) if data.valid else NAN
		leg.solver_error=leg.solved.distance_to(leg.target.global_position)
		leg.contact_error=leg.solved.distance_to(leg.plant.locked_world_position) if leg.plant.locked else leg.terrain_error
		var hip:=_world(leg.bones[0]).origin
		var knee:=_world(leg.bones[1]).origin
		leg.solved_hip=hip
		leg.solved_knee=knee
		var axis: Vector3=(leg.solved-hip).normalized()
		var bend: Vector3=knee-hip-axis*(knee-hip).dot(axis)
		var pole: Vector3=leg.pole.global_position-hip
		pole-=axis*pole.dot(axis)
		leg.knee_stable=bend.dot(pole)>=-0.0001
		leg.length_error=maxf(absf(hip.distance_to(knee)-leg.upper_length),absf(knee.distance_to(leg.solved)-leg.lower_length))
	_debug_node.visible=foot_ik_debug or knee_ik_debug or climb_foot_debug
	if not _debug_node.visible: return
	_mesh.clear_surfaces()
	_mesh.surface_begin(Mesh.PRIMITIVE_LINES,_material)
	for leg in legs:
		if climb_foot_debug and leg.has("climb_contact"):
			var contact: Dictionary=leg.climb_contact
			var color:=Color.LIME_GREEN if contact.valid else Color.RED
			_line(leg.animated,leg.target.global_position,color)
			_line(contact.hit,contact.hit+contact.normal*.12,Color.CYAN)
			_line(leg.target.global_position,leg.target.global_position+Vector3.UP*leg.weight*.2,color)
			for axis in [Vector3.RIGHT,Vector3.UP,Vector3.FORWARD]:
				_line(leg.animated-axis*.025,leg.animated+axis*.025,Color.YELLOW)
				_line(leg.target.global_position-axis*.025,leg.target.global_position+axis*.025,color)
		if knee_ik_debug:
			var color:=Color.CORNFLOWER_BLUE if leg.side=="Left" else Color.HOT_PINK
			_line(leg.solved_hip,leg.solved_knee,color)
			_line(leg.solved_knee,leg.solved,color)
			_line(leg.solved_knee,leg.pole.global_position,Color.YELLOW)
			_line(leg.solved_hip,leg.solved_hip+leg.outward*0.25,color)
			for axis in [Vector3.RIGHT,Vector3.UP,Vector3.FORWARD]:
				for point in [leg.solved_hip,leg.solved_knee,leg.solved,leg.pole.global_position]:
					_line(point-axis*0.025,point+axis*0.025,color)
		if not foot_ik_debug: continue
		_line(leg.animated,leg.target.global_position,Color.YELLOW)
		_line(leg.target.global_position,leg.solved,Color.CYAN)
		_line(leg.solved-Vector3.RIGHT*0.04,leg.solved+Vector3.RIGHT*0.04,Color.LIME_GREEN)
		_line(leg.solved-Vector3.UP*0.04,leg.solved+Vector3.UP*0.04,Color.LIME_GREEN)
		var data=feet.left if leg.side=="Left" else feet.right
		if data.valid:
			_line(data.raw_ground_position-Vector3.RIGHT*0.025,data.raw_ground_position+Vector3.RIGHT*0.025,Color.ORANGE)
			_line(data.smoothed_ground_position-Vector3.FORWARD*0.04,data.smoothed_ground_position+Vector3.FORWARD*0.04,Color.CYAN)
		if leg.plant.locked:
			for axis in [Vector3.RIGHT,Vector3.FORWARD,Vector3.UP]:
				_line(leg.plant.locked_world_position-axis*0.05,leg.plant.locked_world_position+axis*0.05,Color.WHITE)
	_line(pelvis.animated_position,pelvis.corrected_position,Color.MAGENTA)
	_mesh.surface_end()

func _line(a: Vector3,b: Vector3,color: Color) -> void:
	_mesh.surface_set_color(color)
	_mesh.surface_add_vertex(a)
	_mesh.surface_set_color(color)
	_mesh.surface_add_vertex(b)

func _exit_tree() -> void:
	if is_instance_valid(skeleton):
		# A scene-local reset may remove the player before deferred deletion.
		# Stop pose callbacks before restoring the skeleton's callback mode.
		if skeleton.skeleton_updated.is_connected(_capture_result): skeleton.skeleton_updated.disconnect(_capture_result)
		if is_instance_valid(tree) and tree.mixer_applied.is_connected(_after_pose): tree.mixer_applied.disconnect(_after_pose)
		skeleton.modifier_callback_mode_process=_previous_callback
		for leg in legs:
			if is_instance_valid(leg.solver): leg.solver.queue_free()
		if is_instance_valid(_orientation): _orientation.queue_free()
		if is_instance_valid(pelvis): pelvis.queue_free()

func debug_text() -> String:
	var result:="FOOT IK (F8)\nGlobal Weight: %.2f / Normal rotation: OFF" % foot_ik_weight
	result+="\nIdle IK Override: %s / Delta: %s / Max: %.2fm" % [is_grounded_idle(),("%.3fm" % absf(feet.left.ankle_target_transform.origin.y-feet.right.ankle_target_transform.origin.y)) if feet.left.valid and feet.right.valid else "N/A",idle_max_terrain_height_delta]
	for i in legs.size():
		var leg=legs[i]
		var data=feet.left if i==0 else feet.right
		if leg.has("climb_contact"):
			result+="\nClimb %s %s / Weight %.2f / Penetration %.3fm / Offset %.3fm / Limited %s" % [leg.side,leg.climb_contact.mode,leg.weight,leg.climb_contact.penetration,leg.correction.length(),leg.climb_contact.limited]
		if foot_planting_enabled:
			result+="\n%s FOOT PLANTING / Valid: %s / IK: %.2f\n%s" % [leg.side,data.valid,leg.weight,leg.plant.debug_text()]
		else:
			result+="\n%s Valid: %s / Weight: %.2f\nCorrection Y: %+.3f / Clamped: %s\nSwing influence: %.2f" % [leg.side,data.valid,leg.weight,leg.correction.y,leg.clamped,leg.swing]
		if leg.has("terrain_error"):
			if foot_planting_enabled:
				result+="\nProbe / Contact Error: %s / %s" % [("%.3fm" % leg.terrain_error) if data.valid else "N/A",("%.3fm" % leg.contact_error) if data.valid else "N/A"]
			else:
				result+="\nTerrain Target Error: %s / Solver Error: %.3fm" % [("%.3fm" % leg.terrain_error) if data.valid else "N/A",leg.solver_error]
	return result+"\n\n"+pelvis.debug_text()

func knee_debug_text() -> String:
	var result:="KNEE IK (F9)"
	for leg in legs:
		result+="\n%s Pole Valid: %s / Slope: %.1f deg\nSupport: %.2f / Guidance: %.2f / IK Multiplier: %.2f" % [leg.side,leg.get("pole_valid",false),leg.get("slope_angle",0.0),leg.swing,leg.get("pole_guidance",0.0),leg.get("ik_multiplier",1.0)]
	return result
