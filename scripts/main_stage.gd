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
	"enemy_wave": "res://scenes/enemy_unit.tscn"
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
	var custom_map_path: String = ProjectSettings.get_setting("game/custom_map_path", "")
	if custom_map_path != "" and FileAccess.file_exists(custom_map_path):
		print("[MAIN STAGE] Chargement de la carte personnalisée : ", custom_map_path)
		var map_data := MapSerializer.load_map(custom_map_path)
		if not map_data.is_empty() and map_data.has("blocks"):
			_build_custom_map_objects(map_data["blocks"] as Array)

func _build_custom_map_objects(blocks: Array) -> void:
	var custom_container := Node3D.new()
	custom_container.name = "CustomMapObjects"
	add_child(custom_container)
	
	for block_info in blocks:
		if block_info is Dictionary:
			var key: String = block_info.get("key", "bldg_a")
			if BLOCK_CATALOG.has(key):
				var scene_path: String = BLOCK_CATALOG[key]
				if ResourceLoader.exists(scene_path):
					var scn := load(scene_path) as PackedScene
					if scn:
						var inst := scn.instantiate() as Node3D
						custom_container.add_child(inst)
						
						var pos_arr: Array = block_info.get("pos", [0, 0, 0])
						var rot_arr: Array = block_info.get("rot", [0, 0, 0])
						
						inst.global_position = Vector3(pos_arr[0], pos_arr[1], pos_arr[2])
						inst.rotation_degrees = Vector3(rot_arr[0], rot_arr[1], rot_arr[2])

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
