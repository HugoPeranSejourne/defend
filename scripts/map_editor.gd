extends Node3D

@export var grid_step: float = 2.0

# Références UI
@onready var map_name_input: LineEdit = $UI/TopBar/HBox/MapNameInput
@onready var category_option: OptionButton = $UI/TopBar/HBox/CategoryOption
@onready var save_btn: Button = $UI/TopBar/HBox/SaveButton
@onready var test_map_btn: Button = $UI/TopBar/HBox/TestMapButton
@onready var clear_btn: Button = $UI/TopBar/HBox/ClearButton
@onready var main_menu_btn: Button = $UI/TopBar/HBox/MainMenuButton

@onready var tab_container: TabContainer = $UI/LeftSidebar/TabContainer
@onready var status_label: Label = $UI/BottomBar/StatusLabel

# Caméra Libre 3D
@onready var cam_pivot: Node3D = $EditorCamPivot
@onready var camera: Camera3D = $EditorCamPivot/Camera3D

# Catalogue des Bloc par Catégories
const BLOCK_CATALOG: Dictionary = {
	"bldg_a": {"name": "Immeuble Néoclassique", "scene": "res://scenes/ceuta_building_a.tscn", "cat": "bâtiments"},
	"bldg_b": {"name": "Immeuble Terracotta", "scene": "res://scenes/ceuta_building_b.tscn", "cat": "bâtiments"},
	"bldg_c": {"name": "Immeuble Bleu Haussmann", "scene": "res://scenes/ceuta_building_c.tscn", "cat": "bâtiments"},
	"bldg_d": {"name": "Bâtiment Commercial", "scene": "res://scenes/ceuta_building_d.tscn", "cat": "bâtiments"},
	"dragons": {"name": "Casa de los Dragones", "scene": "res://scenes/ceuta_casa_dragones.tscn", "cat": "bâtiments"},
	"palacio": {"name": "Palacio de la Asamblea", "scene": "res://scenes/ceuta_palacio_asamblea.tscn", "cat": "bâtiments"},
	
	"barricade": {"name": "Barricade Tactique", "scene": "res://scenes/barricade_wall.tscn", "cat": "fortifications"},
	"base_hq": {"name": "Structure QG de Base", "scene": "res://scenes/base_structure.tscn", "cat": "fortifications"},
	
	"turret_gatling": {"name": "Tourelle Gatling 3D", "scene": "res://scenes/turret_3d.tscn", "cat": "défenses"},
	
	"unit_ally": {"name": "Soldat Allié GEO", "scene": "res://scenes/unit_3d.tscn", "cat": "tactique"},
	"enemy_wave": {"name": "Point d'Apparition Ennemi", "scene": "res://scenes/enemy_unit.tscn", "cat": "tactique"}
}

var _selected_block_key: String = "bldg_a"
var _current_rot_y: float = 0.0

# Gestion des instances placées
@onready var placed_blocks_container: Node3D = $PlacedBlocks

# Fantôme de prévisualisation
var _ghost_instance: Node3D = null

# État caméra
var _cam_speed: float = 25.0
var _is_rotating_cam: bool = false
var _last_mouse_pos: Vector2 = Vector2.ZERO

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	_populate_category_options()
	_populate_block_buttons()
	
	if save_btn: save_btn.pressed.connect(_on_save_pressed)
	if test_map_btn: test_map_btn.pressed.connect(_on_test_map_pressed)
	if clear_btn: clear_btn.pressed.connect(_on_clear_pressed)
	if main_menu_btn: main_menu_btn.pressed.connect(_on_main_menu_pressed)

	_update_ghost_instance()

func _populate_category_options() -> void:
	if not category_option: return
	category_option.clear()
	category_option.add_item("🏛️ Centre Historique Ceuta")
	category_option.add_item("🏰 Fortifications Côtières")
	category_option.add_item("🏙️ Siège Urbain Défensif")
	category_option.add_item("📜 Cartes Personnalisées")

