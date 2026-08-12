class_name TacticalGenerator
extends RefCounted

## Raster (blocks + routes + zones ouvertes) → MapData complète et validée.

static func generate(raster: Dictionary, projector: GeoProjector, map_name: String) -> MapData:
	var data := MapData.new()
	data.meta_name = map_name
	data.meta_author = "AI Generator (© OSM contributors)"
	data.grid_cell_size = projector.cell_size
	data.grid_dimensions = Vector2i(projector.grid_cells, projector.grid_cells)

	var blocks: Array = raster.blocks
	var road_cells: Dictionary = raster.road_cells
	var open_cells: Dictionary = raster.open_cells
	var squares: Array = raster.squares
	var building_cells := GridRasterizer.blocks_to_cell_set(blocks)

	# --- 1. Base ---
	var base_cell := _choose_base_cell(squares, open_cells, building_cells, projector)
	data.has_base = true
	data.base_position = projector.cell_center(base_cell)

	# --- 2. Spawns ennemis + chemins (branches natives) ---
	var entries := RoadGraph.find_border_entries(road_cells, projector.grid_cells, 4)
	if entries.is_empty():
		var h := projector.grid_cells / 2 - 2
		entries = [Vector2i(-h, -h), Vector2i(h, -h), Vector2i(h, h), Vector2i(-h, h)]
	var near_base := RoadGraph.nearest_road_cell(road_cells, base_cell, 40)
	var extra := {base_cell: true}
	var letter := 0
	for entry in entries:
		var wps: Array[Vector3] = []
		var path_cells: Array[Vector2i] = []
		if near_base.x < 9000:
			path_cells = RoadGraph.bfs_path(road_cells, entry, near_base, extra)
		if path_cells.size() >= 2:
			for c in RoadGraph.simplify(path_cells):
				wps.append(projector.cell_center(c))
		else:
			wps.append(projector.cell_center(entry))
		wps.append(data.base_position) # terminus = base → validate() garanti
		var pid := "Chemin %s" % char(65 + letter)
		letter += 1
		data.enemy_paths.append({"id": pid, "waypoints": wps})
		data.enemy_spawns.append(projector.cell_center(entry))

	# --- 3. Spawn joueur (zone libre proche base) ---
	var p_cell := _find_free_cell_near(base_cell + Vector2i(4, 4), building_cells, 15)
	data.player_spawns.append(projector.cell_center(p_cell))

	# --- 4. Blocs (avec texturation Ceuta automatique) ---
	var bid := 1
	for b in blocks:
		var fp: Vector2i = b.footprint
		var cell: Vector2i = b.cell
		var h: float = b.height
		var tex := _assign_texture(h, fp, bid)
		data.blocks.append({
			"id": bid, "key": _catalog_key(fp), "cell": cell, "footprint": fp,
			"pos": projector.cell_center(cell) + Vector3((fp.x - 1) * projector.cell_size * 0.5, 0, (fp.y - 1) * projector.cell_size * 0.5),
			"rot_y": 0.0,
			"size": Vector3(fp.x * projector.cell_size, h, fp.y * projector.cell_size),
			"texture": tex, "category": &"building", "base_y": 0.0,
		})
		bid += 1

	# --- 5. Unités ---
	var uid := 1
	for off in [Vector3(4, 0, 0), Vector3(-4, 0, 0)]:
		data.units.append({"id": uid, "key": &"soldier", "pos": data.base_position + off, "path_id": "", "directive": "attack"})
		uid += 1
	for i in data.enemy_spawns.size():
		var pid2 := ""
		if i < data.enemy_paths.size():
			pid2 = data.enemy_paths[i].id
		data.units.append({"id": uid, "key": &"enemy", "pos": data.enemy_spawns[i], "path_id": pid2, "directive": "attack"})
		uid += 1
	return data

static func _assign_texture(height: float, fp: Vector2i, id: int) -> String:
	var area := fp.x * fp.y
	if height >= 18.0 or area >= 16:
		var opts := [
			"res://textures/ceuta_facade_blue_neoclassical.png",
			"res://textures/ceuta_casa_dragones_facade.png",
		]
		return opts[id % opts.size()]
	elif height >= 8.0 or area >= 6:
		return "res://textures/ceuta_facade_terracotta.png"
	else:
		return "res://textures/ceuta_fortress_stone.png"

static func _choose_base_cell(squares: Array, open_cells: Dictionary, building_cells: Dictionary, projector: GeoProjector) -> Vector2i:
	var best_cell := Vector2i(9999, 9999)
	var best_dist := INF
	for sq in squares:
		var c := projector.world_to_cell(sq)
		if not projector.is_cell_in_bounds(c):
			continue
		var d: float = Vector2(c.x, c.y).length()
		if d < best_dist:
			best_dist = d
			best_cell = c
	if best_cell.x < 9000:
		return _find_free_cell_near(best_cell, building_cells, 10)
	if not open_cells.is_empty():
		var sum := Vector2.ZERO
		for c in open_cells:
			sum += Vector2(c.x, c.y)
		var centroid := Vector2i(int(sum.x / open_cells.size()), int(sum.y / open_cells.size()))
		return _find_free_cell_near(centroid, building_cells, 15)
	return _find_free_cell_near(Vector2i.ZERO, building_cells, 20)

static func _find_free_cell_near(center: Vector2i, occupied: Dictionary, max_radius := 15) -> Vector2i:
	if not occupied.has(center):
		return center
	for r in range(1, max_radius + 1):
		for dx in range(-r, r + 1):
			for dy in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r:
					continue
				var c := center + Vector2i(dx, dy)
				if not occupied.has(c):
					return c
	return center

static func _catalog_key(fp: Vector2i) -> StringName:
	var area := fp.x * fp.y
	if area >= 16:
		return &"hq"
	if area >= 6:
		return &"bunker"
	return &"wall"
