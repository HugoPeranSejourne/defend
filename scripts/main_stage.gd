extends Node3D
class_name MainStage

@export var max_public_opinion: float = 100.0
@export var public_opinion: float = 100.0

@onready var main_hud: CanvasLayer = $MainHUD

func _ready() -> void:
	add_to_group("main_stages")
	public_opinion = max_public_opinion
	
	# Optimisation Thermique M4 : Limiter à 60 FPS et VSync
	Engine.max_fps = 60
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	
	_update_hud_opinion()

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
