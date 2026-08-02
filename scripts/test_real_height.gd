@tool
extends SceneTree

func _init() -> void:
	print("========== SCALE & HEIGHT DIAGNOSTIC ==========")
	var u_scn := load("res://scenes/unit_3d.tscn") as PackedScene
	if u_scn:
		var inst := u_scn.instantiate() as Node3D
		var child_glb := inst.find_child("SoldierHumanGLB", true, false) as Node3D
		if child_glb:
			child_glb.scale = Vector3(4.14, 4.14, 4.14)
		root.add_child(inst)
		var mi := inst.find_child("vanguard_Mesh", true, false) as MeshInstance3D
		if mi and mi.mesh:
			var aabb := mi.mesh.get_aabb()
			var g_scale := mi.global_transform.basis.get_scale()
			var h_meters := aabb.size.y * g_scale.y
			print("Local AABB Size Y: ", aabb.size.y)
			print("Global Basis Scale Y: ", g_scale.y)
			print("CALCULATED WORLD HEIGHT (METERS): ", h_meters)
		inst.queue_free()
	quit()
