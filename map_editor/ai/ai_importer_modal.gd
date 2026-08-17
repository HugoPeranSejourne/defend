class_name AIImporterModal
extends Window

signal map_generated(data: MapData)

var _orch: AIOrchestrator
var _facade_analyzer: Node
var _coords_edit: LineEdit
var _height_spin: SpinBox
var _name_edit: LineEdit
var _gen_btn: Button
var _apply_btn: Button
var _regen_btn: Button
var _progress: ProgressBar
var _status: Label
var _preview_rect: TextureRect
var _stats: Label
var _log_console: TextEdit
var _log_panel: VBoxContainer
var _file_dialog: FileDialog
var _pending_data: MapData = null
var _last_coords := Vector2(35.8893, -5.3213) # Ceuta par défaut

func _ready() -> void:
	title = "🤖 Import IA & Street View — OpenStreetMap"
	size = Vector2i(680, 880)
	transient = true
	exclusive = false
	visible = false
	close_requested.connect(_on_cancel)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 6)
	add_child(vbox)

	# --- Coordonnées ---
	var lbl_coords := Label.new()
	lbl_coords.text = "Coordonnées GPS (ou URL Google Maps collée) :"
	vbox.add_child(lbl_coords)
	var row := HBoxContainer.new()
	vbox.add_child(row)
	_coords_edit = LineEdit.new()
	_coords_edit.text = "35.8893, -5.3213"
	_coords_edit.placeholder_text = "35.8893, -5.3213"
	_coords_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_coords_edit)
	var btn_ceuta := Button.new()
	btn_ceuta.text = "📍 Ceuta"
	btn_ceuta.pressed.connect(func(): _coords_edit.text = "35.8893, -5.3213")
	row.add_child(btn_ceuta)

	# --- Options ---
	var row2 := HBoxContainer.new()
	vbox.add_child(row2)
	var lbl_h := Label.new()
	lbl_h.text = "Hauteur par défaut (si OSM ne précise pas) :"
	row2.add_child(lbl_h)
	_height_spin = SpinBox.new()
	_height_spin.min_value = 3.0
	_height_spin.max_value = 30.0
	_height_spin.step = 1.0
	_height_spin.value = 6.0
	_height_spin.suffix = " m"
	row2.add_child(_height_spin)
	var lbl_n := Label.new()
	lbl_n.text = "   Nom :"
	row2.add_child(lbl_n)
	_name_edit = LineEdit.new()
	_name_edit.text = "Ceuta_Centre"
	_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row2.add_child(_name_edit)

	# --- Bouton Générer ---
	_gen_btn = Button.new()
	_gen_btn.text = "🚀 Générer la Carte 3D depuis OpenStreetMap"
	_gen_btn.pressed.connect(_on_generate)
	vbox.add_child(_gen_btn)

	# --- Section Import Façade Street View (IA Vision) ---
	var street_box := HBoxContainer.new()
	vbox.add_child(street_box)
	var btn_streetview := Button.new()
	btn_streetview.text = "📸 Importer une Photo de Façade Street View (IA)"
	btn_streetview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_streetview.pressed.connect(_on_pick_streetview_photo)
	street_box.add_child(btn_streetview)

	# --- Progression ---
	_progress = ProgressBar.new()
	_progress.min_value = 0.0
	_progress.max_value = 1.0
	_progress.value = 0.0
	vbox.add_child(_progress)
	_status = Label.new()
	_status.text = "En attente. Zone couverte : 512×512m (grille 256×256)."
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(_status)

	# --- Console de Logs en Direct ---
	var toggle_log_btn := Button.new()
	toggle_log_btn.text = "📟 Console de Logs en Direct (Temps Réel)"
	toggle_log_btn.pressed.connect(func(): _log_panel.visible = not _log_panel.visible)
	vbox.add_child(toggle_log_btn)

	_log_panel = VBoxContainer.new()
	_log_panel.visible = false # Masqué par défaut pour économiser l'espace
	vbox.add_child(_log_panel)

	_log_console = TextEdit.new()
	_log_console.custom_minimum_size = Vector2(0, 120)
	_log_console.editable = false
	_log_console.selecting_enabled = true
	_log_console.text = "--- Console de Logs Défend Europe IA ---\nPrêt.\n"
	_log_panel.add_child(_log_console)

	# --- Preview ---
	_preview_rect = TextureRect.new()
	_preview_rect.custom_minimum_size = Vector2(512, 220)
	_preview_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_preview_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_preview_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	vbox.add_child(_preview_rect)
	_stats = Label.new()
	_stats.text = ""
	vbox.add_child(_stats)

	# --- Boutons finaux ---
	var row3 := HBoxContainer.new()
	row3.add_theme_constant_override("separation", 12)
	vbox.add_child(row3)
	_apply_btn = Button.new()
	_apply_btn.text = "✅ Appliquer dans l'éditeur"
	_apply_btn.disabled = true
	_apply_btn.pressed.connect(_on_apply)
	row3.add_child(_apply_btn)
	_regen_btn = Button.new()
	_regen_btn.text = "🔄 Régénérer (sans cache)"
	_regen_btn.disabled = true
	_regen_btn.pressed.connect(_on_regenerate)
	row3.add_child(_regen_btn)
	var cancel_btn := Button.new()
	cancel_btn.text = "❌ Fermer"
	cancel_btn.pressed.connect(_on_cancel)
	row3.add_child(cancel_btn)

	# --- Attribution légale ---
	var attr := Label.new()
	attr.text = "Données cartographiques © OpenStreetMap contributors (ODbL)"
	attr.add_theme_font_size_override("font_size", 10)
	attr.modulate = Color(1, 1, 1, 0.6)
	vbox.add_child(attr)

	# --- FileDialog pour l'import Street View ---
	_file_dialog = FileDialog.new()
	_file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_file_dialog.filters = PackedStringArray(["*.png, *.jpg, *.jpeg ; Images de Façades Street View"])
	_file_dialog.title = "Sélectionner une photo de Façade Street View"
	_file_dialog.size = Vector2i(700, 500)
	_file_dialog.file_selected.connect(_on_streetview_photo_selected)
	add_child(_file_dialog)

	# --- Orchestrateur & Analyseur ---
	_orch = AIOrchestrator.new()
	_orch.status_changed.connect(_on_status)
	_orch.preview_ready.connect(_on_preview)
	_orch.generation_failed.connect(_on_fail)
	_orch.log_emitted.connect(_append_log)
	add_child(_orch)

	var FacadeScript := load("res://map_editor/ai/facade_analyzer.gd")
	if FacadeScript:
		_facade_analyzer = FacadeScript.new()
		_facade_analyzer.analysis_succeeded.connect(_on_facade_ok)
		_facade_analyzer.analysis_failed.connect(_on_fail)
		_facade_analyzer.status_message.connect(func(msg): _append_log(msg))
		add_child(_facade_analyzer)

