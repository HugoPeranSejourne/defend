extends Node3D
class_name MainStage

@export var max_public_opinion: float = 100.0
@export var public_opinion: float = 100.0

@onready var main_hud: CanvasLayer = $MainHUD

const BLOCK_CATALOG: Dictionary = {
	"bldg_a": "res://scenes/ceuta_building_a.tscn",
	"bldg_b": "res://scenes/ceuta_building_b.tscn",
	"bldg_c": "res://scenes/ceuta_building_c.tscn",
	"bldg_d": "res://scenes/ceuta_building_d.tscn",
	"dragons": "res://scenes/ceuta_casa_dragones.tscn",
	"palacio": "res://scenes/ceuta_palacio_asamblea.tscn",
	"barricade": "res://scenes/barricade_wall.tscn",
	"base_hq": "res://scenes/base_structure.tscn",
	"turret_gatling": "res://scenes/turret_3d.tscn",
	"unit_ally": "res://scenes/unit_3d.tscn",
	"enemy_base": "res://scenes/enemy_unit.tscn",
	"enemy_shield": "res://scenes/enemy_shield.tscn",
	"enemy_sniper": "res://scenes/enemy_sniper.tscn",
	"enemy_boss": "res://scenes/enemy_boss.tscn"
}

func _ready() -> void:
	add_to_group("main_stages")
	public_opinion = max_public_opinion
	
	# Optimisation Thermique M4 : Limiter à 60 FPS et VSync
	Engine.max_fps = 60
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	
	_update_hud_opinion()
	_check_and_load_custom_map()

func _check_and_load_custom_map() -> void:
	var custom_map_path: String = GameState.pending_map_path if GameState and GameState.pending_map_path != "" else ProjectSettings.get_setting("game/custom_map_path", "")
	if custom_map_path != "" and FileAccess.file_exists(custom_map_path):
		print("[MAIN STAGE] Chargement de la carte personnalisée v2 : ", custom_map_path)
		var v2_data := MapIO.load_map(custom_map_path)
		if v2_data != null:
			var custom_container := Node3D.new()
			custom_container.name = "CustomMapContainer"
			add_child(custom_container)
			var catalog := BlockCatalog.create_default()
			MapRuntime.spawn_into(v2_data, custom_container, catalog, 1) # Layer 1 = Physique de jeu

func _build_custom_blocks(blocks: Array, parent: Node3D) -> void:
	for b in blocks:
		if b is Dictionary:
			var key: String = b.get("key", "bldg_a")
			if BLOCK_CATALOG.has(key):
				var path: String = BLOCK_CATALOG[key]
				if ResourceLoader.exists(path):
					var scn := load(path) as PackedScene
					if scn:
						var inst := scn.instantiate() as Node3D
						parent.add_child(inst)
						var pos: Array = b.get("pos", [0,0,0])
						var rot: Array = b.get("rot", [0,0,0])
						inst.global_position = Vector3(pos[0], pos[1], pos[2])
						inst.rotation_degrees = Vector3(rot[0], rot[1], rot[2])

func _build_custom_primitives(primitives: Array, parent: Node3D) -> void:
	for p in primitives:
		if p is Dictionary:
			var type: String = p.get("type", "box")
			var size_arr: Array = p.get("size", [4, 4, 4])
			var size_v := Vector3(size_arr[0], size_arr[1], size_arr[2])
			var pos_arr: Array = p.get("pos", [0, 0, 0])
			var rot_arr: Array = p.get("rot", [0, 0, 0])
			
			var mi := MeshInstance3D.new()
			match type:
				"box":
					var box := BoxMesh.new()
					box.size = size_v
					mi.mesh = box
				"cylinder":
					var cyl := CylinderMesh.new()
					cyl.top_radius = size_v.x * 0.5
					cyl.bottom_radius = size_v.x * 0.5
					cyl.height = size_v.y
					mi.mesh = cyl
				"sphere":
					var sph := SphereMesh.new()
					sph.radius = size_v.x * 0.5
					sph.height = size_v.y
					mi.mesh = sph
				"prism":
					var pri := PrismMesh.new()
					pri.size = size_v
					mi.mesh = pri
					
			var mat := StandardMaterial3D.new()
			var tex_path: String = p.get("texture", "res://textures/ceuta_pavement_tile.png")
			var tex := TextureManager.load_texture_from_path(tex_path)
			if tex:
				mat.albedo_texture = tex
				var uv_arr: Array = p.get("uv_scale", [1, 1])
				mat.uv1_scale = Vector3(uv_arr[0], uv_arr[1], 1)
			mi.material_override = mat
			
			var static_body := StaticBody3D.new()
			var col_shape := CollisionShape3D.new()
			var box_shape := BoxShape3D.new()
			box_shape.size = size_v
			col_shape.shape = box_shape
			static_body.add_child(col_shape)
			static_body.add_child(mi)
			
			parent.add_child(static_body)
			static_body.global_position = Vector3(pos_arr[0], pos_arr[1], pos_arr[2])
			static_body.rotation_degrees = Vector3(rot_arr[0], rot_arr[1], rot_arr[2])

func _build_custom_units(units: Array, parent: Node3D) -> void:
	for u in units:
		if u is Dictionary:
			var key: String = u.get("key", "unit_ally")
			if BLOCK_CATALOG.has(key):
				var path: String = BLOCK_CATALOG[key]
				if ResourceLoader.exists(path):
					var scn := load(path) as PackedScene
					if scn:
						var inst := scn.instantiate() as Node3D
						parent.add_child(inst)
						var pos: Array = u.get("pos", [0,0,0])
						var rot: Array = u.get("rot", [0,0,0])
						inst.global_position = Vector3(pos[0], pos[1], pos[2])
						inst.rotation_degrees = Vector3(rot[0], rot[1], rot[2])
						
						var dir: String = u.get("directive", "GUARD")
						var raw_wpts: Array = u.get("waypoints", [])
						var vec_wpts: Array = []
						for wpt in raw_wpts:
							if wpt is Array and wpt.size() >= 3:
								vec_wpts.append(Vector3(wpt[0], wpt[1], wpt[2]))
								
						if inst.has_method("set_directive"):
							inst.call("set_directive", dir, vec_wpts)

func adjust_public_opinion(amount: float) -> void:
	public_opinion = clamp(public_opinion + amount, 0.0, max_public_opinion)
	_update_hud_opinion()
	
	if public_opinion <= 0.0:
		var huds := get_tree().get_nodes_in_group("main_huds")
		if not huds.is_empty() and huds[0].has_method("show_game_over"):
			huds[0].call("show_game_over", "GAME OVER ! L'opinion publique est tombée à 0 % suite aux bavures civiques.")

func _update_hud_opinion() -> void:
	if main_hud and main_hud.has_method("update_opinion"):
		main_hud.call("update_opinion", public_opinion)
