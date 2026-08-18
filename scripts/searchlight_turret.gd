extends Node3D
class_name SearchlightTurret

@export var light_color: Color = Color(1.0, 0.95, 0.7, 1.0)
@export var spot_range: float = 35.0
@export var spot_angle: float = 30.0

var _spotlight: SpotLight3D = null

func _ready() -> void:
	add_to_group("searchlights")
	_setup_light()

func _setup_light() -> void:
	_spotlight = SpotLight3D.new()
	_spotlight.spot_range = spot_range
	_spotlight.spot_angle = spot_angle
	_spotlight.light_color = light_color
	_spotlight.light_energy = 8.0
	_spotlight.shadow_enabled = true
	add_child(_spotlight)

func _physics_process(delta: float) -> void:
	if not is_instance_valid(_spotlight):
		return

	# Slowly sweep light beam across defense perimeter
	rotation.y += delta * 0.45

	# Slow down and blind enemies inside searchlight cone
	var enemies := get_tree().get_nodes_in_group("enemies")
	for e in enemies:
		if is_instance_valid(e) and e is EnemyUnit:
			var enemy_unit := e as EnemyUnit
			var to_enemy := (enemy_unit.global_position - global_position)
			if to_enemy.length() <= spot_range:
				var angle := rad_to_deg(transform.basis.z.angle_to(-to_enemy.normalized()))
				if angle <= spot_angle:
					enemy_unit.take_non_lethal_damage(15.0 * delta, Vector3.ZERO)