func _on_pick_streetview_photo() -> void:
	_file_dialog.popup_centered()

func _on_streetview_photo_selected(path: String) -> void:
	_append_log("📸 Analyse de la photo Street View sélectionnée : " + path)
	var out_name := "facade_streetview_%d" % Time.get_ticks_msec()
	_facade_analyzer.analyze_image_file(path, out_name)

signal iconic_building_created(entry: Dictionary)

func _on_facade_ok(tex_path: String, metadata: Dictionary) -> void:
	var real_name: String = metadata.get("real_name", "Bâtiment Emblématique")
	var key: StringName = metadata.get("key", &"iconic_custom")
	_append_log("✅ Bâtiment classé par l'IA sous le nom : '%s' (clef: %s)" % [real_name, key])
	_status.text = "🏛️ Bâtiment '%s' classé et ajouté au menu 'Iconic Buildings' !" % real_name

	var entry := {
		"key": key,
		"label": "🏛️ " + real_name,
		"category": &"iconic_buildings",
		"texture": tex_path,
		"size": Vector3(12, 16, 12)
	}

	iconic_building_created.emit(entry)

	if _pending_data != null and not _pending_data.blocks.is_empty():
		for b in _pending_data.blocks:
			b.texture = tex_path
		_append_log("🎨 Texture '%s' appliquée à tous les %d bâtiments !" % [real_name, _pending_data.blocks.size()])

func _append_log(msg: String) -> void:
	var time_str := Time.get_time_string_from_system()
	_log_console.text += "[%s] %s\n" % [time_str, msg]
	_log_console.scroll_vertical = _log_console.get_line_count()

func _on_generate() -> void:
	var coords := _parse_coords(_coords_edit.text)
	if coords == Vector2.INF:
		_status.text = "⛔ Coordonnées invalides. Format attendu : 35.8893, -5.3213"
		return
	_last_coords = coords
	_pending_data = null
	_apply_btn.disabled = true
	_regen_btn.disabled = true
	_gen_btn.disabled = true
	_preview_rect.texture = null
	_stats.text = ""
	_append_log("=== Lancement génération pour lat=%.5f, lng=%.5f ===" % [coords.x, coords.y])
	_orch.start(coords.x, coords.y, _height_spin.value, _name_edit.text.strip_edges())

