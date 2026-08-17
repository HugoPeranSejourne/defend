extends CharacterBody3D
class_name Unit3D

signal unit_selected(unit: Unit3D)
signal unit_deselected(unit: Unit3D)

@export_group("Caractéristiques Soldat")
@export var unit_name: String = "Soldat de Défense"
@export var max_health: float = 120.0
@export var health: float = 120.0
@export var move_speed: float = 6.0
@export var rotation_speed: float = 12.0
@export var auto_attack_range: float = 24.0
@export var auto_attack_cooldown: float = 0.35
@export var auto_attack_damage: float = 20.0

@export_group("Max Payne Bullet-Time & Shoot Dodge")
@export var bullet_time_max_energy: float = 100.0
@export var bullet_time_energy: float = 100.0
@export var bullet_time_drain_rate: float = 25.0
@export var bullet_time_recharge_rate: float = 18.0
@export var bullet_time_time_scale: float = 0.20
@export var shoot_dodge_jump_force: float = 6.5
@export var shoot_dodge_speed: float = 13.0

@export_group("Vue FPS & Armes")
@export var mouse_sensitivity: float = 0.0025
@export var joy_sensitivity: float = 2.5
@export var is_fps_weapon_non_lethal: bool = false

@export_group("Noeuds du Modèle 3D & Animation")
@export var anim_player: AnimationPlayer
@export var selection_ring: MeshInstance3D
@export var character_pivot: Node3D
@export var head_pivot: Node3D
@export var fps_camera: Camera3D
@export var gun_raycast: RayCast3D

@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D

# Directives Tactiques d'Éditeur
var tactical_directive: String = "GUARD" # GUARD, PATROL, ATTACK_MOVE, SNIPER_POST
var waypoints: Array = []
var _current_waypoint_idx: int = 0

var is_selected: bool = false
var is_fps_controlled: bool = false
var is_bullet_time_active: bool = false
var is_shoot_dodging: bool = false
var shoot_dodge_dir: Vector3 = Vector3.ZERO
var _target_pivot_rot: Vector3 = Vector3.ZERO
var _has_started_dodge_jump: bool = false

var _auto_shoot_timer: float = 0.0
var _is_dying: bool = false
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)

var _cam_pitch: float = 0.0
var _fps_hud_node: Control = null
var _glb_anim_player: AnimationPlayer = null

func _ready() -> void:
	add_to_group("units")
	health = max_health
	set_selected(false)

	_glb_anim_player = find_child("AnimationPlayer", true, false) as AnimationPlayer
	if _glb_anim_player and _glb_anim_player.has_animation("Idle"):
		_glb_anim_player.play("Idle")

	var mesh_inst := find_child("vanguard_Mesh", true, false) as MeshInstance3D
	if mesh_inst:
		mesh_inst.extra_cull_margin = 4.0
		var orig_mat := mesh_inst.get_active_material(0)
		if orig_mat and orig_mat is StandardMaterial3D:
			var mat := orig_mat.duplicate() as StandardMaterial3D
			mat.albedo_color = Color(0.2, 0.6, 1.0, 1.0)
			mat.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
			mesh_inst.set_surface_override_material(0, mat)

	if nav_agent:
		nav_agent.avoidance_enabled = true
		nav_agent.radius = 0.6
		nav_agent.velocity_computed.connect(_on_velocity_computed)

	var hud := get_node_or_null("FPSHUD")
	if hud and hud is Control:
		_fps_hud_node = hud as Control
		_fps_hud_node.visible = false

func set_directive(dir: String, waypoints_list: Array = []) -> void:
	tactical_directive = dir
	waypoints = waypoints_list
	_current_waypoint_idx = 0

	if tactical_directive == "SNIPER_POST":
		auto_attack_range = 50.0
		auto_attack_damage = 35.0

func _play_human_anim(anim_name: String) -> void:
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

func set_selected(selected: bool) -> void:
	is_selected = selected
	if selection_ring and not is_fps_controlled:
		selection_ring.visible = selected

