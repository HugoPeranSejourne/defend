class_name MapEditor
extends Node3D

const TEST_STAGE_SCENE := "res://map_editor/test_stage.tscn"
const MAIN_MENU_SCENE := "res://scenes/main_menu.tscn"
const GRID_CELL := 2.0
const GRID_DIM := Vector2i(64, 64)

var map_data := MapData.new()
var catalog: BlockCatalog
var unit_catalog: UnitCatalog
var grid: PlacementGrid
var undo := UndoStack.new()
var state_machine := EditorStateMachine.new()
var camera_rig: EditorCamera
var router: InputRouter
var ui: EditorUI
var ghost: GhostPreview
var selection: EditorSelectionManager
var path_viz: PathVisualizer
var blocks_root: Node3D
var markers_root: Node3D

var current_map_path := ""
var _dirty := false
var _next_id := 1
var _next_unit_id := 1
var _next_path_num := 1
var _block_nodes: Dictionary = {} # id -> Node3D
var _marker_nodes: Dictionary = {} # "spawn_p_0" / "unit_5" / "base" -> Node3D

func _ready() -> void:
	_build_environment()
	blocks_root = Node3D.new()
	blocks_root.name = "PlacedBlocks"
	add_child(blocks_root)
	markers_root = Node3D.new()
	markers_root.name = "GameplayMarkers"
	add_child(markers_root)
	grid = PlacementGrid.new()
	grid.cell_size = GRID_CELL
	grid.dimensions = GRID_DIM
	catalog = BlockCatalog.create_default()
	unit_catalog = UnitCatalog.create_default()
	ghost = GhostPreview.new()
	add_child(ghost)
	selection = EditorSelectionManager.new()
	add_child(selection)
	path_viz = PathVisualizer.new()
	add_child(path_viz)
	camera_rig = EditorCamera.new()
	add_child(camera_rig)
	camera_rig.position = Vector3(0, 0, 20)
	camera_rig.focus_on(Vector3.ZERO)
	router = InputRouter.new()
	add_child(router)
	ui = EditorUI.new()
	add_child(ui)
	ui.setup(catalog.entries, MapIO.scan_textures(), unit_catalog.entries, map_data.enemy_paths)
	router.setup(camera_rig, state_machine, self, ui)

	# Enregistrer les tools
	state_machine.register(&"select", ToolSelect.new(), self)
	state_machine.register(&"place", ToolPlace.new(), self)
	state_machine.register(&"spawn", ToolSpawn.new(), self)
	state_machine.register(&"waypoint", ToolWaypoint.new(), self)
	state_machine.register(&"unit", ToolUnit.new(), self)
	state_machine.register(&"base", ToolBase.new(), self)
	state_machine.activate(&"select")

	_connect_ui()
	undo.changed.connect(func(): ui.set_undo_enabled(undo.can_undo(), undo.can_redo()))
	_update_title()

	# Heartbeat
	if catalog.entries.size() != 9:
		push_warning("[MapEditor] Catalogue inattendu : %d entrées" % catalog.entries.size())
	if ui == null or camera_rig.camera == null:
		ui.show_fatal("Sous-système manquant (ui=%s, camera=%s)" % [ui != null, camera_rig.camera != null])
	else:
		ui.set_status("✅ Éditeur v2 M3 prêt — %d blocs, %d unités, %d chemins" % [catalog.entries.size(), unit_catalog.entries.size(), map_data.enemy_paths.size()])
	print("[MapEditor] init OK — tools: %d | catalogue: %d | unités: %d | textures: %d | grille %dx%d" % [
		state_machine.count(), catalog.entries.size(), unit_catalog.entries.size(), ui.texture_count(), GRID_DIM.x, GRID_DIM.y])

# ---------- Connexions UI ----------