func _on_regenerate() -> void:
	_append_log("Nettoyage du cache disque pour lat=%.5f, lng=%.5f..." % [_last_coords.x, _last_coords.y])
	OSMFetcher.clear_cache(_last_coords.x, _last_coords.y)
	_on_generate()

func _on_apply() -> void:
	if _pending_data != null:
		map_generated.emit(_pending_data)
		hide()

func _on_cancel() -> void:
	_orch.cancel()
	_gen_btn.disabled = false
	hide()

func _on_status(msg: String, progress: float) -> void:
	_status.text = msg
	_progress.value = progress

func _on_fail(reason: String) -> void:
	_status.text = "⛔ " + reason
	_progress.value = 0.0
	_gen_btn.disabled = false
	_append_log("❌ ÉCHEC : " + reason)

func _on_preview(preview: Dictionary) -> void:
	_pending_data = preview.data
	_gen_btn.disabled = false
	_apply_btn.disabled = false
	_regen_btn.disabled = false
	var data: MapData = preview.data
	_stats.text = "%d blocs • %d cellules-route • %d chemins • %d spawns E • base : %s" % [
		data.blocks.size(), preview.road_cells.size(), data.enemy_paths.size(),
		data.enemy_spawns.size(), "oui" if data.has_base else "non"]
	_render_preview(preview)

func _render_preview(preview: Dictionary) -> void:
	var img := Image.create(256, 256, false, Image.FORMAT_RGB8)
	img.fill(Color(0.10, 0.10, 0.12))
	for c in preview.open_cells:
		_plot_cell(img, c, Color(0.20, 0.45, 0.25))
	for c in preview.road_cells:
		_plot_cell(img, c, Color(0.42, 0.42, 0.45))
	for b in preview.blocks:
		var t: float = clampf(b.height / 30.0, 0.0, 1.0)
		var col := Color(0.55, 0.25, 0.20).lerp(Color(0.95, 0.60, 0.25), t)
		for x in range(b.cell.x, b.cell.x + b.footprint.x):
			for y in range(b.cell.y, b.cell.y + b.footprint.y):
				_plot_cell(img, Vector2i(x, y), col)
	var data: MapData = preview.data
	for p in data.enemy_paths:
		var wps: Array = p.waypoints
		for i in range(wps.size() - 1):
			_draw_line_world(img, wps[i], wps[i + 1], Color(1.0, 0.9, 0.2))
	if data.has_base:
		_plot_world(img, data.base_position, Color(0.3, 0.5, 1.0), 3)
	for sp in data.enemy_spawns:
		_plot_world(img, sp, Color(1.0, 0.2, 0.2), 2)
	for sp in data.player_spawns:
		_plot_world(img, sp, Color(0.2, 1.0, 0.3), 2)
	_preview_rect.texture = ImageTexture.create_from_image(img)

func _plot_cell(img: Image, c: Vector2i, col: Color) -> void:
	var px := c.x + 128
	var py := c.y + 128
	if px >= 0 and px < 256 and py >= 0 and py < 256:
		img.set_pixel(px, py, col)

func _plot_world(img: Image, w: Vector3, col: Color, radius: int) -> void:
	var cx := floori(w.x / 2.0) + 128
	var cy := floori(w.z / 2.0) + 128
	for dx in range(-radius, radius + 1):
		for dy in range(-radius, radius + 1):
			_plot_cell(img, Vector2i(cx - 128 + dx, cy - 128 + dy), col)

func _draw_line_world(img: Image, a: Vector3, b: Vector3, col: Color) -> void:
	var pa := Vector2(a.x / 2.0 + 128.0, a.z / 2.0 + 128.0)
	var pb := Vector2(b.x / 2.0 + 128.0, b.z / 2.0 + 128.0)
	var steps := maxi(1, int(pa.distance_to(pb)))
	for i in range(steps + 1):
		var p := pa.lerp(pb, float(i) / float(steps))
		var px := int(p.x)
		var py := int(p.y)
		if px >= 0 and px < 256 and py >= 0 and py < 256:
			img.set_pixel(px, py, col)

func _parse_coords(text: String) -> Vector2:
	text = text.strip_edges()
	if text.contains("@"):
		var after := text.get_slice("@", 1)
		var parts := after.split(",")
		if parts.size() >= 2 and parts[0].is_valid_float() and parts[1].is_valid_float():
			return Vector2(parts[0].to_float(), parts[1].to_float())
		return Vector2.INF
	var parts2 := text.split(",")
	if parts2.size() == 2 and parts2[0].strip_edges().is_valid_float() and parts2[1].strip_edges().is_valid_float():
		return Vector2(parts2[0].strip_edges().to_float(), parts2[1].strip_edges().to_float())
	return Vector2.INF
