extends Node3D

@export var grid_step: float = 2.0

# Références UI principales
@onready var map_name_input: LineEdit = $UI/TopBar/HBox/MapNameInput
@onready var category_option: OptionButton = $UI/TopBar/HBox/CategoryOption
@onready var save_btn: Button = $UI/TopBar/HBox/SaveButton
@onready var test_map_btn: Button = $UI/TopBar/HBox/TestMapButton
@onready var clear_btn: Button = $UI/TopBar/HBox/ClearButton
@onready var main_menu_btn: Button = $UI/TopBar/HBox/MainMenuButton

@onready var tab_container: TabContainer = $UI/LeftSidebar/TabContainer
@onready var status_label: Label = $UI/BottomBar/StatusLabel
@onready var file_dialog: FileDialog = $UI/TextureFileDialog

# UI Réglages de Forme 3D Primitive
@onready var size_x_spin: SpinBox = $UI/LeftSidebar/TabContainer/Formes3D/VBox/SizeX/SpinBox
@onready var size_y_spin: SpinBox = $UI/LeftSidebar/TabContainer/Formes3D/VBox/SizeY/SpinBox
@onready var size_z_spin: SpinBox = $UI/LeftSidebar/TabContainer/Formes3D/VBox/SizeZ/SpinBox

# UI Peintre de Textures & Couleur
@onready var import_tex_btn: Button = $UI/LeftSidebar/TabContainer/Textures/VBox/ImportTexBtn
@onready var texture_option: OptionButton = $UI/LeftSidebar/TabContainer/Textures/VBox/TextureOption
@onready var uv_scale_spin: SpinBox = $UI/LeftSidebar/TabContainer/Textures/VBox/UVScale/SpinBox
@onready var color_picker_btn: ColorPickerButton = $UI/LeftSidebar/TabContainer/Textures/VBox/ColorContainer/ColorPickerButton

# Modal Directives Tactiques d'Unité
@onready var directive_modal: PanelContainer = $UI/CenterContainer/DirectiveModal
@onready var directive_option: OptionButton = $UI/CenterContainer/DirectiveModal/VBox/DirectiveOption
@onready var add_waypoint_btn: Button = $UI/CenterContainer/DirectiveModal/VBox/AddWaypointBtn
@onready var clear_waypoints_btn: Button = $UI/CenterContainer/DirectiveModal/VBox/ClearWaypointsBtn
@onready var close_directive_btn: Button = $UI/CenterContainer/DirectiveModal/VBox/CloseDirectiveBtn

# Containers de données
@onready var placed_blocks_container: Node3D = $PlacedBlocks
@onready var waypoints_container: Node3D = $WaypointsContainer

# Mode d'édition
enum EditMode { PLACE_PREFAB, PLACE_PRIMITIVE, PLACE_UNIT, ADD_WAYPOINT }
var _current_edit_mode: EditMode = EditMode.PLACE_PREFAB
var _selected_prefab_key: String = "bldg_a"
var _selected_primitive_type: String = "box" # box, cylinder, sphere, prism
var _selected_unit_type: String = "unit_ally"

# Informations de la texture sélectionnée
var _active_texture_path: String = "res://textures/ceuta_pavement_tile.png"

# Unité sélectionnée pour directives
var _active_edited_unit: Node3D = null
var _is_adding_waypoints: bool = false

