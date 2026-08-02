extends CharacterBody3D
class_name EnemyUnit

signal enemy_died(enemy: EnemyUnit)

@export_group("Caractéristiques Ennemi")
@export var max_health: float = 100.0
@export var health: float = 100.0
@export var max_stun_health: float = 250.0
@export var stun_health: float = 250.0

@export var base_move_speed: float = 6.5
@export var rotation_speed: float = 10.0
@export var attack_damage: float = 16.0
@export var attack_rate: float = 1.2
@export var attack_range: float = 18.0

@export_group("Noeuds du Modèle 3D & Animation")
@export var anim_player: AnimationPlayer
@export var character_pivot: Node3D

@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D

var target_base: Node3D = null
var is_melee: bool = false
var _attack_cooldown: float = 0.0
var _stagger_timer: float = 0.0
var _knockback_velocity: Vector3 = Vector3.ZERO
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
var _is_dying: bool = false
var _glb_anim_player: AnimationPlayer = null

# Système Anti-Blocage IA
var _last_unstuck_check_pos: Vector3 = Vector3.ZERO
var _stuck_timer: float = 0.0
var _is_unstucking: bool = false
var _unstuck_duration: float = 0.0
var _unstuck_dir: Vector3 = Vector3.ZERO

# Système d'Escalade de Barricades Style World War Z
var is_climbing_wall: bool = false
var _current_wall: Node3D = null
var _climb_target_y: float = 3.6

# Dégâts localisés et état de santé des membres
var is_limping: bool = false
var is_arm_injured: bool = false
var _last_hit_part: String = "torso"

const BODY_PART_MULTIPLIERS: Dictionary = {
	"head_front": 2.8, "head_back": 2.8, "head_top": 2.5, "face_visor": 3.0, "neck": 2.6, "jaw": 2.6,
	"chest_upper_left": 1.2, "chest_upper_right": 1.2, "chest_lower_abdomen": 1.1, "sternum": 1.25,
	"spine_upper": 1.2, "spine_lower": 1.1, "flank_left": 1.0, "flank_right": 1.0,
	"shoulder_left": 0.75, "shoulder_right": 0.75, "bicep_left": 0.7, "bicep_right": 0.7,
	"elbow_left": 0.65, "elbow_right": 0.65, "forearm_left": 0.65, "forearm_right": 0.65,
	"hand_left": 0.6, "hand_right": 0.6,
	"pelvis_hip_left": 0.7, "pelvis_hip_right": 0.7, "thigh_left": 0.65, "thigh_right": 0.65,
	"calf_left": 0.6, "calf_right": 0.6
}

func _ready() -> void:
	add_to_group("enemies")
	health = max_health
	stun_health = max_stun_health
	_last_unstuck_check_pos = global_position
	
	# Évaluation forcée du squelette 3D et du moteur d'animations GLTF ("Idle", "Run", "Walk")
	var skel := find_child("Skeleton3D", true, false) as Skeleton3D
	if skel:
		skel.reset_bone_poses()
		
	_glb_anim_player = find_child("AnimationPlayer", true, false) as AnimationPlayer
	if _glb_anim_player and _glb_anim_player.has_animation("Idle"):
		_glb_anim_player.play("Idle")

	var mesh_inst := find_child("vanguard_Mesh", true, false) as MeshInstance3D
	if mesh_inst:
		mesh_inst.extra_cull_margin = 8.0
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.9, 0.2, 0.2, 1.0)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
		mat.roughness = 0.45
		mesh_inst.material_override = mat
	
	is_melee = (randf() < 0.7)
	if is_melee:
		attack_range = 2.2
		attack_damage = 16.0
		base_move_speed = 7.5
	else:
		attack_range = 18.0
		attack_damage = 8.0

	if nav_agent:
		nav_agent.avoidance_enabled = true
		nav_agent.radius = 0.85
		nav_agent.max_speed = base_move_speed
		nav_agent.velocity_computed.connect(_on_velocity_computed)
		
	_play_anim("idle")

func get_current_move_speed() -> float:
	return base_move_speed * 0.5 if is_limping else base_move_speed

