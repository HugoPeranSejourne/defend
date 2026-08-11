class_name GeoProjector
extends RefCounted

## Conversion lat/lng ↔ mètres locaux ↔ cellules de grille.
## Projection équirectangulaire : précision suffisante pour 512m.

const M_PER_DEG_LAT := 111320.0

var origin_lat := 0.0
var origin_lng := 0.0
var m_per_deg_lng := 0.0
var cell_size := 2.0
var grid_cells := 256 # 256 × 2m = 512m

func _init(lat: float, lng: float, p_cell_size := 2.0, p_grid_cells := 256) -> void:
	origin_lat = lat
	origin_lng = lng
	m_per_deg_lng = M_PER_DEG_LAT * cos(deg_to_rad(lat))
	cell_size = p_cell_size
	grid_cells = p_grid_cells

func to_world(lat: float, lng: float) -> Vector3:
	var x := (lng - origin_lng) * m_per_deg_lng
	var z := (origin_lat - lat) * M_PER_DEG_LAT # nord = -Z
	return Vector3(x, 0.0, z)

func world_to_cell(w: Vector3) -> Vector2i:
	return Vector2i(floori(w.x / cell_size), floori(w.z / cell_size))

func cell_center(c: Vector2i) -> Vector3:
	return Vector3((c.x + 0.5) * cell_size, 0.0, (c.y + 0.5) * cell_size)

func half_extent_m() -> float:
	return grid_cells * cell_size * 0.5

func is_cell_in_bounds(c: Vector2i) -> bool:
	var h := grid_cells / 2
	return c.x >= -h and c.x < h and c.y >= -h and c.y < h

## Bbox Overpass "south,west,north,east" couvrant exactement la zone
func overpass_bbox() -> String:
	var h := half_extent_m()
	var d_lat := h / M_PER_DEG_LAT
	var d_lng := h / m_per_deg_lng
	return "%f,%f,%f,%f" % [origin_lat - d_lat, origin_lng - d_lng, origin_lat + d_lat, origin_lng + d_lng]
