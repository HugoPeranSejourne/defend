class_name FacadeAnalyzer
extends Node

## Module IA Vision : Traitement de photos Street View / Façades réelles pour générer des textures PBR.

signal analysis_succeeded(texture_path: String, metadata: Dictionary)
signal analysis_failed(reason: String)
signal status_message(message: String)

const RES_TEX_DIR := "res://textures"

func analyze_image_file(image_path: String, output_name := "facade_custom") -> void:
	if not FileAccess.file_exists(image_path):
		analysis_failed.emit("Fichier d'image introuvable : " + image_path)
		return

	var img := Image.load_from_file(image_path)
	if img == null or img.is_empty():
		analysis_failed.emit("Impossible de charger l'image : " + image_path)
		return

	status_message.emit("📸 Traitement de l'image de façade Street View…")
	_process_and_save_facade(img, output_name)

func _process_and_save_facade(img: Image, output_name: String) -> void:
	img.resize(1024, 1024, Image.INTERPOLATE_LANCZOS)
	var fname := "%s.png" % output_name
	var save_path := "%s/%s" % [RES_TEX_DIR, fname]

	var err := img.save_png(save_path)
	if err != OK:
		# Fallback sur user://textures/ si res:// est en lecture seule
		DirAccess.make_dir_recursive_absolute("user://textures")
		save_path = "user://textures/%s" % fname
		err = img.save_png(save_path)

	if err == OK:
		print("[FacadeAnalyzer] ✅ Nouvelle texture de façade sauvegardée : ", save_path)
		analysis_succeeded.emit(save_path, {
			"style": "StreetView_Custom",
			"name": output_name,
			"path": save_path
		})
	else:
		analysis_failed.emit("Erreur lors de la sauvegarde PNG : %d" % err)