func enter_fps_mode() -> void:
	is_fps_controlled = true
	if fps_camera:
		fps_camera.make_current()
	if selection_ring:
		selection_ring.visible = false
	if is_instance_valid(_fps_hud_node):
		_fps_hud_node.call("set_hud_visible", true)
		_update_fps_hud_weapon_text()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func exit_fps_mode() -> void:
	_stop_bullet_time()
	is_fps_controlled = false
	is_shoot_dodging = false
	if character_pivot:
		character_pivot.rotation = Vector3.ZERO
	if is_instance_valid(_fps_hud_node):
		_fps_hud_node.call("set_hud_visible", false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func move_to_position(target_pos: Vector3) -> void:
	if nav_agent and not is_fps_controlled:
		nav_agent.set_target_position(target_pos)

func _unhandled_input(event: InputEvent) -> void:
	if not is_fps_controlled:
		if is_selected and event.is_action_pressed("toggle_fps_possession"):
			enter_fps_mode()
			get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("toggle_fps_possession"):
		exit_fps_mode()
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("switch_fps_weapon"):
		is_fps_weapon_non_lethal = not is_fps_weapon_non_lethal
		_update_fps_hud_weapon_text()
		get_viewport().set_input_as_handled()
		return

	# Touche Bullet-Time / Shoot Dodge (Shift / Clic Droit / E / Bouton Souris)
	if event.is_action_pressed("toggle_bullet_time") or (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed) or (event is InputEventKey and event.keycode == KEY_SHIFT and event.pressed):
		_trigger_bullet_time_or_dodge()
		get_viewport().set_input_as_handled()
		return

	if event is InputEventMouseMotion:
		var sens_mult := 1.6 if is_bullet_time_active else 1.0
		rotate_y(-event.relative.x * mouse_sensitivity * sens_mult)
		_cam_pitch = clamp(_cam_pitch - event.relative.y * mouse_sensitivity * sens_mult, -1.2, 1.2)
		if head_pivot:
			head_pivot.rotation.x = _cam_pitch

	if event.is_action_pressed("fps_fire"):
		_perform_fps_shoot()
		get_viewport().set_input_as_handled()

func _get_movement_input_vector() -> Vector2:
	var input_dir := Vector2.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_Z) or Input.is_key_pressed(KEY_UP):
		input_dir.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		input_dir.y += 1.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_Q) or Input.is_key_pressed(KEY_LEFT):
		input_dir.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		input_dir.x += 1.0

	var lx := Input.get_joy_axis(0, JOY_AXIS_LEFT_X)
	var ly := Input.get_joy_axis(0, JOY_AXIS_LEFT_Y)
	if abs(lx) > 0.2: input_dir.x += lx
	if abs(ly) > 0.2: input_dir.y += ly

	return input_dir

func _trigger_bullet_time_or_dodge() -> void:
	if bullet_time_energy < 15.0:
		return

	var input_dir := _get_movement_input_vector()
	if input_dir.length_squared() > 0.05:
		_start_shoot_dodge(input_dir)
	else:
		if is_bullet_time_active:
			_stop_bullet_time()
		else:
			_start_bullet_time()

func _start_bullet_time() -> void:
	is_bullet_time_active = true
	Engine.time_scale = bullet_time_time_scale
	_play_bullet_time_sound(true)

func _stop_bullet_time() -> void:
	is_bullet_time_active = false
	is_shoot_dodging = false
	Engine.time_scale = 1.0
	_target_pivot_rot = Vector3.ZERO
	_play_bullet_time_sound(false)

func _start_shoot_dodge(input_dir: Vector2) -> void:
	if bullet_time_energy < 15.0:
		return

	input_dir = input_dir.normalized()
	shoot_dodge_dir = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	velocity = shoot_dodge_dir * shoot_dodge_speed + Vector3(0, shoot_dodge_jump_force, 0)

	var pitch := 0.0
	var roll := 0.0

	if input_dir.y < -0.1:
		pitch = -50.0
	elif input_dir.y > 0.1:
		pitch = 45.0

	if input_dir.x < -0.1:
		roll = -65.0
	elif input_dir.x > 0.1:
		roll = 65.0

	_target_pivot_rot = Vector3(deg_to_rad(pitch), 0, deg_to_rad(roll))
	is_shoot_dodging = true
	_has_started_dodge_jump = true
	_start_bullet_time()

