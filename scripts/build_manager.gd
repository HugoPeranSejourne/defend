extends Node
class_name BuildManager

signal credits_changed(new_credits: int)

@export var player_credits: int = 150
@export var camera: Node3D
@export var turret_scene: PackedScene
@export var bombardier_scene: PackedScene
@export var barricade_scene: PackedScene

var selected_turret_type: String = ""
var _ghost_instance: Node3D = null
var _ghost_material: StandardMaterial3D = null

func _ready() -> void:
	add_to_group("build_managers")
	_locate_camera()
	if not turret_scene: turret_scene = load("res://scenes/turret_3d.tscn")
	if not bombardier_scene: bombardier_scene = load("res://scenes/unit_bombardier.tscn")
	if not barricade_scene: barricade_scene = load("res://scenes/barricade_wall.tscn")
	emit_signal("credits_changed", player_credits)

func _locate_camera() -> void:
	if not camera:
		var cams := get_tree().get_nodes_in_group("rts_cameras")
		if not cams.is_empty() and cams[0] is Node3D:
			camera = cams[0] as Node3D
		else:
			camera = get_node_or_null("/root/MainStage/RTSCamera3D") as Node3D

func add_credits(amount: int) -> void:
	player_credits += amount
	emit_signal("credits_changed", player_credits)

func get_turret_cost(type_name: String) -> int:
	match type_name:
		"DroneGas":
			return 150
		"Helicopter":
			return 250
		"SupplyCrate":
			return 200
		"Barricade":
			return 80
		"Bombardier":
			return 200
		"GatlingFlashball":
			return 120
		"HeavyCannon":
			return 250
		"Tranquilizer":
			return 280
		_:
			return 100

func start_building(type_name: String) -> void:
	cancel_building()
	_locate_camera()
	
	selected_turret_type = type_name
	if selected_turret_type == "Bombardier":
		if not bombardier_scene: return
		_ghost_instance = bombardier_scene.instantiate() as Node3D
	elif selected_turret_type == "Barricade":
		if not barricade_scene: return
		_ghost_instance = barricade_scene.instantiate() as Node3D
	elif selected_turret_type.begins_with("Drone") or selected_turret_type == "Helicopter" or selected_turret_type == "SupplyCrate":
		_ghost_instance = MeshInstance3D.new()
		var cylinder := CylinderMesh.new()
		cylinder.top_radius = 8.0
		cylinder.bottom_radius = 8.0
		cylinder.height = 0.4
		(_ghost_instance as MeshInstance3D).mesh = cylinder
	else:
		if not turret_scene: return
		_ghost_instance = turret_scene.instantiate() as Node3D
		
	if not _ghost_instance:
		return
		
	var col := _ghost_instance.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if col:
		col.disabled = true
		
	_ghost_material = StandardMaterial3D.new()
	_ghost_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ghost_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ghost_material.albedo_color = Color(0.2, 0.9, 0.4, 0.45)
	
	_apply_ghost_material(_ghost_instance)
	get_tree().root.add_child(_ghost_instance)

func _apply_ghost_material(node: Node) -> void:
	if node is MeshInstance3D:
		(node as MeshInstance3D).material_override = _ghost_material
	for child in node.get_children():
		_apply_ghost_material(child)

func cancel_building() -> void:
	selected_turret_type = ""
	if is_instance_valid(_ghost_instance):
		_ghost_instance.queue_free()
		_ghost_instance = null

func _unhandled_input(event: InputEvent) -> void:
	if not is_instance_valid(_ghost_instance):
		return

	if event is InputEventMouseButton and event.is_pressed():
		if event.button_index == MOUSE_BUTTON_LEFT:
			_try_place_turret(event.position)
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			cancel_building()
			get_viewport().set_input_as_handled()

	elif event is InputEventKey and event.is_pressed() and event.keycode == KEY_ESCAPE:
		cancel_building()
		get_viewport().set_input_as_handled()

