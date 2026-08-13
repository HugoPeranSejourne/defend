class_name BlockCatalog
extends RefCounted

var entries: Array[Dictionary] = []

static func create_default() -> BlockCatalog:
	var c := BlockCatalog.new()
	c.entries = [
		_entry(&"wall", "🧱 Mur défensif", &"building", &"box", Vector3(4, 2.5, 1), Color(0.55, 0.58, 0.62)),
		_entry(&"tower", "🗼 Tour de garde", &"building", &"cylinder", Vector3(3, 6, 3), Color(0.5, 0.45, 0.4)),
		_entry(&"bunker", "🛖 Bunker", &"building", &"box", Vector3(6, 2.5, 4), Color(0.45, 0.47, 0.42)),
		_entry(&"hq", "🏢 Quartier général", &"building", &"box", Vector3(8, 5, 8), Color(0.35, 0.5, 0.7)),
		_entry(&"dragons", "🏛️ Casa de los Dragones", &"monument", &"scene", Vector3(12, 17, 12), Color(0.9, 0.85, 0.75)),
		_entry(&"asamblea", "🏛️ Palacio de la Asamblea", &"monument", &"scene", Vector3(16, 15, 12), Color(0.85, 0.85, 0.85)),
		_entry(&"turret_base", "🎯 Socle de tourelle", &"building", &"cylinder", Vector3(2, 1, 2), Color(0.6, 0.55, 0.5)),
		_entry(&"cube", "🧊 Cube", &"shape", &"box", Vector3(2, 2, 2), Color(0.7, 0.7, 0.7)),
		_entry(&"cylinder", "🛢 Cylindre", &"shape", &"cylinder", Vector3(2, 3, 2), Color(0.65, 0.68, 0.7)),
		_entry(&"sphere", "🔮 Sphère", &"shape", &"sphere", Vector3(2, 2, 2), Color(0.68, 0.66, 0.62)),
		_entry(&"prism", "📐 Prisme", &"shape", &"prism", Vector3(2, 2, 2), Color(0.6, 0.62, 0.68)),
	]
	return c

static func _entry(key: StringName, label: String, category: StringName, mesh_type: StringName, size: Vector3, color: Color) -> Dictionary:
	return {
		"key": key, "label": label, "category": category, "mesh": mesh_type,
		"size": size, "color": color,
		"footprint": Vector2i(maxi(1, ceili(size.x / 2.0)), maxi(1, ceili(size.z / 2.0))),
	}

func get_entry(key: StringName) -> Dictionary:
	for e in entries:
		if e.key == key:
			return e
	return {}

func create_mesh(entry: Dictionary, size: Vector3) -> Mesh:
	match entry.get("mesh", &"box"):
		&"box":
			var m := BoxMesh.new(); m.size = size; return m
		&"cylinder":
			var m := CylinderMesh.new()
			m.top_radius = size.x * 0.5; m.bottom_radius = size.x * 0.5; m.height = size.y
			return m
		&"sphere":
			var m := SphereMesh.new(); m.radius = size.x * 0.5; m.height = size.y; return m
		&"prism":
			var m := PrismMesh.new(); m.size = size; return m
	var fallback := BoxMesh.new(); fallback.size = size; return fallback

func create_shape(entry: Dictionary, size: Vector3) -> Shape3D:
	match entry.get("mesh", &"box"):
		&"cylinder":
			var s := CylinderShape3D.new(); s.radius = size.x * 0.5; s.height = size.y; return s
		&"sphere":
			var s := SphereShape3D.new(); s.radius = size.x * 0.5; return s
		_: # box + prisme
			var s := BoxShape3D.new(); s.size = size; return s
