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

@export_group("Days Gone Swarm Escalade")
@export var climb_speed: float = 4.8
@export var max_climb_height: float = 14.0

@export_group("Noeuds du Modèle 3D & Animation")
@export var anim_player: AnimationPlayer
@export var character_pivot: Node3D

@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D

# Directives Tactiques d'Éditeur
var tactical_directive: String = "CHARGE_BASE" # CHARGE_BASE, HUNT_ALLIES, AMBUSH, PATROL
var waypoints: Array = []
var _current_waypoint_idx: int = 0
var _is_ambush_triggered: bool = false

var target_base: Node3D = null
var is_melee: bool = false
var _attack_cooldown: float = 0.0
var _stagger_timer: float = 0.0
var _knockback_velocity: Vector3 = Vector3.ZERO
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
var _is_dying: bool = false
var _glb_anim_player: AnimationPlayer = null

# Système Anti-Blocage IA & Escalade Swarm Days Gone
var _last_unstuck_check_pos: Vector3 = Vector3.ZERO
var _stuck_timer: float = 0.0

var is_climbing_wall: bool = false
var _current_wall: Node3D = null
var _climb_target_y: float = 3.6
var _climb_forward_dir: Vector3 = Vector3.FORWARD
var _is_vaulting: bool = false
var _vault_timer: float = 0.0

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

	var skel := find_child("Skeleton3D", true, false) as Skeleton3D
	if skel:
		skel.reset_bone_poses()

	_glb_anim_player = find_child("AnimationPlayer", true, false) as AnimationPlayer
	if _glb_anim_player and _glb_anim_player.has_animation("Idle"):
		_glb_anim_player.play("Idle")

	var mesh_inst := find_child("vanguard_Mesh", true, false) as MeshInstance3D
	if mesh_inst:
		mesh_inst.extra_cull_margin = 16.0
		var orig_mat := mesh_inst.get_active_material(0)
		if orig_mat and orig_mat is StandardMaterial3D:
			var mat := orig_mat.duplicate() as StandardMaterial3D
			mat.albedo_color = Color(0.9, 0.25, 0.25, 1.0)
			mat.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
			mesh_inst.set_surface_override_material(0, mat)

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

func set_directive(dir: String, waypoints_list: Array = []) -> void:
	tactical_directive = dir
	waypoints = waypoints_list
	_current_waypoint_idx = 0

func get_current_move_speed() -> float:
	var spd := base_move_speed
	if is_limping:
		spd *= 0.55
	return spd

func take_damage(amount: float, bullet_dir: Vector3 = Vector3.ZERO, body_part: String = "torso") -> void:
	if _is_dying:
		return

	_last_hit_part = body_part
	var mult: float = BODY_PART_MULTIPLIERS.get(body_part, 1.0)
	var final_damage := amount * mult

	health = max(0.0, health - final_damage)
	stun_health = max(0.0, stun_health - final_damage * 1.5)

	# Interruption de l'escalade si touché en montant le mur
	if is_climbing_wall:
		collapse_from_wall()

	if body_part.begins_with("thigh") or body_part.begins_with("calf") or body_part.begins_with("pelvis"):
		is_limping = true
	elif body_part.begins_with("shoulder") or body_part.begins_with("bicep") or body_part.begins_with("forearm"):
		is_arm_injured = true

	if bullet_dir.length_squared() > 0.001:
		_knockback_velocity += bullet_dir.normalized() * randf_range(4.0, 9.0)

	_stagger_timer = 0.25
	_flash_red_hit()

	if health <= 0:
		_die(bullet_dir)

func take_non_lethal_damage(stun_amount: float, hit_dir: Vector3 = Vector3.ZERO) -> void:
	if _is_dying:
		return
	stun_health = max(0.0, stun_health - stun_amount)
	_stagger_timer = 0.4
	if hit_dir.length_squared() > 0.001:
		_knockback_velocity += hit_dir.normalized() * 5.0
	_flash_blue_hit()

	if is_climbing_wall:
		collapse_from_wall()

	if stun_health <= 0.0:
		_die(hit_dir, true)

