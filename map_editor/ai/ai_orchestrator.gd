class_name AIOrchestrator
extends Node

## Machine à états du pipeline. HTTP async + WorkerThreadPool pour le parsing & la rasterisation.

signal status_changed(message: String, progress: float)
signal preview_ready(preview: Dictionary)
signal generation_failed(reason: String)

enum Step { IDLE, FETCHING, PARSING, RASTERIZING, GENERATING, DONE, FAILED }

var _step := Step.IDLE
var _fetcher: OSMFetcher
var _task_id := -1
var _json_text := ""
var _result := {}
var _cancelled := false
var _projector: GeoProjector
var _default_height := 6.0
var _map_name := "Carte_IA"

func _init() -> void:
	_init_fetcher()

func _ready() -> void:
	if _fetcher and _fetcher.get_parent() == null:
		add_child(_fetcher)

func _init_fetcher() -> void:
	if _fetcher != null:
		return
	_fetcher = OSMFetcher.new()
	_fetcher.fetch_succeeded.connect(_on_fetch_ok)
	_fetcher.fetch_failed.connect(func(reason: String):
		_step = Step.FAILED
		print("[AIOrchestrator] ❌ Échec réseau/fetch : ", reason)
		generation_failed.emit(reason)
	)
	_fetcher.status_message.connect(func(msg: String):
		print("[AIOrchestrator] ", msg)
		status_changed.emit(msg, 0.15)
	)

func start(lat: float, lng: float, default_height := 6.0, map_name := "Carte_IA") -> void:
	_cancelled = false
	_default_height = default_height
	_map_name = map_name
	_projector = GeoProjector.new(lat, lng, 2.0, 256)
	_step = Step.FETCHING
	_init_fetcher()
	if is_inside_tree() and _fetcher.get_parent() == null:
		add_child(_fetcher)
	var msg := "📡 Téléchargement OpenStreetMap (512×512m)…"
	print("[AIOrchestrator] Démarrage génération pour lat=%.5f, lng=%.5f" % [lat, lng])
	status_changed.emit(msg, 0.1)
	_fetcher.fetch(lat, lng, _projector.overpass_bbox())

func cancel() -> void:
	_cancelled = true
	if _fetcher:
		_fetcher.cancel()
	_step = Step.IDLE
	print("[AIOrchestrator] Opération annulée par l'utilisateur.")

func is_running() -> bool:
	return _step == Step.FETCHING or _step == Step.PARSING or _step == Step.RASTERIZING or _step == Step.GENERATING

func _on_fetch_ok(json_text: String) -> void:
	if _cancelled:
		return
	print("[AIOrchestrator] 📥 Données OSM reçues (taille: %d octets)" % json_text.length())
	_json_text = json_text
	_step = Step.PARSING
	status_changed.emit("🔍 Analyse des données OSM en arrière-plan…", 0.35)
	_task_id = WorkerThreadPool.add_task(_worker_process_all)

func _worker_process_all() -> void:
	var t0 := Time.get_ticks_msec()
	print("[AIOrchestrator Worker] Début parsing JSON OSM...")
	var parsed := OSMParser.parse(_json_text, _projector, _default_height)
	var t1 := Time.get_ticks_msec()
	print("[AIOrchestrator Worker] Parsing terminé en %d ms (%d bâtiments, %d routes, %d places)" % [
		t1 - t0, parsed.buildings.size(), parsed.roads.size(), parsed.squares.size()
	])

	if parsed.buildings.is_empty() and parsed.roads.is_empty():
		_result = {"error": "Aucune donnée OSM dans cette zone.\nEssayez d'autres coordonnées."}
		return

	print("[AIOrchestrator Worker] Début rasterisation grille 256x256...")
	var res := {}
	res["blocks"] = GridRasterizer.rasterize_buildings(parsed.buildings, _projector.grid_cells, _projector.cell_size)
	res["road_cells"] = GridRasterizer.rasterize_roads(parsed.roads, _projector.grid_cells, _projector.cell_size, 1)
	res["open_cells"] = GridRasterizer.rasterize_areas(parsed.open_areas, _projector.grid_cells, _projector.cell_size)
	res["squares"] = parsed.squares
	var t2 := Time.get_ticks_msec()
	print("[AIOrchestrator Worker] Rasterisation terminée en %d ms (%d blocs générés, %d cellules-route)" % [
		t2 - t1, res["blocks"].size(), res["road_cells"].size()
	])

	print("[AIOrchestrator Worker] Début scénarisation tactique...")
	var data := TacticalGenerator.generate(res, _projector, _map_name)
	var t3 := Time.get_ticks_msec()
	print("[AIOrchestrator Worker] Scénarisation terminée en %d ms (%d chemins, %d spawns E, base=%s)" % [
		t3 - t2, data.enemy_paths.size(), data.enemy_spawns.size(), data.has_base
	])

	res["data"] = data
	_result = res

func _process(_delta: float) -> void:
	if (_step == Step.PARSING or _step == Step.RASTERIZING) and _task_id >= 0 and WorkerThreadPool.is_task_completed(_task_id):
		WorkerThreadPool.wait_for_task_completion(_task_id)
		_task_id = -1
		if _cancelled:
			_step = Step.IDLE
			return

		if _result.has("error"):
			_step = Step.FAILED
			print("[AIOrchestrator] ❌ ERREUR : ", _result["error"])
			generation_failed.emit(_result["error"])
			return

		_step = Step.DONE
		var data: MapData = _result.data
		var problems := MapIO.validate(data)
		if problems.is_empty():
			status_changed.emit("✅ %d blocs, %d chemins, %d spawns ennemis" % [data.blocks.size(), data.enemy_paths.size(), data.enemy_spawns.size()], 1.0)
		else:
			status_changed.emit("⚠ Carte générée avec avertissements : " + " • ".join(problems), 1.0)

		print("[AIOrchestrator] ✅ Génération terminée avec succès !")
		preview_ready.emit(_result)
