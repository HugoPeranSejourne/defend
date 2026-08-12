class_name MapEditor
extends Node3D

const TEST_STAGE_SCENE := "res://map_editor/test_stage.tscn"
const MAIN_MENU_SCENE := "res://scenes/main_menu.tscn"
const GRID_CELL := 2.0
const GRID_DIM := Vector2i(64, 64)
const AUTOSAVE_INTERVAL := 120.0

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
var _block_nodes: Dictionary = {}
var _marker_nodes: Dictionary = {}
var _clipboard: Array[Dictionary] = []
var _autosave_timer := 0.0

# M4 toggles
var stack_enabled := false
var magnet_enabled := true

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

	if catalog.entries.size() != 9:
		push_warning("[MapEditor] Catalogue inattendu : %d entrées" % catalog.entries.size())
	if ui == null or camera_rig.camera == null:
		ui.show_fatal("Sous-système manquant (ui=%s, camera=%s)" % [ui != null, camera_rig.camera != null])
	else:
		ui.set_status("✅ Éditeur v2 M4 prêt — %d blocs, %d unités" % [catalog.entries.size(), unit_catalog.entries.size()])
	print("[MapEditor] init OK — tools: %d | catalogue: %d | unités: %d | textures: %d | grille %dx%d" % [
		state_machine.count(), catalog.entries.size(), unit_catalog.entries.size(), ui.texture_count(), GRID_DIM.x, GRID_DIM.y])

func _process(delta: float) -> void:
	_autosave_timer += delta
	if _autosave_timer >= AUTOSAVE_INTERVAL:
		_autosave_timer = 0.0
		_autosave()

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
	ui.texture_import_requested.connect(_on_texture_import)
	ui.context_duplicate.connect(duplicate_selected)
	ui.context_delete.connect(delete_selected)
	ui.context_texture.connect(func(): ui.focus_texture_tab())
	ui.map_name_changed.connect(func(t: String): map_data.meta_name = t; _mark_dirty())
	ui.spawn_player_requested.connect(func(): state_machine.activate(&"spawn", {"is_player": true}))
	ui.spawn_enemy_requested.connect(func(): state_machine.activate(&"spawn", {"is_player": false}))
	ui.new_path_requested.connect(func(): state_machine.activate(&"waypoint", {}))
	ui.unit_selected.connect(_on_unit_selected)
	ui.base_requested.connect(func(): state_machine.activate(&"base", {}))
	ui.stack_toggled.connect(func(on: bool): stack_enabled = on; ui.set_status("📚 Empilement : %s" % ("ON" if on else "OFF")))
	ui.magnet_toggled.connect(func(on: bool): magnet_enabled = on; ui.set_status("🧲 Magnétisme : %s" % ("ON" if on else "OFF")))
	ui.ai_modal.map_generated.connect(_on_ai_map_generated)

func _on_ai_map_generated(data: MapData) -> void:
	if _dirty:
		save_map()
	map_data = data
	current_map_path = ""
	ui.set_map_name(data.meta_name)
	_rebuild_from_data()
	undo.clear()
	_mark_dirty()
	ui.set_status("🤖 Carte IA chargée : %d blocs, %d chemins — vérifiez puis 💾 Enregistrer" % [data.blocks.size(), data.enemy_paths.size()])

func _on_catalog_selected(key: StringName) -> void:
	var entry := catalog.get_entry(key)
	if not entry.is_empty():
		state_machine.activate(&"place", {"entry": entry})

func _on_texture_selected(path: String) -> void:
	if selection.count() == 0:
		ui.set_status("⚠ Sélectionnez d'abord un bloc.")
		return
	for id in selection.selected_ids:
		apply_texture(id, path)

func _on_texture_import(source_path: String) -> void:
	var dest_dir := MapIO.TEXTURES_DIR
	DirAccess.make_dir_recursive_absolute(dest_dir)
	var fname := source_path.get_file()
	var dest := dest_dir + "/" + fname
	var err := DirAccess.copy_absolute(source_path, dest)
	if err == OK:
		ui.set_status("📥 Texture importée : %s — rechargement…" % fname)
		ui.setup(catalog.entries, MapIO.scan_textures(), unit_catalog.entries, map_data.enemy_paths)
	else:
		ui.show_error("Échec import texture (code %d)" % err)

func _on_unit_selected(key: StringName) -> void:
	var entry := unit_catalog.get_entry(key)
	if not entry.is_empty():
		state_machine.activate(&"unit", {"entry": entry})

