extends Node3D

@onready var main_panel: PanelContainer = $UI/CenterContainer/MainPanel
@onready var options_modal: PanelContainer = $UI/CenterContainer/OptionsModal
@onready var credits_modal: PanelContainer = $UI/CenterContainer/CreditsModal
@onready var map_selector_modal: PanelContainer = $UI/CenterContainer/MapSelectorModal

# Boutons principaux
@onready var play_btn: Button = $UI/CenterContainer/MainPanel/VBox/PlayButton
@onready var editor_btn: Button = $UI/CenterContainer/MainPanel/VBox/MapEditorButton
@onready var options_btn: Button = $UI/CenterContainer/MainPanel/VBox/OptionsButton
@onready var credits_btn: Button = $UI/CenterContainer/MainPanel/VBox/CreditsButton
@onready var quit_btn: Button = $UI/CenterContainer/MainPanel/VBox/QuitButton

# Sliders & Options
@onready var master_vol_slider: HSlider = $UI/CenterContainer/OptionsModal/VBox/MasterVolContainer/MasterVolSlider
@onready var sfx_vol_slider: HSlider = $UI/CenterContainer/OptionsModal/VBox/SFXVolContainer/SFXVolSlider
@onready var sens_slider: HSlider = $UI/CenterContainer/OptionsModal/VBox/SensContainer/SensSlider
@onready var fullscreen_check: CheckBox = $UI/CenterContainer/OptionsModal/VBox/FullscreenContainer/FullscreenCheck
@onready var back_options_btn: Button = $UI/CenterContainer/OptionsModal/VBox/BackOptionsButton
@onready var back_credits_btn: Button = $UI/CenterContainer/CreditsModal/VBox/BackCreditsButton
@onready var back_map_btn: Button = $UI/CenterContainer/MapSelectorModal/VBox/BackMapButton

# Liste des cartes dans le sélecteur
@onready var map_item_list: ItemList = $UI/CenterContainer/MapSelectorModal/VBox/MapItemList
@onready var launch_map_btn: Button = $UI/CenterContainer/MapSelectorModal/VBox/LaunchMapButton

# Caméra panoramique 3D
@onready var menu_cam_pivot: Node3D = $CameraPivot

var _selected_map_name: String = ""

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	if main_panel: main_panel.visible = true
	if options_modal: options_modal.visible = false
	if credits_modal: credits_modal.visible = false
	if map_selector_modal: map_selector_modal.visible = false

	# Connexions des signaux
	if play_btn: play_btn.pressed.connect(_on_play_pressed)
	if editor_btn: editor_btn.pressed.connect(_on_editor_pressed)
	if options_btn: options_btn.pressed.connect(_on_options_pressed)
	if credits_btn: credits_btn.pressed.connect(_on_credits_pressed)
	if quit_btn: quit_btn.pressed.connect(_on_quit_pressed)
	
	if back_options_btn: back_options_btn.pressed.connect(_show_main_panel)
	if back_credits_btn: back_credits_btn.pressed.connect(_show_main_panel)
	if back_map_btn: back_map_btn.pressed.connect(_show_main_panel)
	if launch_map_btn: launch_map_btn.pressed.connect(_on_launch_map_pressed)

	_init_options()

func _init_options() -> void:
	if master_vol_slider: master_vol_slider.value_changed.connect(_on_master_vol_changed)
	if sfx_vol_slider: sfx_vol_slider.value_changed.connect(_on_sfx_vol_changed)
	if fullscreen_check: fullscreen_check.toggled.connect(_on_fullscreen_toggled)

func _process(delta: float) -> void:
	if menu_cam_pivot:
		menu_cam_pivot.rotate_y(delta * 0.05)

func _show_main_panel() -> void:
	if main_panel: main_panel.visible = true
	if options_modal: options_modal.visible = false
	if credits_modal: credits_modal.visible = false
	if map_selector_modal: map_selector_modal.visible = false

func _on_play_pressed() -> void:
	# Charger la liste des cartes disponibles (campagne de base + custom)
	_populate_map_list()
	if main_panel: main_panel.visible = false
	if map_selector_modal: map_selector_modal.visible = true

func _populate_map_list() -> void:
	if not map_item_list:
		return
	map_item_list.clear()
	map_item_list.add_item("🏰 Carte Officielle - Centre Historique Ceuta (Default)")
	map_item_list.set_item_metadata(0, "default")
	
	# Scanner le dossier user://maps/
	var dir := DirAccess.open("user://maps/")
	if dir:
		dir.list_dir_begin()
		var file_name := dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and file_name.ends_with(".json"):
				var map_title := file_name.trim_suffix(".json").capitalize()
				var idx := map_item_list.add_item("📜 " + map_title + " (Custom Map)")
				map_item_list.set_item_metadata(idx, "user://maps/" + file_name)
			file_name = dir.get_next()
	
	map_item_list.select(0)
	_selected_map_name = "default"

func _on_launch_map_pressed() -> void:
	var selected_indices := map_item_list.get_selected_items()
	var map_path := "default"
	if not selected_indices.is_empty():
		map_path = map_item_list.get_item_metadata(selected_indices[0])
		
	# Passer la carte choisie au singleton / main_stage
	if map_path != "default":
		ProjectSettings.set_setting("game/custom_map_path", map_path)
	else:
		ProjectSettings.set_setting("game/custom_map_path", "")

	get_tree().change_scene_to_file("res://scenes/main_stage.tscn")

func _on_editor_pressed() -> void:
	var editor_path := "res://scenes/map_editor.tscn"
	if ResourceLoader.exists(editor_path):
		get_tree().change_scene_to_file(editor_path)

func _on_options_pressed() -> void:
	if main_panel: main_panel.visible = false
	if options_modal: options_modal.visible = true

func _on_credits_pressed() -> void:
	if main_panel: main_panel.visible = false
	if credits_modal: credits_modal.visible = true

func _on_quit_pressed() -> void:
	get_tree().quit()

# Options Callbacks
func _on_master_vol_changed(val: float) -> void:
	var bus_idx := AudioServer.get_bus_index("Master")
	if bus_idx >= 0:
		var db := linear_to_db(val / 100.0) if val > 0 else -80.0
		AudioServer.set_bus_volume_db(bus_idx, db)

func _on_sfx_vol_changed(val: float) -> void:
	var bus_idx := AudioServer.get_bus_index("SFX")
	if bus_idx >= 0:
		var db := linear_to_db(val / 100.0) if val > 0 else -80.0
		AudioServer.set_bus_volume_db(bus_idx, db)

func _on_fullscreen_toggled(button_pressed: bool) -> void:
	if button_pressed:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
