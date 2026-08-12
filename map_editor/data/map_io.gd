class_name MapIO
extends RefCounted

const FORMAT_VERSION := 2
const MAPS_DIR := "user://maps"
const TEXTURES_DIR := "res://textures"

static func save_map(data: MapData, path: String) -> Error:
	var dir_access := DirAccess.open("user://")
	if dir_access and not dir_access.dir_exists("maps"):
		dir_access.make_dir("maps")

	var blocks_json: Array = []
	for b in data.blocks:
		blocks_json.append({
			"id": b.id, "key": String(b.key),
			"cell": [b.cell.x, b.cell.y], "footprint": [b.footprint.x, b.footprint.y],
			"pos": _v3(b.pos), "rot_y": b.rot_y, "size": _v3(b.size),
			"texture": b.texture, "category": String(b.category),
		})
	var player: Array = []
	for v in data.player_spawns: player.append(_v3(v))
	var enemy: Array = []
	for v in data.enemy_spawns: enemy.append(_v3(v))
	var paths_json: Array = []
	for p in data.enemy_paths:
		var wps: Array = []
		for wp in p.get("waypoints", []):
			if wp is Vector3:
				wps.append(_v3(wp))
		paths_json.append({"id": String(p.get("id", "")), "waypoints": wps})
	var units_json: Array = []
	for u in data.units:
		units_json.append({
			"id": u.id, "key": String(u.key), "pos": _v3(u.pos),
			"path_id": String(u.get("path_id", "")), "directive": String(u.get("directive", "attack")),
		})
	var dict := {
		"format_version": FORMAT_VERSION,
		"meta": {"name": data.meta_name, "author": data.meta_author, "modified": Time.get_datetime_string_from_system()},
		"grid": {"cell_size": data.grid_cell_size, "dimensions": [data.grid_dimensions.x, data.grid_dimensions.y]},
		"blocks": blocks_json,
		"spawns": {"player": player, "enemy": enemy},
		"enemy_paths": paths_json,
		"units": units_json,
		"has_base": data.has_base,
		"base_position": _v3(data.base_position),
		"road_cells": _vec2i_arr(data.road_cells),
		"open_cells": _vec2i_arr(data.open_cells),
	}
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_string(JSON.stringify(dict, "  "))
	f.close()
	return OK

static func load_map(path: String) -> MapData:
	if not FileAccess.file_exists(path):
		push_error("[MapIO] Fichier introuvable : " + path)
		return null
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (parsed is Dictionary):
		push_error("[MapIO] JSON invalide : " + path)
		return null
	var version := int(parsed.get("format_version", 0))
	if version > FORMAT_VERSION:
		push_error("[MapIO] Version %d trop récente (max %d)" % [version, FORMAT_VERSION])
		return null
	var data := MapData.new()
	data.meta_name = String(parsed.get("meta", {}).get("name", "Carte"))
	data.meta_author = String(parsed.get("meta", {}).get("author", ""))
	var g: Dictionary = parsed.get("grid", {})
	data.grid_cell_size = float(g.get("cell_size", 2.0))
	var dims: Array = g.get("dimensions", [64, 64])
	data.grid_dimensions = Vector2i(int(dims[0]), int(dims[1]))
	for bd in parsed.get("blocks", []):
		if not (bd is Dictionary):
			continue
		var cell_arr: Array = bd.get("cell", [0, 0])
		var fp_arr: Array = bd.get("footprint", [1, 1])
		data.blocks.append({
			"id": int(bd.get("id", 0)),
			"key": StringName(bd.get("key", "cube")),
			"cell": Vector2i(int(cell_arr[0]), int(cell_arr[1])),
			"footprint": Vector2i(maxi(1, int(fp_arr[0])), maxi(1, int(fp_arr[1]))),
			"pos": _to_v3(bd.get("pos", [0, 0, 0])),
			"rot_y": float(bd.get("rot_y", 0.0)),
			"size": _to_v3(bd.get("size", [2, 2, 2])),
			"texture": String(bd.get("texture", "")),
			"category": StringName(bd.get("category", "shape")),
		})
	# M3 — Gameplay
	for v in parsed.get("spawns", {}).get("player", []):
		data.player_spawns.append(_to_v3(v))
	for v in parsed.get("spawns", {}).get("enemy", []):
		data.enemy_spawns.append(_to_v3(v))
	for pd in parsed.get("enemy_paths", []):
		if not (pd is Dictionary):
			continue
		var wps: Array[Vector3] = []
		for wp in pd.get("waypoints", []):
			wps.append(_to_v3(wp))
		data.enemy_paths.append({"id": String(pd.get("id", "")), "waypoints": wps})
	for ud in parsed.get("units", []):
		if not (ud is Dictionary):
			continue
		data.units.append({
			"id": int(ud.get("id", 0)),
			"key": StringName(ud.get("key", "soldier")),
			"pos": _to_v3(ud.get("pos", [0, 0, 0])),
			"path_id": String(ud.get("path_id", "")),
			"directive": String(ud.get("directive", "attack")),
		})
	data.has_base = bool(parsed.get("has_base", false))
	data.base_position = _to_v3(parsed.get("base_position", [0, 0, 0]))
	data.road_cells = _to_vec2i_arr(parsed.get("road_cells", []))
	data.open_cells = _to_vec2i_arr(parsed.get("open_cells", []))
	return data