# Prefabs disponibles
const PREFAB_CATALOG: Dictionary = {
	"bldg_a": {"name": "Immeuble Néoclassique", "scene": "res://scenes/ceuta_building_a.tscn", "cat": "bâtiments"},
	"bldg_b": {"name": "Immeuble Terracotta", "scene": "res://scenes/ceuta_building_b.tscn", "cat": "bâtiments"},
	"bldg_c": {"name": "Immeuble Bleu Haussmann", "scene": "res://scenes/ceuta_building_c.tscn", "cat": "bâtiments"},
	"bldg_d": {"name": "Bâtiment Commercial", "scene": "res://scenes/ceuta_building_d.tscn", "cat": "bâtiments"},
	"dragons": {"name": "Casa de los Dragones", "scene": "res://scenes/ceuta_casa_dragones.tscn", "cat": "bâtiments"},
	"palacio": {"name": "Palacio de la Asamblea", "scene": "res://scenes/ceuta_palacio_asamblea.tscn", "cat": "bâtiments"},
	"barricade": {"name": "Barricade Tactique", "scene": "res://scenes/barricade_wall.tscn", "cat": "fortifications"},
	"base_hq": {"name": "Structure QG de Base", "scene": "res://scenes/base_structure.tscn", "cat": "fortifications"},
	"turret_gatling": {"name": "Tourelle Gatling 3D", "scene": "res://scenes/turret_3d.tscn", "cat": "défenses"}
}

const UNIT_CATALOG: Dictionary = {
	"unit_ally": {"name": "Soldat Allié GEO", "scene": "res://scenes/unit_3d.tscn", "is_enemy": false},
	"enemy_base": {"name": "Ennemi Insurgé de Base", "scene": "res://scenes/enemy_unit.tscn", "is_enemy": true},
	"enemy_shield": {"name": "Ennemi Bouclier Anti-Émeute", "scene": "res://scenes/enemy_shield.tscn", "is_enemy": true},
	"enemy_sniper": {"name": "Tireur d'Élite / Balcon", "scene": "res://scenes/enemy_sniper.tscn", "is_enemy": true},
	"enemy_boss": {"name": "Boss Mastodonte", "scene": "res://scenes/enemy_boss.tscn", "is_enemy": true}
}

var _ghost_instance: Node3D = null
var _current_rot_y: float = 0.0

@onready var cam_pivot: Node3D = $EditorCamPivot
@onready var camera: Camera3D = $EditorCamPivot/Camera3D
var _cam_speed: float = 25.0
var _is_rotating_cam: bool = false

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	if directive_modal: directive_modal.visible = false
	
	_populate_category_options()
	_populate_sidebar_tabs()
	_update_texture_dropdown()
	
	if save_btn: save_btn.pressed.connect(_on_save_pressed)
	if test_map_btn: test_map_btn.pressed.connect(_on_test_map_pressed)
	if clear_btn: clear_btn.pressed.connect(_on_clear_pressed)
	if main_menu_btn: main_menu_btn.pressed.connect(_on_main_menu_pressed)
	if import_tex_btn: import_tex_btn.pressed.connect(_on_import_texture_click)
	if file_dialog: file_dialog.file_selected.connect(_on_texture_file_selected)
	
	if close_directive_btn: close_directive_btn.pressed.connect(func(): directive_modal.visible = false)
	if add_waypoint_btn: add_waypoint_btn.pressed.connect(_start_adding_waypoints)
	if clear_waypoints_btn: clear_waypoints_btn.pressed.connect(_clear_active_unit_waypoints)
	if directive_option: directive_option.item_selected.connect(_on_directive_selected)

	_update_ghost_instance()

func _populate_category_options() -> void:
	if not category_option: return
	category_option.clear()
	category_option.add_item("🏛️ Centre Historique Ceuta")
	category_option.add_item("🏰 Fortifications Côtières")
	category_option.add_item("🏙️ Siège Urbain Défensif")
	category_option.add_item("📜 Cartes Personnalisées")

