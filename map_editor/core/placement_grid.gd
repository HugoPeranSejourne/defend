class_name PlacementGrid
extends RefCounted

var cell_size := 2.0
var dimensions := Vector2i(64, 64)
# _occupied : Vector2i -> Dictionary { "ground": int, "volumes": Dictionary } 
# volumes : clé "level_idx" (String) -> id
var _occupied: Dictionary = {}
var _blocks: Dictionary = {} # id -> { cell, footprint, base_y, height }

func world_to_cell(pos: Vector3) -> Vector2i:
	return Vector2i(floori(pos.x / cell_size), floori(pos.z / cell_size))

func cell_to_world(cell: Vector2i, footprint := Vector2i.ONE) -> Vector3:
	return Vector3((cell.x + footprint.x * 0.5) * cell_size, 0.0, (cell.y + footprint.y * 0.5) * cell_size)

func clamp_cell(cell: Vector2i, footprint: Vector2i) -> Vector2i:
	var h := dimensions / 2
	return Vector2i(clampi(cell.x, -h.x, h.x - footprint.x), clampi(cell.y, -h.y, h.y - footprint.y))

func is_inside(cell: Vector2i) -> bool:
	var h := dimensions / 2
	return cell.x >= -h.x and cell.x < h.x and cell.y >= -h.y and cell.y < h.y

## Mode simple (sol uniquement) — M1/M2
func can_place(cell: Vector2i, footprint: Vector2i) -> bool:
	for x in range(cell.x, cell.x + footprint.x):
		for y in range(cell.y, cell.y + footprint.y):
			var c := Vector2i(x, y)
			if not is_inside(c) or _occupied.has(c):
				return false
	return true

func occupy(id: int, cell: Vector2i, footprint: Vector2i) -> void:
	occupy_block(id, cell, footprint, 0.0, 0.0)

func release(id: int) -> void:
	_blocks.erase(id)
	var to_erase: Array = []
	for c in _occupied:
		var rec: Dictionary = _occupied[c]
		if rec.get("ground", -1) == id:
			to_erase.append(c)
		else:
			var vols: Dictionary = rec.get("volumes", {})
			var empty_vols: Array = []
			for k in vols:
				if vols[k] == id:
					empty_vols.append(k)
			for k in empty_vols:
				vols.erase(k)
			if rec.get("ground", -1) == -1 and vols.is_empty():
				to_erase.append(c)
	for c in to_erase:
		_occupied.erase(c)

func clear() -> void:
	_occupied.clear()
	_blocks.clear()

# ---------- Mode volumes (empilement) ----------

## Trouve le premier niveau libre pour un footprint à une cellule donnée.
## Retourne base_y (mètres) ou -1 si impossible.
func find_free_level(cell: Vector2i, footprint: Vector2i, height: float, ignore_id := -1) -> float:
	var intervals: Array = [] # Array de [bottom, top]
	for x in range(cell.x, cell.x + footprint.x):
		for y in range(cell.y, cell.y + footprint.y):
			var c := Vector2i(x, y)
			if not is_inside(c):
				return -1.0
			if not _occupied.has(c):
				continue
			var rec: Dictionary = _occupied[c]
			var g: int = rec.get("ground", -1)
			if g != -1 and g != ignore_id and _blocks.has(g):
				var b: Dictionary = _blocks[g]
				intervals.append([b.base_y, b.base_y + b.height])
			for k in rec.get("volumes", {}):
				var vid: int = rec.volumes[k]
				if vid != ignore_id and _blocks.has(vid):
					var b: Dictionary = _blocks[vid]
					var iv := [b.base_y, b.base_y + b.height]
					if not intervals.has(iv):
						intervals.append(iv)
	intervals.sort_custom(func(a, b): return a[0] < b[0])
	var level := 0.0
	for iv in intervals:
		if level + height <= iv[0] + 0.001:
			return level
		if level < iv[1]:
			level = iv[1]
	return level

func can_place_at(cell: Vector2i, footprint: Vector2i, base_y: float, height: float, ignore_id := -1) -> bool:
	for x in range(cell.x, cell.x + footprint.x):
		for y in range(cell.y, cell.y + footprint.y):
			var c := Vector2i(x, y)
			if not is_inside(c):
				return false
			if not _occupied.has(c):
				continue
			var rec: Dictionary = _occupied[c]
			var ids: Array[int] = []
			var g: int = rec.get("ground", -1)
			if g != -1: ids.append(g)
			for k in rec.get("volumes", {}):
				ids.append(rec.volumes[k])
			for vid in ids:
				if vid == ignore_id or not _blocks.has(vid):
					continue
				var b: Dictionary = _blocks[vid]
				if base_y < b.base_y + b.height - 0.001 and b.base_y < base_y + height - 0.001:
					return false
	return true

func occupy_block(id: int, cell: Vector2i, footprint: Vector2i, base_y: float, height: float) -> void:
	_blocks[id] = {"cell": cell, "footprint": footprint, "base_y": base_y, "height": height}
	for x in range(cell.x, cell.x + footprint.x):
		for y in range(cell.y, cell.y + footprint.y):
			var c := Vector2i(x, y)
			if not _occupied.has(c):
				_occupied[c] = {"ground": -1, "volumes": {}}
			var rec: Dictionary = _occupied[c]
			if base_y <= 0.001:
				rec["ground"] = id
			else:
				var key := str(snappedi(int(base_y * 10), 1))
				rec["volumes"][key] = id

func get_top_at(cell: Vector2i, footprint: Vector2i) -> float:
	var top := 0.0
	for x in range(cell.x, cell.x + footprint.x):
		for y in range(cell.y, cell.y + footprint.y):
			var c := Vector2i(x, y)
			if not _occupied.has(c):
				continue
			var rec: Dictionary = _occupied[c]
			var g: int = rec.get("ground", -1)
			if g != -1 and _blocks.has(g):
				top = maxf(top, _blocks[g].base_y + _blocks[g].height)
			for k in rec.get("volumes", {}):
				var vid: int = rec.volumes[k]
				if _blocks.has(vid):
					top = maxf(top, _blocks[vid].base_y + _blocks[vid].height)
	return top
