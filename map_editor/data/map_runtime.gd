class_name MapRuntime
extends RefCounted

## Fabrique de blocs partagée : l'éditeur ET le jeu construisent avec le même code.
## collision_layer : 2 dans l'éditeur (raycast de sélection), 1 dans le jeu (physique).

static func spawn_into(data: MapData, parent: Node3D, catalog: BlockCatalog, collision_layer := 1) -> void:
	for b in data.blocks:
		parent.add_child(create_block_node(b, catalog, collision_layer))

static func create_block_node(block: Dictionary, catalog: BlockCatalog, collision_layer := 2) -> Node3D:
	var entry := catalog.get_entry(block.key)
	var size: Vector3 = block.size
	var root := Node3D.new()
	root.name = "Block_%d" % int(block.get("id", 0))
	root.position = block.pos
	root.rotation.y = float(block.get("rot_y", 0.0))
	root.set_meta("block_id", int(block.get("id", 0)))
	root.set_meta("catalog_key", block.key)
	root.set_meta("size", size)

	var mi := MeshInstance3D.new()
	mi.name = "Mesh"
	mi.mesh = catalog.create_mesh(entry, size)
	mi.position.y = size.y * 0.5
	var mat := StandardMaterial3D.new()
	var tex_path: String = block.get("texture", "")
	if tex_path != "" and ResourceLoader.exists(tex_path):
		mat.albedo_texture = load(tex_path) as Texture2D
		mat.albedo_color = Color.WHITE
		mat.uv1_triplanar = true # Placage triplanaire parfait sur tous les murs 3D !
		mat.uv1_scale = Vector3(0.15, 0.15, 0.15)
	else:
		mat.albedo_color = entry.get("color", Color.WHITE)
	mi.material_override = mat
	root.add_child(mi)

	var body := StaticBody3D.new()
	body.name = "Body"
	body.collision_layer = collision_layer
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	cs.shape = catalog.create_shape(entry, size)
	cs.position.y = size.y * 0.5
	body.add_child(cs)
	root.add_child(body)
	return root
