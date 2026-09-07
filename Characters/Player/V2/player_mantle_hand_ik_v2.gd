extends Node3D
## Dedicated mantle-only arms appended to the existing single skeleton pass.
const Modifier=preload("res://Characters/Player/V2/player_environment_hand_modifier_v2.gd")
@export var enabled: bool = true
@export var hand_ik_debug: bool = false
@export_group("Mantle Hand Clamp")
@export_range(10,24,1) var hand_clamp_start_frame: float = 17
@export_range(20,24,1) var hand_clamp_full_frame: float = 23
@export_range(30,40,1) var hand_release_frame: float = 37
@export_range(38,50,1) var hand_release_end_frame: float = 44
## Spacing guided by authored frame-24 wrists (~-.33m / +.23m).
@export_range(.12,.40,.01) var left_grip_spacing: float = .28
@export_range(.12,.40,.01) var right_grip_spacing: float = .25
@export_range(0,.10,.005) var hand_vertical_offset: float = .03
@export_range(0,.10,.005) var hand_wall_normal_offset: float = .03
@export_range(.2,.6,.01) var max_hand_correction_distance: float = .45
## Elbow guidance smoothing; grip influence uses exact source-frame easing.
@export_range(5,40,1) var ik_blend_speed: float = 25
@export_range(0,1,.05) var hand_orientation_weight: float = .35
@export_range(0,60,1) var max_wrist_rotation_degrees: float = 45
var skeleton: Skeleton3D
var arms: Array[Dictionary]=[]
var modifiers: Array[Node]=[]
var captured: bool = false
var captured_source: Node3D
var captured_alignment := Vector3.ZERO
var debug_mesh: MeshInstance3D
@onready var motor=get_parent()
var mantle: Node:
	get:
		var hang=motor.get_node("TraversalController/BracedHang")
		return hang if hang.pose_owned() else motor.get_node("TraversalController/Mantle")

func _ready() -> void:
	call_deferred("_bind")

func _bind() -> void:
	skeleton=motor.get_node("FootIKController").skeleton
	if skeleton==null: return
	var prepare:=Modifier.new()
	prepare.name="PrepareMantleHands"
	prepare.controller=self
	skeleton.add_child(prepare)
	modifiers.append(prepare)
	for side in ["Left","Right"]:
		var bones: Array[int]=[]
		for part in ["Arm","ForeArm","Hand"]: bones.append(skeleton.find_bone("mixamorig_"+side+part))
		if bones.has(-1): push_error("Mantle hands: missing chain"); return
		var target:=Marker3D.new()
		add_child(target)
		var pole:=Marker3D.new()
		add_child(pole)
		var solver:=TwoBoneIK3D.new()
		solver.name=side+"MantleHandIK"
		skeleton.add_child(solver)
		modifiers.append(solver)
		solver.influence=0
		solver.setting_count=1
		solver.set_root_bone(0,bones[0])
		solver.set_middle_bone(0,bones[1])
		solver.set_end_bone(0,bones[2])
		solver.set_target_node(0,solver.get_path_to(target))
		solver.set_pole_node(0,solver.get_path_to(pole))
		arms.append({"side":side,"bones":bones,"target":target,"pole":pole,"solver":solver,"weight":0.0,"grip":Vector3.ZERO,"valid":false,"limited":false,"animated":Vector3.ZERO,"solved":Vector3.ZERO,"error":0.0,"length_error":0.0,"basis":Basis.IDENTITY,"pole_direction":Vector3.ZERO})
	var capture:=Modifier.new()
	capture.name="CaptureMantleHands"
	capture.controller=self
	capture.capture=true
	skeleton.add_child(capture)
	modifiers.append(capture)
	debug_mesh=MeshInstance3D.new()
	add_child(debug_mesh)
	debug_mesh.top_level=true
	debug_mesh.global_transform=Transform3D.IDENTITY
	var material:=StandardMaterial3D.new()
	material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo=true
	material.no_depth_test=true
	debug_mesh.material_override=material

func world(bone: int) -> Transform3D:
	return skeleton.global_transform*skeleton.get_bone_global_pose(bone)

func _capture_grips() -> void:
	captured=true
	captured_source=mantle.source
	captured_alignment=mantle.alignment
	var tangent: Vector3=mantle.facing.cross(Vector3.UP).normalized()
	for arm in arms:
		var lateral: float=-left_grip_spacing if arm.side=="Left" else right_grip_spacing
		var edge: Vector3=mantle.ledge_edge+tangent*lateral
		var n: Vector3=mantle.landing_plane_normal
		edge.y=mantle.top.y-(n.x*(edge.x-mantle.top.x)+n.z*(edge.z-mantle.top.z))/n.y
		# One local check per hand per commitment; never slide/reacquire a grip.
		var probe: Vector3=edge+mantle.facing*.025
		probe.y=mantle.top.y-(n.x*(probe.x-mantle.top.x)+n.z*(probe.z-mantle.top.z))/n.y
		var query:=PhysicsRayQueryParameters3D.create(probe+n*.05,probe-n*.05,motor.collision_mask,[motor.get_rid()])
		var hit: Dictionary=get_world_3d().direct_space_state.intersect_ray(query)
		arm.valid=not hit.is_empty() and hit.collider==mantle.source and hit.normal.dot(n)>.98
		arm.grip=edge+Vector3.UP*hand_vertical_offset+mantle.wall_normal*hand_wall_normal_offset
		arm.weight=0.0
		arm.pole_direction=Vector3.ZERO

