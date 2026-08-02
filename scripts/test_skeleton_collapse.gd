@tool
extends SceneTree

func _init() -> void:
	print("--- SKELETON COLLAPSE TEST ---")
	var scn := load("res://scenes/unit_3d.tscn") as PackedScene
	if scn:
		var inst := scn.instantiate() as Node3D
		root.add_child(inst)
		
		var skel := inst.find_child("Skeleton3D", true, false) as Skeleton3D
		print("Skeleton3D Found: ", skel != null)
		if skel:
			print("  Bone Count: ", skel.get_bone_count())
			print("  Skeleton Enabled: ", skel.animate_physical_bones)
			
		var mesh_inst := inst.find_child("vanguard_Mesh", true, false) as MeshInstance3D
		if mesh_inst:
			print("MeshInstance3D Found: ", mesh_inst.name)
			print("  Skin: ", mesh_inst.skin != null)
			print("  Skeleton Path: ", mesh_inst.skeleton)
			print("  Material Override: ", mesh_inst.material_override)
			print("  Surface Materials Count: ", mesh_inst.get_surface_override_material_count())

		inst.queue_free()
	quit()
