extends Node3D
## Read-only terrain observation. No skeleton overrides or motor writes.
@export var enabled: bool = true
@export var foot_grounding_debug: bool = false
@export_range(0.05,0.4,0.01) var foot_probe_origin_height: float = 0.20
## Total cast length, measured from the elevated origin.
@export_range(0.2,1.0,0.01) var foot_probe_distance: float = 0.60
@export_range(0.0,0.15,0.005) var foot_sole_offset: float = 0.08
@export_range(0.0,40.0,1.0) var foot_target_smoothing_speed: float = 20.0
@export_range(0.0,40.0,1.0) var foot_normal_smoothing_speed: float = 15.0
@export_flags_3d_physics var ground_collision_mask: int = 1

class FootSample extends RefCounted:
	var bone_index: int = -1
	var valid: bool = false
	var hit: bool = false
	var reason: String = "UNINITIALIZED"
	var bone_position := Vector3.ZERO
	var raw_ground_position := Vector3.ZERO
	var smoothed_ground_position := Vector3.ZERO
	var raw_ground_normal := Vector3.UP
	var ground_normal := Vector3.UP
	## Signed vertical distance from the estimated animated sole to the raw hit.
	var distance: float = INF
	var target_transform := Transform3D.IDENTITY
	var ankle_target_transform := Transform3D.IDENTITY
	var collider_id: int = 0

var left := FootSample.new()
var right := FootSample.new()
var foot_height_delta: float = NAN
var lowest_required_pelvis_offset: float = NAN
var samples: int = 0
var skeleton: Skeleton3D
var _ready_to_sample: bool = false
var _debug_mesh := ImmediateMesh.new()
var _material := StandardMaterial3D.new()
@onready var motor = get_parent()
@onready var tree: AnimationTree = $"../AnimationTree"
@onready var left_probe: RayCast3D = $LeftFootProbe
@onready var right_probe: RayCast3D = $RightFootProbe
@onready var left_target: Marker3D = $LeftFootTarget
@onready var right_target: Marker3D = $RightFootTarget
@onready var debug_geometry: MeshInstance3D = $DebugGeometry

func _ready() -> void:
	# Connect after AnimationController has connected its sink/pivot pose handler.
	call_deferred("_bind")

func _bind() -> void:
	skeleton = get_node_or_null("../VisualRoot/MasterRig/Base Armature and Mesh/Skeleton3D")
	if skeleton == null:
		push_error("FootGrounding: canonical Skeleton3D missing")
		return
	left.bone_index=skeleton.find_bone("mixamorig_LeftFoot")
	right.bone_index=skeleton.find_bone("mixamorig_RightFoot")
	if left.bone_index<0 or right.bone_index<0:
		push_error("FootGrounding: required foot bone missing")
		return
	for probe in [left_probe,right_probe]:
		probe.enabled=false # Exactly one explicit cast per foot per evaluated pose.
		probe.collide_with_areas=false
		probe.collide_with_bodies=true
		probe.add_exception(motor)
	_material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.vertex_color_use_as_albedo=true
	_material.no_depth_test=true
	debug_geometry.top_level=true
	debug_geometry.global_transform=Transform3D.IDENTITY
	debug_geometry.mesh=_debug_mesh
	_ready_to_sample=true
	tree.mixer_applied.connect(_after_pose)

func _after_pose() -> void:
	sample_pose(get_physics_process_delta_time())

func sample_pose(delta: float) -> void:
	if not _ready_to_sample:
		return
	var state = motor.animation_state
	var allowed: bool = enabled and motor.physical_ground_contact() and not state.jump_started
	_sample(left,left_probe,left_target,allowed,delta)
	_sample(right,right_probe,right_target,allowed,delta)
	foot_height_delta=left.raw_ground_position.y-right.raw_ground_position.y if left.valid and right.valid else NAN
	lowest_required_pelvis_offset=minf(0.0,minf(-left.distance,-right.distance)) if left.valid and right.valid else NAN
	samples+=1
	_draw_debug()