func _connect_ui() -> void:
	ui.save_requested.connect(save_map)
	ui.load_requested.connect(load_map)
	ui.test_requested.connect(test_map)
	ui.clear_requested.connect(clear_map)
	ui.main_menu_requested.connect(quit_to_menu)
	ui.quit_confirmed.connect(_do_quit)
	ui.undo_requested.connect(undo.undo)
	ui.redo_requested.connect(undo.redo)
	ui.catalog_selected.connect(_on_catalog_selected)
	ui.texture_selected.connect(_on_texture_selected)
	ui.context_duplicate.connect(duplicate_selected)
	ui.context_delete.connect(delete_selected)
	ui.context_texture.connect(func(): ui.focus_texture_tab())
	ui.map_name_changed.connect(func(t: String): map_data.meta_name = t; _mark_dirty())
	# M3
	ui.spawn_player_requested.connect(func(): state_machine.activate(&"spawn", {"is_player": true}))
	ui.spawn_enemy_requested.connect(func(): state_machine.activate(&"spawn", {"is_player": false}))
	ui.new_path_requested.connect(func(): state_machine.activate(&"waypoint", {}))
	ui.unit_selected.connect(_on_unit_selected)
	ui.base_requested.connect(func(): state_machine.activate(&"base", {}))

func _on_catalog_selected(key: StringName) -> void:
	var entry := catalog.get_entry(key)
	if not entry.is_empty():
		state_machine.activate(&"place", {"entry": entry})

func _on_texture_selected(path: String) -> void:
	if selection.selected_id < 0:
		ui.set_status("⚠ Sélectionnez d'abord un bloc (clic gauche dessus).")
		return
	apply_texture(selection.selected_id, path)

func _on_unit_selected(key: StringName) -> void:
	var entry := unit_catalog.get_entry(key)
	if not entry.is_empty():
		state_machine.activate(&"unit", {"entry": entry})

# ---------- Actions blocs ----------

func place_block(key: StringName, cell: Vector2i, quarter: int) -> void:
	var entry := catalog.get_entry(key)
	if entry.is_empty():
		return
	var fp: Vector2i = entry.footprint
	if quarter % 2 == 1:
		fp = Vector2i(fp.y, fp.x)
	if not grid.can_place(cell, fp):
		ui.set_status("⛔ Emplacement occupé ou hors limites.")
		return
	var block := {
		"id": _next_id, "key": key, "cell": cell, "footprint": fp,
		"pos": grid.cell_to_world(cell, fp), "rot_y": quarter * PI * 0.5,
		"size": Vector3(fp.x * GRID_CELL, entry.size.y, fp.y * GRID_CELL),
		"texture": "", "category": entry.category,
	}
	_next_id += 1
	undo.push(func(): _do_add_block(block), func(): _do_remove_block(block.id), "Placer %s" % entry.label)
	ui.set_status("✅ %s placé (%d blocs)" % [entry.label, map_data.blocks.size()])

func delete_selected() -> void:
	if selection.selected_id < 0:
		return
	var block := get_block(selection.selected_id)
	if block.is_empty():
		return
	var snapshot: Dictionary = block.duplicate(true)
	undo.push(func(): _do_remove_block(snapshot.id), func(): _do_add_block(snapshot), "Supprimer bloc")

func duplicate_selected() -> void:
	var src := get_block(selection.selected_id)
	if src.is_empty():
		return
	var b: Dictionary = src.duplicate(true)
	b.id = _next_id
	_next_id += 1
	for offset in [Vector2i(src.footprint.x, 0), Vector2i(0, src.footprint.y), Vector2i(1, 1)]:
		b.cell = src.cell + offset
		if grid.can_place(b.cell, b.footprint):
			break
	if not grid.can_place(b.cell, b.footprint):
		ui.set_status("⛔ Pas de place pour dupliquer à côté.")
		return
	b.pos = grid.cell_to_world(b.cell, b.footprint)
	undo.push(func(): _do_add_block(b), func(): _do_remove_block(b.id), "Dupliquer bloc")

func commit_move(id: int, start_cell: Vector2i, end_cell: Vector2i) -> void:
	var block := get_block(id)
	if block.is_empty():
		return
	end_cell = grid.clamp_cell(end_cell, block.footprint)
	if end_cell == start_cell:
		preview_block_position(id, start_cell)
		return
	grid.release(id)
	if grid.can_place(end_cell, block.footprint):
		undo.push(func(): _apply_move(block, end_cell), func(): _apply_move(block, start_cell), "Déplacer bloc")
	else:
		grid.occupy(id, start_cell, block.footprint)
		preview_block_position(id, start_cell)
		ui.set_status("⛔ Destination occupée.")

