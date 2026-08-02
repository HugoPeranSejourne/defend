@tool
extends SceneTree

func _init() -> void:
	print("--- TESTING SKINNED MATERIAL TINTING ---")
	var scn := load("res://scenes/unit_3d.tscn") as PackedScene
	if scn:
		var inst := scn.instantiate() as Node3D
		root.add_child(inst)
		var mi := inst.find_child("vanguard_Mesh", true, false) as MeshInstance3D
		if mi:
			print("Material Override: ", mi.material_override)
			print("Active Surface 0 Material: ", mi.get_active_material(0))
			if mi.get_active_material(0) is StandardMaterial3D:
				var std_mat := mi.get_active_material(0) as StandardMaterial3D
				std_mat.albedo_color = Color(0.2, 0.6, 1.0, 1.0)
				print("Successfully set albedo_color on active material without breaking skinning shader!")
		inst.queue_free()
	quit()
