@tool
extends SceneTree

func _init() -> void:
	var scn := load("res://assets/models/insurgent_enemy_human.glb") as PackedScene
	if scn:
		var inst := scn.instantiate()
		print("Insurgent GLB Children:")
		_print_aabb(inst)
	quit()

func _print_aabb(node: Node) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		if mi.mesh:
			print("  - ", mi.name, " AABB: ", mi.mesh.get_aabb().size)
	for child in node.get_children():
		_print_aabb(child)
