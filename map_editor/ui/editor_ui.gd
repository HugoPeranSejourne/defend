class_name EditorUI
extends CanvasLayer

signal save_requested
signal load_requested(path: String)
signal test_requested
signal clear_requested
signal main_menu_requested
signal quit_confirmed
signal undo_requested
signal redo_requested
signal catalog_selected(key: StringName)
signal texture_selected(path: String)
signal context_duplicate
signal context_delete
signal context_texture
signal map_name_changed(new_name: String)

var _status_label: Label
var _coords_label: Label
var _name_edit: LineEdit
var _tabs: TabContainer
var _tab_buildings: GridContainer
var _tab_shapes: GridContainer
var _tab_textures: GridContainer
var _tab_units: GridContainer
var _load_popup: PopupMenu
var _map_paths: PackedStringArray = []
var _context_popup: PopupMenu
var _confirm_clear: ConfirmationDialog
var _confirm_quit: ConfirmationDialog
var _error_dialog: AcceptDialog
var _fatal: PanelContainer
var _undo_btn: Button
var _redo_btn: Button
var _tex_count := 0

func _ready() -> void:
	layer = 10
	_build_chrome()
	_build_popups()

func setup(entries: Array[Dictionary], textures: PackedStringArray) -> void:
	_tab_buildings = _mk_tab("🏢 Bâtiments")
	_tab_shapes = _mk_tab("📐 Formes 3D")
	_tab_textures = _mk_tab("🎨 Textures")
	_tab_units = _mk_tab("👥 Unités")
	for e in entries:
		var btn := Button.new()
		btn.text = e.label
		btn.tooltip_text = "Taille : %s m" % str(e.size)
		var key: StringName = e.key
		btn.pressed.connect(func(): catalog_selected.emit(key))
		if e.category == &"building":
			_tab_buildings.add_child(btn)
		else:
			_tab_shapes.add_child(btn)
	var none := Button.new()
	none.text = "Couleur unie (défaut)"
	none.pressed.connect(func(): texture_selected.emit(""))
	_tab_textures.add_child(none)
	for t in textures:
		var b := Button.new()
		b.text = t.get_file().get_basename()
		var path := t
		b.pressed.connect(func(): texture_selected.emit(path))
		_tab_textures.add_child(b)
	_tex_count = textures.size()
	var l := Label.new()
	l.text = "🚧 Disponible au milestone M3\n(spawns, chemins ennemis, directives)"
	l.autowrap_mode = TextServer.AUTOWRAP_WORD
	_tab_units.add_child(l)

func texture_count() -> int:
	return _tex_count

# ---------- Construction ----------

func _build_chrome() -> void:
	var root := Control.new()
	root.name = "Root"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE # LE plein écran qui ne bloque rien
	add_child(root)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(vbox)

	# --- TopBar ---
	var top := PanelContainer.new()
	top.name = "TopBar"
	vbox.add_child(top)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 8)
	top.add_child(hb)

	_name_edit = LineEdit.new()
	_name_edit.placeholder_text = "Nom de la carte"
	_name_edit.custom_minimum_size.x = 180
	_name_edit.text_changed.connect(func(t: String): map_name_changed.emit(t))
	hb.add_child(_name_edit)
	hb.add_child(_mk_button("💾 Enregistrer", func(): save_requested.emit(), "Ctrl+S"))
	hb.add_child(_mk_button("📂 Charger", _open_load_popup, ""))
	hb.add_child(_mk_button("▶ Tester", func(): test_requested.emit(), "Sauvegarde puis lance la partie"))
	hb.add_child(_mk_button("🗑 Effacer", func(): _confirm_clear.popup_centered(), ""))
	_undo_btn = _mk_button("↶", func(): undo_requested.emit(), "Annuler (Ctrl+Z)")
	_redo_btn = _mk_button("↷", func(): redo_requested.emit(), "Rétablir (Ctrl+Maj+Z)")
	_undo_btn.disabled = true
	_redo_btn.disabled = true
	hb.add_child(_undo_btn)
	hb.add_child(_redo_btn)
	hb.add_child(_mk_button("🏠 Menu", func(): main_menu_requested.emit(), ""))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(spacer)
	_coords_label = Label.new()
	_coords_label.text = "X: —  Z: —"
	hb.add_child(_coords_label)

	# --- Milieu : sidebar + espace 3D ---
	var middle := HBoxContainer.new()
	middle.size_flags_vertical = Control.SIZE_EXPAND_FILL
	middle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(middle)

	var sidebar := PanelContainer.new()
	sidebar.name = "LeftSidebar"
	sidebar.custom_minimum_size.x = 280
	sidebar.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	middle.add_child(sidebar)

	_tabs = TabContainer.new()
	_tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sidebar.add_child(_tabs)

	var spacer2 := Control.new()
	spacer2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer2.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer2.mouse_filter = Control.MOUSE_FILTER_IGNORE
	middle.add_child(spacer2)

	# --- StatusBar ---
	var status := PanelContainer.new()
	status.name = "StatusBar"
	vbox.add_child(status)
	_status_label = Label.new()
	_status_label.text = "Initialisation…"
	status.add_child(_status_label)

	# --- Écran d'erreur fatale ---
	_fatal = PanelContainer.new()
	_fatal.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fatal.visible = false
	var fl := Label.new()
	fl.name = "Label"
	fl.add_theme_color_override("font_color", Color.RED)
	fl.autowrap_mode = TextServer.AUTOWRAP_WORD
	_fatal.add_child(fl)
	add_child(_fatal)