func _play_bullet_time_sound(start: bool) -> void:
	var mgrs := get_tree().get_nodes_in_group("sound_managers")
	if not mgrs.is_empty() and mgrs[0].has_method("play_bullet_time"):
		mgrs[0].call("play_bullet_time", start)

func _update_fps_hud_weapon_text() -> void:
	if is_instance_valid(_fps_hud_node) and _fps_hud_node.has_method("set_weapon_info"):
		if is_fps_weapon_non_lethal:
			_fps_hud_node.call("set_weapon_info", "Flashball / Tranquillisant (Non-Létal)", Color(0.2, 0.85, 1.0))
		else:
			_fps_hud_node.call("set_weapon_info", "Fusil d'Assaut (Létal)", Color(1.0, 0.4, 0.2))

func _perform_fps_shoot() -> void:
	_play_human_anim("idle")

	var muzzle_pos := global_position + Vector3(0, 1.4, 0)
	var shoot_target_pos := muzzle_pos + (-fps_camera.global_transform.basis.z * 40.0)

	var mgrs := get_tree().get_nodes_in_group("sound_managers")
	if not mgrs.is_empty():
		if is_fps_weapon_non_lethal:
			mgrs[0].call("play_flashball_shot", self, muzzle_pos)
		else:
			mgrs[0].call("play_rifle_shot", self, muzzle_pos)

	if gun_raycast:
		gun_raycast.force_raycast_update()
		if gun_raycast.is_colliding():
			var collider := gun_raycast.get_collider()
			shoot_target_pos = gun_raycast.get_collision_point()
			var hit_norm := gun_raycast.get_collision_normal()
			var shoot_dir := -hit_norm

			if collider and collider.has_method("take_non_lethal_damage") and is_fps_weapon_non_lethal:
				collider.call("take_non_lethal_damage", 60.0, shoot_dir)
			elif collider and collider.has_method("take_damage"):
				var dmg_mult := 1.5 if is_bullet_time_active else 1.0
				collider.call("take_damage", auto_attack_damage * 2.0 * dmg_mult, shoot_dir, "chest_upper_left")

	_create_fps_bullet_tracer(muzzle_pos, shoot_target_pos)

func _create_fps_bullet_tracer(from: Vector3, to: Vector3) -> void:
	var line := MeshInstance3D.new()
	var imm := ImmediateMesh.new()
	var mat := StandardMaterial3D.new()

	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.2, 0.85, 1.0, 0.95) if is_fps_weapon_non_lethal else Color(1.0, 0.8, 0.2, 0.95)

	imm.surface_begin(Mesh.PRIMITIVE_LINES, mat)
	imm.surface_add_vertex(from)
	imm.surface_add_vertex(to)
	imm.surface_end()

	line.mesh = imm
	get_tree().root.add_child(line)
	var timer := get_tree().create_timer(0.04)
	timer.timeout.connect(line.queue_free)

func take_damage(amount: float, _bullet_dir: Vector3 = Vector3.ZERO, _body_part: String = "") -> void:
	if _is_dying:
		return
	health = max(0.0, health - amount)
	if health <= 0:
		_die()

func _die() -> void:
	if _is_dying:
		return
	_is_dying = true
	_stop_bullet_time()
	remove_from_group("units")
	if is_fps_controlled:
		exit_fps_mode()

	var corpse_mgrs := get_tree().get_nodes_in_group("corpse_managers")
	if not corpse_mgrs.is_empty() and corpse_mgrs[0].has_method("add_corpse"):
		corpse_mgrs[0].call("add_corpse", global_position, rotation.y, false)

	queue_free()

