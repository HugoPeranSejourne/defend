extends Unit3D
class_name UnitSniper

@export_group("Spécificités Sniper")
@export var thermal_scope_enabled: bool = false
@export var hold_breath_energy: float = 100.0
@export var max_hold_breath: float = 100.0
@export var sniper_damage_multiplier: float = 4.5

var is_holding_breath: bool = false
var _thermal_viewport_rect: ColorRect = null

func _ready() -> void:
	super._ready()
	unit_name = "Tireur d'Élite / Sniper"
	auto_attack_range = 65.0
	auto_attack_damage = 75.0
	move_speed = 5.2

func _unhandled_input(event: InputEvent) -> void:
	super._unhandled_input(event)
	if not is_fps_controlled:
		return

	# Touche T : Basculer le Viseur Thermique X-Ray
	if event is InputEventKey and event.pressed and event.keycode == KEY_T:
		toggle_thermal_scope()
		get_viewport().set_input_as_handled()
		return

	# Clic Droit / Shift : Hold Breath (Visée ralentie extrême)
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		if event.pressed and hold_breath_energy > 20.0:
			_start_hold_breath()
		else:
			_stop_hold_breath()

func toggle_thermal_scope() -> void:
	thermal_scope_enabled = not thermal_scope_enabled
	_update_thermal_overlay()

func _update_thermal_overlay() -> void:
	var enemies := get_tree().get_nodes_in_group("enemies")
	for e in enemies:
		if is_instance_valid(e) and e is EnemyUnit:
			var mesh_inst := (e as EnemyUnit).find_child("vanguard_Mesh", true, false) as MeshInstance3D
			if mesh_inst:
				var mat := mesh_inst.get_active_material(0)
				if mat and mat is StandardMaterial3D:
					if thermal_scope_enabled:
						mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
						mat.albedo_color = Color(1.0, 0.95, 0.4, 1.0) # Thermal Yellow/White
					else:
						mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
						mat.albedo_color = Color(0.9, 0.25, 0.25, 1.0)

func _start_hold_breath() -> void:
	is_holding_breath = true
	Engine.time_scale = 0.12 # Slow motion extrême 12%
	if is_instance_valid(_fps_hud_node) and _fps_hud_node.has_method("update_bullet_time"):
		_fps_hud_node.call("update_bullet_time", hold_breath_energy, max_hold_breath, true, false)

func _stop_hold_breath() -> void:
	is_holding_breath = false
	if not is_bullet_time_active:
		Engine.time_scale = 1.0

func _perform_fps_shoot() -> void:
	var orig_damage := auto_attack_damage
	if is_holding_breath:
		auto_attack_damage *= sniper_damage_multiplier

	super._perform_fps_shoot()
	auto_attack_damage = orig_damage

	if is_holding_breath:
		hold_breath_energy = max(0.0, hold_breath_energy - 25.0)
		if hold_breath_energy <= 0.0:
			_stop_hold_breath()

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if is_holding_breath:
		hold_breath_energy = max(0.0, hold_breath_energy - delta * 20.0)
		if hold_breath_energy <= 0.0:
			_stop_hold_breath()
	else:
		hold_breath_energy = min(max_hold_breath, hold_breath_energy + delta * 15.0)