func _populate_sidebar_tabs() -> void:
	if not tab_container: return
	
	# Boutons de bâtiments et préfabs
	var bldg_container := $UI/LeftSidebar/TabContainer/Bâtiments/VBox
	if bldg_container:
		for child in bldg_container.get_children(): child.queue_free()
		for key in PREFAB_CATALOG.keys():
			var item: Dictionary = PREFAB_CATALOG[key]
			var btn := Button.new()
			btn.text = "🧱 " + item["name"]
			btn.custom_minimum_size = Vector2(0, 36)
			btn.pressed.connect(func(): _select_prefab(key))
			bldg_container.add_child(btn)

	# Boutons d'unités
	var unit_container := $UI/LeftSidebar/TabContainer/Unités/VBox
	if unit_container:
		for child in unit_container.get_children(): child.queue_free()
		for u_key in UNIT_CATALOG.keys():
			var u_item: Dictionary = UNIT_CATALOG[u_key]
			var u_btn := Button.new()
			u_btn.text = ("🔵 " if not u_item["is_enemy"] else "🔴 ") + u_item["name"]
			u_btn.custom_minimum_size = Vector2(0, 36)
			u_btn.pressed.connect(func(): _select_unit_type(u_key))
			unit_container.add_child(u_btn)

	# Boutons de Formes 3D Primitives
	var form_box_btn := $UI/LeftSidebar/TabContainer/Formes3D/VBox/BoxBtn
	var form_cyl_btn := $UI/LeftSidebar/TabContainer/Formes3D/VBox/CylBtn
	var form_sph_btn := $UI/LeftSidebar/TabContainer/Formes3D/VBox/SphBtn
	var form_pri_btn := $UI/LeftSidebar/TabContainer/Formes3D/VBox/PriBtn
	
	if form_box_btn: form_box_btn.pressed.connect(func(): _select_primitive("box"))
	if form_cyl_btn: form_cyl_btn.pressed.connect(func(): _select_primitive("cylinder"))
	if form_sph_btn: form_sph_btn.pressed.connect(func(): _select_primitive("sphere"))
	if form_pri_btn: form_pri_btn.pressed.connect(func(): _select_primitive("prism"))

func _update_texture_dropdown() -> void:
	if not texture_option: return
	texture_option.clear()
	texture_option.add_item("Pavés Ceuta (Défaut)", 0)
	texture_option.set_item_metadata(0, "res://textures/ceuta_pavement_tile.png")
	texture_option.add_item("Pierre de Forteresse", 1)
	texture_option.set_item_metadata(1, "res://textures/ceuta_fortress_stone.png")
	texture_option.add_item("Façade Néoclassique Bleue", 2)
	texture_option.set_item_metadata(2, "res://textures/ceuta_facade_blue_neoclassical.png")
	texture_option.add_item("Façade Terracotta", 3)
	texture_option.set_item_metadata(3, "res://textures/ceuta_facade_terracotta.png")
	
	# Charger les textures importées dans user://textures/
	var imported_list := TextureManager.get_all_imported_textures()
	for i in range(imported_list.size()):
		var item: Dictionary = imported_list[i]
		var idx := texture_option.get_item_count()
		texture_option.add_item("🖼️ " + item["name"], idx)
		texture_option.set_item_metadata(idx, item["path"])

	texture_option.item_selected.connect(func(idx): 
		_active_texture_path = texture_option.get_item_metadata(idx)
		if _ghost_instance and _current_edit_mode == EditMode.PLACE_PRIMITIVE:
			_update_ghost_instance()
	)

func _on_import_texture_click() -> void:
	if file_dialog:
		file_dialog.popup_centered(Vector2i(700, 500))

func _on_texture_file_selected(path: String) -> void:
	var res := TextureManager.import_texture_from_file(path)
	if not res.is_empty():
		_update_texture_dropdown()
		_active_texture_path = res["path"]
		if status_label: status_label.text = "Texture importée : " + res["name"]

func _select_prefab(key: String) -> void:
	_current_edit_mode = EditMode.PLACE_PREFAB
	_selected_prefab_key = key
	_update_ghost_instance()
	if status_label: status_label.text = "Bâtiment sélectionné : " + PREFAB_CATALOG[key]["name"]

func _select_primitive(type: String) -> void:
	_current_edit_mode = EditMode.PLACE_PRIMITIVE
	_selected_primitive_type = type
	_update_ghost_instance()
	if status_label: status_label.text = "Forme 3D Primitive : " + type.capitalize()