# ---------- M1/M2/M4 blocs ----------

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
		"texture": "", "category": entry.category, "base_y": 0.0,
	}
	_next_id += 1
	undo.push(func(): _do_add_block(block), func(): _do_remove_block(block.id), "Placer %s" % entry.label)
	ui.set_status("✅ %s placé (%d blocs)" % [entry.label, map_data.blocks.size()])

func place_block_stacked(key: StringName, cell: Vector2i, quarter: int, base_y: float) -> void:
	var entry := catalog.get_entry(key)
	if entry.is_empty():
		return
	var fp: Vector2i = entry.footprint
	if quarter % 2 == 1:
		fp = Vector2i(fp.y, fp.x)
	var h: float = entry.size.y
	if not grid.can_place_at(cell, fp, base_y, h):
		ui.set_status("⛔ Emplacement occupé à ce niveau.")
		return
	var pos := grid.cell_to_world(cell, fp)
	pos.y = base_y
	var block := {
		"id": _next_id, "key": key, "cell": cell, "footprint": fp,
		"pos": pos, "rot_y": quarter * PI * 0.5,
		"size": Vector3(fp.x * GRID_CELL, h, fp.y * GRID_CELL),
		"texture": "", "category": entry.category, "base_y": base_y,
	}
	_next_id += 1
	undo.push(func(): _do_add_block(block), func(): _do_remove_block(block.id), "Placer %s (niv %.1f)" % [entry.label, base_y])
	ui.set_status("✅ %s placé au niveau %.1fm (%d blocs)" % [entry.label, base_y, map_data.blocks.size()])

func delete_selected() -> void:
	var marker := selection.get_marker()
	if not marker.is_empty():
		_delete_marker(marker.get("kind", ""))
		selection.deselect()
		return
	if selection.count() == 0:
		return
	var snapshots: Array[Dictionary] = []
	for id in selection.selected_ids:
		var b := get_block(id)
		if not b.is_empty():
			snapshots.append(b.duplicate(true))
	selection.deselect()
	undo.push(
		func(): for s in snapshots: _do_remove_block(s.id),
		func(): for s in snapshots: _do_add_block(s),
		"Supprimer %d bloc(s)" % snapshots.size()
	)

func duplicate_selected() -> void:
	if selection.count() == 0:
		return
	var new_blocks: Array[Dictionary] = []
	for id in selection.selected_ids:
		var src := get_block(id)
		if src.is_empty():
			continue
		var b: Dictionary = src.duplicate(true)
		b.id = _next_id
		_next_id += 1
		var placed := false
		var fp: Vector2i = b.get("footprint", Vector2i.ONE)
		var base_y: float = b.get("base_y", 0.0)
		var size: Vector3 = b.get("size", Vector3(2, 2, 2))
		for offset in [Vector2i(fp.x, 0), Vector2i(0, fp.y), Vector2i(1, 1)]:
			b.cell = (src.cell as Vector2i) + offset
			var ok := grid.can_place_at(b.cell, fp, base_y, size.y) if stack_enabled else grid.can_place(b.cell, fp)
			if ok:
				placed = true
				break
		if not placed:
			ui.set_status("⛔ Pas de place pour dupliquer.")
			continue
		b.pos = grid.cell_to_world(b.cell, fp)
		b.pos.y = base_y
		new_blocks.append(b)
	if new_blocks.is_empty():
		return
	selection.deselect()
	undo.push(
		func():
			for b in new_blocks:
				_do_add_block(b)
				selection.add(b.id, _block_nodes[b.id]),
		func(): for b in new_blocks: _do_remove_block(b.id),
		"Dupliquer %d bloc(s)" % new_blocks.size()
	)

func copy_selected() -> void:
	_clipboard.clear()
	for id in selection.selected_ids:
		var b := get_block(id)
		if not b.is_empty():
			_clipboard.append(b.duplicate(true))
	if not _clipboard.is_empty():
		ui.set_status("📋 %d bloc(s) copié(s)" % _clipboard.size())

