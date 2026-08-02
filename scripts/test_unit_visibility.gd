@tool
extends SceneTree

func _init() -> void:
	print("================ UNIT VISIBILITY TEST ================")
	var unit_scn := load("res://scenes/unit_3d.tscn") as PackedScene
	if unit_scn:
		var u_inst := unit_scn.instantiate() as Node3D
		root.add_child(u_inst)
		u_inst.global_position = Vector3(0, 0, 0)
		_check_visibility_and_bounds(u_inst)
		u_inst.queue_free()
		
	print("\n================ ENEMY VISIBILITY TEST ================")
	var enemy_scn := load("res://scenes/enemy_unit.tscn") as PackedScene
	if enemy_scn:
		var e_inst := enemy_scn.instantiate() as Node3D
		root.add_child(e_inst)
		e_inst.global_position = Vector3(0, 0, 0)
		_check_visibility_and_bounds(e_inst)
		e_inst.queue_free()
		
	quit()

func _check_visibility_and_bounds(node: Node) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		var visible := mi.is_visible_in_tree()
		var mesh_name := mi.mesh.resource_path if mi.mesh else "No Mesh"
		var local_aabb := mi.mesh.get_aabb() if mi.mesh else AABB()
		var global_trans := mi.global_transform
		var world_size := local_aabb.size * global_trans.basis.get_scale()
		print("Mesh: '%s' | Node: '%s' | VisibleInTree: %s | Local AABB Size: %s | World Size (meters): %s | Global Scale: %s" % [
			mi.name, node.get_path(), visible, local_aabb.size, world_size, global_trans.basis.get_scale()
		])
	for c in node.get_children():
		_check_visibility_and_bounds(c)
