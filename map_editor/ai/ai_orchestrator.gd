class_name AIOrchestrator
extends Node

## Contrat threading : HTTP sur thread dédié (use_threads), parsing + rasterisation
## sur WorkerThreadPool, retour par polling dans _process (thread principal).

signal status_changed(message: String, progress: float)
signal preview_ready(preview: Dictionary)
signal generation_failed(reason: String)
signal log_emitted(message: String)

enum Step { IDLE, FETCHING, WORKING, DONE, FAILED }

const WATCHDOG_SEC := 45.0

var _step := Step.IDLE
var _fetcher: OSMFetcher
var _task_id := -1
var _payload := {}
var _result := {}
var _cancelled := false
var _projector: GeoProjector
var _default_height := 6.0
var _map_name := "Carte_IA"
var _watchdog := 0.0

func _ready() -> void:
	_fetcher = OSMFetcher.new()
	_fetcher.fetch_succeeded.connect(_on_fetch_ok)
	_fetcher.fetch_failed.connect(func(reason: String):
		_step = Step.FAILED
		_log("❌ Échec : " + reason)
		generation_failed.emit(reason))
	_fetcher.status_message.connect(func(msg: String):
		_log(msg)
		status_changed.emit(msg, 0.15))
	_fetcher.log_emitted.connect(func(msg: String): log_emitted.emit(msg))
	add_child(_fetcher)

func start(lat: float, lng: float, default_height := 6.0, map_name := "Carte_IA") -> void:
	_cancelled = false
	_default_height = default_height
	_map_name = map_name
	_projector = GeoProjector.new(lat, lng, 2.0, 256)
	_step = Step.FETCHING
	_watchdog = WATCHDOG_SEC
	var msg := "📡 Téléchargement OpenStreetMap (512×512m)…"
	_log("Démarrage génération lat=%.5f, lng=%.5f" % [lat, lng])
	status_changed.emit(msg, 0.1)
	_fetcher.fetch(lat, lng, _projector.overpass_bbox())

func cancel() -> void:
	_cancelled = true
	_fetcher.cancel()
	_step = Step.IDLE
	_log("Annulation demandée")

func is_running() -> bool:
	return _step == Step.FETCHING or _step == Step.WORKING

func _on_fetch_ok(json_text: String) -> void:
	if _cancelled:
		return
	_step = Step.WORKING
	_watchdog = WATCHDOG_SEC
	_log("📥 Fichier OSM reçu (%d octets) → démarrage parsing background" % json_text.length())
	status_changed.emit("⚙ Analyse + rasterisation en arrière-plan…", 0.4)
	_payload = {
		"json_text": json_text,
		"lat": _projector.origin_lat,
		"lng": _projector.origin_lng,
		"cell_size": _projector.cell_size,
		"grid_cells": _projector.grid_cells,
		"default_height": _default_height,
	}
	_task_id = WorkerThreadPool.add_task(_worker_pipeline)

func _worker_pipeline() -> void:
	# ⚠ Thread worker — données pures uniquement.
	var res := {}
	var t0 := Time.get_ticks_msec()
	var projector := GeoProjector.new(_payload.lat, _payload.lng, _payload.cell_size, _payload.grid_cells)
	var parsed := OSMParser.parse(_payload.json_text, projector, _payload.default_height)
	var t1 := Time.get_ticks_msec()

	if parsed.buildings.is_empty() and parsed.roads.is_empty():
		res["error"] = "Aucune donnée OSM dans cette zone.\nEssayez d'autres coordonnées."
		_result = res
		return

	res["blocks"] = GridRasterizer.rasterize_buildings(parsed.buildings, _payload.grid_cells, _payload.cell_size)
	res["road_cells"] = GridRasterizer.rasterize_roads(parsed.roads, _payload.grid_cells, _payload.cell_size, 1)
	res["open_cells"] = GridRasterizer.rasterize_areas(parsed.open_areas, _payload.grid_cells, _payload.cell_size)
	res["squares"] = parsed.squares
	var t2 := Time.get_ticks_msec()

	var data := TacticalGenerator.generate(res, projector, _map_name)
	var t3 := Time.get_ticks_msec()

	res["data"] = data
	res["stats_msg"] = "Parsing: %dms • Raster: %dms • Scénario: %dms" % [t1 - t0, t2 - t1, t3 - t2]
	_result = res

func _process(delta: float) -> void:
	if is_running():
		_watchdog -= delta
		if _watchdog <= 0.0:
			cancel()
			_step = Step.FAILED
			var err := "Délai dépassé (%d s).\nOverpass est surchargé ou injoignable — réessayez dans une minute." % int(WATCHDOG_SEC)
			_log("❌ Watchdog : " + err)
			generation_failed.emit(err)
			return

	if _step == Step.WORKING and _task_id >= 0 and WorkerThreadPool.is_task_completed(_task_id):
		WorkerThreadPool.wait_for_task_completion(_task_id)
		_task_id = -1
		if _cancelled:
			_step = Step.IDLE
			return
		if _result.has("error"):
			_step = Step.FAILED
			_log("❌ ERREUR : " + _result.error)
			generation_failed.emit(_result.error)
			return

		if _result.has("stats_msg"):
			_log("⚡ Performance : " + _result.stats_msg)

		_generate()

func _generate() -> void:
	status_changed.emit("🎯 Scénarisation tactique…", 0.8)
	var data: MapData = _result.data
	var problems := MapIO.validate(data)
	_step = Step.DONE
	if problems.is_empty():
		status_changed.emit("✅ %d blocs, %d chemins, %d spawns ennemis" % [data.blocks.size(), data.enemy_paths.size(), data.enemy_spawns.size()], 1.0)
	else:
		status_changed.emit("⚠ Générée avec avertissements : " + " • ".join(problems), 1.0)
	_log("✅ Génération OK — carte '%s' prête (%d blocs)" % [data.meta_name, data.blocks.size()])
	preview_ready.emit({
		"data": data,
		"blocks": _result.blocks,
		"road_cells": _result.road_cells,
		"open_cells": _result.open_cells,
	})

func _log(msg: String) -> void:
	print("[AIOrchestrator] ", msg)
	log_emitted.emit(msg)
