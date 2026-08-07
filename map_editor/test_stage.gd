extends Node3D

## Scène de test isolée pour les cartes créées dans l'éditeur.
## NE charge PAS le jeu principal — environnement de validation uniquement.

var camera: Camera3D
var yaw := 0.0
var pitch := -0.9
var distance := 60.0

func _ready() -> void:
	# Environnement
	var env := WorldEnvironment.new()
	var e := Environment.new()
	var sky := Sky.new()
	sky.sky_material = ProceduralSkyMaterial.new()
	e.background_mode = Environment.BG_SKY
	e.sky = sky
	e.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	e.ambient_light_energy = 0.6
	env.environment = e
	add_child(env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -30, 0)
	sun.shadow_enabled = true
	add_child(sun)

	# Sol
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(200, 200)
	ground.mesh = pm
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.16, 0.18, 0.16)
	ground.material_override = gm
	add_child(ground)

	# Caméra orbitale simple
	camera = Camera3D.new()
	camera.current = true
	camera.fov = 60.0
	add_child(camera)
	_update_camera()

	# Charger la carte de test
	var map_path: String = GameState.pending_map_path if ("pending_map_path" in GameState and GameState.pending_map_path != "") else ProjectSettings.get_setting("game/custom_map_path", "")
	if map_path == "":
		print("[TestStage] Aucune carte à tester")
		return

	var data := MapIO.load_map(map_path)
	if data == null:
		print("[TestStage] Échec chargement : %s" % map_path)
		return

	# Spawn blocs
	var catalog := BlockCatalog.create_default()
	var blocks_root := Node3D.new()
	blocks_root.name = "Blocks"
	add_child(blocks_root)
	MapRuntime.spawn_into(data, blocks_root, catalog, 1)

	# Spawn marqueurs gameplay
	_spawn_gameplay_markers(data)

	# UI retour
	var ui := CanvasLayer.new()
	add_child(ui)
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_TOP_WIDE)
	ui.add_child(panel)
	var hb := HBoxContainer.new()
	panel.add_child(hb)
	var lbl := Label.new()
	lbl.text = "TEST : %s — %d blocs, %d spawns P, %d spawns E, %d chemins, %d unités, base: %s" % [
		data.meta_name, data.blocks.size(), data.player_spawns.size(), data.enemy_spawns.size(),
		data.enemy_paths.size(), data.units.size(), "OUI" if data.has_base else "NON"]
	hb.add_child(lbl)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(spacer)
	var btn := Button.new()
	btn.text = "↩ Retour Éditeur"
	btn.pressed.connect(func(): get_tree().change_scene_to_file("res://map_editor/map_editor.tscn"))
	hb.add_child(btn)

	print("[TestStage] Carte '%s' chargée : %d blocs, %d chemins, %d unités" % [data.meta_name, data.blocks.size(), data.enemy_paths.size(), data.units.size()])

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			distance = maxf(10.0, distance * 0.9)
			_update_camera()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			distance = minf(150.0, distance * 1.1)
			_update_camera()
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		elif event.button_index == MOUSE_BUTTON_RIGHT and not event.pressed:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		yaw -= event.relative.x * 0.004
		pitch = clampf(pitch - event.relative.y * 0.004, -1.4, -0.2)
		_update_camera()

func _update_camera() -> void:
	var rot := Basis.from_euler(Vector3(pitch, yaw, 0))
	camera.position = rot * Vector3(0, 0, distance)
	camera.look_at(Vector3.ZERO, Vector3.UP)

func _spawn_gameplay_markers(data: MapData) -> void:
	var markers := Node3D.new()
	markers.name = "GameplayMarkers"
	add_child(markers)

	for pos in data.player_spawns:
		markers.add_child(MarkerFactory.create_spawn_marker(pos, true))
	for pos in data.enemy_spawns:
		markers.add_child(MarkerFactory.create_spawn_marker(pos, false))
	if data.has_base:
		markers.add_child(MarkerFactory.create_base_marker(data.base_position))

	var unit_cat := UnitCatalog.create_default()
	for u in data.units:
		var entry := unit_cat.get_entry(u.key)
		if not entry.is_empty():
			markers.add_child(MarkerFactory.create_unit_marker(u.pos, entry, u.path_id))

	# Visualiser chemins
	var pv := PathVisualizer.new()
	markers.add_child(pv)
	pv.set_paths(data.enemy_paths)
