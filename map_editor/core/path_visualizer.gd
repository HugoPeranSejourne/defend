class_name PathVisualizer
extends Node3D

## Dessine tous les chemins ennemis en 3D (lignes + sphères aux waypoints).

const COLORS: Array[Color] = [
	Color(1.0, 0.3, 0.3), Color(1.0, 0.6, 0.2), Color(1.0, 0.9, 0.2),
	Color(0.6, 0.3, 1.0), Color(0.3, 0.8, 1.0), Color(1.0, 0.4, 0.8),
]

var _paths_ref: Array[Dictionary] = []
var _lines_root: Node3D
var _markers_root: Node3D

func _ready() -> void:
	_lines_root = Node3D.new()
	_lines_root.name = "Lines"
	add_child(_lines_root)
	_markers_root = Node3D.new()
	_markers_root.name = "Markers"
	add_child(_markers_root)

func set_paths(paths: Array[Dictionary]) -> void:
	_paths_ref = paths
	rebuild()

func rebuild() -> void:
	if _lines_root == null or _markers_root == null:
		return
	for c in _lines_root.get_children():
		c.queue_free()
	for c in _markers_root.get_children():
		c.queue_free()

	for i in _paths_ref.size():
		var path := _paths_ref[i]
		var color: Color = COLORS[i % COLORS.size()]
		var wps: Array = path.get("waypoints", [])
		if wps.size() < 1:
			continue

		# Lignes entre waypoints
		if wps.size() >= 2:
			var im := ImmediateMesh.new()
			var mat := StandardMaterial3D.new()
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			mat.albedo_color = color
			mat.no_depth_test = true
			im.surface_begin(Mesh.PRIMITIVE_LINE_STRIP, mat)
			for wp in wps:
				if wp is Vector3:
					im.surface_add_vertex(Vector3(wp.x, 0.3, wp.z))
			im.surface_end()
			var mi := MeshInstance3D.new()
			mi.mesh = im
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_lines_root.add_child(mi)

		# Sphères aux waypoints
		for j in wps.size():
			var wp = wps[j]
			if not (wp is Vector3):
				continue
			var sp := MeshInstance3D.new()
			var sm := SphereMesh.new()
			sm.radius = 0.4 if j < wps.size() - 1 else 0.6 # dernier = plus gros
			sm.height = sm.radius * 2.0
			sp.mesh = sm
			sp.position = Vector3(wp.x, 0.4, wp.z)
			var m := StandardMaterial3D.new()
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			m.albedo_color = color
			sp.material_override = m
			sp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_markers_root.add_child(sp)