func _populate_block_buttons() -> void:
	if not tab_container: return
	
	# Vider les onglets existants
	for child in tab_container.get_children():
		child.queue_free()
		
	var categories := ["Bâtiments", "Fortifications", "Défenses", "Tactique"]
	for cat in categories:
		var scroll := ScrollContainer.new()
		scroll.name = cat
		var vbox := VBoxContainer.new()
		scroll.add_child(vbox)
		tab_container.add_child(scroll)
		
		for key in BLOCK_CATALOG.keys():
			var item: Dictionary = BLOCK_CATALOG[key]
			if item["cat"].to_lower() == cat.to_lower():
				var btn := Button.new()
				btn.text = "🧱 " + item["name"]
				btn.custom_minimum_size = Vector2(0, 36)
				btn.pressed.connect(func(): _select_block(key))
				vbox.add_child(btn)

func _select_block(key: String) -> void:
	_selected_block_key = key
	_update_ghost_instance()
	if status_label:
		status_label.text = "Bloc sélectionné : " + BLOCK_CATALOG[key]["name"]

func _update_ghost_instance() -> void:
	if _ghost_instance:
		_ghost_instance.queue_free()
		_ghost_instance = null
		
	if not BLOCK_CATALOG.has(_selected_block_key):
		return
		
	var path: String = BLOCK_CATALOG[_selected_block_key]["scene"]
	if ResourceLoader.exists(path):
		var scn := load(path) as PackedScene
		if scn:
			_ghost_instance = scn.instantiate() as Node3D
			add_child(_ghost_instance)
			_ghost_instance.rotation_degrees.y = _current_rot_y
			# Rendre le fantôme semi-transparent
			_apply_ghost_material(_ghost_instance)

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
	# Rotation Caméra (Bouton Droit de la souris)
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			_is_rotating_cam = event.pressed
		elif event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			# Placer le bloc si pas sur l'UI
			if not _is_mouse_over_ui():
				_place_current_block()
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
	
	# Intersecter le plan Z/X (Y = 0)
	if abs(ray_dir.y) > 0.001:
		var t := -ray_from.y / ray_dir.y
		if t > 0:
			var hit_pos := ray_from + ray_dir * t
			# Snap sur la grille
			var snapped_x := round(hit_pos.x / grid_step) * grid_step
			var snapped_z := round(hit_pos.z / grid_step) * grid_step
			_ghost_instance.global_position = Vector3(snapped_x, 0.0, snapped_z)

func _place_current_block() -> void:
	if not _ghost_instance or not BLOCK_CATALOG.has(_selected_block_key):
		return
		
	var path: String = BLOCK_CATALOG[_selected_block_key]["scene"]
	var scn := load(path) as PackedScene
	if scn:
		var block := scn.instantiate() as Node3D
		placed_blocks_container.add_child(block)
		block.global_position = _ghost_instance.global_position
		block.rotation_degrees.y = _current_rot_y
		block.set_meta("block_key", _selected_block_key)
		
		if status_label:
			status_label.text = "Bloc placé : " + BLOCK_CATALOG[_selected_block_key]["name"]

func _remove_block_under_mouse() -> void:
	if not camera: return
	var m_pos := get_viewport().get_mouse_position()
	var ray_from := camera.project_ray_origin(m_pos)
	var ray_to := ray_from + camera.project_ray_normal(m_pos) * 200.0
	
	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(ray_from, ray_to)
	var result := space.intersect_ray(query)
	
	if not result.is_empty() and result.collider:
		var col: Node = result.collider
		var target := col
		while target and target.get_parent() != placed_blocks_container:
			target = target.get_parent()
		if target and target.get_parent() == placed_blocks_container:
			target.queue_free()
			if status_label: status_label.text = "Bloc supprimé avec succès."

func _on_clear_pressed() -> void:
	for child in placed_blocks_container.get_children():
		child.queue_free()
	if status_label: status_label.text = "Carte entièrement effacée."

func _on_save_pressed() -> void:
	var m_name := map_name_input.text if map_name_input and map_name_input.text != "" else "Ma_Carte_Ceuta"
	var m_cat := category_option.get_item_text(category_option.selected) if category_option else "Custom"
	
	var blocks_data := []
	for child in placed_blocks_container.get_children():
		if child is Node3D:
			var n3d := child as Node3D
			var key: String = n3d.get_meta("block_key") if n3d.has_meta("block_key") else "bldg_a"
			blocks_data.append({
				"key": key,
				"pos": [n3d.global_position.x, n3d.global_position.y, n3d.global_position.z],
				"rot": [n3d.rotation_degrees.x, n3d.rotation_degrees.y, n3d.rotation_degrees.z]
			})
			
	var saved_path := MapSerializer.save_map(m_name, m_cat, "Joueur", blocks_data)
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
