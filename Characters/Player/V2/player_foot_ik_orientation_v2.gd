extends SkeletonModifier3D
## Native leg IK changes parent rotations. Preserve the authored ankle world
## orientation afterward; terrain tilt is intentionally deferred.
var controller: Node
func _process_modification_with_delta(_delta: float) -> void:
	if not is_instance_valid(controller): return
	var sk := get_skeleton()
	for leg in controller.legs:
		var pose := sk.get_bone_global_pose(leg.bones[2])
		pose.basis=sk.global_basis.inverse()*leg.animated_basis
		sk.set_bone_global_pose(leg.bones[2],pose)
