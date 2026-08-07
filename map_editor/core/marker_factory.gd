class_name MarkerFactory
extends RefCounted

const UNIT_LAYER := 4
const SPAWN_LAYER := 8
const BASE_LAYER := 16

static func create_spawn_marker(pos: Vector3, is_player: bool) -> Node3D:
	var root := Node3D.new()
	root.name = "Spawn_Player" if is_player else "Spawn_Enemy"
	root.position = pos
	var color := Color(0.2, 0.8, 0.2) if is_player else Color(0.9, 0.2, 0.2)

	var cone := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.0
	cm.bottom_radius = 0.8
	cm.height = 1.6
	cone.mesh = cm
	cone.position.y = 0.8
	cone.material_override = _unshaded(color)
	root.add_child(cone)

	var ring := MeshInstance3D.new()
	var rm := TorusMesh.new()
	rm.inner_radius = 0.9
	rm.outer_radius = 1.1
	ring.mesh = rm
	ring.rotation.x = PI * 0.5
	ring.position.y = 0.05
	ring.material_override = _unshaded(color)
	root.add_child(ring)

	var body := StaticBody3D.new()
	body.collision_layer = SPAWN_LAYER
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 1.0
	shape.height = 2.0
	cs.shape = shape
	cs.position.y = 1.0
	body.add_child(cs)
	root.add_child(body)
	root.set_meta("is_spawn", true)
	root.set_meta("is_player_spawn", is_player)
	return root

static func create_base_marker(pos: Vector3) -> Node3D:
	var root := Node3D.new()
	root.name = "Base"
	root.position = pos
	var color := Color(0.3, 0.5, 1.0)

	var box := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(4, 3, 4)
	box.mesh = bm
	box.position.y = 1.5
	box.material_override = _unshaded(color)
	root.add_child(box)

	var pole := MeshInstance3D.new()
	var pm := CylinderMesh.new()
	pm.top_radius = 0.1
	pm.bottom_radius = 0.1
	pm.height = 5.0
	pole.mesh = pm
	pole.position.y = 5.5
	pole.material_override = _unshaded(color)
	root.add_child(pole)

	var flag := MeshInstance3D.new()
	var fm := BoxMesh.new()
	fm.size = Vector3(1.5, 1.0, 0.1)
	flag.mesh = fm
	flag.position = Vector3(0.8, 7.0, 0)
	flag.material_override = _unshaded(Color(1.0, 0.9, 0.2))
	root.add_child(flag)

	var body := StaticBody3D.new()
	body.collision_layer = BASE_LAYER
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(4, 3, 4)
	cs.shape = shape
	cs.position.y = 1.5
	body.add_child(cs)
	root.add_child(body)
	root.set_meta("is_base", true)
	return root

static func create_unit_marker(pos: Vector3, entry: Dictionary, path_id: String) -> Node3D:
	var root := Node3D.new()
	root.name = "Unit_%s" % String(entry.key)
	root.position = pos

	var body_mesh := MeshInstance3D.new()
	var cm := CapsuleMesh.new()
	cm.radius = float(entry.get("radius", 0.5))
	cm.height = float(entry.get("height", 1.8))
	body_mesh.mesh = cm
	body_mesh.position.y = float(entry.get("height", 1.8)) * 0.5
	body_mesh.material_override = _unshaded(entry.get("color", Color.WHITE))
	root.add_child(body_mesh)

	# Indicateur de direction (cône vers l'avant)
	var cone := MeshInstance3D.new()
	var arrow := CylinderMesh.new()
	arrow.top_radius = 0.0
	arrow.bottom_radius = 0.25
	arrow.height = 0.6
	cone.mesh = arrow
	cone.rotation.x = PI * 0.5
	cone.position = Vector3(0, float(entry.get("height", 1.8)) * 0.7, -float(entry.get("radius", 0.5)) - 0.3)
	cone.material_override = _unshaded(Color.WHITE)
	root.add_child(cone)

	var body := StaticBody3D.new()
	body.collision_layer = UNIT_LAYER
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = float(entry.get("radius", 0.5)) + 0.2
	shape.height = float(entry.get("height", 1.8))
	cs.shape = shape
	cs.position.y = float(entry.get("height", 1.8)) * 0.5
	body.add_child(cs)
	root.add_child(body)
	root.set_meta("is_unit", true)
	root.set_meta("unit_key", entry.key)
	root.set_meta("path_id", path_id)
	root.set_meta("directive", "attack")
	return root

static func _unshaded(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = color
	return m
