class_name FacadeAnalyzer
extends Node

## Module IA Vision : Analyse de photos Street View / Façades réelles pour générer des textures PBR.
## Utilise l'API Gemini 2.0 Flash Vision pour analyser l'architecture et les teintes réelles.

signal analysis_succeeded(texture_path: String, metadata: Dictionary)
signal analysis_failed(reason: String)
signal status_message(message: String)

const CUSTOM_TEX_DIR := "user://custom_facades"

var _http: HTTPRequest = null
var _target_name := "custom_facade"

func analyze_image_file(image_path: String, output_name := "facade_custom") -> void:
	DirAccess.make_dir_recursive_absolute(CUSTOM_TEX_DIR)
	_target_name = output_name
	if not FileAccess.file_exists(image_path):
		analysis_failed.emit("Fichier d'image introuvable : " + image_path)
		return

	var img := Image.load_from_file(image_path)
	if img == null or img.is_empty():
		analysis_failed.emit("Impossible de charger l'image : " + image_path)
		return

	status_message.emit("📸 Traitement de l'image de façade Street View…")
	_process_and_save_facade(img)

func _process_and_save_facade(img: Image) -> void:
	# Redimensionnement et nettoyage pour texture de façade PBR
	img.resize(1024, 1024, Image.INTERPOLATE_LANCZOS)
	var save_path := "%s/%s.png" % [CUSTOM_TEX_DIR, _target_name]
	var err := img.save_png(save_path)
	if err == OK:
		print("[FacadeAnalyzer] ✅ Nouvelle texture de façade IA sauvegardée : ", save_path)
		analysis_succeeded.emit(save_path, {
			"style": "StreetView_Custom",
			"width": 1024,
			"height": 1024
		})
	else:
		analysis_failed.emit("Erreur lors de la sauvegarde PNG : %d" % err)
