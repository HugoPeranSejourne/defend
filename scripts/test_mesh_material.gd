@tool
extends SceneTree

func _init() -> void:
	print("--- MESH MATERIAL INSPECTION ---")
	var scn := load("res://assets/models/soldier_allied_human.glb") as PackedScene
	if scn:
		var inst := scn.instantiate() as Node3D
		var mi := inst.find_child("vanguard_Mesh", true, false) as MeshInstance3D
		if mi and mi.mesh:
			print("Active Surface Count: ", mi.mesh.get_surface_count())
			for i in range(mi.mesh.get_surface_count()):
				var mat := mi.get_active_material(i)
				print("Surface ", i, " Material: ", mat)
				if mat is StandardMaterial3D:
					var std_mat := mat as StandardMaterial3D
					print("  Albedo Color: ", std_mat.albedo_color)
					print("  Albedo Texture: ", std_mat.albedo_texture)
					print("  Transparency Mode: ", std_mat.transparency)
					print("  Cull Mode: ", std_mat.cull_mode)
					print("  Shading Mode: ", std_mat.shading_mode)
		inst.queue_free()
	quit()
