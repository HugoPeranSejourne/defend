extends StaticBody3D
class_name BaseStructure

signal health_changed(current_hp: float, max_hp: float)
signal base_destroyed()

@export var max_health: float = 1000.0
@export var health: float = 1000.0

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D

var _is_destroyed: bool = false

func _ready() -> void:
	add_to_group("base")
	health = max_health
	emit_signal("health_changed", health, max_health)
	_update_hud_hp()

func take_damage(amount: float, _bullet_dir: Vector3 = Vector3.ZERO, _body_part: String = "") -> void:
	if _is_destroyed:
		return
		
	health = max(0.0, health - amount)
	emit_signal("health_changed", health, max_health)
	_update_hud_hp()
	_create_damage_spark()
	
	if health <= 0.0:
		_destroy_base()

func _update_hud_hp() -> void:
	var huds := get_tree().get_nodes_in_group("main_huds")
	if not huds.is_empty() and huds[0].has_method("update_base_hp"):
		huds[0].call("update_base_hp", health, max_health)

func _create_damage_spark() -> void:
	if not mesh_instance:
		return
		
	var orig_scale := mesh_instance.scale
	mesh_instance.scale = orig_scale * 0.96
	
	var timer := get_tree().create_timer(0.06)
	timer.timeout.connect(func(): if is_instance_valid(mesh_instance): mesh_instance.scale = orig_scale)

func _destroy_base() -> void:
	if _is_destroyed:
		return
	_is_destroyed = true
	emit_signal("base_destroyed")
	
	var huds := get_tree().get_nodes_in_group("main_huds")
	if not huds.is_empty() and huds[0].has_method("show_game_over"):
		huds[0].call("show_game_over", "GAME OVER ! La Base Joueur a été totalement détruite par les envahisseurs.")