func paste_clipboard() -> void:
	if _clipboard.is_empty():
		return
	var new_blocks: Array[Dictionary] = []
	for src in _clipboard:
		var b: Dictionary = src.duplicate(true)
		b.id = _next_id
		_next_id += 1
		var fp: Vector2i = b.get("footprint", Vector2i.ONE)
		var base_y: float = b.get("base_y", 0.0)
		var size: Vector3 = b.get("size", Vector3(2, 2, 2))
		b.cell = (src.cell as Vector2i) + Vector2i(2, 2)
		var ok := grid.can_place_at(b.cell, fp, base_y, size.y) if stack_enabled else grid.can_place(b.cell, fp)
		if not ok:
			continue
		b.pos = grid.cell_to_world(b.cell, fp)
		b.pos.y = base_y
		new_blocks.append(b)
	if new_blocks.is_empty():
		ui.set_status("⛔ Pas de place pour coller.")
		return
	selection.deselect()
	undo.push(
		func():
			for b in new_blocks:
				_do_add_block(b)
				selection.add(b.id, _block_nodes[b.id]),
		func(): for b in new_blocks: _do_remove_block(b.id),
		"Coller %d bloc(s)" % new_blocks.size()
	)

func commit_move(id: int, start_cell: Vector2i, end_cell: Vector2i) -> void:
	var block := get_block(id)
	if block.is_empty():
		return
	var fp: Vector2i = block.get("footprint", Vector2i.ONE)
	end_cell = grid.clamp_cell(end_cell, fp)
	if end_cell == start_cell:
		preview_block_position(id, start_cell)
		return
	grid.release(id)
	if grid.can_place(end_cell, fp):
		undo.push(func(): _apply_move(block, end_cell), func(): _apply_move(block, start_cell), "Déplacer bloc")
	else:
		grid.occupy(id, start_cell, fp)
		preview_block_position(id, start_cell)
		ui.set_status("⛔ Destination occupée.")

func commit_move_stacked(id: int, start_cell: Vector2i, start_y: float, end_cell: Vector2i, end_y: float) -> void:
	var block := get_block(id)
	if block.is_empty():
		return
	var fp: Vector2i = block.get("footprint", Vector2i.ONE)
	var size: Vector3 = block.get("size", Vector3(2, 2, 2))
	end_cell = grid.clamp_cell(end_cell, fp)
	if end_cell == start_cell:
		preview_block_position_stacked(id, start_cell, start_y)
		return
	grid.release(id)
	if grid.can_place_at(end_cell, fp, end_y, size.y):
		undo.push(
			func(): _apply_move_stacked(block, end_cell, end_y),
			func(): _apply_move_stacked(block, start_cell, start_y),
			"Déplacer bloc"
		)
	else:
		grid.occupy_block(id, start_cell, fp, start_y, size.y)
		preview_block_position_stacked(id, start_cell, start_y)
		ui.set_status("⛔ Destination occupée à ce niveau.")

func rotate_selected(dir: int) -> void:
	if selection.count() == 0:
		return
	for id in selection.selected_ids:
		_rotate_block(id, dir)

func _rotate_block(id: int, dir: int) -> void:
	var block := get_block(id)
	if block.is_empty():
		return
	var old_q := posmod(int(round(float(block.get("rot_y", 0.0)) / (PI * 0.5))), 4)
	var new_q := posmod(old_q + dir, 4)
	var old_fp: Vector2i = block.get("footprint", Vector2i.ONE)
	var new_fp := Vector2i(old_fp.y, old_fp.x)
	var base_y: float = block.get("base_y", 0.0)
	var size: Vector3 = block.get("size", Vector3(2, 2, 2))
	grid.release(id)
	var ok := grid.can_place_at(block.cell, new_fp, base_y, size.y) if stack_enabled else grid.can_place(block.cell, new_fp)
	if ok:
		undo.push(func(): _apply_rotate(block, new_q, new_fp), func(): _apply_rotate(block, old_q, old_fp), "Pivoter bloc")
	else:
		if stack_enabled:
			grid.occupy_block(id, block.cell, old_fp, base_y, size.y)
		else:
			grid.occupy(id, block.cell, old_fp)
		ui.set_status("⛔ Rotation impossible (encombrement).")

func resize_selected(delta: int) -> void:
	if selection.count() == 0:
		return
	for id in selection.selected_ids:
		_resize_block(id, delta)

