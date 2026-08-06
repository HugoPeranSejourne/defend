class_name GhostPreview
extends Node3D

var _mesh_inst: MeshInstance3D
var _mat: StandardMaterial3D

func _init() -> void:
	_mat = StandardMaterial3D.new()
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mesh_inst = MeshInstance3D.new()
	_mesh_inst.name = "GhostMesh"
	_mesh_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mesh_inst.material_override = _mat
	add_child(_mesh_inst)
	visible = false

func configure(mesh: Mesh, height: float) -> void:
	_mesh_inst.mesh = mesh
	_mesh_inst.position = Vector3(0, height * 0.5, 0)

func set_valid(valid: bool) -> void:
	_mat.albedo_color = Color(0.2, 1.0, 0.35, 0.45) if valid else Color(1.0, 0.25, 0.2, 0.45)
