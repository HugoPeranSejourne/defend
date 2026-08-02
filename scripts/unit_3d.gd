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

var is_selected: bool = false
var is_fps_controlled: bool = false
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
	
	# Évaluation forcée du squelette 3D et du moteur d'animations GLTF
	var skel := find_child("Skeleton3D", true, false) as Skeleton3D
	if skel:
		skel.reset_bone_poses()
		
	_glb_anim_player = find_child("AnimationPlayer", true, false) as AnimationPlayer
	if _glb_anim_player and _glb_anim_player.has_animation("Idle"):
		_glb_anim_player.play("Idle")

	# Teinture du matériau d'origine GLTF sans détruire le shader de skinning
	var mesh_inst := find_child("vanguard_Mesh", true, false) as MeshInstance3D
	if mesh_inst:
		mesh_inst.extra_cull_margin = 16.0
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
		selection_ring.visible = is_selected
	if is_selected:
		emit_signal("unit_selected", self)
	else:
		emit_signal("unit_deselected", self)

func enter_fps_mode() -> void:
	is_fps_controlled = true
	if selection_ring:
		selection_ring.visible = false
	if nav_agent:
		nav_agent.avoidance_enabled = false
	if fps_camera:
		fps_camera.current = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if is_instance_valid(_fps_hud_node):
		_fps_hud_node.visible = true
	_update_fps_hud_weapon_text()

	var rts_cams := get_tree().get_nodes_in_group("rts_cameras")
	if not rts_cams.is_empty() and rts_cams[0].has_method("set_fps_active"):
		rts_cams[0].call("set_fps_active", true)

func exit_fps_mode() -> void:
	is_fps_controlled = false
	if selection_ring:
		selection_ring.visible = is_selected
	if nav_agent:
		nav_agent.avoidance_enabled = true
	if fps_camera:
		fps_camera.current = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if is_instance_valid(_fps_hud_node):
		_fps_hud_node.visible = false

	var rts_cams := get_tree().get_nodes_in_group("rts_cameras")
	if not rts_cams.is_empty() and rts_cams[0].has_method("set_fps_active"):
		rts_cams[0].call("set_fps_active", false)

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

	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * mouse_sensitivity)
		_cam_pitch = clamp(_cam_pitch - event.relative.y * mouse_sensitivity, -1.2, 1.2)
		if head_pivot:
			head_pivot.rotation.x = _cam_pitch

	if event.is_action_pressed("fps_fire"):
		_perform_fps_shoot()
		get_viewport().set_input_as_handled()

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
				collider.call("take_damage", auto_attack_damage * 2.0, shoot_dir, "chest_upper_left")

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
		
	if _auto_shoot_timer > 0.0:
		_auto_shoot_timer -= delta

	if is_fps_controlled:
		var rx := Input.get_joy_axis(0, JOY_AXIS_RIGHT_X)
		var ry := Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y)
		if abs(rx) > 0.15:
			rotate_y(-rx * joy_sensitivity * delta)
		if abs(ry) > 0.15:
			_cam_pitch = clamp(_cam_pitch - ry * joy_sensitivity * delta, -1.2, 1.2)
			if head_pivot:
				head_pivot.rotation.x = _cam_pitch

		if Input.is_action_pressed("fps_fire") and _auto_shoot_timer <= 0.0:
			_auto_shoot_timer = 0.18
			_perform_fps_shoot()

		if not is_on_floor():
			velocity.y -= _gravity * delta
		elif Input.is_action_just_pressed("fps_jump"):
			velocity.y = 5.5

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

		move_and_slide()
		return

	if not is_on_floor():
		velocity.y -= _gravity * delta

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
			rotation.y = lerp_angle(rotation.y, target_angle, delta * rotation_speed)

		if _auto_shoot_timer <= 0.0:
			_auto_shoot_timer = auto_attack_cooldown
			_auto_shoot_at_target(closest_enemy)

	if nav_agent and not nav_agent.is_navigation_finished():
		var next_pos := nav_agent.get_next_path_position()
		var dir := (next_pos - global_position)
		dir.y = 0.0
		if dir.length_squared() > 0.001:
			dir = dir.normalized()
			var target_vel := dir * move_speed
			var target_angle := atan2(-dir.x, -dir.z)
			rotation.y = lerp_angle(rotation.y, target_angle, delta * rotation_speed)
			_play_human_anim("run")
			if nav_agent.avoidance_enabled:
				nav_agent.set_velocity(target_vel)
			else:
				velocity.x = target_vel.x
				velocity.z = target_vel.z
				move_and_slide()

func _auto_shoot_at_target(target: Node3D) -> void:
	if not is_instance_valid(target):
		return
		
	_play_human_anim("idle")
		
	var muzzle_pos := global_position + Vector3(0, 1.3, 0)
	var target_pos := target.global_position + Vector3(0, 0.9, 0)
	var shoot_dir := (target_pos - muzzle_pos).normalized()

	var mgrs := get_tree().get_nodes_in_group("sound_managers")
	if not mgrs.is_empty():
		mgrs[0].call("play_rifle_shot", self, muzzle_pos)

	if target.has_method("take_damage"):
		target.call("take_damage", auto_attack_damage, shoot_dir, "chest_upper_left")
		
	_create_fps_bullet_tracer(muzzle_pos, target_pos)

func _on_velocity_computed(safe_velocity: Vector3) -> void:
	if not is_fps_controlled and not _is_dying:
		velocity.x = safe_velocity.x
		velocity.z = safe_velocity.z
		move_and_slide()