func _flash_red_hit() -> void:
	var mesh_inst := find_child("vanguard_Mesh", true, false) as MeshInstance3D
	if mesh_inst:
		var orig_mat := mesh_inst.get_active_material(0)
		if orig_mat and orig_mat is StandardMaterial3D:
			orig_mat.albedo_color = Color(1.0, 0.9, 0.2, 1.0)
			var timer := get_tree().create_timer(0.08)
			timer.timeout.connect(func():
				if is_instance_valid(orig_mat):
					orig_mat.albedo_color = Color(0.9, 0.25, 0.25, 1.0)
			)

func _flash_blue_hit() -> void:
	var mesh_inst := find_child("vanguard_Mesh", true, false) as MeshInstance3D
	if mesh_inst:
		var orig_mat := mesh_inst.get_active_material(0)
		if orig_mat and orig_mat is StandardMaterial3D:
			orig_mat.albedo_color = Color(0.2, 0.8, 1.0, 1.0)
			var timer := get_tree().create_timer(0.12)
			timer.timeout.connect(func():
				if is_instance_valid(orig_mat):
					orig_mat.albedo_color = Color(0.9, 0.25, 0.25, 1.0)
			)

func _die(bullet_dir: Vector3 = Vector3.ZERO, is_non_lethal := false) -> void:
	if _is_dying:
		return
	_is_dying = true
	if is_climbing_wall:
		collapse_from_wall()
	remove_from_group("enemies")
	enemy_died.emit(self)

	var stages := get_tree().get_nodes_in_group("main_stages")
	if not stages.is_empty() and stages[0].has_method("record_enemy_neutralized"):
		stages[0].call("record_enemy_neutralized", is_non_lethal)

	var corpse_mgrs := get_tree().get_nodes_in_group("corpse_managers")
	if not corpse_mgrs.is_empty() and corpse_mgrs[0].has_method("add_corpse"):
		corpse_mgrs[0].call("add_corpse", global_position, rotation.y, true)

	queue_free()

func start_days_gone_climb(target_y: float, wall_node: Node3D = null) -> void:
	if is_climbing_wall or _is_dying:
		return
	is_climbing_wall = true
	_climb_target_y = target_y
	_current_wall = wall_node
	_climb_forward_dir = -transform.basis.z.normalized()
	_is_vaulting = false

	if is_instance_valid(_current_wall) and _current_wall.has_method("register_climber"):
		_current_wall.call("register_climber", self)
		var lat_offset := (randf() - 0.5) * 0.9
		global_position += transform.basis.x * lat_offset

		# Écroulement de corniche si surcharge (>4 ennemis sur le même mur)
		var climbers: Array = _current_wall.get("attached_climbers") if _current_wall.get("attached_climbers") != null else []
		if climbers.size() >= 4:
			print("[SWARM OVERLOAD] Corniche effondrée sous le poids de l'essaim !")
			var debris_script := load("res://scripts/debris_system.gd") as GDScript
			if debris_script and debris_script.has_method("spawn_rubble_explosion"):
				debris_script.call("spawn_rubble_explosion", get_tree().root, global_position + Vector3(0, 1.5, 0), 12)
			for climber in climbers:
				if is_instance_valid(climber) and climber.has_method("collapse_from_wall"):
					climber.call("collapse_from_wall")

func collapse_from_wall() -> void:
	if is_climbing_wall:
		is_climbing_wall = false
		_is_vaulting = false
		if character_pivot:
			character_pivot.rotation = Vector3.ZERO
		if is_instance_valid(_current_wall) and _current_wall.has_method("unregister_climber"):
			_current_wall.call("unregister_climber", self)
			_current_wall = null
		_stagger_timer = 0.6
		_knockback_velocity = -_climb_forward_dir * 5.0 + Vector3(0, 3.5, 0)

