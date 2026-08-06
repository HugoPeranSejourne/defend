class_name MapEditor
extends Node3D

const MAIN_STAGE_SCENE := "res://scenes/main_stage.tscn"
const MAIN_MENU_SCENE := "res://scenes/main_menu.tscn"
const GRID_CELL := 2.0
const GRID_DIM := Vector2i(64, 64)

var map_data := MapData.new()
var catalog: BlockCatalog
var grid: PlacementGrid
var undo := UndoStack.new()
var state_machine := EditorStateMachine.new()
var camera_rig: EditorCamera
var router: InputRouter
var ui: EditorUI
var ghost: GhostPreview
var selection: EditorSelectionManager
var blocks_root: Node3D

var current_map_path := ""
var _dirty := false
var _next_id := 1
var _block_nodes: Dictionary = {} # id -> Node3D

func _ready() -> void:
	_build_environment()
	blocks_root = Node3D.new()
	blocks_root.name = "PlacedBlocks"
	add_child(blocks_root)
	
	grid = PlacementGrid.new()
	grid.cell_size = GRID_CELL
	grid.dimensions = GRID_DIM
	
	catalog = BlockCatalog.create_default()
	
	ghost = GhostPreview.new()
	add_child(ghost)
	
	selection = EditorSelectionManager.new()
	add_child(selection)
	
	camera_rig = EditorCamera.new()
	add_child(camera_rig)
	
	router = InputRouter.new()
	add_child(router)
	
	ui = EditorUI.new()
	add_child(ui)
	ui.setup(catalog.entries, MapIO.scan_textures())
	
	router.setup(camera_rig, state_machine, self, ui)
	
	state_machine.register(&"select", ToolSelect.new(), self)
	state_machine.register(&"place", ToolPlace.new(), self)
	state_machine.activate(&"select")
	
	_connect_ui()
	undo.changed.connect(func(): ui.set_undo_enabled(undo.can_undo(), undo.can_redo()))
	_update_title()

	camera_rig.position = Vector3(0, 0, 20)
	camera_rig.focus_on(Vector3.ZERO)

	# Heartbeat : vérification des sous-systèmes
	if ui == null or camera_rig.camera == null:
		ui.show_fatal("Sous-système manquant (ui=%s, camera=%s)" % [ui != null, camera_rig.camera != null])
		DebugLog.log_error("Sous-système manquant")
	else:
		ui.set_status("✅ Éditeur v2 prêt — %d entrées catalogue. Choisissez un élément à gauche." % catalog.entries.size())
		DebugLog.log_msg("[MapEditor] Éditeur prêt")
	print("[MapEditor] init OK — tools: %d | catalogue: %d | textures: %d | grille %dx%d (cellule %.1fm)" % [
		state_machine.count(), catalog.entries.size(), ui.texture_count(), GRID_DIM.x, GRID_DIM.y, GRID_CELL])
	DebugLog.log_msg("[MapEditor] init OK — tools: %d | catalogue: %d" % [state_machine.count(), catalog.entries.size()])

func _build_environment() -> void:
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-45, 35, 0)
	sun.shadow_enabled = true
	add_child(sun)
	
	var env_node := WorldEnvironment.new()
	env_node.name = "WorldEnvironment"
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.12, 0.15, 0.2)
	env.ambient_light_color = Color(0.6, 0.65, 0.7)
	env.ambient_light_sky_contribution = 0.5
	env_node.environment = env
	add_child(env_node)

	# Grille 3D visuelle
	var grid_mesh := ImmediateMesh.new()
	grid_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	var half_x := (GRID_DIM.x * GRID_CELL) * 0.5
	var half_z := (GRID_DIM.y * GRID_CELL) * 0.5
	
	for x in range(-int(half_x), int(half_x) + 1, int(GRID_CELL)):
		grid_mesh.surface_add_vertex(Vector3(x, 0, -half_z))
		grid_mesh.surface_add_vertex(Vector3(x, 0, half_z))
	for z in range(-int(half_z), int(half_z) + 1, int(GRID_CELL)):
		grid_mesh.surface_add_vertex(Vector3(-half_x, 0, z))
		grid_mesh.surface_add_vertex(Vector3(half_x, 0, z))
	grid_mesh.surface_end()
	
	var grid_inst := MeshInstance3D.new()
	grid_inst.mesh = grid_mesh
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.3, 0.4, 0.5, 0.4)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	grid_inst.material_override = mat
	add_child(grid_inst)

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

