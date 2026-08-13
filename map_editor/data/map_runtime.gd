class_name MapRuntime
extends RefCounted

## Fabrique 3D AAA : Extrusion vectorielle lisse (Geometry2D), Landmarks 3D et PBR.

const SCENE_LANDMARKS := {
	&"dragons": "res://scenes/ceuta_casa_dragones.tscn",
	&"asamblea": "res://scenes/ceuta_palacio_asamblea.tscn",
}

static func spawn_into(data: MapData, parent: Node3D, catalog: BlockCatalog, collision_layer := 1) -> void:
	var ground := create_ground_node(data)
	if ground:
		parent.add_child(ground)
	for b in data.blocks:
		parent.add_child(create_block_node(b, catalog, collision_layer))

static func create_block_node(block: Dictionary, catalog: BlockCatalog, collision_layer := 2) -> Node3D:
	var bkey: StringName = block.key
	var size: Vector3 = block.size
	var root := Node3D.new()
	root.name = "Block_%d" % int(block.get("id", 0))
	root.position = block.pos
	root.rotation.y = float(block.get("rot_y", 0.0))
	root.set_meta("block_id", int(block.get("id", 0)))
	root.set_meta("catalog_key", bkey)
	root.set_meta("size", size)

	# --- Support des Monuments & Landmarks 3D complexes (ex: Casa de los Dragones) ---
	var scene_path: String = block.get("scene_path", "")
	if scene_path == "" and SCENE_LANDMARKS.has(bkey):
		scene_path = SCENE_LANDMARKS[bkey]

	if scene_path != "" and ResourceLoader.exists(scene_path):
		var scn := load(scene_path) as PackedScene
		if scn:
			var landmark_inst := scn.instantiate()
			landmark_inst.name = "LandmarkModel"
			root.add_child(landmark_inst)
			return root

	# --- Rendu Procédural standard ---
	var entry := catalog.get_entry(bkey)
	var mi := MeshInstance3D.new()
	mi.name = "Mesh"

	var raw_poly: Variant = block.get("polygon", null)
	var poly := PackedVector2Array()
	if raw_poly is PackedVector2Array:
		poly = raw_poly
	elif raw_poly is Array:
		for pt in raw_poly:
			if pt is Vector2:
				poly.append(pt)
			elif pt is Array and pt.size() >= 2:
				poly.append(Vector2(float(pt[0]), float(pt[1])))

	var mesh: ArrayMesh
	if poly.size() >= 3:
		mesh = create_extruded_polygon_mesh(poly, size.y, block.pos)
		mi.position = Vector3.ZERO
	else:
		mesh = create_two_surface_box(size)
		mi.position.y = size.y * 0.5

	mi.mesh = mesh

	# Matériau 0 : Façade PBR ancrée
	var mat_walls := StandardMaterial3D.new()
	var tex_path: String = block.get("texture", "")
	if tex_path != "" and ResourceLoader.exists(tex_path):
		mat_walls.albedo_texture = load(tex_path) as Texture2D
		mat_walls.albedo_color = Color.WHITE
		mat_walls.uv1_triplanar = true
		mat_walls.uv1_triplanar_world_triplanar = true
		mat_walls.uv1_scale = Vector3(0.18, 0.18, 0.18)

		var norm_path := tex_path.get_basename() + "_normal.png"
		if ResourceLoader.exists(norm_path):
			mat_walls.normal_enabled = true
			mat_walls.normal_texture = load(norm_path) as Texture2D
			mat_walls.normal_scale = 1.2
	else:
		mat_walls.albedo_color = entry.get("color", Color(0.65, 0.55, 0.45))

	mat_walls.roughness = 0.75

	# Matériau 1 : Toiture Neutre Sombre
	var mat_roof := StandardMaterial3D.new()
	mat_roof.albedo_color = Color(0.20, 0.21, 0.24)
	mat_roof.roughness = 0.85

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

