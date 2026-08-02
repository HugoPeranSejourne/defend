extends Node3D
class_name CorpseManager

@export var max_corpses: int = 500
@onready var multimesh_instance: MultiMeshInstance3D = $MultiMeshInstance3D

var _corpse_count: int = 0
var _next_index: int = 0

func _ready() -> void:
	add_to_group("corpse_managers")
	_setup_multimesh()

func _setup_multimesh() -> void:
	if not multimesh_instance:
		multimesh_instance = MultiMeshInstance3D.new()
		add_child(multimesh_instance)

	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.instance_count = max_corpses

	# Humanoïde 3D pour les cadavres
	var body_box := BoxMesh.new()
	body_box.size = Vector3(0.5, 0.28, 1.65)

	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.65
	body_box.material = mat

	mm.mesh = body_box
	multimesh_instance.multimesh = mm

func add_corpse(pos: Vector3, rot_y: float, is_enemy: bool = true) -> void:
	if not multimesh_instance or not multimesh_instance.multimesh:
		return
		
	var mm := multimesh_instance.multimesh
	var idx := _next_index
	_next_index = (_next_index + 1) % max_corpses
	_corpse_count = min(_corpse_count + 1, max_corpses)

	var t := Transform3D()
	t = t.rotated(Vector3.UP, rot_y)
	t = t.rotated(Vector3.RIGHT, -PI * 0.48)
	t.origin = pos + Vector3(0, 0.12, 0)

	mm.set_instance_transform(idx, t)
	
	var col := Color(0.85, 0.25, 0.25, 1.0) if is_enemy else Color(0.15, 0.4, 0.9, 1.0)
	mm.set_instance_color(idx, col)
	mm.visible_instance_count = _corpse_count
