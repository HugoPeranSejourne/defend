extends Unit3D
class_name UnitEngineer

@export_group("Spécificités Ingénieur")
@export var mines_count: int = 5
@export var repair_power: float = 80.0 # Santé restaurée par seconde

var _repair_target: BarricadeWall = null

func _ready() -> void:
	super._ready()
	unit_name = "Ingénieur / Démolisseur"
	max_health = 150.0
	health = 150.0
	move_speed = 5.8

func _unhandled_input(event: InputEvent) -> void:
	super._unhandled_input(event)
	if not is_fps_controlled:
		return

	# Touche F : Déposer une Mine de Proximité
	if event is InputEventKey and event.pressed and event.keycode == KEY_F:
		deploy_mine()
		get_viewport().set_input_as_handled()
		return

	# Touche E : Réparer la Barricade la plus proche
	if event is InputEventKey and event.pressed and event.keycode == KEY_E:
		_try_repair_barricade()
		get_viewport().set_input_as_handled()
		return

func deploy_mine() -> void:
	if mines_count <= 0:
		return
	mines_count -= 1

	var mine := Node3D.new()
	mine.name = "ProximityMine"
	mine.global_position = global_position + Vector3(0, 0.1, 0)

	var mi := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.4
	cyl.bottom_radius = 0.4
	cyl.height = 0.15
	mi.mesh = cyl

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.4, 0.1, 1.0)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.5, 0.1, 1.0)
	mat.emission_energy_multiplier = 1.5
	mi.material_override = mat
	mine.add_child(mi)

	get_tree().root.add_child(mine)

	# Trigger area for enemies
	var timer := get_tree().create_timer(0.5)
	timer.timeout.connect(func():
		_arm_mine(mine)
	)

func _arm_mine(mine: Node3D) -> void:
	if not is_instance_valid(mine):
		return
	var area := Area3D.new()
	var cs := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 2.5
	cs.shape = sphere
	area.add_child(cs)
	mine.add_child(area)

	area.body_entered.connect(func(body: Node):
		if body is EnemyUnit:
			_explode_mine(mine)
	)

func _explode_mine(mine: Node3D) -> void:
	if not is_instance_valid(mine):
		return
	var explosion_pos := mine.global_position

	var enemies := get_tree().get_nodes_in_group("enemies")
	for e in enemies:
		if is_instance_valid(e) and e is EnemyUnit:
			var dist := explosion_pos.distance_to((e as EnemyUnit).global_position)
			if dist <= 5.0:
				(e as EnemyUnit).take_damage(140.0 * (1.0 - dist / 5.0), Vector3.UP, "chest_upper_left")

	var debris_script := load("res://scripts/debris_system.gd") as GDScript
	if debris_script and debris_script.has_method("spawn_rubble_explosion"):
		debris_script.call("spawn_rubble_explosion", get_tree().root, explosion_pos, 10)

	mine.queue_free()

func _try_repair_barricade() -> void:
	var barricades := get_tree().get_nodes_in_group("barricades")
	for b in barricades:
		if is_instance_valid(b) and b is BarricadeWall:
			if global_position.distance_to((b as BarricadeWall).global_position) <= 4.0:
				var wall := b as BarricadeWall
				wall.health = min(wall.max_health, wall.health + repair_power)
				wall._flash_impact()
				print("[ENGINEER] Barricade réparée ! Santé : ", wall.health)
				break
