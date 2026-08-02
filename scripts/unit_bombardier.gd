extends Unit3D
class_name UnitBombardier

@export var explosion_radius: float = 6.0
@export var explosion_damage: float = 80.0

func _ready() -> void:
	super._ready()
	unit_name = "Bombardier Grenadier"
	auto_attack_range = 22.0
	auto_attack_cooldown = 1.8

func _auto_shoot_at_target(target: Node3D) -> void:
	if not is_instance_valid(target):
		return
		
	var dir := (target.global_position - global_position).normalized()
	dir.y = 0.0
	if dir.length_squared() > 0.001:
		var target_angle := atan2(-dir.x, -dir.z)
		rotation.y = lerp_angle(rotation.y, target_angle, 0.4)

	var target_pos := target.global_position
	if anim_player and anim_player.has_animation("shoot"):
		anim_player.play("shoot")

	_create_grenade_arc(global_position + Vector3(0, 1.4, 0), target_pos)

func _create_grenade_arc(from: Vector3, to: Vector3) -> void:
	var grenade := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.2
	sphere.height = 0.4
	
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.15, 0.15, 0.15, 1.0)
	mat.metallic = 0.8
	sphere.material = mat
	
	grenade.mesh = sphere
	get_tree().root.add_child(grenade)
	grenade.global_position = from
	
	var tween := get_tree().create_tween()
	var mid_pos := (from + to) * 0.5 + Vector3(0, 4.0, 0)
	
	tween.tween_property(grenade, "global_position", mid_pos, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(grenade, "global_position", to, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	
	tween.finished.connect(func():
		if is_instance_valid(grenade):
			grenade.queue_free()
		_explode_at_position(to)
	)

func _explode_at_position(impact_pos: Vector3) -> void:
	# 1. Effet d'explosion 3D & Son de déflagration
	var mgrs := get_tree().get_nodes_in_group("sound_managers")
	if not mgrs.is_empty():
		mgrs[0].call("play_explosion", get_tree().root, impact_pos)

	var fire_mesh := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = explosion_radius * 0.6
	sphere.height = explosion_radius * 1.2
	
	var fire_mat := StandardMaterial3D.new()
	fire_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fire_mat.albedo_color = Color(1.0, 0.45, 0.05, 0.95)
	sphere.material = fire_mat
	
	fire_mesh.mesh = sphere
	get_tree().root.add_child(fire_mesh)
	fire_mesh.global_position = impact_pos + Vector3(0, 0.5, 0)
	
	var timer := get_tree().create_timer(0.25)
	timer.timeout.connect(fire_mesh.queue_free)

	# Débris 3D
	var debris_script := load("res://scripts/debris_system.gd") as GDScript
	if debris_script and debris_script.has_method("spawn_rubble_explosion"):
		debris_script.call("spawn_rubble_explosion", get_tree().root, impact_pos, 10)

	# 2. Dégâts de Zone AoE sur tous les ennemis à proximité (6m)
	var enemies := get_tree().get_nodes_in_group("enemies")
	for enemy_node in enemies:
		if is_instance_valid(enemy_node) and enemy_node is Node3D:
			var enemy := enemy_node as Node3D
			var dist := impact_pos.distance_to(enemy.global_position)
			if dist <= explosion_radius:
				var blast_dir := (enemy.global_position - impact_pos).normalized()
				var falloff_damage := explosion_damage * (1.0 - (dist / explosion_radius) * 0.5)
				if is_fps_weapon_non_lethal and enemy.has_method("take_non_lethal_damage"):
					enemy.call("take_non_lethal_damage", falloff_damage, blast_dir)
				elif enemy.has_method("take_damage"):
					enemy.call("take_damage", falloff_damage, blast_dir, "chest_lower_abdomen")
