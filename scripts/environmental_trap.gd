extends StaticBody3D
class_name EnvironmentalTrap

enum TrapType { WATER_TANK, FUEL_BARREL, LIGHTING_POLE, CARGO_CONTAINER }

@export var trap_type: TrapType = TrapType.FUEL_BARREL
@export var health: float = 40.0
@export var blast_radius: float = 7.0
@export var blast_damage: float = 180.0

var _is_triggered: bool = false

func _ready() -> void:
	add_to_group("environmental_traps")

func take_damage(amount: float, _bullet_dir: Vector3 = Vector3.ZERO, _body_part: String = "") -> void:
	if _is_triggered:
		return
	health -= amount
	if health <= 0.0:
		trigger_trap()

func trigger_trap() -> void:
	if _is_triggered:
		return
	_is_triggered = true

	var pos := global_position
	print("[ENVIRONMENTAL TRAP] Piège déclenché type %d à %s" % [trap_type, str(pos)])

	var debris_script := load("res://scripts/debris_system.gd") as GDScript
	if debris_script and debris_script.has_method("spawn_rubble_explosion"):
		debris_script.call("spawn_rubble_explosion", get_tree().root, pos + Vector3(0, 1.0, 0), 16)

	var enemies := get_tree().get_nodes_in_group("enemies")
	for e in enemies:
		if is_instance_valid(e) and e is EnemyUnit:
			var enemy_unit := e as EnemyUnit
			var dist := pos.distance_to(enemy_unit.global_position)
			if dist <= blast_radius:
				var fall_off := 1.0 - (dist / blast_radius)
				if trap_type == TrapType.WATER_TANK:
					enemy_unit.take_non_lethal_damage(160.0 * fall_off, (enemy_unit.global_position - pos).normalized())
				else:
					enemy_unit.take_damage(blast_damage * fall_off, (enemy_unit.global_position - pos).normalized(), "chest_upper_left")

	queue_free()
