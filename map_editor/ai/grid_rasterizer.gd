class_name GridRasterizer
extends RefCounted

## Fonctions pures, thread-safe (aucun accès au scene tree).
## Polygones monde → masques de cellules → rectangles fusionnés → blocks.

static func rasterize_buildings(buildings: Array, grid_cells: int, cell_size: float) -> Array:
	var blocks: Array = []
	var half := grid_cells / 2
	for b in buildings:
		var poly: PackedVector2Array = b.polygon
		if poly.size() < 3:
			continue
		var minp: Vector2 = poly[0]
		var maxp: Vector2 = poly[0]
		for p in poly:
			minp = minp.min(p)
			maxp = maxp.max(p)
		var cmin := Vector2i(maxi(-half, floori(minp.x / cell_size)), maxi(-half, floori(minp.y / cell_size)))
		var cmax := Vector2i(mini(half - 1, floori(maxp.x / cell_size)), mini(half - 1, floori(maxp.y / cell_size)))
		if cmin.x > cmax.x or cmin.y > cmax.y:
			continue
		var mask := {}
		for cx in range(cmin.x, cmax.x + 1):
			for cy in range(cmin.y, cmax.y + 1):
				var center := Vector2((cx + 0.5) * cell_size, (cy + 0.5) * cell_size)
				if point_in_polygon(center, poly):
					mask[Vector2i(cx, cy)] = true
		if mask.is_empty():
			continue
		for rect in merge_rectangles(mask):
			blocks.append({"cell": rect.position, "footprint": rect.size, "height": b.height})
	return blocks

static func rasterize_roads(roads: Array, grid_cells: int, cell_size: float, dilation := 1) -> Dictionary:
	var cells := {}
	var half := grid_cells / 2
	for line in roads:
		for i in range(line.size() - 1):
			var a: Vector2 = line[i]
			var b: Vector2 = line[i + 1]
			var steps := maxi(1, int(a.distance_to(b) / (cell_size * 0.5)))
			for s in range(steps + 1):
				var p := a.lerp(b, float(s) / float(steps))
				var cx := floori(p.x / cell_size)
				var cy := floori(p.y / cell_size)
				for dx in range(-dilation, dilation + 1):
					for dy in range(-dilation, dilation + 1):
						var c := Vector2i(cx + dx, cy + dy)
						if c.x >= -half and c.x < half and c.y >= -half and c.y < half:
							cells[c] = true
	return cells

static func rasterize_areas(areas: Array, grid_cells: int, cell_size: float) -> Dictionary:
	var cells := {}
	var half := grid_cells / 2
	for poly in areas:
		if poly.size() < 3:
			continue
		var minp: Vector2 = poly[0]
		var maxp: Vector2 = poly[0]
		for p in poly:
			minp = minp.min(p)
			maxp = maxp.max(p)
		var cmin := Vector2i(maxi(-half, floori(minp.x / cell_size)), maxi(-half, floori(minp.y / cell_size)))
		var cmax := Vector2i(mini(half - 1, floori(maxp.x / cell_size)), mini(half - 1, floori(maxp.y / cell_size)))
		for cx in range(cmin.x, cmax.x + 1):
			for cy in range(cmin.y, cmax.y + 1):
				var center := Vector2((cx + 0.5) * cell_size, (cy + 0.5) * cell_size)
				if point_in_polygon(center, poly):
					cells[Vector2i(cx, cy)] = true
	return cells

static func blocks_to_cell_set(blocks: Array) -> Dictionary:
	var set := {}
	for b in blocks:
		for x in range(b.cell.x, b.cell.x + b.footprint.x):
			for y in range(b.cell.y, b.cell.y + b.footprint.y):
				set[Vector2i(x, y)] = true
	return set

static func point_in_polygon(p: Vector2, poly: PackedVector2Array) -> bool:
	var inside := false
	var j := poly.size() - 1
	for i in poly.size():
		var pi := poly[i]
		var pj := poly[j]
		if (pi.y > p.y) != (pj.y > p.y) and p.x < (pj.x - pi.x) * (p.y - pi.y) / (pj.y - pi.y) + pi.x:
			inside = not inside
		j = i
	return inside

## Masque binaire → rectangles maximaux (greedy, style voxel meshing)
static func merge_rectangles(mask: Dictionary) -> Array[Rect2i]:
	var rects: Array[Rect2i] = []
	var used := {}
	const MAX_DIM := 512
	for cell in mask:
		if used.has(cell):
			continue
		var w := 0
		while w < MAX_DIM and mask.has(cell + Vector2i(w, 0)) and not used.has(cell + Vector2i(w, 0)):
			w += 1
		var h := 0
		var grow := true
		while grow and h < MAX_DIM:
			for x in w:
				var probe: Vector2i = cell + Vector2i(x, h + 1)
				if not mask.has(probe) or used.has(probe):
					grow = false
					break
			if grow:
				h += 1
		for x in w:
			for y in h + 1:
				used[cell + Vector2i(x, y)] = true
		rects.append(Rect2i(cell, Vector2i(w, h + 1)))
	return rects