func rotate_selected(dir: int) -> void:
	var block := get_block(selection.selected_id)
	if block.is_empty():
		return
	var old_q := posmod(int(round(block.rot_y / (PI * 0.5))), 4)
	var new_q := posmod(old_q + dir, 4)
	var old_fp: Vector2i = block.footprint
	var new_fp := Vector2i(old_fp.y, old_fp.x)
	grid.release(block.id)
	if grid.can_place(block.cell, new_fp):
		undo.push(func(): _apply_rotate(block, new_q, new_fp), func(): _apply_rotate(block, old_q, old_fp), "Pivoter bloc")
	else:
		grid.occupy(block.id, block.cell, old_fp)
		ui.set_status("⛔ Rotation impossible ici (encombrement).")

func resize_selected(delta: int) -> void:
	var block := get_block(selection.selected_id)
	if block.is_empty():
		return
	var old_fp: Vector2i = block.footprint
	var new_fp := Vector2i(clampi(old_fp.x + delta, 1, 8), clampi(old_fp.y + delta, 1, 8))
	if new_fp == old_fp:
		return
	grid.release(block.id)
	if grid.can_place(block.cell, new_fp):
		undo.push(func(): _apply_resize(block, new_fp), func(): _apply_resize(block, old_fp), "Redimensionner bloc")
	else:
		grid.occupy(block.id, block.cell, old_fp)
		ui.set_status("⛔ Pas de place pour agrandir.")

func apply_texture(id: int, path: String) -> void:
	var block := get_block(id)
	if block.is_empty() or block.texture == path:
		return
	var old: String = block.texture
	undo.push(func(): _apply_texture(block, path), func(): _apply_texture(block, old), "Texturer bloc")
	ui.set_status("🎨 Texture appliquée : %s" % (path.get_file() if path != "" else "couleur unie"))

# ---------- M3 : Actions gameplay ----------

func place_spawn(pos: Vector3, is_player: bool) -> void:
	var arr: Array[Vector3] = map_data.player_spawns if is_player else map_data.enemy_spawns
	var idx := arr.size()
	var marker_id := "spawn_p_%d" % idx if is_player else "spawn_e_%d" % idx
	undo.push(
		func():
			arr.append(pos)
			var m := MarkerFactory.create_spawn_marker(pos, is_player)
			markers_root.add_child(m)
			_marker_nodes[marker_id] = m
			_mark_dirty(),
		func():
			arr.remove_at(arr.size() - 1)
			var m := _marker_nodes.get(marker_id) as Node3D
			if m: m.queue_free()
			_marker_nodes.erase(marker_id)
			_mark_dirty(),
		"Placer spawn"
	)
	ui.set_status("✅ Spawn %s placé (%d total)" % ["JOUEUR" if is_player else "ENNEMI", arr.size()])

func place_base(pos: Vector3) -> void:
	var old_has := map_data.has_base
	var old_pos := map_data.base_position
	undo.push(
		func():
			map_data.has_base = true
			map_data.base_position = pos
			var old := _marker_nodes.get("base") as Node3D
			if old: old.queue_free()
			var m := MarkerFactory.create_base_marker(pos)
			markers_root.add_child(m)
			_marker_nodes["base"] = m
			_mark_dirty(),
		func():
			map_data.has_base = old_has
			map_data.base_position = old_pos
			var m := _marker_nodes.get("base") as Node3D
			if m: m.queue_free()
			_marker_nodes.erase("base")
			if old_has:
				var om := MarkerFactory.create_base_marker(old_pos)
				markers_root.add_child(om)
				_marker_nodes["base"] = om
			_mark_dirty(),
		"Placer base"
	)
	ui.set_status("✅ Base placée")