func _select_unit_type(key: String) -> void:
	_current_edit_mode = EditMode.PLACE_UNIT
	_selected_unit_type = key
	_update_ghost_instance()
	if status_label: status_label.text = "Unité à placer : " + UNIT_CATALOG[key]["name"]

func _update_ghost_instance() -> void:
	if _ghost_instance:
		_ghost_instance.queue_free()
		_ghost_instance = null
		
	match _current_edit_mode:
		EditMode.PLACE_PREFAB:
			if PREFAB_CATALOG.has(_selected_prefab_key):
				var path: String = PREFAB_CATALOG[_selected_prefab_key]["scene"]
				if ResourceLoader.exists(path):
					var scn := load(path) as PackedScene
					if scn: _ghost_instance = scn.instantiate() as Node3D
					
		EditMode.PLACE_PRIMITIVE:
			_ghost_instance = _create_primitive_mesh_node(_selected_primitive_type, _get_primitive_size())
			
		EditMode.PLACE_UNIT:
			if UNIT_CATALOG.has(_selected_unit_type):
				var path: String = UNIT_CATALOG[_selected_unit_type]["scene"]
				if ResourceLoader.exists(path):
					var scn := load(path) as PackedScene
					if scn: _ghost_instance = scn.instantiate() as Node3D

	if _ghost_instance:
		add_child(_ghost_instance)
		_ghost_instance.rotation_degrees.y = _current_rot_y
		_apply_ghost_material(_ghost_instance)

func _get_primitive_size() -> Vector3:
	var sx := size_x_spin.value if size_x_spin else 4.0
	var sy := size_y_spin.value if size_y_spin else 4.0
	var sz := size_z_spin.value if size_z_spin else 4.0
	return Vector3(sx, sy, sz)

func _create_primitive_mesh_node(type: String, size_v: Vector3) -> Node3D:
	var mi := MeshInstance3D.new()
	mi.name = "PrimitiveMesh"
	
	match type:
		"box":
			var box := BoxMesh.new()
			box.size = size_v
			mi.mesh = box
		"cylinder":
			var cyl := CylinderMesh.new()
			cyl.top_radius = size_v.x * 0.5
			cyl.bottom_radius = size_v.x * 0.5
			cyl.height = size_v.y
			mi.mesh = cyl
		"sphere":
			var sph := SphereMesh.new()
			sph.radius = size_v.x * 0.5
			sph.height = size_v.y
			mi.mesh = sph
		"prism":
			var pri := PrismMesh.new()
			pri.size = size_v
			mi.mesh = pri

	var mat := StandardMaterial3D.new()
	var tex := TextureManager.load_texture_from_path(_active_texture_path)
	if tex:
		mat.albedo_texture = tex
		var uv_val := uv_scale_spin.value if uv_scale_spin else 1.0
		mat.uv1_scale = Vector3(uv_val, uv_val, 1)
	if color_picker_btn:
		mat.albedo_color = color_picker_btn.color
		
	mi.material_override = mat
	return mi

func _apply_ghost_material(node: Node) -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 0.8, 1.0, 0.45)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	
	if node is MeshInstance3D:
		(node as MeshInstance3D).material_override = mat
	for child in node.get_children():
		_apply_ghost_material(child)

func _process(delta: float) -> void:
	_process_camera_movement(delta)
	_update_ghost_position()

