@tool
extends SceneTree

func _init() -> void:
	for path in ["res://assets/models/soldier_allied_human.glb", "res://assets/models/insurgent_enemy_human.glb"]:
		print("==== ", path)
		var inst := (load(path) as PackedScene).instantiate() as Node3D
		root.add_child(inst)
		_dump(inst, 0)
		var mi := inst.find_child("vanguard_Mesh", true, false) as MeshInstance3D
		var skel := inst.find_child("Skeleton3D", true, false) as Skeleton3D
		if mi and mi.mesh:
			print("  >> bind AABB size: ", mi.mesh.get_aabb().size)
			print("  >> mesh node global scale: ", mi.global_transform.basis.get_scale())
		if skel:
			print("  >> SKELETON global scale: ", skel.global_transform.basis.get_scale())
		inst.queue_free()
	quit()

func _dump(n: Node, d: int) -> void:
	var s := ""
	if n is Node3D:
		s = " local_scale=" + str((n as Node3D).transform.basis.get_scale())
	print("  ".repeat(d) + n.name + " (" + n.get_class() + ")" + s)
	for c in n.get_children():
		_dump(c, d + 1)
