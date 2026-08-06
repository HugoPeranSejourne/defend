class_name EditorSelectionManager
extends Node3D

signal selection_changed(id: int)

var selected_id := -1
var _box: MeshInstance3D
var _target: Node3D = null
var _half_h := 0.5

func _init() -> void:
	_box = MeshInstance3D.new()
	_box.name = "Highlight"
	_box.mesh = BoxMesh.new()
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(1.0, 0.85, 0.2, 0.3)
	m.no_depth_test = true
	_box.material_override = m
	_box.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_box)
	_box.visible = false

func _process(_delta: float) -> void:
	if _target != null and is_instance_valid(_target):
		_box.global_position = _target.global_position + Vector3(0, _half_h, 0)
		_box.global_rotation.y = _target.global_rotation.y

func select(id: int, node: Node3D) -> void:
	selected_id = id
	_target = node
	var size: Vector3 = node.get_meta("size", Vector3.ONE)
	_half_h = size.y * 0.5
	(_box.mesh as BoxMesh).size = size + Vector3(0.15, 0.15, 0.15)
	_box.visible = true
	selection_changed.emit(id)

func deselect() -> void:
	selected_id = -1
	_target = null
	_box.visible = false
	selection_changed.emit(-1)