func _process_camera_movement(delta: float) -> void:
	var input_dir := Vector3.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP): input_dir.z -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN): input_dir.z += 1.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT): input_dir.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): input_dir.x += 1.0
	if Input.is_key_pressed(KEY_E) or Input.is_key_pressed(KEY_PAGEUP): input_dir.y += 1.0
	if Input.is_key_pressed(KEY_Q) or Input.is_key_pressed(KEY_PAGEDOWN): input_dir.y -= 1.0

	if input_dir.length_squared() > 0.001:
		input_dir = input_dir.normalized()
		var move := cam_pivot.transform.basis * input_dir
		cam_pivot.global_position += move * _cam_speed * delta

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			_is_rotating_cam = event.pressed
		elif event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			if not _is_mouse_over_ui():
				if _is_adding_waypoints:
					_place_waypoint_at_cursor()
				else:
					_try_select_unit_or_place()
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_current_rot_y = wrapf(_current_rot_y + 90.0, 0.0, 360.0)
			if _ghost_instance: _ghost_instance.rotation_degrees.y = _current_rot_y
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_current_rot_y = wrapf(_current_rot_y - 90.0, 0.0, 360.0)
			if _ghost_instance: _ghost_instance.rotation_degrees.y = _current_rot_y

	elif event is InputEventMouseMotion and _is_rotating_cam:
		cam_pivot.rotate_y(-event.relative.x * 0.005)

	elif event is InputEventKey and event.pressed:
		if event.keycode == KEY_R:
			_current_rot_y = wrapf(_current_rot_y + 90.0, 0.0, 360.0)
			if _ghost_instance: _ghost_instance.rotation_degrees.y = _current_rot_y
		elif event.keycode == KEY_DELETE or event.keycode == KEY_BACKSPACE:
			_remove_block_under_mouse()

func _is_mouse_over_ui() -> bool:
	var m_pos := get_viewport().get_mouse_position()
	return m_pos.x < 240.0 or m_pos.y < 50.0

func _update_ghost_position() -> void:
	if not _ghost_instance or not camera:
		return
		
	var m_pos := get_viewport().get_mouse_position()
	var ray_from := camera.project_ray_origin(m_pos)
	var ray_dir := camera.project_ray_normal(m_pos)
	
	if abs(ray_dir.y) > 0.001:
		var t := -ray_from.y / ray_dir.y
		if t > 0:
			var hit_pos := ray_from + ray_dir * t
			var snapped_x := round(hit_pos.x / grid_step) * grid_step
			var snapped_z := round(hit_pos.z / grid_step) * grid_step
			_ghost_instance.global_position = Vector3(snapped_x, 0.0, snapped_z)

func _try_select_unit_or_place() -> void:
	# Vérifier si l'utilisateur clique sur une unité existante pour éditer ses directives
	var m_pos := get_viewport().get_mouse_position()
	var ray_from := camera.project_ray_origin(m_pos)
	var ray_to := ray_from + camera.project_ray_normal(m_pos) * 200.0
	var query := PhysicsRayQueryParameters3D.create(ray_from, ray_to)
	var res := get_world_3d().direct_space_state.intersect_ray(query)
	
	if not res.is_empty() and res.collider:
		var col: Node = res.collider
		var unit_node: Node = col
		while unit_node and not (unit_node is Unit3D or unit_node is EnemyUnit):
			unit_node = unit_node.get_parent()
		if unit_node:
			_open_directive_modal(unit_node as Node3D)
			return

	_place_current_object()

