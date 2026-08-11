class_name AIOrchestrator
extends Node

## Machine à états du pipeline. HTTP async + WorkerThreadPool pour la rasterisation.
## Contrat threading : le worker ne touche JAMAIS au scene tree ;
## le retour se fait par polling dans _process (thread principal).

signal status_changed(message: String, progress: float)
signal preview_ready(preview: Dictionary) # {data, blocks, road_cells, open_cells}
signal generation_failed(reason: String)

enum Step { IDLE, FETCHING, PARSING, RASTERIZING, GENERATING, DONE, FAILED }

var _step := Step.IDLE
var _fetcher: OSMFetcher
var _task_id := -1
var _payload := {}
var _result := {}
var _cancelled := false
var _projector: GeoProjector
var _default_height := 6.0
var _map_name := "Carte_IA"

func _ready() -> void:
	_fetcher = OSMFetcher.new()
	_fetcher.fetch_succeeded.connect(_on_fetch_ok)
	_fetcher.fetch_failed.connect(func(reason: String):
		_step = Step.FAILED
		generation_failed.emit(reason)
	)
	_fetcher.status_message.connect(func(msg: String): status_changed.emit(msg, 0.15))
	add_child(_fetcher)

func start(lat: float, lng: float, default_height := 6.0, map_name := "Carte_IA") -> void:
	_cancelled = false
	_default_height = default_height
	_map_name = map_name
	_projector = GeoProjector.new(lat, lng, 2.0, 256)
	_step = Step.FETCHING
	status_changed.emit("📡 Téléchargement OpenStreetMap (512×512m)…", 0.1)
	_fetcher.fetch(lat, lng, _projector.overpass_bbox())

func cancel() -> void:
	_cancelled = true
	_fetcher.cancel()
	_step = Step.IDLE

func is_running() -> bool:
	return _step == Step.FETCHING or _step == Step.PARSING or _step == Step.RASTERIZING or _step == Step.GENERATING

func _on_fetch_ok(json_text: String) -> void:
	if _cancelled:
		return
	_step = Step.PARSING
	status_changed.emit("🔍 Analyse des données OSM…", 0.35)
	var parsed := OSMParser.parse(json_text, _projector, _default_height)
	if parsed.buildings.is_empty() and parsed.roads.is_empty():
		_step = Step.FAILED
		generation_failed.emit("Aucune donnée OSM dans cette zone.\nEssayez d'autres coordonnées.")
		return
	_step = Step.RASTERIZING
	status_changed.emit("⚙ Rasterisation : %d bâtiments, %d tronçons de route…" % [parsed.buildings.size(), parsed.roads.size()], 0.5)
	_payload = {
		"buildings": parsed.buildings,
		"roads": parsed.roads,
		"open_areas": parsed.open_areas,
		"squares": parsed.squares,
		"grid_cells": _projector.grid_cells,
		"cell_size": _projector.cell_size,
	}
	_task_id = WorkerThreadPool.add_task(_worker_rasterize)

func _worker_rasterize() -> void:
	# ⚠ Thread worker — données pures uniquement, aucun nœud.
	var res := {}
	res["blocks"] = GridRasterizer.rasterize_buildings(_payload.buildings, _payload.grid_cells, _payload.cell_size)
	res["road_cells"] = GridRasterizer.rasterize_roads(_payload.roads, _payload.grid_cells, _payload.cell_size, 1)
	res["open_cells"] = GridRasterizer.rasterize_areas(_payload.open_areas, _payload.grid_cells, _payload.cell_size)
	res["squares"] = _payload.squares
	_result = res

func _process(_delta: float) -> void:
	if _step == Step.RASTERIZING and _task_id >= 0 and WorkerThreadPool.is_task_completed(_task_id):
		WorkerThreadPool.wait_for_task_completion(_task_id)
		_task_id = -1
		if _cancelled:
			_step = Step.IDLE
			return
		_generate()

func _generate() -> void:
	_step = Step.GENERATING
	status_changed.emit("🎯 Scénarisation tactique…", 0.8)
	var data := TacticalGenerator.generate(_result, _projector, _map_name)
	var problems := MapIO.validate(data)
	_step = Step.DONE
	if problems.is_empty():
		status_changed.emit("✅ %d blocs, %d chemins, %d spawns ennemis" % [data.blocks.size(), data.enemy_paths.size(), data.enemy_spawns.size()], 1.0)
	else:
		status_changed.emit("⚠ Générée avec avertissements : " + " • ".join(problems), 1.0)
	preview_ready.emit({
		"data": data,
		"blocks": _result.blocks,
		"road_cells": _result.road_cells,
		"open_cells": _result.open_cells,
	})
