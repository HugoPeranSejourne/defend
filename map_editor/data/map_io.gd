class_name MapIO
extends RefCounted

const FORMAT_VERSION := 1
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
	var player: Array = []; for v in data.player_spawns: player.append(_v3(v))
	var enemy: Array = []; for v in data.enemy_spawns: enemy.append(_v3(v))
	var dict := {
		"format_version": FORMAT_VERSION,
		"meta": {"name": data.meta_name, "author": data.meta_author, "modified": Time.get_datetime_string_from_system()},
		"grid": {"cell_size": data.grid_cell_size, "dimensions": [data.grid_dimensions.x, data.grid_dimensions.y]},
		"blocks": blocks_json,
		"spawns": {"player": player, "enemy": enemy},
		"enemy_paths": data.enemy_paths,
		"units": data.units,
		"base_position": _v3(data.base_position),
		"buildable_zones": [],
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
	return problems

static func _v3(v: Vector3) -> Array:
	return [v.x, v.y, v.z]

static func _to_v3(a: Array) -> Vector3:
	return Vector3(float(a[0]), float(a[1]), float(a[2]))