func _resize_block(id: int, delta: int) -> void:
	var block := get_block(id)
	if block.is_empty():
		return
	var old_fp: Vector2i = block.get("footprint", Vector2i.ONE)
	var new_fp := Vector2i(clampi(old_fp.x + delta, 1, 8), clampi(old_fp.y + delta, 1, 8))
	if new_fp == old_fp:
		return
	var base_y: float = block.get("base_y", 0.0)
	var size: Vector3 = block.get("size", Vector3(2, 2, 2))
	grid.release(id)
	var ok := grid.can_place_at(block.cell, new_fp, base_y, size.y) if stack_enabled else grid.can_place(block.cell, new_fp)
	if ok:
		undo.push(func(): _apply_resize(block, new_fp), func(): _apply_resize(block, old_fp), "Redimensionner bloc")
	else:
		if stack_enabled:
			grid.occupy_block(id, block.cell, old_fp, base_y, size.y)
		else:
			grid.occupy(id, block.cell, old_fp)
		ui.set_status("⛔ Impossible de redimensionner ici.")

func apply_texture(id: int, path: String) -> void:
	var block := get_block(id)
	if block.is_empty() or block.get("texture", "") == path:
		return
	var old: String = block.get("texture", "")
	undo.push(func(): _apply_texture(block, path), func(): _apply_texture(block, old), "Texturer bloc")
	ui.set_status("🎨 Texture appliquée : %s" % (path.get_file() if path != "" else "couleur unie"))

# ---------- M3/M4 : Actions gameplay & marqueurs ----------

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
		"Placer %s" % String(entry.get("label", "Unité"))
	)
	ui.set_status("✅ %s placé (%d unités)" % [String(entry.get("label", "Unité")), map_data.units.size()])

func create_new_path_id() -> String:
	var id := "Chemin %s" % char(65 + _next_path_num - 1)
	_next_path_num += 1
	return id

func update_path_waypoints(path_id: String, wps: Array[Vector3]) -> void:
	for i in map_data.enemy_paths.size():
		if map_data.enemy_paths[i].id == path_id:
			map_data.enemy_paths[i].waypoints = wps
			path_viz.set_paths(map_data.enemy_paths)
			_mark_dirty()
			return
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

func _delete_marker(kind: String) -> void:
	if kind.begins_with("spawn_p:"):
		var idx := int(kind.split(":")[1])
		if idx >= 0 and idx < map_data.player_spawns.size():
			map_data.player_spawns.remove_at(idx)
	elif kind.begins_with("spawn_e:"):
		var idx := int(kind.split(":")[1])
		if idx >= 0 and idx < map_data.enemy_spawns.size():
			map_data.enemy_spawns.remove_at(idx)
	elif kind == "base":
		map_data.has_base = false
	elif kind.begins_with("unit:"):
		var uid := int(kind.split(":")[1])
		for i in map_data.units.size():
			if map_data.units[i].id == uid:
				map_data.units.remove_at(i)
				break
	_rebuild_from_data()

func _instantiate_block(block: Dictionary) -> void:
	var bid: int = block.get("id", 0)
	var fp: Vector2i = block.get("footprint", Vector2i.ONE)
	var base_y: float = block.get("base_y", 0.0)
	var size: Vector3 = block.get("size", Vector3(2, 2, 2))
	grid.occupy_block(bid, block.cell, fp, base_y, size.y)
	var n := MapRuntime.create_block_node(block, catalog, 2)
	blocks_root.add_child(n)
	_block_nodes[bid] = n

func _do_add_block(block: Dictionary) -> void:
	map_data.blocks.append(block)
	_instantiate_block(block)
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
	if selection.is_selected(id):
		selection.remove(id)
	_mark_dirty()

func _apply_move(block: Dictionary, cell: Vector2i) -> void:
	var fp: Vector2i = block.get("footprint", Vector2i.ONE)
	var base_y: float = block.get("base_y", 0.0)
	var size: Vector3 = block.get("size", Vector3(2, 2, 2))
	grid.release(block.id)
	grid.occupy_block(block.id, cell, fp, base_y, size.y)
	block.cell = cell
	block.pos = grid.cell_to_world(cell, fp)
	block.pos.y = base_y
	var node := _block_nodes.get(block.id) as Node3D
	if node:
		node.position = block.pos
	_mark_dirty()

func _apply_move_stacked(block: Dictionary, cell: Vector2i, base_y: float) -> void:
	var fp: Vector2i = block.get("footprint", Vector2i.ONE)
	var size: Vector3 = block.get("size", Vector3(2, 2, 2))
	grid.release(block.id)
	grid.occupy_block(block.id, cell, fp, base_y, size.y)
	block.cell = cell
	block.base_y = base_y
	block.pos = grid.cell_to_world(cell, fp)
	block.pos.y = base_y
	var node := _block_nodes.get(block.id) as Node3D
	if node:
		node.position = block.pos
	_mark_dirty()