func set_target_base(base_node: Node3D) -> void:
	target_base = base_node
	if nav_agent and target_base:
		nav_agent.set_target_position(target_base.global_position)

func take_damage(amount: float, bullet_dir: Vector3 = Vector3.ZERO, body_part: String = "") -> void:
	if _is_dying:
		return

	if body_part == "":
		var parts: Array = BODY_PART_MULTIPLIERS.keys()
		body_part = parts[randi() % parts.size()]
		
	_last_hit_part = body_part
	var mult: float = BODY_PART_MULTIPLIERS.get(body_part, 1.0)
	var final_damage := amount * mult

	if body_part.begins_with("thigh_") or body_part.begins_with("calf_") or body_part.begins_with("pelvis_"):
		is_limping = true
	elif body_part.begins_with("shoulder_") or body_part.begins_with("bicep_") or body_part.begins_with("forearm_"):
		is_arm_injured = true

	health = max(0.0, health - final_damage)
	
	if bullet_dir != Vector3.ZERO:
		_knockback_velocity += bullet_dir.normalized() * randf_range(6.0, 12.0)
	else:
		_knockback_velocity += -transform.basis.z * randf_range(5.0, 9.0)
		
	_stagger_timer = randf_range(0.2, 0.35)
	_flash_color(Color(1.0, 0.25, 0.25))
	
	if health <= 0:
		_die_lethal()

func take_non_lethal_damage(amount: float, bullet_dir: Vector3 = Vector3.ZERO) -> void:
	if _is_dying:
		return

	stun_health = max(0.0, stun_health - amount)
	
	if bullet_dir != Vector3.ZERO:
		_knockback_velocity += bullet_dir.normalized() * randf_range(4.0, 8.0)
		
	_stagger_timer = 0.2
	_flash_color(Color(0.2, 0.85, 1.0))
	
	if stun_health <= 0:
		_pacify_non_lethal()

func _flash_color(col: Color) -> void:
	if character_pivot:
		var orig_scale := Vector3.ONE
		character_pivot.scale = Vector3(1.15, 0.9, 1.15)
		var timer := get_tree().create_timer(0.08)
		timer.timeout.connect(func(): if is_instance_valid(character_pivot): character_pivot.scale = orig_scale)

func _die_lethal() -> void:
	if _is_dying:
		return
	_is_dying = true
	
	remove_from_group("enemies")
	
	var stages := get_tree().get_nodes_in_group("main_stages")
	if not stages.is_empty() and stages[0].has_method("adjust_public_opinion"):
		stages[0].adjust_public_opinion(-1.5)

	var build_mgrs := get_tree().get_nodes_in_group("build_managers")
	if not build_mgrs.is_empty() and build_mgrs[0].has_method("add_credits"):
		build_mgrs[0].add_credits(25)

	var corpse_mgrs := get_tree().get_nodes_in_group("corpse_managers")
	if not corpse_mgrs.is_empty() and corpse_mgrs[0].has_method("add_corpse"):
		corpse_mgrs[0].call("add_corpse", global_position, rotation.y, true)

	emit_signal("enemy_died", self)
	_create_death_particles(Color(1.0, 0.25, 0.1))
	queue_free()

func _pacify_non_lethal() -> void:
	if _is_dying:
		return
	_is_dying = true
	
	remove_from_group("enemies")

	var stages := get_tree().get_nodes_in_group("main_stages")
	if not stages.is_empty() and stages[0].has_method("adjust_public_opinion"):
		stages[0].adjust_public_opinion(0.5)

	var build_mgrs := get_tree().get_nodes_in_group("build_managers")
	if not build_mgrs.is_empty() and build_mgrs[0].has_method("add_credits"):
		build_mgrs[0].add_credits(25)

	var corpse_mgrs := get_tree().get_nodes_in_group("corpse_managers")
	if not corpse_mgrs.is_empty() and corpse_mgrs[0].has_method("add_corpse"):
		corpse_mgrs[0].call("add_corpse", global_position, rotation.y, true)

	emit_signal("enemy_died", self)
	_create_death_particles(Color(0.2, 0.9, 1.0))
	queue_free()