func place_unit(entry: Dictionary, pos: Vector3) -> void:
	var unit := {
		"id": _next_unit_id, "key": entry.key, "pos": pos,
		"path_id": "", "directive": "attack",
	}
	_next_unit_id += 1
	undo.push(
		func():
			map_data.units.append(unit)
			var m := MarkerFactory.create_unit_marker(pos, entry, unit.path_id)
			markers_root.add_child(m)
			_marker_nodes["unit_%d" % unit.id] = m
			_mark_dirty(),
		func():
			for i in map_data.units.size():
				if map_data.units[i].id == unit.id:
					map_data.units.remove_at(i)
					break
			var m := _marker_nodes.get("unit_%d" % unit.id) as Node3D
			if m: m.queue_free()
			_marker_nodes.erase("unit_%d" % unit.id)
			_mark_dirty(),
		"Placer %s" % entry.label
	)
	ui.set_status("✅ %s placé (%d unités)" % [entry.label, map_data.units.size()])

func create_new_path_id() -> String:
	var id := "Chemin %s" % char(65 + _next_path_num - 1) # A, B, C...
	_next_path_num += 1
	return id

func update_path_waypoints(path_id: String, wps: Array[Vector3]) -> void:
	for i in map_data.enemy_paths.size():
		if map_data.enemy_paths[i].id == path_id:
			map_data.enemy_paths[i].waypoints = wps
			path_viz.set_paths(map_data.enemy_paths)
			_mark_dirty()
			return
	# Nouveau chemin
	map_data.enemy_paths.append({"id": path_id, "waypoints": wps})
	path_viz.set_paths(map_data.enemy_paths)
	_mark_dirty()

func remove_path(path_id: String) -> void:
	for i in map_data.enemy_paths.size():
		if map_data.enemy_paths[i].id == path_id:
			map_data.enemy_paths.remove_at(i)
			break
	path_viz.set_paths(map_data.enemy_paths)
	_mark_dirty()

# ---------- Primitives internes blocs ----------

func _do_add_block(block: Dictionary) -> void:
	map_data.blocks.append(block)
	grid.occupy(block.id, block.cell, block.footprint)
	var n := MapRuntime.create_block_node(block, catalog, 2)
	blocks_root.add_child(n)
	_block_nodes[block.id] = n
	_mark_dirty()

func _do_remove_block(id: int) -> void:
	var node := _block_nodes.get(id) as Node3D
	if node:
		node.queue_free()
	_block_nodes.erase(id)
	for i in map_data.blocks.size():
		if map_data.blocks[i].id == id:
			map_data.blocks.remove_at(i)
			break
	grid.release(id)
	if selection.selected_id == id:
		selection.deselect()
	_mark_dirty()

func _apply_move(block: Dictionary, cell: Vector2i) -> void:
	grid.release(block.id)
	grid.occupy(block.id, cell, block.footprint)
	block.cell = cell
	block.pos = grid.cell_to_world(cell, block.footprint)
	var node := _block_nodes.get(block.id) as Node3D
	if node:
		node.position = block.pos
	_mark_dirty()

func _apply_rotate(block: Dictionary, quarter: int, fp: Vector2i) -> void:
	grid.release(block.id)
	grid.occupy(block.id, block.cell, fp)
	block.rot_y = quarter * PI * 0.5
	block.footprint = fp
	block.size = Vector3(fp.x * GRID_CELL, block.size.y, fp.y * GRID_CELL)
	var node := _block_nodes.get(block.id) as Node3D
	if node:
		node.rotation.y = block.rot_y
		node.set_meta("size", block.size)
		if selection.selected_id == block.id:
			selection.select(block.id, node)
	_mark_dirty()

func _apply_resize(block: Dictionary, fp: Vector2i) -> void:
	grid.release(block.id)
	grid.occupy(block.id, block.cell, fp)
	block.footprint = fp
	block.size = Vector3(fp.x * GRID_CELL, block.size.y, fp.y * GRID_CELL)
	block.pos = grid.cell_to_world(block.cell, fp)
	_rebuild_node(block)
	_mark_dirty()

func _apply_texture(block: Dictionary, path: String) -> void:
	block.texture = path
	_rebuild_node(block)
	_mark_dirty()

