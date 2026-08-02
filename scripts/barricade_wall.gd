extends StaticBody3D
class_name BarricadeWall

signal barricade_destroyed(barricade: BarricadeWall)

@export var max_health: float = 500.0
@export var health: float = 500.0
@export var wall_height: float = 3.5
@export var wall_width: float = 8.0

var _is_destroyed: bool = false
var attached_climbers: Array[Node3D] = []

func _ready() -> void:
	add_to_group("barricades")
	health = max_health

func take_damage(amount: float, _bullet_dir: Vector3 = Vector3.ZERO, _body_part: String = "") -> void:
	if _is_destroyed:
		return
	health = max(0.0, health - amount)
	_flash_impact()
	if health <= 0.0:
		_destroy_barricade()

func _flash_impact() -> void:
	var mesh := get_node_or_null("WallMesh") as MeshInstance3D
	if mesh:
		var orig_scale := Vector3.ONE
		mesh.scale = Vector3(1.03, 1.03, 1.03)
		var timer := get_tree().create_timer(0.08)
		timer.timeout.connect(func(): if is_instance_valid(mesh): mesh.scale = orig_scale)

func register_climber(enemy: Node3D) -> void:
	if not attached_climbers.has(enemy):
		attached_climbers.append(enemy)

func unregister_climber(enemy: Node3D) -> void:
	attached_climbers.erase(enemy)

func _destroy_barricade() -> void:
	if _is_destroyed:
		return
	_is_destroyed = true
	
	for climber in attached_climbers:
		if is_instance_valid(climber) and climber.has_method("collapse_from_wall"):
			climber.call("collapse_from_wall")

	var debris_script := load("res://scripts/debris_system.gd") as GDScript
	if debris_script and debris_script.has_method("spawn_rubble_explosion"):
		debris_script.call("spawn_rubble_explosion", get_tree().root, global_position + Vector3(0, 1.5, 0), 14)

	emit_signal("barricade_destroyed", self)
	queue_free()
