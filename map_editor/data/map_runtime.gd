class_name MapRuntime
extends RefCounted

## Fabrique de blocs et sol 3D partagée : l'éditeur ET le jeu construisent avec le même code.

static func spawn_into(data: MapData, parent: Node3D, catalog: BlockCatalog, collision_layer := 1) -> void:
	# Sol (Routes & Parcs)
	var ground := create_ground_node(data)
	if ground:
		parent.add_child(ground)
	# Bâtiments
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
	
	# Création du maillage à 2 surfaces : 0 = Murs (Façade), 1 = Toit (Neutre/Toiture)
	var mesh := create_two_surface_box(size)
	mi.mesh = mesh
	mi.position.y = size.y * 0.5

	# Matériau 0 : Murs (Façade)
	var mat_walls := StandardMaterial3D.new()
	var tex_path: String = block.get("texture", "")
	if tex_path != "" and ResourceLoader.exists(tex_path):
		mat_walls.albedo_texture = load(tex_path) as Texture2D
		mat_walls.albedo_color = Color.WHITE
		mat_walls.uv1_triplanar = true
		mat_walls.uv1_scale = Vector3(0.2, 0.2, 0.2)
	else:
		mat_walls.albedo_color = entry.get("color", Color(0.6, 0.5, 0.4))

	# Matériau 1 : Toit (Toiture neutre sans fenêtres)
	var mat_roof := StandardMaterial3D.new()
	mat_roof.albedo_color = Color(0.22, 0.23, 0.26)
	mat_roof.roughness = 0.8

	mi.set_surface_override_material(0, mat_walls)
	mi.set_surface_override_material(1, mat_roof)
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

static func create_two_surface_box(size: Vector3) -> ArrayMesh:
	var hx := size.x * 0.5
	var hy := size.y * 0.5
	var hz := size.z * 0.5

	var mesh := ArrayMesh.new()

	# --- Surface 0 : 4 Murs Verticaux ---
	var st_walls := SurfaceTool.new()
	st_walls.begin(Mesh.PRIMITIVE_TRIANGLES)

	# Avant (-Z)
	_add_quad(st_walls, Vector3(-hx, -hy, -hz), Vector3(hx, -hy, -hz), Vector3(hx, hy, -hz), Vector3(-hx, hy, -hz), Vector3(0, 0, -1))
	# Arrière (+Z)
	_add_quad(st_walls, Vector3(hx, -hy, hz), Vector3(-hx, -hy, hz), Vector3(-hx, hy, hz), Vector3(hx, hy, hz), Vector3(0, 0, 1))
	# Gauche (-X)
	_add_quad(st_walls, Vector3(-hx, -hy, hz), Vector3(-hx, -hy, -hz), Vector3(-hx, hy, -hz), Vector3(-hx, hy, hz), Vector3(-1, 0, 0))
	# Droite (+X)
	_add_quad(st_walls, Vector3(hx, -hy, -hz), Vector3(hx, -hy, hz), Vector3(hx, hy, hz), Vector3(hx, hy, -hz), Vector3(1, 0, 0))

	st_walls.generate_normals()
	mesh = st_walls.commit(mesh)

	# --- Surface 1 : Toit (+Y) & Bas (-Y) ---
	var st_roof := SurfaceTool.new()
	st_roof.begin(Mesh.PRIMITIVE_TRIANGLES)

	# Toit (+Y)
	_add_quad(st_roof, Vector3(-hx, hy, -hz), Vector3(hx, hy, -hz), Vector3(hx, hy, hz), Vector3(-hx, hy, hz), Vector3(0, 1, 0))
	# Bas (-Y)
	_add_quad(st_roof, Vector3(-hx, -hy, hz), Vector3(hx, -hy, hz), Vector3(hx, -hy, -hz), Vector3(-hx, -hy, -hz), Vector3(0, -1, 0))

	st_roof.generate_normals()
	mesh = st_roof.commit(mesh)

	return mesh

static func _add_quad(st: SurfaceTool, p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, normal: Vector3) -> void:
	st.set_normal(normal)
	st.set_uv(Vector2(0, 1)); st.add_vertex(p0)
	st.set_uv(Vector2(1, 1)); st.add_vertex(p1)
	st.set_uv(Vector2(1, 0)); st.add_vertex(p2)

	st.set_normal(normal)
	st.set_uv(Vector2(0, 1)); st.add_vertex(p0)
	st.set_uv(Vector2(1, 0)); st.add_vertex(p2)
	st.set_uv(Vector2(0, 0)); st.add_vertex(p3)

static func create_ground_node(data: MapData) -> Node3D:
	if data.road_cells.is_empty() and data.open_cells.is_empty():
		return null

	var root := Node3D.new()
	root.name = "Ground_3D"
	var cs := data.grid_cell_size

	# 1. Routes (Asphalte / Trottoir)
	if not data.road_cells.is_empty():
		var mi_road := MeshInstance3D.new()
		mi_road.name = "Roads"
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var hcs := cs * 0.5
		for cell in data.road_cells:
			var center := Vector3(cell.x * cs, 0.02, cell.y * cs)
			_add_quad(st, center + Vector3(-hcs, 0, -hcs), center + Vector3(hcs, 0, -hcs), center + Vector3(hcs, 0, hcs), center + Vector3(-hcs, 0, hcs), Vector3(0, 1, 0))
		st.generate_normals()
		mi_road.mesh = st.commit()

		var mat_road := StandardMaterial3D.new()
		var ptex := "res://textures/ceuta_pavement_tile.png"
		if ResourceLoader.exists(ptex):
			mat_road.albedo_texture = load(ptex) as Texture2D
			mat_road.uv1_scale = Vector3(0.2, 0.2, 0.2)
			mat_road.uv1_triplanar = true
		else:
			mat_road.albedo_color = Color(0.35, 0.35, 0.38)
		mi_road.material_override = mat_road
		root.add_child(mi_road)

	# 2. Espaces Verts / Parcs
	if not data.open_cells.is_empty():
		var mi_parks := MeshInstance3D.new()
		mi_parks.name = "Parks"
		var st_p := SurfaceTool.new()
		st_p.begin(Mesh.PRIMITIVE_TRIANGLES)
		var hcs := cs * 0.5
		for cell in data.open_cells:
			var center := Vector3(cell.x * cs, 0.01, cell.y * cs)
			_add_quad(st_p, center + Vector3(-hcs, 0, -hcs), center + Vector3(hcs, 0, -hcs), center + Vector3(hcs, 0, hcs), center + Vector3(-hcs, 0, hcs), Vector3(0, 1, 0))
		st_p.generate_normals()
		mi_parks.mesh = st_p.commit()

		var mat_park := StandardMaterial3D.new()
		mat_park.albedo_color = Color(0.20, 0.45, 0.25)
		mi_parks.material_override = mat_park
		root.add_child(mi_parks)

	return root