func _rebuild_node(block: Dictionary) -> void:
	var old := _block_nodes.get(block.id) as Node3D
	if old:
		old.queue_free()
	var n := MapRuntime.create_block_node(block, catalog, 2)
	blocks_root.add_child(n)
	_block_nodes[block.id] = n
	if selection.selected_id == block.id:
		selection.select(block.id, n)

# ---------- Requêtes ----------

func get_block(id: int) -> Dictionary:
	for b in map_data.blocks:
		if b.id == id:
			return b
	return {}

func preview_block_position(id: int, cell: Vector2i) -> void:
	var block := get_block(id)
	if block.is_empty():
		return
	var c := grid.clamp_cell(cell, block.footprint)
	var node := _block_nodes.get(id) as Node3D
	if node:
		node.position = grid.cell_to_world(c, block.footprint)

func screen_to_ground(screen_pos: Vector2) -> Vector3:
	var cam := camera_rig.camera
	var from := cam.project_ray_origin(screen_pos)
	var dir := cam.project_ray_normal(screen_pos)
	var hit: Variant = Plane(Vector3.UP, 0.0).intersects_ray(from, dir)
	return hit if hit != null else Vector3.INF

func pick_block(screen_pos: Vector2) -> Node3D:
	var cam := camera_rig.camera
	var from := cam.project_ray_origin(screen_pos)
	var to := from + cam.project_ray_normal(screen_pos) * 2000.0
	var q := PhysicsRayQueryParameters3D.create(from, to, 2)
	var res := get_world_3d().direct_space_state.intersect_ray(q)
	if res.is_empty():
		return null
	var n: Node = res.collider
	while n != null and not n.has_meta("block_id"):
		n = n.get_parent()
	return n as Node3D

func request_context_menu(screen_pos: Vector2) -> void:
	var node := pick_block(screen_pos)
	if node == null:
		return
	selection.select(int(node.get_meta("block_id")), node)
	ui.open_context_menu(screen_pos)

func focus_selection_or_origin() -> void:
	var block := get_block(selection.selected_id)
	camera_rig.focus_on(block.pos if not block.is_empty() else Vector3.ZERO)

# ---------- Fichier / navigation ----------

func save_map() -> void:
	map_data.meta_name = ui.get_map_name()
	if current_map_path == "":
		var fname := map_data.meta_name.validate_filename()
		if fname == "":
			fname = "carte"
		current_map_path = "%s/%s.json" % [MapIO.MAPS_DIR, fname]
	DirAccess.make_dir_recursive_absolute(MapIO.MAPS_DIR)
	var err := MapIO.save_map(map_data, current_map_path)
	if err == OK:
		_dirty = false
		_update_title()
		ui.set_status("💾 Carte enregistrée : %s" % current_map_path)
		print("[MapEditor] Sauvegarde OK -> %s (%d blocs, %d chemins, %d unités)" % [current_map_path, map_data.blocks.size(), map_data.enemy_paths.size(), map_data.units.size()])
	else:
		ui.show_error("Échec de sauvegarde (code %d)" % err)

func load_map(path: String) -> void:
	var data := MapIO.load_map(path)
	if data == null:
		ui.show_error("Impossible de charger :\n" + path)
		return
	map_data = data
	current_map_path = path
	ui.set_map_name(data.meta_name)
	_rebuild_from_data()
	undo.clear()
	_dirty = false
	_update_title()
	ui.set_status("📂 Carte chargée : %s (%d blocs, %d chemins, %d unités)" % [path.get_file(), data.blocks.size(), data.enemy_paths.size(), data.units.size()])

func test_map() -> void:
	var problems := MapIO.validate(map_data)
	if not problems.is_empty():
		ui.show_error("Carte invalide :\n• " + "\n• ".join(problems))
		return
	save_map()
	if current_map_path == "":
		return
	GameState.pending_map_path = current_map_path
	get_tree().change_scene_to_file(TEST_STAGE_SCENE)

func clear_map() -> void:
	map_data = MapData.new()
	current_map_path = ""
	ui.set_map_name("")
	_rebuild_from_data()
	undo.clear()
	_dirty = false
	_update_title()
	ui.set_status("🗑 Carte effacée.")