func prepare_targets(delta: float) -> void:
	var releasing: bool=mantle==motor.traversal.hang and motor.traversal.hang.release_active
	var active: bool=enabled and mantle.pose_owned() and (mantle.owner_controller.phase==mantle.owner_controller.Phase.ACTIVE or releasing) and is_instance_valid(mantle.source)
	if not active:
		captured=false
		for arm in arms:
			arm.weight=0.0
			arm.solver.influence=0.0
		return
	if not captured or captured_source!=mantle.source or captured_alignment!=mantle.alignment: _capture_grips()
	var frame: float=mantle.current_frame()
	var envelope: float=smoothstep(hand_clamp_start_frame,hand_clamp_full_frame,frame)*(1.0-smoothstep(hand_release_frame,hand_release_end_frame,frame))
	for arm in arms:
		var shoulder:=world(arm.bones[0]).origin
		var elbow:=world(arm.bones[1]).origin
		var pose:=world(arm.bones[2])
		arm.animated=pose.origin
		arm.basis=pose.basis.orthonormalized()
		arm.upper_length=shoulder.distance_to(elbow)
		arm.lower_length=elbow.distance_to(pose.origin)
		var reach: float=arm.upper_length+arm.lower_length
		var offset: Vector3=arm.grip-pose.origin
		var goal: Vector3=arm.grip
		arm.limited=offset.length()>max_hand_correction_distance or shoulder.distance_to(goal)>reach*.995
		if offset.length()>max_hand_correction_distance: goal=pose.origin+offset.limit_length(max_hand_correction_distance)
		if shoulder.distance_to(goal)>reach*.995: goal=shoulder+(goal-shoulder).normalized()*reach*.995
		var desired: float=envelope if arm.valid else 0.0
		if goal.distance_to(pose.origin)>max_hand_correction_distance+.001:
			goal=pose.origin
			desired=0.0
		arm.weight=desired
		# Position-space easing hits the fixed grip exactly during full clamp.
		# Reach/correction safety wins over contact if a pose is impossible.
		var target: Vector3=pose.origin.lerp(goal,arm.weight)
		arm.target.global_transform=Transform3D(pose.basis,target)
		var axis: Vector3=(target-shoulder).normalized()
		var bend: Vector3=elbow-shoulder-axis*(elbow-shoulder).dot(axis)
		if bend.length()<.025:
			bend=motor.visual.global_basis.x*(-1.0 if arm.side=="Left" else 1.0)+mantle.wall_normal*.2
			bend-=axis*bend.dot(axis)
		var prior: Vector3=arm.pole_direction
		if prior.length()>.01 and prior.dot(bend)<0: bend=-bend
		arm.pole_direction=bend.normalized() if prior.length()<.01 else prior.lerp(bend.normalized(),1-exp(-ik_blend_speed*delta)).normalized()
		arm.pole.global_position=elbow+arm.pole_direction*.4
		arm.solver.influence=1.0 if arm.weight>0 else 0.0

func capture_result() -> void:
	for arm in arms:
		if arm.weight>0:
			# Mild bounded orientation; position has priority over a perfect grip.
			var z: Vector3=-mantle.landing_plane_normal.normalized()
			var y: Vector3=mantle.facing.normalized()
			var x:=y.cross(z).normalized()
			y=z.cross(x).normalized()
			var desired:=Basis(x,y,z)
			var angle: float=arm.basis.get_rotation_quaternion().angle_to(desired.get_rotation_quaternion())
			var fraction: float=minf(1.0,deg_to_rad(max_wrist_rotation_degrees)/maxf(angle,.001))*hand_orientation_weight*arm.weight
			var pose:=skeleton.get_bone_global_pose(arm.bones[2])
			var scale: Vector3=(skeleton.global_basis*pose.basis).get_scale()
			pose.basis=skeleton.global_basis.inverse()*arm.basis.slerp(desired,fraction).scaled(scale)
			skeleton.set_bone_global_pose(arm.bones[2],pose)
		arm.solved=world(arm.bones[2]).origin
		arm.solved_elbow=world(arm.bones[1]).origin
		var shoulder:=world(arm.bones[0]).origin
		var axis: Vector3=(arm.solved-shoulder).normalized()
		var bend: Vector3=arm.solved_elbow-shoulder
		arm.elbow_direction=(bend-axis*bend.dot(axis)).normalized()
		arm.error=arm.solved.distance_to(arm.grip)
		if arm.has("upper_length"):
			arm.length_error=maxf(absf(world(arm.bones[0]).origin.distance_to(world(arm.bones[1]).origin)-arm.upper_length),absf(world(arm.bones[1]).origin.distance_to(arm.solved)-arm.lower_length))

func debug_text() -> String:
	var result: String="HANG HANDS (settle in / idle clamp / climb 45-70% out)" if motor.traversal.hang.running else "MANTLE HANDS (17-23 in / 24-37 clamp / 37-44 out)"
	for arm in arms: result+="\n%s grip %s / Weight %.2f / Error %.3fm / Limited %s" % [arm.side,arm.grip,arm.weight,arm.error,arm.limited]
	return result

func _process(_delta: float) -> void:
	if debug_mesh==null: return
	debug_mesh.visible=(hand_ik_debug or mantle.mantle_debug or mantle.owner_controller.traversal_debug) and mantle.running
	if not debug_mesh.visible: return
	var mesh:=ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	for arm in arms:
		mesh.surface_set_color(Color.CYAN if arm.side=="Left" else Color.MAGENTA)
		mesh.surface_add_vertex(arm.animated)
		mesh.surface_add_vertex(arm.grip)
		for axis in [Vector3.RIGHT,Vector3.UP,Vector3.BACK]:
			mesh.surface_add_vertex(arm.grip-axis*.04)
			mesh.surface_add_vertex(arm.grip+axis*.04)
	mesh.surface_end()
	debug_mesh.mesh=mesh

func _exit_tree() -> void:
	for modifier in modifiers:
		if is_instance_valid(modifier): modifier.queue_free()