func _physics_process(delta: float) -> void:
	if _is_dying:
		return

	var real_delta := delta / Engine.time_scale if Engine.time_scale > 0.0 else delta

	if _auto_shoot_timer > 0.0:
		_auto_shoot_timer -= delta

	if is_bullet_time_active:
		bullet_time_energy = max(0.0, bullet_time_energy - bullet_time_drain_rate * real_delta)
		if bullet_time_energy <= 0.0 and not is_shoot_dodging:
			_stop_bullet_time()
	else:
		bullet_time_energy = min(bullet_time_max_energy, bullet_time_energy + bullet_time_recharge_rate * real_delta)

	if is_fps_controlled:
		var rx := Input.get_joy_axis(0, JOY_AXIS_RIGHT_X)
		var ry := Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y)
		if abs(rx) > 0.15:
			rotate_y(-rx * joy_sensitivity * real_delta)
		if abs(ry) > 0.15:
			_cam_pitch = clamp(_cam_pitch - ry * joy_sensitivity * real_delta, -1.2, 1.2)
			if head_pivot:
				head_pivot.rotation.x = _cam_pitch

		# Plongeon Shoot-Dodge en plein vol
		if is_shoot_dodging:
			velocity.y -= _gravity * real_delta
			velocity.x = shoot_dodge_dir.x * shoot_dodge_speed
			velocity.z = shoot_dodge_dir.z * shoot_dodge_speed

			if character_pivot:
				character_pivot.rotation = character_pivot.rotation.lerp(_target_pivot_rot, real_delta * 12.0)

			if Input.is_action_pressed("fps_fire") and _auto_shoot_timer <= 0.0:
				_auto_shoot_timer = 0.08
				_perform_fps_shoot()

			if is_on_floor() and _has_started_dodge_jump:
				is_shoot_dodging = false
				_has_started_dodge_jump = false
				_target_pivot_rot = Vector3.ZERO
				if not Input.is_key_pressed(KEY_SHIFT):
					_stop_bullet_time()
		else:
			if not is_on_floor():
				velocity.y -= _gravity * real_delta
			elif Input.is_action_just_pressed("fps_jump"):
				var input_dir := _get_movement_input_vector()
				if input_dir.length_squared() > 0.05 and bullet_time_energy >= 15.0:
					_start_shoot_dodge(input_dir)
				else:
					velocity.y = 5.5

			if character_pivot:
				character_pivot.rotation = character_pivot.rotation.lerp(Vector3.ZERO, real_delta * 15.0)

			var input_dir := _get_movement_input_vector()
			if input_dir.length_squared() > 0.001:
				input_dir = input_dir.normalized()
				var move_dir := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
				velocity.x = move_dir.x * move_speed
				velocity.z = move_dir.z * move_speed
				_play_human_anim("run")
			else:
				velocity.x = 0.0
				velocity.z = 0.0
				_play_human_anim("idle")

			if Input.is_action_pressed("fps_fire") and _auto_shoot_timer <= 0.0:
				_auto_shoot_timer = 0.18
				_perform_fps_shoot()

		move_and_slide()

		if is_instance_valid(_fps_hud_node) and _fps_hud_node.has_method("update_bullet_time"):
			_fps_hud_node.call("update_bullet_time", bullet_time_energy, bullet_time_max_energy, is_bullet_time_active, is_shoot_dodging)
		return

	if not is_on_floor():
		velocity.y -= _gravity * delta

	# Mode Automatique RTS
	var enemies := get_tree().get_nodes_in_group("enemies")
	var closest_enemy: Node3D = null
	var min_dist: float = 99999.0

	for enemy_node in enemies:
		if is_instance_valid(enemy_node) and enemy_node is Node3D:
			var d := global_position.distance_to((enemy_node as Node3D).global_position)
			if d < min_dist and d <= auto_attack_range:
				min_dist = d
				closest_enemy = enemy_node as Node3D

	if is_instance_valid(closest_enemy):
		var dir := (closest_enemy.global_position - global_position).normalized()
		dir.y = 0.0
		if dir.length_squared() > 0.001:
			var target_angle := atan2(-dir.x, -dir.z)
			rotation.y = lerp_angle(rotation.y, target_angle, rotation_speed * delta)
		if _auto_shoot_timer <= 0.0:
			_auto_shoot_timer = auto_attack_cooldown
			_perform_fps_shoot()

	move_and_slide()

func _on_velocity_computed(safe_velocity: Vector3) -> void:
	if not is_fps_controlled:
		velocity.x = safe_velocity.x
		velocity.z = safe_velocity.z
