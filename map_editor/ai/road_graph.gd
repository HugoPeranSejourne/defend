class_name RoadGraph
extends RefCounted

## Graphe de cellules-route : entrées en bordure + BFS + simplification.

static func find_border_entries(road_cells: Dictionary, grid_cells: int, max_entries := 4) -> Array[Vector2i]:
	var half := grid_cells / 2
	var sides: Array = [[], [], [], []] # N, S, E, O
	for c in road_cells:
		if c.y == -half:
			sides[0].append(c)
		elif c.y == half - 1:
			sides[1].append(c)
		elif c.x == half - 1:
			sides[2].append(c)
		elif c.x == -half:
			sides[3].append(c)
	var entries: Array[Vector2i] = []
	for side in sides:
		if not side.is_empty():
			side.sort_custom(func(a: Vector2i, b: Vector2i): return (a.x + a.y) < (b.x + b.y))
			entries.append(side[side.size() / 2])
	return entries.slice(0, max_entries)

static func bfs_path(road_cells: Dictionary, from: Vector2i, to: Vector2i, extra_allowed := {}) -> Array[Vector2i]:
	if from == to:
		return [from]
	var came_from := {from: from}
	var queue: Array[Vector2i] = [from]
	var head := 0
	var dirs := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	while head < queue.size():
		var cur := queue[head]
		head += 1
		for d in dirs:
			var nxt: Vector2i = cur + d
			if came_from.has(nxt):
				continue
			if nxt != to and not road_cells.has(nxt) and not extra_allowed.has(nxt):
				continue
			came_from[nxt] = cur
			if nxt == to:
				var path: Array[Vector2i] = [to]
				var c := to
				while c != from:
					c = came_from[c]
					path.push_front(c)
				return path
			queue.append(nxt)
	return []

## Ne garde que les changements de direction + extrémités
static func simplify(cells: Array[Vector2i]) -> Array[Vector2i]:
	if cells.size() <= 2:
		return cells
	var out: Array[Vector2i] = [cells[0]]
	var prev_dir := cells[1] - cells[0]
	for i in range(1, cells.size() - 1):
		var dir := cells[i + 1] - cells[i]
		if dir != prev_dir:
			out.append(cells[i])
			prev_dir = dir
	out.append(cells[cells.size() - 1])
	return out

static func nearest_road_cell(road_cells: Dictionary, target: Vector2i, max_radius := 30) -> Vector2i:
	if road_cells.has(target):
		return target
	for r in range(1, max_radius + 1):
		for dx in range(-r, r + 1):
			for dy in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r:
					continue
				var c := target + Vector2i(dx, dy)
				if road_cells.has(c):
					return c
	return Vector2i(9999, 9999) # signal "non trouvé"
