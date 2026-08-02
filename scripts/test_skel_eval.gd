@tool
extends SceneTree

func _init() -> void:
	print("--- SKELETON POSE EVALUATION TEST ---")
	var scn := load("res://scenes/unit_3d.tscn") as PackedScene
	if scn:
		var inst := scn.instantiate() as Node3D
		root.add_child(inst)
		
		var skel := inst.find_child("Skeleton3D", true, false) as Skeleton3D
		if skel:
			print("Resetting Bone Poses on Skeleton3D...")
			skel.reset_bone_poses()
			for b in range(min(5, skel.get_bone_count())):
				print("  Bone %d (%s) Pose Transform: %s" % [b, skel.get_bone_name(b), skel.get_bone_pose(b)])

		var glb_anim := inst.find_child("AnimationPlayer", true, false) as AnimationPlayer
		if glb_anim:
			print("GLB AnimationPlayer Found! Animations: ", glb_anim.get_animation_list())

		inst.queue_free()
	quit()
