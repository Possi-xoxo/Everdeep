extends SkeletonModifier3D
## Runs on the restored animation pose, before both native leg modifiers.
var controller: Node
var bone: int = -1
var target_offset: float = 0.0
var current_offset: float = 0.0
var applied_offset: float = 0.0
var effective_weight: float = 0.8
var required: Array[float] = [0.0, 0.0]
var support: Array[float] = [0.0, 0.0]
var animated_position := Vector3.ZERO
var corrected_position := Vector3.ZERO

func prepare(delta: float) -> void:
	var s = controller.motor.animation_state
	var allowed: bool = controller.pelvis_enabled and controller.enabled and controller.motor.physical_ground_contact() and not s.jump_started and not controller.motor.dodge.is_dodging
	allowed=allowed and not controller.motor.traversal.mantle.pose_owned() and not controller.motor.traversal.hang.is_attached()
	var lowest := 0.0
	for i in controller.legs.size():
		var leg = controller.legs[i]
		var data = controller.feet.left if i == 0 else controller.feet.right
		var target_y: float=leg.plant.locked_world_position.y if leg.plant.locked else data.ankle_target_transform.origin.y
		required[i] = target_y - leg.animated.y if data.valid else 0.0
		# leg.swing now carries planting confidence when planting is enabled.
		support[i] = minf(leg.swing, leg.weight / maxf(controller.foot_ik_weight, 0.001)) if allowed and data.valid else 0.0
		lowest = minf(lowest, required[i] * support[i])
	# Idle has its own authorized drop budget; moving gait behavior is intact.
	effective_weight=1.0 if controller.is_grounded_idle() else controller.pelvis_ik_weight
	target_offset = maxf(lowest, -controller.pelvis_drop_limit()) * effective_weight
	current_offset = lerpf(current_offset, target_offset, 1.0 - exp(-controller.pelvis_adjust_speed * delta))
	if absf(current_offset) < 0.0001: current_offset = 0.0
	# Landing already lowers VisualRoot. It pays this shared downward budget;
	# Hips never adds its entire drop on top of the authored landing compression.
	var sink: float = minf(controller.motor.get_node("AnimationController").land_visual_offset, 0.0)
	applied_offset = minf(0.0, current_offset - sink)

func _process_modification_with_delta(_delta: float) -> void:
	if not is_instance_valid(controller) or bone < 0: return
	var sk := get_skeleton()
	var pose := sk.get_bone_global_pose(bone)
	animated_position = sk.global_transform * pose.origin
	pose.origin += sk.global_basis.inverse() * (Vector3.UP * applied_offset)
	sk.set_bone_global_pose(bone, pose)
	corrected_position = sk.global_transform * pose.origin
	controller.place_targets()

func debug_text() -> String:
	return "PELVIS IK\nWeight: %.2f / Max Drop: %.2fm / Raise: 0\nTarget: %+.3fm / Current: %+.3fm / Applied: %+.3fm\nLeft Required: %+.3f / Support: %.2f\nRight Required: %+.3f / Support: %.2f" % [effective_weight, controller.pelvis_drop_limit(), target_offset, current_offset, applied_offset, required[0], support[0], required[1], support[1]]
