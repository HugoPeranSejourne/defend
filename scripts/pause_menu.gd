extends CanvasLayer

@onready var pause_panel: PanelContainer = $CenterContainer/PausePanel
@onready var options_modal: PanelContainer = $CenterContainer/OptionsModal

# Boutons principaux
@onready var resume_btn: Button = $CenterContainer/PausePanel/VBox/ResumeButton
@onready var restart_btn: Button = $CenterContainer/PausePanel/VBox/RestartButton
@onready var options_btn: Button = $CenterContainer/PausePanel/VBox/OptionsButton
@onready var main_menu_btn: Button = $CenterContainer/PausePanel/VBox/MainMenuButton
@onready var quit_btn: Button = $CenterContainer/PausePanel/VBox/QuitButton

# Options Sliders & Controls
@onready var master_vol_slider: HSlider = $CenterContainer/OptionsModal/VBox/MasterVolContainer/MasterVolSlider
@onready var sfx_vol_slider: HSlider = $CenterContainer/OptionsModal/VBox/SFXVolContainer/SFXVolSlider
@onready var sens_slider: HSlider = $CenterContainer/OptionsModal/VBox/SensContainer/SensSlider
@onready var fullscreen_check: CheckBox = $CenterContainer/OptionsModal/VBox/FullscreenContainer/FullscreenCheck
@onready var back_options_btn: Button = $CenterContainer/OptionsModal/VBox/BackOptionsButton

var _is_paused: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	if options_modal:
		options_modal.visible = false
		
	# Connexions des signaux boutons
	if resume_btn: resume_btn.pressed.connect(_on_resume_pressed)
	if restart_btn: restart_btn.pressed.connect(_on_restart_pressed)
	if options_btn: options_btn.pressed.connect(_on_options_pressed)
	if main_menu_btn: main_menu_btn.pressed.connect(_on_main_menu_pressed)
	if quit_btn: quit_btn.pressed.connect(_on_quit_pressed)
	if back_options_btn: back_options_btn.pressed.connect(_on_back_options_pressed)

	# Initialisation des valeurs d'options
	_init_options_values()

func _init_options_values() -> void:
	if master_vol_slider:
		master_vol_slider.value = 80.0
		master_vol_slider.value_changed.connect(_on_master_vol_changed)
	if sfx_vol_slider:
		sfx_vol_slider.value = 90.0
		sfx_vol_slider.value_changed.connect(_on_sfx_vol_changed)
	if sens_slider:
		sens_slider.value = 50.0
		sens_slider.value_changed.connect(_on_sensitivity_changed)
	if fullscreen_check:
		var mode := DisplayServer.window_get_mode()
		fullscreen_check.button_pressed = (mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
		fullscreen_check.toggled.connect(_on_fullscreen_toggled)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE):
		toggle_pause()
		get_viewport().set_input_as_handled()

func toggle_pause() -> void:
	set_paused(not _is_paused)

func set_paused(p: bool) -> void:
	_is_paused = p
	get_tree().paused = _is_paused
	visible = _is_paused
	
	if _is_paused:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		if pause_panel: pause_panel.visible = true
		if options_modal: options_modal.visible = false
	else:
		# Si une unité FPS était possédée, ne pas forcer MOUSE_MODE_VISIBLE
		var units := get_tree().get_nodes_in_group("units")
		var is_fps := false
		for u in units:
			if u.get("is_fps_controlled") == true:
				is_fps = true
				break
		if is_fps:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _on_resume_pressed() -> void:
	set_paused(false)

func _on_restart_pressed() -> void:
	set_paused(false)
	get_tree().reload_current_scene()

func _on_options_pressed() -> void:
	if pause_panel: pause_panel.visible = false
	if options_modal: options_modal.visible = true

func _on_back_options_pressed() -> void:
	if options_modal: options_modal.visible = false
	if pause_panel: pause_panel.visible = true

func _on_main_menu_pressed() -> void:
	set_paused(false)
	var main_menu_path := "res://scenes/main_menu.tscn"
	if ResourceLoader.exists(main_menu_path):
		get_tree().change_scene_to_file(main_menu_path)

func _on_quit_pressed() -> void:
	get_tree().quit()

# Callbacks Options
func _on_master_vol_changed(val: float) -> void:
	var bus_idx := AudioServer.get_bus_index("Master")
	if bus_idx >= 0:
		var db := linear_to_db(val / 100.0) if val > 0 else -80.0
		AudioServer.set_bus_volume_db(bus_idx, db)

func _on_sfx_vol_changed(val: float) -> void:
	# Si un bus SFX existe
	var bus_idx := AudioServer.get_bus_index("SFX")
	if bus_idx >= 0:
		var db := linear_to_db(val / 100.0) if val > 0 else -80.0
		AudioServer.set_bus_volume_db(bus_idx, db)

func _on_sensitivity_changed(val: float) -> void:
	var sens := (val / 100.0) * 0.005 + 0.0005
	var units := get_tree().get_nodes_in_group("units")
	for u in units:
		if u.has_method("set"):
			u.set("mouse_sensitivity", sens)

func _on_fullscreen_toggled(button_pressed: bool) -> void:
	if button_pressed:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
