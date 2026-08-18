extends Unit3D
class_name UnitMedic

@export_group("Spécificités Médecin")
@export var tear_gas_count: int = 4
@export var revive_range: float = 3.5

func _ready() -> void:
	super._ready()
	unit_name = "Médecin de Combat"
	max_health = 130.0
	health = 130.0
	move_speed = 6.2

func _unhandled_input(event: InputEvent) -> void:
	super._unhandled_input(event)
	if not is_fps_controlled:
		return

	# Touche G : Lancer une Grenade Lacrymogène
	if event is InputEventKey and event.pressed and event.keycode == KEY_G:
		throw_tear_gas()
		get_viewport().set_input_as_handled()
		return

	# Touche E : Réanimer un Allié à terre
	if event is InputEventKey and event.pressed and event.keycode == KEY_E:
		_try_revive_ally()
		get_viewport().set_input_as_handled()
		return

func throw_tear_gas() -> void:
	if tear_gas_count <= 0:
		return
	tear_gas_count -= 1

	var throw_dir := -fps_camera.global_transform.basis.z
	var start_pos := global_position + Vector3(0, 1.5, 0)
	var target_pos := start_pos + throw_dir * 18.0
	target_pos.y = max(0.2, target_pos.y)

	var cloud := Node3D.new()
	cloud.name = "TearGasCloud"
	cloud.global_position = target_pos

	var mi := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 4.0
	sphere.height = 8.0
	mi.mesh = sphere

	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.3, 0.9, 0.4, 0.35)
	mi.material_override = mat
	cloud.add_child(mi)

	get_tree().root.add_child(cloud)

	# Stun & blind all enemies in gas radius
	var timer := get_tree().create_timer(6.0)
	var tween := get_tree().create_tween()
	tween.tween_property(mat, "albedo_color:a", 0.0, 6.0)
	timer.timeout.connect(cloud.queue_free)

	var enemies := get_tree().get_nodes_in_group("enemies")
	for e in enemies:
		if is_instance_valid(e) and e is EnemyUnit:
			var enemy_unit := e as EnemyUnit
			if target_pos.distance_to(enemy_unit.global_position) <= 8.0:
				enemy_unit.take_non_lethal_damage(120.0, Vector3.UP)

func _try_revive_ally() -> void:
	var units := get_tree().get_nodes_in_group("units")
	for u in units:
		if is_instance_valid(u) and u is Unit3D and u != self:
			var unit := u as Unit3D
			if global_position.distance_to(unit.global_position) <= revive_range:
				unit.health = unit.max_health
				print("[MEDIC] Allié soigné et réanimé : ", unit.unit_name)
				break
