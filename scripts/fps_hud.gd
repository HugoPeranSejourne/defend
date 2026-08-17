extends CanvasLayer
class_name FPSHUD

@onready var container: Control = $HUDContainer
@onready var health_bar: ProgressBar = $HUDContainer/BottomMargin/VBoxContainer/HealthBar
@onready var health_label: Label = $HUDContainer/BottomMargin/VBoxContainer/HealthLabel
@onready var ammo_label: Label = $HUDContainer/BottomMargin/VBoxContainer/AmmoLabel
@onready var weapon_label: Label = $HUDContainer/BottomMargin/VBoxContainer/WeaponLabel

var _bt_bar: ProgressBar = null
var _bt_label: Label = null
var _bt_vignette: ColorRect = null

func _ready() -> void:
	set_hud_visible(false)
	_setup_bullet_time_ui()

func _setup_bullet_time_ui() -> void:
	if container and container.has_node("BottomMargin/VBoxContainer"):
		var vbox := container.get_node("BottomMargin/VBoxContainer") as VBoxContainer
		if vbox and not vbox.has_node("BulletTimeBar"):
			_bt_label = Label.new()
			_bt_label.name = "BulletTimeLabel"
			_bt_label.text = "⏳ BULLET-TIME (MAX PAYNE) [SHIFT / MOLETTE / ESPACE]"
			_bt_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2, 1.0))
			vbox.add_child(_bt_label)

			_bt_bar = ProgressBar.new()
			_bt_bar.name = "BulletTimeBar"
			_bt_bar.custom_minimum_size = Vector2(0, 14)
			_bt_bar.max_value = 100.0
			_bt_bar.value = 100.0
			vbox.add_child(_bt_bar)

		_bt_vignette = ColorRect.new()
		_bt_vignette.name = "BTVignette"
		_bt_vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
		_bt_vignette.color = Color(1.0, 0.75, 0.2, 0.12)
		_bt_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_bt_vignette.visible = false
		container.add_child(_bt_vignette)

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

func update_bullet_time(energy: float, max_val: float, is_active: bool, is_dodging: bool) -> void:
	if _bt_bar:
		_bt_bar.max_value = max_val
		_bt_bar.value = energy
	if _bt_label:
		if is_dodging:
			_bt_label.text = "🦘 MAX PAYNE SHOOT DODGE MID-AIR !"
			_bt_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.1, 1.0))
		elif is_active:
			_bt_label.text = "⏳ BULLET-TIME ACTIF (RALENTISSEMENT 20%)"
			_bt_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3, 1.0))
		else:
			_bt_label.text = "⏳ BULLET-TIME : %d%% [SHIFT / CLIC DROIT / ESPACE EN MOVT]" % int((energy / max_val) * 100.0)
			_bt_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8, 1.0))
	if _bt_vignette:
		_bt_vignette.visible = is_active or is_dodging
