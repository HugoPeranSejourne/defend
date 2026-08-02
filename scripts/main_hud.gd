extends CanvasLayer
class_name MainHUD

@export var build_manager: Node

@onready var enemy_count_label: Label = $TopContainer/MarginContainer/HBoxContainer/EnemyBox/EnemyCountLabel
@onready var base_hp_bar: ProgressBar = $TopContainer/MarginContainer/HBoxContainer/BaseBox/BaseHPBar
@onready var base_hp_label: Label = $TopContainer/MarginContainer/HBoxContainer/BaseBox/BaseHPLabel
@onready var credits_label: Label = $TopContainer/MarginContainer/HBoxContainer/CreditsBox/CreditsLabel
@onready var opinion_label: Label = $TopContainer/MarginContainer/HBoxContainer/OpinionBox/OpinionLabel
@onready var opinion_bar: ProgressBar = $TopContainer/MarginContainer/HBoxContainer/OpinionBox/OpinionBar

@onready var btn_gatling: Button = $BuildMenuPanel/VBox/GatlingButton
@onready var btn_gatling_non_lethal: Button = $BuildMenuPanel/VBox/GatlingNonLethalButton
@onready var btn_cannon: Button = $BuildMenuPanel/VBox/CannonButton
@onready var btn_tranq: Button = $BuildMenuPanel/VBox/TranquilizerButton
@onready var btn_bombardier: Button = $BuildMenuPanel/VBox/BombardierButton
@onready var btn_barricade: Button = $BuildMenuPanel/VBox/BarricadeButton

@onready var btn_drone_gas: Button = $BuildMenuPanel/VBox/DroneGasButton
@onready var btn_helico: Button = $BuildMenuPanel/VBox/HelicoButton
@onready var btn_supply: Button = $BuildMenuPanel/VBox/SupplyButton

@onready var end_game_overlay: Control = $EndGameOverlay
@onready var end_game_title: Label = $EndGameOverlay/PanelContainer/VBox/TitleLabel
@onready var end_game_subtitle: Label = $EndGameOverlay/PanelContainer/VBox/SubtitleLabel
@onready var restart_button: Button = $EndGameOverlay/PanelContainer/VBox/RestartButton

func _ready() -> void:
	add_to_group("main_huds")
	
	if not build_manager:
		var managers := get_tree().get_nodes_in_group("build_managers")
		if not managers.is_empty():
			build_manager = managers[0]
		else:
			build_manager = get_node_or_null("/root/MainStage/BuildManager")

	if end_game_overlay:
		end_game_overlay.visible = false
	if restart_button:
		restart_button.pressed.connect(_on_restart_button_pressed)
		
	if btn_gatling: btn_gatling.pressed.connect(func(): _on_build_pressed("Gatling"))
	if btn_gatling_non_lethal: btn_gatling_non_lethal.pressed.connect(func(): _on_build_pressed("GatlingFlashball"))
	if btn_cannon: btn_cannon.pressed.connect(func(): _on_build_pressed("HeavyCannon"))
	if btn_tranq: btn_tranq.pressed.connect(func(): _on_build_pressed("Tranquilizer"))
	if btn_bombardier: btn_bombardier.pressed.connect(func(): _on_build_pressed("Bombardier"))
	if btn_barricade: btn_barricade.pressed.connect(func(): _on_build_pressed("Barricade"))
	if btn_drone_gas: btn_drone_gas.pressed.connect(func(): _on_build_pressed("DroneGas"))
	if btn_helico: btn_helico.pressed.connect(func(): _on_build_pressed("Helicopter"))
	if btn_supply: btn_supply.pressed.connect(func(): _on_build_pressed("SupplyCrate"))

func update_credits(amount: int) -> void:
	if credits_label:
		credits_label.text = "Crédits : %d $" % amount

func update_opinion(opinion: float) -> void:
	if opinion_bar:
		opinion_bar.value = opinion
	if opinion_label:
		opinion_label.text = "Opinion Publique : %d %%" % int(opinion)
		if opinion < 30.0:
			opinion_label.add_theme_color_override("font_color", Color(1.0, 0.25, 0.25, 1.0))
		else:
			opinion_label.add_theme_color_override("font_color", Color(0.3, 0.85, 1.0, 1.0))

func update_enemy_count(remaining: int, total: int) -> void:
	if enemy_count_label:
		enemy_count_label.text = "Ennemis restants : %d / %d" % [remaining, total]

func update_base_hp(current: float, max_val: float) -> void:
	if base_hp_bar:
		base_hp_bar.max_value = max_val
		base_hp_bar.value = current
	if base_hp_label:
		base_hp_label.text = "Base QG : %d / %d HP" % [int(current), int(max_val)]

func _on_build_pressed(type_name: String) -> void:
	if not build_manager:
		var managers := get_tree().get_nodes_in_group("build_managers")
		if not managers.is_empty():
			build_manager = managers[0]

	if build_manager and build_manager.has_method("start_building"):
		build_manager.call("start_building", type_name)

func show_game_over(reason: String = "") -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if end_game_overlay:
		end_game_overlay.visible = true
	if end_game_title:
		end_game_title.text = "GAME OVER !"
		end_game_title.add_theme_color_override("font_color", Color(1.0, 0.25, 0.25, 1.0))
	if end_game_subtitle:
		if reason != "":
			end_game_subtitle.text = reason
		else:
			end_game_subtitle.text = "La Base a été entièrement détruite par les ennemis."

func show_victory() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if end_game_overlay:
		end_game_overlay.visible = true
	if end_game_title:
		end_game_title.text = "VICTOIRE !"
		end_game_title.add_theme_color_override("font_color", Color(0.2, 0.95, 0.4, 1.0))
	if end_game_subtitle:
		end_game_subtitle.text = "Toutes les vagues d'ennemis ont été neutralisées avec succès !"

func _on_restart_button_pressed() -> void:
	get_tree().reload_current_scene()
