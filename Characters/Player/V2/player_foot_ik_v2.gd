extends Node3D
const Orientation = preload("res://Characters/Player/V2/player_foot_ik_orientation_v2.gd")
const Pelvis = preload("res://Characters/Player/V2/player_pelvis_ik_v2.gd")
@export_category("Pelvis Compensation")
@export var pelvis_enabled: bool = true
@export_range(0,0.3,0.01) var max_pelvis_drop: float = 0.20
@export_range(1,25,0.5) var pelvis_adjust_speed: float = 10.0
@export_range(0,1,0.01) var pelvis_ik_weight: float = 0.8
@export_category("Foot IK")
@export var enabled: bool = true
@export_range(0,1,0.01) var foot_ik_weight: float = 0.8
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
	prepare_targets(get_physics_process_delta_time())
	pelvis.prepare(get_physics_process_delta_time())
	skeleton.advance(get_physics_process_delta_time())

func prepare_targets(delta: float) -> void:
	for i in legs.size():
		var leg: Dictionary=legs[i]
		var data=feet.left if i==0 else feet.right
		var pose:=_world(leg.bones[2])
		leg.animated=pose.origin
		leg.animated_basis=pose.basis
		var usable: bool=enabled and data.valid and motor.animation_state.is_grounded and not motor.animation_state.jump_started
		var correction:=Vector3.ZERO
		var swing:=1.0
		if usable:
			correction=data.ankle_target_transform.origin-pose.origin
			# Terrain detection is not gait phase. Do not pin an elevated swing
			# foot downward merely because its long ray can still see the floor.
			if motor.animation_state.move_input_magnitude>0.01 and correction.y<0:
				var lift: float=pose.origin.y-motor.global_position.y-feet.foot_sole_offset
				swing=1.0-smoothstep(0.04,0.18,lift)
		var capped:=Vector3(correction.x,0,correction.z).limit_length(max_foot_ik_horizontal_correction)
		capped.y=clampf(correction.y,-max_foot_ik_vertical_correction,max_foot_ik_vertical_correction)
		leg.clamped=not capped.is_equal_approx(correction)
		var desired_weight:=foot_ik_weight*swing if usable else 0.0
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
		if hip.distance_to(destination)>reach*0.995:
			destination=hip+(destination-hip).normalized()*reach*0.995
			# A target cannot be both within correction bounds and reachable in
			# every pose. Reduce influence instead of stretching the chain.
			if absf(destination.y-pose.origin.y)>max_foot_ik_vertical_correction or Vector2(destination.x-pose.origin.x,destination.z-pose.origin.z).length()>max_foot_ik_horizontal_correction:
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
		leg.solver.influence=leg.weight

func _capture_result() -> void:
	for leg in legs:
		leg.solved=_world(leg.bones[2]).origin
		var hip:=_world(leg.bones[0]).origin
		var knee:=_world(leg.bones[1]).origin
		var axis: Vector3=(leg.solved-hip).normalized()
		var bend: Vector3=knee-hip-axis*(knee-hip).dot(axis)
		var pole: Vector3=leg.pole.global_position-hip
		pole-=axis*pole.dot(axis)
		leg.knee_stable=bend.dot(pole)>=-0.0001
		leg.length_error=maxf(absf(hip.distance_to(knee)-leg.upper_length),absf(knee.distance_to(leg.solved)-leg.lower_length))
	_debug_node.visible=foot_ik_debug
	if not foot_ik_debug: return
	_mesh.clear_surfaces()
	_mesh.surface_begin(Mesh.PRIMITIVE_LINES,_material)
	for leg in legs:
		_line(leg.animated,leg.target.global_position,Color.YELLOW)
		_line(leg.target.global_position,leg.solved,Color.CYAN)
		_line(leg.solved-Vector3.RIGHT*0.04,leg.solved+Vector3.RIGHT*0.04,Color.LIME_GREEN)
		_line(leg.solved-Vector3.UP*0.04,leg.solved+Vector3.UP*0.04,Color.LIME_GREEN)
	_line(pelvis.animated_position,pelvis.corrected_position,Color.MAGENTA)
	_mesh.surface_end()

func _line(a: Vector3,b: Vector3,color: Color) -> void:
	_mesh.surface_set_color(color)
	_mesh.surface_add_vertex(a)
	_mesh.surface_set_color(color)
	_mesh.surface_add_vertex(b)

func _exit_tree() -> void:
	if is_instance_valid(skeleton):
		skeleton.modifier_callback_mode_process=_previous_callback
		for leg in legs:
			if is_instance_valid(leg.solver): leg.solver.queue_free()
		if is_instance_valid(_orientation): _orientation.queue_free()
		if is_instance_valid(pelvis): pelvis.queue_free()

func debug_text() -> String:
	var result:="FOOT IK (F8)\nGlobal Weight: %.2f / Normal rotation: OFF" % foot_ik_weight
	for i in legs.size():
		var leg=legs[i]
		var data=feet.left if i==0 else feet.right
		result+="\n%s Valid: %s / Weight: %.2f\nCorrection Y: %+.3f / Clamped: %s\nSwing influence: %.2f" % [leg.side,data.valid,leg.weight,leg.correction.y,leg.clamped,leg.swing]
	return result+"\n\n"+pelvis.debug_text()