func _build_popups() -> void:
	_load_popup = PopupMenu.new()
	_load_popup.about_to_popup.connect(_refresh_load_popup)
	_load_popup.id_pressed.connect(_on_load_id)
	add_child(_load_popup)

	_context_popup = PopupMenu.new()
	_context_popup.add_item("📋 Dupliquer (Ctrl+D)", 0)
	_context_popup.add_item("🎨 Texturer…", 1)
	_context_popup.add_item("🗑 Supprimer (Suppr)", 2)
	_context_popup.id_pressed.connect(func(id: int):
		match id:
			0: context_duplicate.emit()
			1: context_texture.emit()
			2: context_delete.emit())
	add_child(_context_popup)

	_confirm_clear = ConfirmationDialog.new()
	_confirm_clear.title = "Effacer la carte"
	_confirm_clear.dialog_text = "Supprimer TOUS les blocs de la carte ?\n(Cette action ne peut pas être annulée.)"
	_confirm_clear.ok_button_text = "Tout effacer"
	_confirm_clear.confirmed.connect(func(): clear_requested.emit())
	add_child(_confirm_clear)

	_confirm_quit = ConfirmationDialog.new()
	_confirm_quit.title = "Modifications non sauvegardées"
	_confirm_quit.dialog_text = "Quitter l'éditeur sans enregistrer ?"
	_confirm_quit.ok_button_text = "Quitter sans sauvegarder"
	_confirm_quit.confirmed.connect(func(): quit_confirmed.emit())
	add_child(_confirm_quit)

	_error_dialog = AcceptDialog.new()
	_error_dialog.title = "Erreur"
	add_child(_error_dialog)

func _mk_tab(title: String) -> GridContainer:
	var scroll := ScrollContainer.new()
	scroll.name = title
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_tabs.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 1
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(grid)
	return grid

func _mk_button(text: String, cb: Callable, tooltip: String) -> Button:
	var b := Button.new()
	b.text = text
	if tooltip != "":
		b.tooltip_text = tooltip
	b.pressed.connect(cb)
	return b

# ---------- API publique ----------

func is_modal_open() -> bool:
	return _confirm_clear.visible or _confirm_quit.visible or _error_dialog.visible \
		or _load_popup.visible or _context_popup.visible or _fatal.visible

func set_status(text: String) -> void:
	_status_label.text = text

func set_coords(world_pos: Vector3) -> void:
	if world_pos == Vector3.INF:
		_coords_label.text = "X: —  Z: —"
	else:
		_coords_label.text = "X: %.1f  Z: %.1f" % [world_pos.x, world_pos.z]

func get_map_name() -> String:
	return _name_edit.text.strip_edges()

func set_map_name(n: String) -> void:
	_name_edit.text = n

func set_undo_enabled(can_u: bool, can_r: bool) -> void:
	_undo_btn.disabled = not can_u
	_redo_btn.disabled = not can_r

func show_error(msg: String) -> void:
	_error_dialog.dialog_text = msg
	_error_dialog.popup_centered()

func show_fatal(msg: String) -> void:
	_fatal.visible = true
	(_fatal.get_node("Label") as Label).text = "⛔ ERREUR CRITIQUE ÉDITEUR\n" + msg

func ask_quit() -> void:
	_confirm_quit.popup_centered()

func open_context_menu(screen_pos: Vector2) -> void:
	_context_popup.popup(Rect2i(Vector2i(screen_pos), Vector2i.ZERO))

func focus_texture_tab() -> void:
	_tabs.current_tab = 2

func _open_load_popup() -> void:
	_load_popup.popup(Rect2i(Vector2i(get_viewport().get_mouse_position()), Vector2i.ZERO))

func _refresh_load_popup() -> void:
	_load_popup.clear()
	_map_paths = MapIO.list_maps()
	if _map_paths.is_empty():
		_load_popup.add_item("(aucune carte sauvegardée)", 999)
		_load_popup.set_item_disabled(0, true)
		return
	for i in _map_paths.size():
		_load_popup.add_item(_map_paths[i].get_file().get_basename(), i)

func _on_load_id(id: int) -> void:
	if id >= 0 and id < _map_paths.size():
		load_requested.emit(_map_paths[id])