func _on_catalog_selected(key: StringName) -> void:
	var entry := catalog.get_entry(key)
	if not entry.is_empty():
		state_machine.activate(&"place", {"entry": entry})

func _on_texture_selected(path: String) -> void:
	if selection.selected_id < 0:
		ui.set_status("⚠ Sélectionnez d'abord un bloc (clic gauche dessus).")
		return
	apply_texture(selection.selected_id, path)

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
	selection.deselect()

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

func rotate_selected(steps: int) -> void:
	if selection.selected_id < 0:
		return
	var id := selection.selected_id
	var block := get_block(id)
	if block.is_empty(): return
	var old_rot: float = block.rot_y
	var new_rot := wrapf(old_rot + steps * PI * 0.5, 0.0, TAU)
	undo.push(func(): _do_rotate_block(id, new_rot), func(): _do_rotate_block(id, old_rot), "Pivoter bloc")

func resize_selected(step: int) -> void:
	if selection.selected_id < 0: return
	var id := selection.selected_id
	var block := get_block(id)
	if block.is_empty(): return
	var old_size: Vector3 = block.size
	var new_size := Vector3(maxf(1.0, old_size.x + step), maxf(1.0, old_size.y + step), maxf(1.0, old_size.z + step))
	undo.push(func(): _do_resize_block(id, new_size), func(): _do_resize_block(id, old_size), "Redimensionner bloc")

func apply_texture(id: int, tex_path: String) -> void:
	var block := get_block(id)
	if block.is_empty(): return
	var old_tex: String = block.texture
	undo.push(func(): _do_texture_block(id, tex_path), func(): _do_texture_block(id, old_tex), "Appliquer texture")

func preview_block_position(id: int, cell: Vector2i) -> void:
	if _block_nodes.has(id):
		var node: Node3D = _block_nodes[id]
		var block := get_block(id)
		node.position = grid.cell_to_world(cell, block.footprint)

func commit_move(id: int, from_cell: Vector2i, to_cell: Vector2i) -> void:
	var block := get_block(id)
	if block.is_empty() or from_cell == to_cell:
		return
	grid.release(id)
	if not grid.can_place(to_cell, block.footprint):
		grid.occupy(id, from_cell, block.footprint)
		preview_block_position(id, from_cell)
		ui.set_status("⛔ Emplacement occupé.")
		return
	grid.occupy(id, from_cell, block.footprint)
	undo.push(func(): _do_move_block(id, to_cell), func(): _do_move_block(id, from_cell), "Déplacer bloc")

func get_block(id: int) -> Dictionary:
	for b in map_data.blocks:
		if b.id == id: return b
	return {}

func pick_block(screen_pos: Vector2) -> Node3D:
	var ray_from := camera_rig.camera.project_ray_origin(screen_pos)
	var ray_to := ray_from + camera_rig.camera.project_ray_normal(screen_pos) * 2000.0
	var query := PhysicsRayQueryParameters3D.create(ray_from, ray_to)
	query.collision_mask = 2 # Équivalent layer 2 (Éditeur)
	var res := get_world_3d().direct_space_state.intersect_ray(query)
	if res.has("collider") and res.collider is Node:
		var node: Node = res.collider
		while node != null and not node.has_meta("block_id"):
			node = node.get_parent()
		return node as Node3D
	return null

func screen_to_ground(screen_pos: Vector2) -> Vector3:
	if camera_rig == null or camera_rig.camera == null: return Vector3.INF
	var origin := camera_rig.camera.project_ray_origin(screen_pos)
	var dir := camera_rig.camera.project_ray_normal(screen_pos)
	var plane := Plane(Vector3.UP, 0.0)
	var hit: Variant = plane.intersects_ray(origin, dir)
	if hit != null and hit is Vector3:
		return hit
	return Vector3.INF

func request_context_menu(screen_pos: Vector2) -> void:
	var picked := pick_block(screen_pos)
	if picked != null:
		var id := int(picked.get_meta("block_id"))
		selection.select(id, picked)
		ui.open_context_menu(screen_pos)

func focus_selection_or_origin() -> void:
	if selection.selected_id >= 0 and _block_nodes.has(selection.selected_id):
		camera_rig.focus_on(_block_nodes[selection.selected_id].global_position)
	else:
		camera_rig.focus_on(Vector3.ZERO)

# ---------- Implémentations bas niveau ----------

