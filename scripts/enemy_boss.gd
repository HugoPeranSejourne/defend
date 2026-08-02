extends EnemyUnit
class_name EnemyBoss

func _ready() -> void:
	super._ready()
	max_health = 800.0
	health = 800.0
	max_stun_health = 1800.0
	stun_health = 1800.0
	base_move_speed = 4.2
	attack_range = 3.2
	attack_damage = 50.0
	attack_rate = 2.0
	is_melee = true
	scale = Vector3(1.4, 1.4, 1.4)

func _perform_machete_attack(target: Node3D) -> void:
	if not is_instance_valid(target):
		return
		
	if anim_player and anim_player.has_animation("machete_slash"):
		anim_player.play("machete_slash")
		
	var debris_script := load("res://scripts/debris_system.gd") as GDScript
	if debris_script and debris_script.has_method("spawn_rubble_explosion"):
		debris_script.call("spawn_rubble_explosion", get_tree().root, global_position + Vector3(0, 0.2, -1.0), 8)
	
	if target.has_method("take_damage"):
		target.call("take_damage", attack_damage, -transform.basis.z, "")