func _create_death_particles(particle_color: Color) -> void:
	var spark := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.4
	sphere.height = 0.8
	
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = particle_color
	sphere.material = mat
	
	spark.mesh = sphere
	get_tree().root.add_child(spark)
	spark.global_position = global_position + Vector3(0, 0.4, 0)
	
	var timer := get_tree().create_timer(0.2)
	timer.timeout.connect(spark.queue_free)

func collapse_from_wall() -> void:
	if is_climbing_wall:
		is_climbing_wall = false
		if is_instance_valid(_current_wall) and _current_wall.has_method("unregister_climber"):
			_current_wall.call("unregister_climber", self)
		_current_wall = null
		global_position.y = 0.0
		_stagger_timer = 0.5
		_knockback_velocity = -transform.basis.z * 6.0

func _play_anim(anim_name: String) -> void:
	if _is_dying or not _glb_anim_player:
		return
	var target_anim := "Idle"
	match anim_name:
		"run": target_anim = "Run"
		"walk": target_anim = "Walk"
		"walk_backward": target_anim = "Walk"
		"idle": target_anim = "Idle"
		_: target_anim = "Idle"

	if _glb_anim_player.has_animation(target_anim) and _glb_anim_player.current_animation != target_anim:
		_glb_anim_player.play(target_anim)

func _physics_process(delta: float) -> void:
	if _is_dying:
		return
		
	if _attack_cooldown > 0.0:
		_attack_cooldown -= delta
	if _stagger_timer > 0.0:
		_stagger_timer -= delta
		
	_knockback_velocity = _knockback_velocity.lerp(Vector3.ZERO, delta * 10.0)

	# 1. Logique d'Escalade de Barricades Style World War Z
	if is_climbing_wall:
		_play_anim("run")
		global_position.y += delta * 3.5
		global_position += -transform.basis.z * delta * 1.5
		
		if global_position.y >= _climb_target_y:
			is_climbing_wall = false
			global_position.y = 0.0
			global_position += -transform.basis.z * 2.5
			if is_instance_valid(_current_wall) and _current_wall.has_method("unregister_climber"):
				_current_wall.call("unregister_climber", self)
				_current_wall = null
		return

	if not is_on_floor():
		velocity.y -= _gravity * delta

	# Check de détection des barricades à escalader
	var barricades := get_tree().get_nodes_in_group("barricades")
	for b_node in barricades:
		if is_instance_valid(b_node) and b_node is Node3D:
			var wall := b_node as Node3D
			var dist := global_position.distance_to(wall.global_position)
			if dist <= 2.2:
				is_climbing_wall = true
				_current_wall = wall
				if wall.has_method("register_climber"):
					wall.call("register_climber", self)
				var wall_h: float = wall.get("wall_height") if wall.get("wall_height") != null else 3.5
				_climb_target_y = wall_h + 0.2
				return

	# 2. Gestion de la manœuvre de déblocage (Anti-Stuck AI)
	if _is_unstucking:
		_unstuck_duration -= delta
		velocity.x = _unstuck_dir.x * (base_move_speed * 0.85) + _knockback_velocity.x
		velocity.z = _unstuck_dir.z * (base_move_speed * 0.85) + _knockback_velocity.z
		move_and_slide()
		_play_anim("walk_backward")
		if _unstuck_duration <= 0.0:
			_is_unstucking = false
			_stuck_timer = 0.0
			_last_unstuck_check_pos = global_position
		return

	_stuck_timer += delta
	if _stuck_timer >= 0.6:
		var dist_moved := global_position.distance_to(_last_unstuck_check_pos)
		_last_unstuck_check_pos = global_position
		_stuck_timer = 0.0
		
		if dist_moved < 0.35 and _stagger_timer <= 0.0:
			_is_unstucking = true
			_unstuck_duration = 0.85
			var side := 1.0 if randf() > 0.5 else -1.0
			_unstuck_dir = (-transform.basis.z * 1.2 + transform.basis.x * (side * 1.5)).normalized()
			return

	if not is_instance_valid(target_base):
		var bases := get_tree().get_nodes_in_group("base")
		if not bases.is_empty():
			target_base = bases[0] as Node3D

	var target_to_attack: Node3D = target_base
	var closest_dist: float = 99999.0
	
	if is_instance_valid(target_base):
		closest_dist = global_position.distance_to(target_base.global_position)
		
	var units := get_tree().get_nodes_in_group("units")
	for unit in units:
		if is_instance_valid(unit) and unit is Node3D:
			var d := global_position.distance_to((unit as Node3D).global_position)
			if d < closest_dist and d <= (attack_range + 1.5):
				closest_dist = d
				target_to_attack = unit as Node3D

	var active_speed := get_current_move_speed()

	if is_instance_valid(target_to_attack) and closest_dist <= attack_range:
		velocity.x = _knockback_velocity.x
		velocity.z = _knockback_velocity.z
		move_and_slide()
		
		var dir := (target_to_attack.global_position - global_position).normalized()
		var target_angle := atan2(-dir.x, -dir.z)
		rotation.y = lerp_angle(rotation.y, target_angle, delta * rotation_speed)
		
		_play_anim("idle")
		
		if _attack_cooldown <= 0.0 and _stagger_timer <= 0.0:
			var cd := attack_rate * 1.4 if is_arm_injured else attack_rate
			_attack_cooldown = cd
			if is_melee:
				_perform_machete_attack(target_to_attack)
			else:
				_enemy_shoot_target(target_to_attack)
		return

	if _stagger_timer > 0.0:
		velocity.x = _knockback_velocity.x
		velocity.z = _knockback_velocity.z
		move_and_slide()
		_play_anim("idle")
		return

	if nav_agent and is_instance_valid(target_base):
		nav_agent.set_target_position(target_base.global_position)
		if not nav_agent.is_navigation_finished():
			var next_pos := nav_agent.get_next_path_position()
			var dir := (next_pos - global_position)
			dir.y = 0.0
			
			if dir.length_squared() > 0.001:
				dir = dir.normalized()
				var target_vel := dir * active_speed
				var target_angle := atan2(-dir.x, -dir.z)
				rotation.y = lerp_angle(rotation.y, target_angle, delta * rotation_speed)
				_play_anim("run")
				
				if nav_agent.avoidance_enabled:
					nav_agent.set_velocity(target_vel)
				else:
					velocity.x = target_vel.x + _knockback_velocity.x
					velocity.z = target_vel.z + _knockback_velocity.z
					move_and_slide()

