class_name EditorSelectionManager
extends Node3D

signal selection_changed(ids: Array[int])

var selected_ids: Array[int] = []
var _selected_nodes: Dictionary = {} # id -> Node3D
var _marker_key := ""
var _marker_node: Node3D = null
var _boxes: Dictionary = {} # id -> MeshInstance3D
var _marker_box: MeshInstance3D = null

func _process(_delta: float) -> void:
	for id in _boxes:
		var node := _selected_nodes.get(id) as Node3D
		var box := _boxes[id] as MeshInstance3D
		if node != null and is_instance_valid(node) and box != null:
			box.global_position = node.global_position + Vector3(0, _half_height(node), 0)
			box.global_rotation.y = node.global_rotation.y
	if _marker_box != null and _marker_node != null and is_instance_valid(_marker_node):
		_marker_box.global_position = _marker_node.global_position + Vector3(0, 1.0, 0)

func select_single(id: int, node: Node3D) -> void:
	deselect()
	add(id, node)

func add(id: int, node: Node3D) -> void:
	if selected_ids.has(id):
		return
	selected_ids.append(id)
	_selected_nodes[id] = node
	_boxes[id] = _make_box(node)
	selection_changed.emit(selected_ids)

func remove(id: int) -> void:
	if not selected_ids.has(id):
		return
	selected_ids.erase(id)
	_selected_nodes.erase(id)
	var box := _boxes.get(id) as MeshInstance3D
	if box:
		box.queue_free()
	_boxes.erase(id)
	selection_changed.emit(selected_ids)

func deselect() -> void:
	selected_ids.clear()
	_selected_nodes.clear()
	for b in _boxes.values():
		if b is MeshInstance3D and is_instance_valid(b):
			(b as MeshInstance3D).queue_free()
	_boxes.clear()
	_deselect_marker()
	selection_changed.emit(selected_ids)

func is_selected(id: int) -> bool:
	return selected_ids.has(id)

func count() -> int:
	return selected_ids.size()

func first_id() -> int:
	return selected_ids[0] if not selected_ids.is_empty() else -1

var selected_id: int:
	get:
		return first_id()

# ---------- Marqueurs gameplay ----------

func select_marker(kind: String, node: Node3D) -> void:
	deselect()
	_marker_key = kind
	_marker_node = node
	_marker_box = MeshInstance3D.new()
	_marker_box.mesh = BoxMesh.new()
	(_marker_box.mesh as BoxMesh).size = Vector3(2.5, 2.5, 2.5)
	_marker_box.material_override = _highlight_material()
	_marker_box.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_marker_box)

func get_marker() -> Dictionary:
	if _marker_key == "":
		return {}
	return {"kind": _marker_key, "node": _marker_node}

func _deselect_marker() -> void:
	_marker_key = ""
	_marker_node = null
	if _marker_box:
		_marker_box.queue_free()
		_marker_box = null

# ---------- Interne ----------

func _make_box(node: Node3D) -> MeshInstance3D:
	var box := MeshInstance3D.new()
	box.mesh = BoxMesh.new()
	var size: Vector3 = node.get_meta("size", Vector3.ONE)
	(box.mesh as BoxMesh).size = size + Vector3(0.15, 0.15, 0.15)
	box.material_override = _highlight_material()
	box.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(box)
	box.global_position = node.global_position + Vector3(0, _half_height(node), 0)
	return box

func _half_height(node: Node3D) -> float:
	var size: Vector3 = node.get_meta("size", Vector3.ONE)
	return size.y * 0.5

func _highlight_material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(1.0, 0.85, 0.2, 0.3)
	m.no_depth_test = true
	return m
