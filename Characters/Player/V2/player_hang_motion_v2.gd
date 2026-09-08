extends RefCounted
## Sample private, still-unmodified source clips before root compensation.
const SAMPLE_COUNT: int=240
var profiles: Dictionary={}
var measurements: Dictionary={}
var original_right_profile: Array[Vector3]=[]

func capture(h: Node,player: AnimationPlayer,name: String,clip: Animation) -> void:
	var track: int=h.hip_track(clip)
	var first: Vector3=clip.position_track_interpolate(track,0)
	var last: Vector3=clip.position_track_interpolate(track,clip.length)
	var hop: bool=name.begins_with("HangHop")
	var source_direction: float=1.0 if name.ends_with("Left") else -1.0
	var skeleton: Skeleton3D=h.motor.get_node("AnimationController").rig.get_node("Base Armature and Mesh/Skeleton3D")
	var lead: int=skeleton.find_bone("mixamorig_"+("Left" if source_direction>0 else "Right")+"Hand")
	var trail: int=skeleton.find_bone("mixamorig_"+("Right" if source_direction>0 else "Left")+"Hand")
	var previous_lead: float=0
	var previous_trail: float=0
	var reconstructed: float=0
	var samples: Array[Vector3]=[]
	player.play(h.lateral.CLIPS[name])
	for i in range(SAMPLE_COUNT+1):
		var p: float=float(i)/SAMPLE_COUNT
		var value: Vector3=clip.position_track_interpolate(track,p*clip.length)
		var delta_position: Vector3=(value-first)/100.0
		var lateral: float=delta_position.x*source_direction
		if not hop:
			player.seek(p*clip.length,true)
			player.advance(0)
			var lead_x: float=skeleton.get_bone_global_pose(lead).origin.x/100.0
			var trail_x: float=skeleton.get_bone_global_pose(trail).origin.x/100.0
			if i>0:
				# The leading hand arrives at ~35%; stance switches there.
				var wrist_delta: float=trail_x-previous_trail if p<=.35 else lead_x-previous_lead
				reconstructed+=maxf(0,-wrist_delta*source_direction)
			previous_lead=lead_x
			previous_trail=trail_x
			lateral+=reconstructed
		# Remove endpoint drift, not the authored up/down arc. Wall-normal
		# retreat is optional: preserve outward motion, never push into wall.
		var residual: Vector3=delta_position-(last-first)/100.0*p
		samples.append(Vector3(lateral,-residual.z,maxf(0,-residual.y)))
	player.stop()
	var distance: float=samples.back().x
	assert(distance>.01,"Lateral clip has no usable authored/reconstructed travel")
	var peak: float=0
	for i in samples.size():
		samples[i].x/=distance
		peak=maxf(peak,samples[i].y)
	samples[0]=Vector3.ZERO
	samples[SAMPLE_COUNT]=Vector3(1,0,0)
	profiles[StringName(name)]=samples
	if name=="HangHopRight": original_right_profile=samples.duplicate()
	measurements[name]={"raw_lateral_m":(last.x-first.x)*source_direction/100.0,"derived_distance_m":distance,"vertical_peak_m":peak,"duration":clip.length,"in_place_reconstruction":not hop}

func sample(name: StringName,p: float) -> Vector3:
	var samples: Array=profiles[name]
	var index: float=clampf(p,0,1)*SAMPLE_COUNT
	var low: int=mini(int(index),SAMPLE_COUNT-1)
	return Vector3(samples[low]).lerp(samples[low+1],index-low)

func configure_right_hop(mirror_left: bool) -> void:
	# X is normalized unsigned travel, not world X. The existing right-side
	# route supplies the mirror sign; do not negate it twice. Y (rise) and Z
	# (outward retreat) are copied unchanged. Right keeps its own clip clock.
	profiles[&"HangHopRight"]=profiles[&"HangHopLeft"].duplicate() if mirror_left else original_right_profile.duplicate()
	measurements["HangHopRight"]["movement_profile_source"]="HangHopLeft mirrored" if mirror_left else "HangHopRight authored"
