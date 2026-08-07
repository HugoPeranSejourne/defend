class_name UnitCatalog
extends RefCounted

var entries: Array[Dictionary] = []

static func create_default() -> UnitCatalog:
	var c := UnitCatalog.new()
	c.entries = [
		{"key": &"soldier", "label": "🪖 Soldat allié", "color": Color(0.2, 0.6, 1.0), "radius": 0.5, "height": 1.8},
		{"key": &"turret", "label": "🎯 Tourelle", "color": Color(0.3, 0.8, 0.4), "radius": 0.8, "height": 2.2},
		{"key": &"enemy", "label": "👹 Ennemi générique", "color": Color(1.0, 0.3, 0.2), "radius": 0.5, "height": 1.8},
	]
	return c

func get_entry(key: StringName) -> Dictionary:
	for e in entries:
		if e.key == key:
			return e
	return {}