func quit_to_menu() -> void:
	if _dirty:
		ui.ask_quit()
	else:
		_do_quit()

func _do_quit() -> void:
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)

func _rebuild_from_data() -> void:
	for c in blocks_root.get_children():
		c.queue_free()
	for c in markers_root.get_children():
		c.queue_free()
	_block_nodes.clear()
	_marker_nodes.clear()
	grid.clear()
	grid.cell_size = map_data.grid_cell_size
	grid.dimensions = map_data.grid_dimensions
	selection.deselect()
	_next_id = 1
	_next_unit_id = 1
	_next_path_num = 1
	for b in map_data.blocks:
		_do_add_block(b)
		_next_id = maxi(_next_id, b.id + 1)
	# M3 — rebuild markers
	for i in map_data.player_spawns.size():
		var m := MarkerFactory.create_spawn_marker(map_data.player_spawns[i], true)
		markers_root.add_child(m)
		_marker_nodes["spawn_p_%d" % i] = m
	for i in map_data.enemy_spawns.size():
		var m := MarkerFactory.create_spawn_marker(map_data.enemy_spawns[i], false)
		markers_root.add_child(m)
		_marker_nodes["spawn_e_%d" % i] = m
	if map_data.has_base:
		var m := MarkerFactory.create_base_marker(map_data.base_position)
		markers_root.add_child(m)
		_marker_nodes["base"] = m
	for u in map_data.units:
		var entry := unit_catalog.get_entry(u.key)
		if not entry.is_empty():
			var m := MarkerFactory.create_unit_marker(u.pos, entry, u.path_id)
			markers_root.add_child(m)
			_marker_nodes["unit_%d" % u.id] = m
			_next_unit_id = maxi(_next_unit_id, u.id + 1)
	# Chemins
	for p in map_data.enemy_paths:
		var num_str: String = String(p.get("id", "")).trim_prefix("Chemin ")
		if num_str.length() == 1:
			var num := num_str.unicode_at(0) - 64 # A=1, B=2...
			_next_path_num = maxi(_next_path_num, num + 1)
	path_viz.set_paths(map_data.enemy_paths)
	_dirty = false

func _mark_dirty() -> void:
	_dirty = true
	_update_title()

func _update_title() -> void:
	get_window().title = "Éditeur de Cartes — %s%s" % [map_data.meta_name, " *" if _dirty else ""]

# ---------- Environnement ----------

func _build_environment() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	var sky := Sky.new()
	sky.sky_material = ProceduralSkyMaterial.new()
	e.background_mode = Environment.BG_SKY
	e.sky = sky
	e.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	e.ambient_light_energy = 0.6
	env.environment = e
	add_child(env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -30, 0)
	sun.shadow_enabled = true
	add_child(sun)

	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(GRID_DIM.x * GRID_CELL, GRID_DIM.y * GRID_CELL)
	ground.mesh = pm
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.16, 0.18, 0.16)
	ground.material_override = gm
	ground.position.y = -0.02
	add_child(ground)

	var lines := MeshInstance3D.new()
	var im := ImmediateMesh.new()
	var lm := StandardMaterial3D.new()
	lm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	lm.albedo_color = Color(0.3, 0.4, 0.5, 0.5)
	lm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	im.surface_begin(Mesh.PRIMITIVE_LINES, lm)
	var half_x := GRID_DIM.x * GRID_CELL * 0.5
	var half_z := GRID_DIM.y * GRID_CELL * 0.5
	for i in range(GRID_DIM.x + 1):
		var x := -half_x + i * GRID_CELL
		im.surface_add_vertex(Vector3(x, 0.01, -half_z))
		im.surface_add_vertex(Vector3(x, 0.01, half_z))
	for i in range(GRID_DIM.y + 1):
		var z := -half_z + i * GRID_CELL
		im.surface_add_vertex(Vector3(-half_x, 0.01, z))
		im.surface_add_vertex(Vector3(half_x, 0.01, z))
	im.surface_end()
	lines.mesh = im
	lines.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(lines)