func _sample(data: FootSample, probe: RayCast3D, target: Marker3D, allowed: bool, delta: float) -> void:
	var previously_valid := data.valid
	data.valid=false
	data.hit=false
	data.distance=INF
	data.bone_position=skeleton.global_transform*skeleton.get_bone_global_pose(data.bone_index).origin
	probe.global_transform=Transform3D(Basis.IDENTITY,data.bone_position+Vector3.UP*foot_probe_origin_height)
	var distance:=foot_probe_distance
	var ik=motor.get_node_or_null("FootIKController")
	if ik!=null and ik.is_grounded_idle():
		distance=maxf(distance,foot_probe_origin_height+foot_sole_offset+ik.idle_max_terrain_height_delta+0.03)
	probe.target_position=Vector3.DOWN*distance
	probe.collision_mask=ground_collision_mask & motor.collision_mask
	if not allowed:
		data.reason="AIRBORNE" if enabled else "DISABLED"
		return
	probe.force_raycast_update()
	if not probe.is_colliding():
		data.reason="NO_GROUND"
		return
	data.hit=true
	data.raw_ground_position=probe.get_collision_point()
	data.raw_ground_normal=probe.get_collision_normal().normalized()
	data.distance=data.bone_position.y-foot_sole_offset-data.raw_ground_position.y
	var collider := probe.get_collider()
	# Dynamic characters/rigid bodies cannot become IK terrain. AnimatableBody3D
	# derives from StaticBody3D and remains eligible for future platform support.
	if not collider is StaticBody3D:
		data.reason="NOT_TERRAIN"
		return
	if data.raw_ground_normal.dot(Vector3.UP)<cos(motor.floor_max_angle):
		data.reason="TOO_STEEP"
		return
	var id: int = collider.get_instance_id()
	var reset := not previously_valid or id!=data.collider_id or absf(data.raw_ground_position.y-data.smoothed_ground_position.y)>0.08
	if reset:
		data.smoothed_ground_position=data.raw_ground_position
		data.ground_normal=data.raw_ground_normal
	else:
		var weight := 1.0-exp(-foot_target_smoothing_speed*maxf(delta,0.0)) if foot_target_smoothing_speed>0 else 1.0
		# Preserve the exact animated-foot X/Z column; do not trail a sprinting
		# foot horizontally. Filter small height noise, not entire stair risers.
		data.smoothed_ground_position=Vector3(data.raw_ground_position.x,lerpf(data.smoothed_ground_position.y,data.raw_ground_position.y,weight),data.raw_ground_position.z)
		var normal_weight := 1.0-exp(-foot_normal_smoothing_speed*maxf(delta,0.0)) if foot_normal_smoothing_speed>0 else 1.0
		data.ground_normal=data.ground_normal.lerp(data.raw_ground_normal,normal_weight).normalized()
	data.collider_id=id
	data.valid=true
	data.reason="VALID"
	# Ground marker is on the surface. Separate ankle suggestion includes sole
	# offset; neither is connected to an IK consumer in this phase.
	data.target_transform=Transform3D(Basis.IDENTITY,data.smoothed_ground_position)
	data.ankle_target_transform=Transform3D(Basis.IDENTITY,data.smoothed_ground_position+data.ground_normal*foot_sole_offset)
	target.global_transform=data.target_transform

func _line(a: Vector3,b: Vector3,color: Color) -> void:
	_debug_mesh.surface_set_color(color)
	_debug_mesh.surface_add_vertex(a)
	_debug_mesh.surface_set_color(color)
	_debug_mesh.surface_add_vertex(b)

func _cross(p: Vector3,color: Color,size: float) -> void:
	for axis in [Vector3.UP,Vector3.RIGHT,Vector3.FORWARD]:
		_line(p-axis*size,p+axis*size,color)

func _draw_debug() -> void:
	debug_geometry.visible=foot_grounding_debug
	if not foot_grounding_debug: return
	_debug_mesh.clear_surfaces()
	_debug_mesh.surface_begin(Mesh.PRIMITIVE_LINES,_material)
	for data in [left,right]:
		var origin: Vector3=data.bone_position+Vector3.UP*foot_probe_origin_height
		var color := Color.CYAN if data==left else Color.MAGENTA
		_cross(origin,color,0.025)
		var probe: RayCast3D=left_probe if data==left else right_probe
		_line(origin,origin+probe.target_position,color if data.valid else Color.ORANGE_RED)
		if data.hit:
			_cross(data.raw_ground_position,Color.YELLOW,0.025)
			_line(data.raw_ground_position,data.raw_ground_position+data.raw_ground_normal*0.2,Color.YELLOW)
		if data.valid:
			_cross(data.smoothed_ground_position,Color.LIME_GREEN,0.04)
			_line(data.smoothed_ground_position,data.smoothed_ground_position+data.ground_normal*0.3,color)
	_debug_mesh.surface_end()

func debug_text() -> String:
	return "FOOT GROUNDING (F7)\nLeft Valid: %s [%s]\nLeft Distance: %.3f / Target Y: %.3f\nLeft Normal: %s\nRight Valid: %s [%s]\nRight Distance: %.3f / Target Y: %.3f\nRight Normal: %s\nFoot Height Delta: %.3f m" % [left.valid,left.reason,left.distance,left.smoothed_ground_position.y,left.ground_normal,right.valid,right.reason,right.distance,right.smoothed_ground_position.y,right.ground_normal,foot_height_delta]