func _apply_rotate(block: Dictionary, quarter: int, fp: Vector2i) -> void:
	var base_y: float = block.get("base_y", 0.0)
	var size: Vector3 = block.get("size", Vector3(2, 2, 2))
	grid.release(block.id)
	grid.occupy_block(block.id, block.cell, fp, base_y, size.y)
	block.rot_y = quarter * PI * 0.5
	block.footprint = fp
	block.size = Vector3(fp.x * GRID_CELL, block.size.y, fp.y * GRID_CELL)
	var node := _block_nodes.get(block.id) as Node3D
	if node:
		node.rotation.y = block.rot_y
		node.set_meta("size", block.size)
	_mark_dirty()

func _apply_resize(block: Dictionary, fp: Vector2i) -> void:
	var base_y: float = block.get("base_y", 0.0)
	grid.release(block.id)
	block.footprint = fp
	block.size = Vector3(fp.x * GRID_CELL, block.size.y, fp.y * GRID_CELL)
	block.pos = grid.cell_to_world(block.cell, fp)
	block.pos.y = base_y
	grid.occupy_block(block.id, block.cell, fp, base_y, block.size.y)
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
	if selection.is_selected(block.id):
		selection.add(block.id, n)

# ---------- Requêtes M4 ----------

func get_block(id: int) -> Dictionary:
	for b in map_data.blocks:
		if b.get("id", -1) == id:
			return b
	return {}

func preview_block_position(id: int, cell: Vector2i) -> void:
	var block := get_block(id)
	if block.is_empty():
		return
	var fp: Vector2i = block.get("footprint", Vector2i.ONE)
	var c := grid.clamp_cell(cell, fp)
	var node := _block_nodes.get(id) as Node3D
	if node:
		var pos := grid.cell_to_world(c, fp)
		pos.y = block.get("base_y", 0.0)
		node.position = pos

func preview_block_position_stacked(id: int, cell: Vector2i, base_y: float) -> void:
	var block := get_block(id)
	if block.is_empty():
		return
	var fp: Vector2i = block.get("footprint", Vector2i.ONE)
	var c := grid.clamp_cell(cell, fp)
	var node := _block_nodes.get(id) as Node3D
	if node:
		var pos := grid.cell_to_world(c, fp)
		pos.y = base_y
		node.position = pos

func screen_to_ground(screen_pos: Vector2) -> Vector3:
	var cam := camera_rig.camera
	var from := cam.project_ray_origin(screen_pos)
	var dir := cam.project_ray_normal(screen_pos)
	var hit: Variant = Plane(Vector3.UP, 0.0).intersects_ray(from, dir)
	return hit if hit != null else Vector3.INF

func pick_any(screen_pos: Vector2) -> Node3D:
	var cam := camera_rig.camera
	var from := cam.project_ray_origin(screen_pos)
	var to := from + cam.project_ray_normal(screen_pos) * 2000.0
	# Raycast masque 2 (blocs) + 4 (unités) + 8 (spawns) + 16 (base)
	var q := PhysicsRayQueryParameters3D.create(from, to, 2 | 4 | 8 | 16)
	var res := get_world_3d().direct_space_state.intersect_ray(q)
	if res.is_empty():
		return null
	var n: Node = res.collider
	while n != null:
		if n.has_meta("block_id") or n.has_meta("is_spawn") or n.has_meta("is_unit") or n.has_meta("is_base"):
			return n as Node3D
		n = n.get_parent()
	return null

func identify_node(node: Node3D) -> String:
	if node.has_meta("block_id"):
		return "block:%d" % int(node.get_meta("block_id"))
	if node.has_meta("is_spawn"):
		var is_p: bool = node.get_meta("is_player_spawn", true)
		# Retrouver l'index dans les tableaux de spawns
		var arr: Array[Vector3] = map_data.player_spawns if is_p else map_data.enemy_spawns
		for i in arr.size():
			if arr[i].distance_to(node.global_position) < 0.5:
				return "spawn_p:%d" % i if is_p else "spawn_e:%d" % i
		return "spawn_p:0" if is_p else "spawn_e:0"
	if node.has_meta("is_base"):
		return "base"
	if node.has_meta("is_unit"):
		for u in map_data.units:
			if (u.get("pos", Vector3.ZERO) as Vector3).distance_to(node.global_position) < 0.5:
				return "unit:%d" % int(u.get("id", 0))
	return ""

