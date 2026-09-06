extends SkeletonModifier3D
## Runs on the restored animation pose, before both native leg modifiers.
var controller: Node
var bone: int = -1
var target_offset: float = 0.0
var current_offset: float = 0.0
var applied_offset: float = 0.0
var required: Array[float] = [0.0, 0.0]
var support: Array[float] = [0.0, 0.0]
var animated_position := Vector3.ZERO
var corrected_position := Vector3.ZERO

func prepare(delta: float) -> void:
	var s = controller.motor.animation_state
	var allowed: bool = controller.pelvis_enabled and controller.enabled and s.is_grounded and not s.jump_started and not s.is_airborne
	var lowest := 0.0
	for i in controller.legs.size():
		var leg = controller.legs[i]
		var data = controller.feet.left if i == 0 else controller.feet.right
		required[i] = data.ankle_target_transform.origin.y - leg.animated.y if data.valid else 0.0
		# Reuse the existing swing classifier; never chase an unsupported ray.
		support[i] = minf(leg.swing, leg.weight / maxf(controller.foot_ik_weight, 0.001)) if allowed and data.valid else 0.0
		lowest = minf(lowest, required[i] * support[i])
	target_offset = maxf(lowest, -controller.max_pelvis_drop) * controller.pelvis_ik_weight
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
	return "PELVIS IK\nWeight: %.2f / Max Drop: %.2fm / Raise: 0\nTarget: %+.3fm / Current: %+.3fm / Applied: %+.3fm\nLeft Required: %+.3f / Support: %.2f\nRight Required: %+.3f / Support: %.2f" % [controller.pelvis_ik_weight, controller.max_pelvis_drop, target_offset, current_offset, applied_offset, required[0], support[0], required[1], support[1]]