func _play_anim(anim_name: String) -> void:
	if _is_dying or not _glb_anim_player:
		return
	var target_anim := "Idle"
	match anim_name:
		"run": target_anim = "Run"
		"walk": target_anim = "Walk"
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

	# --- Escalade Procédurale Days Gone Swarm ---
	if is_climbing_wall:
		if _is_vaulting:
			_vault_timer -= delta
			global_position += _climb_forward_dir * delta * 4.0
			if character_pivot:
				character_pivot.rotation.x = lerp_angle(character_pivot.rotation.x, 0.0, delta * 12.0)
				character_pivot.rotation.z = lerp_angle(character_pivot.rotation.z, 0.0, delta * 12.0)
			if _vault_timer <= 0.0:
				_is_vaulting = false
				is_climbing_wall = false
				if is_instance_valid(_current_wall) and _current_wall.has_method("unregister_climber"):
					_current_wall.call("unregister_climber", self)
					_current_wall = null
			return

		# Ascension verticale rythmée avec oscillation de grimpette
		global_position.y += delta * climb_speed
		global_position += _climb_forward_dir * delta * 0.45

		_play_anim("run")

		if character_pivot:
			var climb_time := Time.get_ticks_msec() * 0.016
			var sway := sin(climb_time) * 0.24
			var pitch := deg_to_rad(22.0)
			character_pivot.rotation = Vector3(pitch, 0.0, sway)

		# Franchissement de la corniche / du sommet du barrage
		if global_position.y >= _climb_target_y:
			_is_vaulting = true
			_vault_timer = 0.35
			global_position.y = _climb_target_y + 0.25
			if character_pivot:
				character_pivot.rotation = Vector3(deg_to_rad(-18.0), 0, 0)
		return

	if not is_on_floor():
		velocity.y -= _gravity * delta

	# Recherche d'obstacles / murs devant l'ennemi pour déclencher l'escalade
	_check_and_probe_wall_climb()

	# Recherche de la Base HQ
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

	# Engagement du combat
	if is_instance_valid(target_to_attack) and closest_dist <= attack_range:
		velocity.x = _knockback_velocity.x
		velocity.z = _knockback_velocity.z
		move_and_slide()

		var dir := (target_to_attack.global_position - global_position).normalized()
		var target_angle := atan2(dir.x, dir.z)
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

	# Navigation vers la Base HQ ou Waypoint
	var dest_pos := target_base.global_position if is_instance_valid(target_base) else global_position
	if tactical_directive == "PATROL" and not waypoints.is_empty():
		dest_pos = waypoints[_current_waypoint_idx]
		if global_position.distance_to(dest_pos) <= 1.2:
			_current_waypoint_idx = (_current_waypoint_idx + 1) % waypoints.size()
			dest_pos = waypoints[_current_waypoint_idx]

	if nav_agent:
		nav_agent.set_target_position(dest_pos)
		if not nav_agent.is_navigation_finished():
			var next_pos := nav_agent.get_next_path_position()
			var dir := (next_pos - global_position)
			dir.y = 0.0

			if dir.length_squared() > 0.001:
				dir = dir.normalized()
				var target_vel := dir * active_speed
				var target_angle := atan2(dir.x, dir.z)
				rotation.y = lerp_angle(rotation.y, target_angle, delta * rotation_speed)

				_play_anim("run")

				if nav_agent.avoidance_enabled:
					nav_agent.set_velocity(target_vel)
				else:
					velocity.x = target_vel.x + _knockback_velocity.x
					velocity.z = target_vel.z + _knockback_velocity.z
					move_and_slide()

func _check_and_probe_wall_climb() -> void:
	if is_climbing_wall or _is_dying:
		return

	if is_on_wall():
		for i in get_slide_collision_count():
			var col := get_slide_collision(i)
			var collider := col.get_collider() as Node3D
			if collider:
				var wall_top := global_position.y + 3.5
				if collider is BarricadeWall:
					wall_top = global_position.y + (collider as BarricadeWall).wall_height
				elif collider.has_meta("size"):
					var sz: Vector3 = collider.get_meta("size")
					wall_top = collider.global_position.y + sz.y
				start_days_gone_climb(wall_top, collider)
				break

func _perform_machete_attack(target: Node3D) -> void:
	if not is_instance_valid(target):
		return
	_play_anim("idle")
	if target.has_method("take_damage"):
		target.call("take_damage", attack_damage, transform.basis.z, "")

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
	if not _is_dying and _stagger_timer <= 0.0 and not is_climbing_wall:
		velocity.x = safe_velocity.x + _knockback_velocity.x
		velocity.z = safe_velocity.z + _knockback_velocity.z
		move_and_slide()
