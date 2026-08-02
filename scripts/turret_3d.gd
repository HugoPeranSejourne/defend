extends StaticBody3D
class_name Turret3D

signal turret_destroyed(turret: Turret3D)

@export_group("Caractéristiques Tourelle")
@export var turret_type: String = "Gatling" # "Gatling", "GatlingFlashball", "HeavyCannon", "Tranquilizer"
@export var is_non_lethal: bool = false
@export var max_health: float = 250.0
@export var health: float = 250.0
@export var attack_range: float = 22.0
@export var attack_damage: float = 15.0
@export var fire_rate: float = 0.2
@export var rotation_speed: float = 8.0

@export_group("Noeuds 3D")
@export var turret_head: Node3D
@export var barrel_left: MeshInstance3D
@export var barrel_right: MeshInstance3D

var _fire_cooldown: float = 0.0
var _scan_timer: float = 0.0
var _cached_target: Node3D = null
var _use_left_barrel: bool = true
var _is_destroyed: bool = false

func _ready() -> void:
	add_to_group("turrets")
	configure_type(turret_type)

func configure_type(type_name: String) -> void:
	turret_type = type_name
	match turret_type:
		"HeavyCannon":
			is_non_lethal = false
			max_health = 450.0
			health = 450.0
			attack_range = 28.0
			attack_damage = 55.0
			fire_rate = 1.0
			rotation_speed = 5.0
		"GatlingFlashball":
			is_non_lethal = true
			max_health = 250.0
			health = 250.0
			attack_range = 22.0
			attack_damage = 45.0
			fire_rate = 0.22
			rotation_speed = 8.0
		"Tranquilizer":
			is_non_lethal = true
			max_health = 400.0
			health = 400.0
			attack_range = 28.0
			attack_damage = 130.0
			fire_rate = 1.1
			rotation_speed = 5.0
		_: # Gatling classique Létale
			is_non_lethal = false
			max_health = 250.0
			health = 250.0
			attack_range = 22.0
			attack_damage = 15.0
			fire_rate = 0.2
			rotation_speed = 8.0

func take_damage(amount: float, _bullet_dir: Vector3 = Vector3.ZERO, _body_part: String = "") -> void:
	if _is_destroyed:
		return
	health = max(0.0, health - amount)
	if health <= 0.0:
		_destroy_turret()

func _destroy_turret() -> void:
	if _is_destroyed:
		return
	_is_destroyed = true
	emit_signal("turret_destroyed", self)
	queue_free()

func _physics_process(delta: float) -> void:
	if _is_destroyed:
		return
		
	if _fire_cooldown > 0.0:
		_fire_cooldown -= delta

	# Optimization : Scan de cible cadencé à 0.1s
	_scan_timer -= delta
	if _scan_timer <= 0.0 or not is_instance_valid(_cached_target):
		_scan_timer = 0.1
		_cached_target = _find_closest_enemy_to_base()

	if not is_instance_valid(_cached_target):
		return

	var dist := global_position.distance_to(_cached_target.global_position)
	if dist > attack_range:
		_cached_target = null
		return

	if turret_head:
		var dir := (_cached_target.global_position - global_position).normalized()
		dir.y = 0.0
		if dir.length_squared() > 0.001:
			var target_angle := atan2(-dir.x, -dir.z)
			turret_head.rotation.y = lerp_angle(turret_head.rotation.y, target_angle, delta * rotation_speed)

	if _fire_cooldown <= 0.0:
		_fire_cooldown = fire_rate
		_fire_at_target(_cached_target)

func _find_closest_enemy_to_base() -> Node3D:
	var enemies := get_tree().get_nodes_in_group("enemies")
	if enemies.is_empty():
		return null

	var base_pos := Vector3(0, 0, 75.0)
	var bases := get_tree().get_nodes_in_group("base")
	if not bases.is_empty():
		base_pos = (bases[0] as Node3D).global_position

	var best_target: Node3D = null
	var min_base_dist: float = 999999.0

	for enemy_node in enemies:
		if not is_instance_valid(enemy_node) or not enemy_node is Node3D:
			continue
		var enemy := enemy_node as Node3D
		var dist_to_turret := global_position.distance_to(enemy.global_position)
		if dist_to_turret <= attack_range:
			var dist_to_base := enemy.global_position.distance_to(base_pos)
			if dist_to_base < min_base_dist:
				min_base_dist = dist_to_base
				best_target = enemy

	return best_target

func _fire_at_target(target: Node3D) -> void:
	if not is_instance_valid(target):
		return

	var barrel_pos := global_position + Vector3(0, 0.8, 0)
	if turret_head:
		var active_barrel := barrel_left if _use_left_barrel else barrel_right
		_use_left_barrel = not _use_left_barrel
		if active_barrel:
			barrel_pos = active_barrel.global_position

	var target_center := target.global_position + Vector3(0, 0.9, 0)
	var shoot_dir := (target_center - barrel_pos).normalized()

	if is_non_lethal:
		if target.has_method("take_non_lethal_damage"):
			target.call("take_non_lethal_damage", attack_damage, shoot_dir)
		elif target.has_method("take_damage"):
			target.call("take_damage", attack_damage, shoot_dir, "")
	else:
		if target.has_method("take_damage"):
			target.call("take_damage", attack_damage, shoot_dir, "")

	_create_turret_laser_tracer(barrel_pos, target_center)

func _create_turret_laser_tracer(from: Vector3, to: Vector3) -> void:
	var mesh_instance_line := MeshInstance3D.new()
	var immediate_mesh := ImmediateMesh.new()
	var mat := StandardMaterial3D.new()

	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	match turret_type:
		"HeavyCannon":
			mat.albedo_color = Color(0.95, 0.2, 0.95, 0.9)
		"GatlingFlashball":
			mat.albedo_color = Color(0.2, 0.85, 1.0, 0.9)
		"Tranquilizer":
			mat.albedo_color = Color(0.9, 0.9, 0.2, 0.9)
		_:
			mat.albedo_color = Color(1.0, 0.6, 0.1, 0.9)

	immediate_mesh.surface_begin(Mesh.PRIMITIVE_LINES, mat)
	immediate_mesh.surface_add_vertex(from)
	immediate_mesh.surface_add_vertex(to)
	immediate_mesh.surface_end()

	mesh_instance_line.mesh = immediate_mesh
	get_tree().root.add_child(mesh_instance_line)

	var timer := get_tree().create_timer(0.05)
	timer.timeout.connect(mesh_instance_line.queue_free)