func _place_current_object() -> void:
	if not _ghost_instance: return
	
	match _current_edit_mode:
		EditMode.PLACE_PREFAB:
			var path: String = PREFAB_CATALOG[_selected_prefab_key]["scene"]
			var scn := load(path) as PackedScene
			if scn:
				var block := scn.instantiate() as Node3D
				placed_blocks_container.add_child(block)
				block.global_position = _ghost_instance.global_position
				block.rotation_degrees.y = _current_rot_y
				block.set_meta("block_key", _selected_prefab_key)

		EditMode.PLACE_PRIMITIVE:
			var prim := _create_primitive_mesh_node(_selected_primitive_type, _get_primitive_size())
			placed_blocks_container.add_child(prim)
			prim.global_position = _ghost_instance.global_position
			prim.rotation_degrees.y = _current_rot_y
			prim.set_meta("primitive_type", _selected_primitive_type)
			prim.set_meta("primitive_size", [_get_primitive_size().x, _get_primitive_size().y, _get_primitive_size().z])
			prim.set_meta("texture_path", _active_texture_path)
			var uv_val := uv_scale_spin.value if uv_scale_spin else 1.0
			prim.set_meta("uv_scale", [uv_val, uv_val])

		EditMode.PLACE_UNIT:
			var u_path: String = UNIT_CATALOG[_selected_unit_type]["scene"]
			var u_scn := load(u_path) as PackedScene
			if u_scn:
				var unit := u_scn.instantiate() as Node3D
				placed_blocks_container.add_child(unit)
				unit.global_position = _ghost_instance.global_position
				unit.rotation_degrees.y = _current_rot_y
				unit.set_meta("unit_key", _selected_unit_type)
				unit.set_meta("directive", "GUARD" if not UNIT_CATALOG[_selected_unit_type]["is_enemy"] else "CHARGE_BASE")
				unit.set_meta("waypoints", [])
				_open_directive_modal(unit)

# Modal Directives & Waypoints
func _open_directive_modal(unit: Node3D) -> void:
	_active_edited_unit = unit
	if not directive_modal: return
	directive_modal.visible = true
	
	if directive_option:
		directive_option.clear()
		var is_enemy := unit is EnemyUnit
		if not is_enemy:
			directive_option.add_item("🛡️ GUARD (Défendre sur place)", 0)
			directive_option.add_item("🚶 PATROL (Patrouiller Waypoints)", 1)
			directive_option.add_item("⚔️ ATTACK_MOVE (Assaut direct)", 2)
			directive_option.add_item("🎯 SNIPER_POST (Poste surélevé)", 3)
		else:
			directive_option.add_item("💥 CHARGE_BASE (Attaquer le QG)", 0)
			directive_option.add_item("🥷 HUNT_ALLIES (Traquer les soldats)", 1)
			directive_option.add_item("🫣 AMBUSH (Embuscade immobile)", 2)
			directive_option.add_item("🚶 PATROL (Patrouiller Waypoints)", 3)

func _start_adding_waypoints() -> void:
	_is_adding_waypoints = true
	if status_label: status_label.text = "Cliquez sur la carte 3D pour poser les Waypoints de patrouille..."

func _place_waypoint_at_cursor() -> void:
	if not _active_edited_unit or not camera: return
	var m_pos := get_viewport().get_mouse_position()
	var ray_from := camera.project_ray_origin(m_pos)
	var ray_dir := camera.project_ray_normal(m_pos)
	
	if abs(ray_dir.y) > 0.001:
		var t := -ray_from.y / ray_dir.y
		if t > 0:
			var hit_pos := ray_from + ray_dir * t
			var w_wpt_scn := load("res://scenes/waypoint_marker.tscn") as PackedScene
			if w_wpt_scn:
				var wpt_marker := w_wpt_scn.instantiate() as Node3D
				waypoints_container.add_child(wpt_marker)
				wpt_marker.global_position = hit_pos
				
				var waypoints_list: Array = _active_edited_unit.get_meta("waypoints") if _active_edited_unit.has_meta("waypoints") else []
				waypoints_list.append([hit_pos.x, hit_pos.y, hit_pos.z])
				_active_edited_unit.set_meta("waypoints", waypoints_list)
				if status_label: status_label.text = "Waypoint %d ajouté avec succès !" % waypoints_list.size()

func _clear_active_unit_waypoints() -> void:
	if _active_edited_unit:
		_active_edited_unit.set_meta("waypoints", [])
		for child in waypoints_container.get_children(): child.queue_free()
		if status_label: status_label.text = "Waypoints effacés."