func select_blocks_in_rect(screen_rect: Rect2, additive: bool) -> void:
	if not additive:
		selection.deselect()
	var cam := camera_rig.camera
	for id in _block_nodes:
		var node := _block_nodes[id] as Node3D
		if node != null and is_instance_valid(node):
			if not cam.is_position_behind(node.global_position):
				var sp := cam.unproject_position(node.global_position)
				if screen_rect.has_point(sp):
					selection.add(id, node)

func request_context_menu(screen_pos: Vector2) -> void:
	var node := pick_any(screen_pos)
	if node == null:
		return
	var kind := identify_node(node)
	if kind.begins_with("block:"):
		var id := int(kind.split(":")[1])
		selection.select_single(id, node)
		ui.open_context_menu(screen_pos)

func focus_selection_or_origin() -> void:
	if selection.count() > 0:
		var id := selection.first_id()
		var block := get_block(id)
		if not block.is_empty():
			camera_rig.focus_on(block.get("pos", Vector3.ZERO))
			return
	selection.deselect()
	camera_rig.focus_on(Vector3.ZERO)

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

func _autosave() -> void:
	if not _dirty:
		return
	var path := "user://maps/_autosave.json"
	DirAccess.make_dir_recursive_absolute(MapIO.MAPS_DIR)
	MapIO.save_map(map_data, path)
	ui.set_status("💾 Sauvegarde automatique effectuée (%s)" % Time.get_time_string_from_system())

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
	var old_ground := get_node_or_null("Ground_3D")
	if old_ground:
		old_ground.name = "Ground_3D_Deleting"
		old_ground.queue_free()

	_block_nodes.clear()
	_marker_nodes.clear()
	grid.clear()
	grid.cell_size = map_data.grid_cell_size
	grid.dimensions = map_data.grid_dimensions

	var ground := MapRuntime.create_ground_node(map_data)
	if ground:
		add_child(ground)

	selection.deselect()
	_next_id = 1
	_next_unit_id = 1
	_next_path_num = 1
	for b in map_data.blocks:
		_instantiate_block(b)
		_next_id = maxi(_next_id, int(b.get("id", 0)) + 1)
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
			_next_unit_id = maxi(_next_unit_id, int(u.get("id", 0)) + 1)
	for p in map_data.enemy_paths:
		var num_str: String = String(p.get("id", "")).trim_prefix("Chemin ")
		if num_str.length() == 1:
			var num := num_str.unicode_at(0) - 64
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
	var psky := ProceduralSkyMaterial.new()
	psky.sky_top_color = Color(0.35, 0.55, 0.85)
	psky.sky_horizon_color = Color(0.70, 0.78, 0.88)
	psky.ground_bottom_color = Color(0.2, 0.2, 0.22)
	sky.sky_material = psky
	e.background_mode = Environment.BG_SKY
	e.sky = sky

	# Éclairage Ambiant AAA + Tonemapping ACES + SSAO (Ombrage de contact 3D réel)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	e.ambient_light_energy = 0.7
	e.tonemap_mode = Environment.TONE_MAPPER_ACES
	e.tonemap_exposure = 1.0

	# Activations Graphiques AAA Godot 4
	e.ssao_enabled = true
	e.ssao_radius = 1.8
	e.ssao_intensity = 2.5
	e.glow_enabled = true
	e.glow_intensity = 0.4
	e.glow_bloom = 0.1

	env.environment = e
	add_child(env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42, -35, 0)
	sun.light_color = Color(1.0, 0.95, 0.88)
	sun.light_energy = 1.3
	sun.shadow_enabled = true
	sun.shadow_blur = 1.5
	sun.directional_shadow_max_distance = 600.0
	add_child(sun)

	var dims: Vector2i = map_data.grid_dimensions if map_data else GRID_DIM
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(dims.x * GRID_CELL, dims.y * GRID_CELL)
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
	var half_x := dims.x * GRID_CELL * 0.5
	var half_z := dims.y * GRID_CELL * 0.5
	for i in range(dims.x + 1):
		var x := -half_x + i * GRID_CELL
		im.surface_add_vertex(Vector3(x, 0.01, -half_z))
		im.surface_add_vertex(Vector3(x, 0.01, half_z))
	for i in range(dims.y + 1):
		var z := -half_z + i * GRID_CELL
		im.surface_add_vertex(Vector3(-half_x, 0.01, z))
		im.surface_add_vertex(Vector3(half_x, 0.01, z))
	im.surface_end()
	lines.mesh = im
	lines.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(lines)