static func create_extruded_polygon_mesh(world_poly: PackedVector2Array, height: float, origin_pos: Vector3) -> ArrayMesh:
	var local_poly := PackedVector2Array()
	for pt in world_poly:
		local_poly.append(Vector2(pt.x - origin_pos.x, pt.y - origin_pos.z))

	var mesh := ArrayMesh.new()
	var n_pts := local_poly.size()

	var st_walls := SurfaceTool.new()
	st_walls.begin(Mesh.PRIMITIVE_TRIANGLES)

	var u_accum := 0.0
	for i in range(n_pts):
		var p1 := local_poly[i]
		var p2 := local_poly[(i + 1) % n_pts]
		var wall_len := p1.distance_to(p2)
		var dir := (p2 - p1).normalized()
		var normal := Vector3(-dir.y, 0, dir.x)

		var u0 := u_accum * 0.2
		var u1 := (u_accum + wall_len) * 0.2
		u_accum += wall_len

		var v0 := Vector3(p1.x, 0.0, p1.y)
		var v1 := Vector3(p2.x, 0.0, p2.y)
		var v2 := Vector3(p2.x, height, p2.y)
		var v3 := Vector3(p1.x, height, p1.y)

		_add_quad_uv(st_walls, v0, v1, v2, v3, normal, u0, u1, 0.0, height * 0.2)

	st_walls.generate_normals()
	mesh = st_walls.commit(mesh)

	var st_roof := SurfaceTool.new()
	st_roof.begin(Mesh.PRIMITIVE_TRIANGLES)

	var triangles := Geometry2D.triangulate_polygon(local_poly)
	if triangles.size() >= 3:
		st_roof.set_normal(Vector3(0, 1, 0))
		for i in range(0, triangles.size(), 3):
			var idx0: int = triangles[i]
			var idx1: int = triangles[i + 1]
			var idx2: int = triangles[i + 2]

			var p0 := local_poly[idx0]
			var p1 := local_poly[idx1]
			var p2 := local_poly[idx2]

			st_roof.set_uv(Vector2(p0.x * 0.1, p0.y * 0.1)); st_roof.add_vertex(Vector3(p0.x, height, p0.y))
			st_roof.set_uv(Vector2(p1.x * 0.1, p1.y * 0.1)); st_roof.add_vertex(Vector3(p1.x, height, p1.y))
			st_roof.set_uv(Vector2(p2.x * 0.1, p2.y * 0.1)); st_roof.add_vertex(Vector3(p2.x, height, p2.y))

	st_roof.generate_normals()
	mesh = st_roof.commit(mesh)

	return mesh

static func create_two_surface_box(size: Vector3) -> ArrayMesh:
	var hx := size.x * 0.5
	var hy := size.y * 0.5
	var hz := size.z * 0.5
	var mesh := ArrayMesh.new()

	var st_walls := SurfaceTool.new()
	st_walls.begin(Mesh.PRIMITIVE_TRIANGLES)
	_add_quad(st_walls, Vector3(-hx, -hy, -hz), Vector3(hx, -hy, -hz), Vector3(hx, hy, -hz), Vector3(-hx, hy, -hz), Vector3(0, 0, -1))
	_add_quad(st_walls, Vector3(hx, -hy, hz), Vector3(-hx, -hy, hz), Vector3(-hx, hy, hz), Vector3(hx, hy, hz), Vector3(0, 0, 1))
	_add_quad(st_walls, Vector3(-hx, -hy, hz), Vector3(-hx, -hy, -hz), Vector3(-hx, hy, -hz), Vector3(-hx, hy, hz), Vector3(-1, 0, 0))
	_add_quad(st_walls, Vector3(hx, -hy, -hz), Vector3(hx, -hy, hz), Vector3(hx, hy, hz), Vector3(hx, hy, -hz), Vector3(1, 0, 0))
	st_walls.generate_normals()
	mesh = st_walls.commit(mesh)

	var st_roof := SurfaceTool.new()
	st_roof.begin(Mesh.PRIMITIVE_TRIANGLES)
	_add_quad(st_roof, Vector3(-hx, hy, -hz), Vector3(hx, hy, -hz), Vector3(hx, hy, hz), Vector3(-hx, hy, hz), Vector3(0, 1, 0))
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

static func _add_quad_uv(st: SurfaceTool, p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, normal: Vector3, u0: float, u1: float, v0: float, v1: float) -> void:
	st.set_normal(normal)
	st.set_uv(Vector2(u0, v1)); st.add_vertex(p0)
	st.set_uv(Vector2(u1, v1)); st.add_vertex(p1)
	st.set_uv(Vector2(u1, v0)); st.add_vertex(p2)

	st.set_normal(normal)
	st.set_uv(Vector2(u0, v1)); st.add_vertex(p0)
	st.set_uv(Vector2(u1, v0)); st.add_vertex(p2)
	st.set_uv(Vector2(0, 0)); st.add_vertex(p3)

static func create_ground_node(data: MapData) -> Node3D:
	if data.road_cells.is_empty() and data.open_cells.is_empty():
		return null

	var root := Node3D.new()
	root.name = "Ground_3D"
	var cs := data.grid_cell_size

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
			mat_road.uv1_triplanar_world_triplanar = true

			var norm_path := "res://textures/ceuta_pavement_tile_normal.png"
			if ResourceLoader.exists(norm_path):
				mat_road.normal_enabled = true
				mat_road.normal_texture = load(norm_path) as Texture2D
				mat_road.normal_scale = 1.0
		else:
			mat_road.albedo_color = Color(0.35, 0.35, 0.38)
		mi_road.material_override = mat_road
		root.add_child(mi_road)

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
		mat_park.albedo_color = Color(0.18, 0.42, 0.22)
		mi_parks.material_override = mat_park
		root.add_child(mi_parks)

	return root
