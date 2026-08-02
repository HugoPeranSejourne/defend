extends EnemyUnit
class_name EnemySniper

func _ready() -> void:
	super._ready()
	max_health = 75.0
	health = 75.0
	attack_range = 45.0
	attack_damage = 35.0
	attack_rate = 2.2
	is_melee = false

func _physics_process(delta: float) -> void:
	if _is_dying:
		return
		
	if _attack_cooldown > 0.0:
		_attack_cooldown -= delta
		
	var units := get_tree().get_nodes_in_group("units")
	var closest_unit: Node3D = null
	var min_d: float = 99999.0
	
	for u_node in units:
		if is_instance_valid(u_node) and u_node is Node3D:
			var d := global_position.distance_to((u_node as Node3D).global_position)
			if d < min_d and d <= attack_range:
				min_d = d
				closest_unit = u_node as Node3D

	if is_instance_valid(closest_unit):
		var dir := (closest_unit.global_position - global_position).normalized()
		var target_angle := atan2(-dir.x, -dir.z)
		rotation.y = lerp_angle(rotation.y, target_angle, delta * rotation_speed)
		
		_play_anim("idle")
		if _attack_cooldown <= 0.0:
			_attack_cooldown = attack_rate
			_enemy_shoot_target(closest_unit)