func _do_add_block(block: Dictionary) -> void:
	map_data.blocks.append(block)
	grid.occupy(block.id, block.cell, block.footprint)
	var node := MapRuntime.create_block_node(block, catalog, 2)
	blocks_root.add_child(node)
	_block_nodes[block.id] = node
	_mark_dirty()

func _do_remove_block(id: int) -> void:
	grid.release(id)
	if _block_nodes.has(id):
		(_block_nodes[id] as Node3D).queue_free()
		_block_nodes.erase(id)
	for i in range(map_data.blocks.size()):
		if map_data.blocks[i].id == id:
			map_data.blocks.remove_at(i)
			break
	_mark_dirty()

func _do_move_block(id: int, cell: Vector2i) -> void:
	var b := get_block(id)
	if b.is_empty(): return
	grid.release(id)
	b.cell = cell
	b.pos = grid.cell_to_world(cell, b.footprint)
	grid.occupy(id, cell, b.footprint)
	if _block_nodes.has(id):
		(_block_nodes[id] as Node3D).position = b.pos
	_mark_dirty()

func _do_rotate_block(id: int, rot_y: float) -> void:
	var b := get_block(id)
	if b.is_empty(): return
	b.rot_y = rot_y
	if _block_nodes.has(id):
		(_block_nodes[id] as Node3D).rotation.y = rot_y
	_mark_dirty()

func _do_resize_block(id: int, size: Vector3) -> void:
	var b := get_block(id)
	if b.is_empty(): return
	b.size = size
	if _block_nodes.has(id):
		_do_remove_block(id)
		_do_add_block(b)
	_mark_dirty()

func _do_texture_block(id: int, tex_path: String) -> void:
	var b := get_block(id)
	if b.is_empty(): return
	b.texture = tex_path
	if _block_nodes.has(id):
		var node: Node3D = _block_nodes[id]
		var mi := node.get_node_or_null("Mesh") as MeshInstance3D
		if mi:
			var mat := StandardMaterial3D.new()
			if tex_path != "" and ResourceLoader.exists(tex_path):
				mat.albedo_texture = load(tex_path) as Texture2D
				mat.albedo_color = Color.WHITE
			else:
				var entry := catalog.get_entry(b.key)
				mat.albedo_color = entry.get("color", Color.WHITE)
			mi.material_override = mat
	_mark_dirty()

func save_map() -> void:
	var name := ui.get_map_name()
	if name == "": name = "Ma_Carte"
	map_data.meta_name = name
	current_map_path = "user://maps/%s.json" % name.validate_filename()
	var err := MapIO.save_map(map_data, current_map_path)
	if err == OK:
		_dirty = false
		_update_title()
		ui.set_status("💾 Enregistrée : " + current_map_path)
	else:
		ui.show_error("Impossible de sauvegarder (%d)" % err)

func load_map(path: String) -> void:
	var loaded := MapIO.load_map(path)
	if loaded == null:
		ui.show_error("Échec du chargement de " + path)
		return
	clear_map()
	map_data = loaded
	current_map_path = path
	ui.set_map_name(map_data.meta_name)
	for b in map_data.blocks:
		grid.occupy(b.id, b.cell, b.footprint)
		var node := MapRuntime.create_block_node(b, catalog, 2)
		blocks_root.add_child(node)
		_block_nodes[b.id] = node
		if b.id >= _next_id:
			_next_id = b.id + 1
	_dirty = false
	_update_title()
	ui.set_status("📂 Carte chargée : " + path)

func test_map() -> void:
	save_map()
	GameState.pending_map_path = current_map_path
	ProjectSettings.set_setting("game/custom_map_path", current_map_path)
	get_tree().change_scene_to_file(MAIN_STAGE_SCENE)

func clear_map() -> void:
	for id in _block_nodes.keys():
		(_block_nodes[id] as Node3D).queue_free()
	_block_nodes.clear()
	grid.clear()
	map_data.blocks.clear()
	undo.clear()
	selection.deselect()
	_next_id = 1
	_dirty = false
	_update_title()
	ui.set_status("🗑 Carte entièrement effacée.")

func quit_to_menu() -> void:
	if _dirty: ui.ask_quit()
	else: _do_quit()

func _do_quit() -> void:
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)

func _mark_dirty() -> void:
	_dirty = true
	_update_title()

func _update_title() -> void:
	var title := map_data.meta_name + (" *" if _dirty else "")
	ui.set_map_name(title)