func _process(_delta: float) -> void:
	if not is_instance_valid(_ghost_instance):
		return
		
	_locate_camera()
	if not camera:
		return
		
	var mouse_pos := get_viewport().get_mouse_position()
	var hit: Dictionary = camera.call("raycast_from_screen", mouse_pos, 1) if camera.has_method("raycast_from_screen") else {}
	
	if not hit.is_empty() and hit.has("position"):
		_ghost_instance.global_position = hit["position"]
		var cost := get_turret_cost(selected_turret_type)
		
		if player_credits >= cost:
			_ghost_material.albedo_color = Color(0.2, 0.95, 0.4, 0.5)
		else:
			_ghost_material.albedo_color = Color(0.95, 0.2, 0.2, 0.5)

func _try_place_turret(screen_pos: Vector2) -> void:
	_locate_camera()
	if not camera:
		return
		
	var cost := get_turret_cost(selected_turret_type)
	if player_credits < cost:
		print("Crédits insuffisants !")
		return

	var hit: Dictionary = camera.call("raycast_from_screen", screen_pos, 1) if camera.has_method("raycast_from_screen") else {}
	if not hit.is_empty() and hit.has("position"):
		var build_pos: Vector3 = hit["position"]
		
		if selected_turret_type == "DroneGas":
			_trigger_drone_gas(build_pos)
			add_credits(-cost)
			cancel_building()
		elif selected_turret_type == "Helicopter":
			_trigger_helicopter_spotlight(build_pos)
			add_credits(-cost)
			cancel_building()
		elif selected_turret_type == "SupplyCrate":
			_trigger_supply_crate(build_pos)
			add_credits(-cost)
			cancel_building()
		elif selected_turret_type == "Bombardier":
			var new_bombardier := bombardier_scene.instantiate() as Node3D
			if new_bombardier:
				var units_container := get_tree().root.get_node_or_null("MainStage/UnitsContainer")
				if units_container: units_container.add_child(new_bombardier)
				else: get_tree().root.add_child(new_bombardier)
				new_bombardier.global_position = build_pos
				add_credits(-cost)
				cancel_building()
		elif selected_turret_type == "Barricade":
			var new_barricade := barricade_scene.instantiate() as Node3D
			if new_barricade:
				get_tree().root.add_child(new_barricade)
				new_barricade.global_position = build_pos
				add_credits(-cost)
				cancel_building()
		else:
			var new_turret: Node3D = turret_scene.instantiate() as Node3D
			if new_turret:
				get_tree().root.add_child(new_turret)
				new_turret.global_position = build_pos
				if new_turret.has_method("configure_type"):
					new_turret.call("configure_type", selected_turret_type)
				add_credits(-cost)
				cancel_building()

func _trigger_drone_gas(target_pos: Vector3) -> void:
	var cloud := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 8.0
	sphere.height = 4.0
	
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.2, 0.9, 0.6, 0.45)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sphere.material = mat
	
	cloud.mesh = sphere
	get_tree().root.add_child(cloud)
	cloud.global_position = target_pos + Vector3(0, 1.5, 0)
	
	var enemies := get_tree().get_nodes_in_group("enemies")
	for e in enemies:
		if is_instance_valid(e) and e is Node3D:
			if (e as Node3D).global_position.distance_to(target_pos) <= 8.5:
				if e.has_method("take_non_lethal_damage"):
					e.call("take_non_lethal_damage", 120.0, Vector3.ZERO)

	var timer := get_tree().create_timer(8.0)
	timer.timeout.connect(cloud.queue_free)

func _trigger_helicopter_spotlight(target_pos: Vector3) -> void:
	var light := SpotLight3D.new()
	light.light_color = Color(1.0, 0.95, 0.8)
	light.light_energy = 8.0
	light.spot_range = 40.0
	light.spot_angle = 35.0
	
	get_tree().root.add_child(light)
	light.global_position = target_pos + Vector3(0, 25.0, 0)
	light.rotation_degrees = Vector3(-90, 0, 0)
	
	var timer := get_tree().create_timer(10.0)
	timer.timeout.connect(light.queue_free)

func _trigger_supply_crate(target_pos: Vector3) -> void:
	add_credits(350)
	
	var units := get_tree().get_nodes_in_group("units")
	for u in units:
		if is_instance_valid(u) and u is Node3D:
			if (u as Node3D).global_position.distance_to(target_pos) <= 12.0:
				if u.get("health") != null:
					u.set("health", min(u.get("max_health"), u.get("health") + 50.0))
