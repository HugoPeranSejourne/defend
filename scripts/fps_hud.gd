extends CanvasLayer
class_name FPSHUD

@onready var container: Control = $HUDContainer
@onready var health_bar: ProgressBar = $HUDContainer/BottomMargin/VBoxContainer/HealthBar
@onready var health_label: Label = $HUDContainer/BottomMargin/VBoxContainer/HealthLabel
@onready var ammo_label: Label = $HUDContainer/BottomMargin/VBoxContainer/AmmoLabel
@onready var weapon_label: Label = $HUDContainer/BottomMargin/VBoxContainer/WeaponLabel

func _ready() -> void:
	set_hud_visible(false)

func set_hud_visible(is_vis: bool) -> void:
	if container:
		container.visible = is_vis

func update_health(current: float, max_val: float) -> void:
	if health_bar:
		health_bar.max_value = max_val
		health_bar.value = current
	if health_label:
		health_label.text = "SANTÉ : %d / %d" % [int(current), int(max_val)]

func update_ammo(current: int, max_val: int) -> void:
	if ammo_label:
		ammo_label.text = "MUNITIONS : %d / %d" % [current, max_val]

func update_weapon_mode(is_non_lethal: bool) -> void:
	if weapon_label:
		if is_non_lethal:
			weapon_label.text = "ARME : FLASHBALL NON-LÉTAL [2]"
			weapon_label.add_theme_color_override("font_color", Color(0.2, 0.9, 1.0, 1.0))
		else:
			weapon_label.text = "ARME : FUSIL D'ASSAUT LÉTAL [1]"
			weapon_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2, 1.0))
