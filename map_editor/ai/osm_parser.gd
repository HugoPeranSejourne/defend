class_name OSMParser
extends RefCounted

## JSON Overpass → géométries en coordonnées monde (mètres).
## Hauteurs : tag "height" prioritaire, sinon "building:levels" × 3m, sinon défaut.

const MIN_HEIGHT := 2.5
const MAX_HEIGHT := 100.0
const M_PER_FLOOR := 3.0

static func parse(json_text: String, projector: GeoProjector, default_height := 6.0) -> Dictionary:
	var out := {"buildings": [], "roads": [], "open_areas": [], "squares": []}
	var parsed: Variant = JSON.parse_string(json_text)
	if not (parsed is Dictionary):
		return out
	for el in parsed.get("elements", []):
		if not (el is Dictionary):
			continue
		var tags: Dictionary = el.get("tags", {})
		var etype := String(el.get("type", ""))
		if etype == "way" and tags.has("building"):
			var poly := _geometry_to_polygon(el.get("geometry", []), projector)
			if poly.size() >= 3:
				out.buildings.append({"polygon": poly, "height": _extract_height(tags, default_height)})
		elif etype == "way" and tags.has("highway"):
			var line := _geometry_to_polygon(el.get("geometry", []), projector)
			if line.size() >= 2:
				out.roads.append(line)
		elif etype == "way" and tags.has("leisure"):
			var area := _geometry_to_polygon(el.get("geometry", []), projector)
			if area.size() >= 3:
				out.open_areas.append(area)
		elif etype == "node" and String(tags.get("place", "")) == "square":
			out.squares.append(projector.to_world(float(el.get("lat", 0.0)), float(el.get("lon", 0.0))))
	return out

static func _geometry_to_polygon(geom: Array, projector: GeoProjector) -> PackedVector2Array:
	var poly := PackedVector2Array()
	for pt in geom:
		if pt is Dictionary:
			var w := projector.to_world(float(pt.get("lat", 0.0)), float(pt.get("lon", 0.0)))
			poly.append(Vector2(w.x, w.z))
	return poly

static func _extract_height(tags: Dictionary, default_h: float) -> float:
	if tags.has("height"):
		var s := String(tags["height"]).replace("m", "").replace(",", ".").strip_edges()
		if s.is_valid_float():
			return clampf(s.to_float(), MIN_HEIGHT, MAX_HEIGHT)
	if tags.has("building:levels"):
		var s2 := String(tags["building:levels"]).strip_edges()
		if s2.is_valid_float():
			return clampf(s2.to_float() * M_PER_FLOOR, MIN_HEIGHT, MAX_HEIGHT)
	return clampf(default_h, MIN_HEIGHT, MAX_HEIGHT)
