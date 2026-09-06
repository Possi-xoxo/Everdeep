extends SkeletonModifier3D
## Preparation and palm orientation/result capture bracket native arm solvers.
## Bone writes are scoped to this modifier pass: Skeleton3D restores the input
## pose afterward. Never use persistent global-pose overrides or clear other
## modifiers' overrides (Foot IK owns its separate layer).
var controller: Node
var capture: bool = false
func _process_modification_with_delta(delta: float) -> void:
	if not is_instance_valid(controller): return
	if capture: controller.capture_result()
	else: controller.prepare_targets(delta)
