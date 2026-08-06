class_name PlacementGrid
extends RefCounted

var cell_size := 2.0
var dimensions := Vector2i(64, 64)
var _occupied: Dictionary = {} # Vector2i -> block_id (int)

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

func can_place(cell: Vector2i, footprint: Vector2i) -> bool:
	for x in range(cell.x, cell.x + footprint.x):
		for y in range(cell.y, cell.y + footprint.y):
			var c := Vector2i(x, y)
			if not is_inside(c) or _occupied.has(c):
				return false
	return true

func occupy(id: int, cell: Vector2i, footprint: Vector2i) -> void:
	for x in range(cell.x, cell.x + footprint.x):
		for y in range(cell.y, cell.y + footprint.y):
			_occupied[Vector2i(x, y)] = id

func release(id: int) -> void:
	var to_erase: Array = []
	for c in _occupied:
		if _occupied[c] == id:
			to_erase.append(c)
	for c in to_erase:
		_occupied.erase(c)

func clear() -> void:
	_occupied.clear()