static func list_maps() -> PackedStringArray:
	var out := PackedStringArray()
	var dir := DirAccess.open(MAPS_DIR)
	if dir == null:
		return out
	for f in dir.get_files():
		if f.ends_with(".json"):
			out.append(MAPS_DIR + "/" + f)
	out.sort()
	return out

static func scan_textures() -> PackedStringArray:
	var out := PackedStringArray()
	var dir := DirAccess.open(TEXTURES_DIR)
	if dir == null:
		return out
	for f in dir.get_files():
		var lower := f.to_lower()
		if lower.ends_with(".import"):
			continue
		if lower.ends_with(".png") or lower.ends_with(".jpg") or lower.ends_with(".jpeg") or lower.ends_with(".webp"):
			out.append(TEXTURES_DIR + "/" + f)
	out.sort()
	return out

static func validate(data: MapData) -> Array[String]:
	var problems: Array[String] = []
	if data.blocks.is_empty():
		problems.append("La carte ne contient aucun bloc.")
	if data.enemy_spawns.is_empty():
		problems.append("Aucun spawn ennemi placé.")
	if data.player_spawns.is_empty():
		problems.append("Aucune zone de déploiement joueur placée.")
	if data.enemy_paths.is_empty():
		problems.append("Aucun chemin ennemi tracé.")
	else:
		for i in data.enemy_paths.size():
			var wps: Array = data.enemy_paths[i].get("waypoints", [])
			if wps.size() < 2:
				problems.append("Chemin '%s' : moins de 2 waypoints." % data.enemy_paths[i].get("id", "?"))
	if not data.has_base:
		problems.append("Aucune base à défendre placée.")
	# Vérifier que chaque chemin atteint la base (rayon 20m)
	if data.has_base and not data.enemy_paths.is_empty():
		for p in data.enemy_paths:
			var wps: Array = p.get("waypoints", [])
			if wps.size() >= 2:
				var last: Vector3 = wps[wps.size() - 1]
				if last.distance_to(data.base_position) > 20.0:
					problems.append("Chemin '%s' : le dernier waypoint est à %.0fm de la base (>20m)." % [p.get("id", "?"), last.distance_to(data.base_position)])
	return problems

static func _v3(v: Vector3) -> Array:
	return [v.x, v.y, v.z]

static func _to_v3(a: Array) -> Vector3:
	if a.size() >= 3:
		return Vector3(float(a[0]), float(a[1]), float(a[2]))
	return Vector3.ZERO

static func _vec2i_arr(arr: Array[Vector2i]) -> Array:
	var out := []
	for c in arr:
		out.append([c.x, c.y])
	return out

static func _to_vec2i_arr(arr: Array) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for item in arr:
		if item is Array and item.size() >= 2:
			out.append(Vector2i(int(item[0]), int(item[1])))
	return out