func _on_directive_selected(idx: int) -> void:
	if _active_edited_unit:
		var text := directive_option.get_item_text(idx)
		var key := "GUARD"
		if "GUARD" in text: key = "GUARD"
		elif "PATROL" in text: key = "PATROL"
		elif "ATTACK_MOVE" in text: key = "ATTACK_MOVE"
		elif "SNIPER_POST" in text: key = "SNIPER_POST"
		elif "CHARGE_BASE" in text: key = "CHARGE_BASE"
		elif "HUNT_ALLIES" in text: key = "HUNT_ALLIES"
		elif "AMBUSH" in text: key = "AMBUSH"
		_active_edited_unit.set_meta("directive", key)

func _remove_block_under_mouse() -> void:
	if not camera: return
	var m_pos := get_viewport().get_mouse_position()
	var ray_from := camera.project_ray_origin(m_pos)
	var ray_to := ray_from + camera.project_ray_normal(m_pos) * 200.0
	var query := PhysicsRayQueryParameters3D.create(ray_from, ray_to)
	var result := get_world_3d().direct_space_state.intersect_ray(query)
	
	if not result.is_empty() and result.collider:
		var col: Node = result.collider
		var target := col
		while target and target.get_parent() != placed_blocks_container:
			target = target.get_parent()
		if target and target.get_parent() == placed_blocks_container:
			target.queue_free()
			if status_label: status_label.text = "Élément supprimé avec succès."

func _on_clear_pressed() -> void:
	for child in placed_blocks_container.get_children(): child.queue_free()
	for child in waypoints_container.get_children(): child.queue_free()
	if status_label: status_label.text = "Carte entièrement effacée."

func _on_save_pressed() -> void:
	var m_name := map_name_input.text if map_name_input and map_name_input.text != "" else "Ma_Carte_Ceuta"
	var m_cat := category_option.get_item_text(category_option.selected) if category_option else "Custom"
	
	var blocks_data := []
	var primitives_data := []
	var units_data := []
	
	for child in placed_blocks_container.get_children():
		if child is Node3D:
			var n3d := child as Node3D
			if n3d.has_meta("block_key"):
				blocks_data.append({
					"key": n3d.get_meta("block_key"),
					"pos": [n3d.global_position.x, n3d.global_position.y, n3d.global_position.z],
					"rot": [n3d.rotation_degrees.x, n3d.rotation_degrees.y, n3d.rotation_degrees.z]
				})
			elif n3d.has_meta("primitive_type"):
				primitives_data.append({
					"type": n3d.get_meta("primitive_type"),
					"size": n3d.get_meta("primitive_size"),
					"texture": n3d.get_meta("texture_path"),
					"uv_scale": n3d.get_meta("uv_scale"),
					"pos": [n3d.global_position.x, n3d.global_position.y, n3d.global_position.z],
					"rot": [n3d.rotation_degrees.x, n3d.rotation_degrees.y, n3d.rotation_degrees.z]
				})
			elif n3d.has_meta("unit_key"):
				units_data.append({
					"key": n3d.get_meta("unit_key"),
					"directive": n3d.get_meta("directive"),
					"waypoints": n3d.get_meta("waypoints"),
					"pos": [n3d.global_position.x, n3d.global_position.y, n3d.global_position.z],
					"rot": [n3d.rotation_degrees.x, n3d.rotation_degrees.y, n3d.rotation_degrees.z]
				})
			
	var saved_path := MapSerializer.save_map(m_name, m_cat, "Joueur", blocks_data, primitives_data, units_data)
	if status_label and saved_path != "":
		status_label.text = "Carte enregistrée sous : " + saved_path

func _on_test_map_pressed() -> void:
	_on_save_pressed()
	var m_name := map_name_input.text if map_name_input and map_name_input.text != "" else "Ma_Carte_Ceuta"
	var clean_name := m_name.strip_edges().validate_filename()
	var full_path := "user://maps/" + clean_name + ".json"
	
	ProjectSettings.set_setting("game/custom_map_path", full_path)
	get_tree().change_scene_to_file("res://scenes/main_stage.tscn")

func _on_main_menu_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