func _perform_machete_attack(target: Node3D) -> void:
	if not is_instance_valid(target):
		return
	_play_anim("idle")
	if target.has_method("take_damage"):
		target.call("take_damage", attack_damage, -transform.basis.z, "")

func _enemy_shoot_target(target: Node3D) -> void:
	if not is_instance_valid(target):
		return
		
	var origin := global_position + Vector3(0, 1.3, 0)
	var target_pos := target.global_position + Vector3(0, 1.0, 0)
	
	_play_anim("idle")
	
	if target.has_method("take_damage"):
		target.call("take_damage", attack_damage, Vector3.ZERO, "")
		
	_create_enemy_laser_tracer(origin, target_pos)

func _create_enemy_laser_tracer(from: Vector3, to: Vector3) -> void:
	var mesh_instance_line := MeshInstance3D.new()
	var immediate_mesh := ImmediateMesh.new()
	var mat := StandardMaterial3D.new()
	
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.15, 0.15, 0.9)
	
	immediate_mesh.surface_begin(Mesh.PRIMITIVE_LINES, mat)
	immediate_mesh.surface_add_vertex(from)
	immediate_mesh.surface_add_vertex(to)
	immediate_mesh.surface_end()
	
	mesh_instance_line.mesh = immediate_mesh
	get_tree().root.add_child(mesh_instance_line)
	
	var timer := get_tree().create_timer(0.05)
	timer.timeout.connect(mesh_instance_line.queue_free)

func _on_velocity_computed(safe_velocity: Vector3) -> void:
	if not _is_dying and _stagger_timer <= 0.0 and not _is_unstucking and not is_climbing_wall:
		velocity.x = safe_velocity.x + _knockback_velocity.x
		velocity.z = safe_velocity.z + _knockback_velocity.z
		move_and_slide()
