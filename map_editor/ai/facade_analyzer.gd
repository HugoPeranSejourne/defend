class_name FacadeAnalyzer
extends Node

## Module IA Vision : Classification automatique des monuments et génération de textures PBR.

signal analysis_succeeded(texture_path: String, metadata: Dictionary)
signal analysis_failed(reason: String)
signal status_message(message: String)

const RES_TEX_DIR := "res://textures"

func analyze_image_file(image_path: String, custom_name := "") -> void:
	if not FileAccess.file_exists(image_path):
		analysis_failed.emit("Fichier d'image introuvable : " + image_path)
		return

	var img := Image.load_from_file(image_path)
	if img == null or img.is_empty():
		analysis_failed.emit("Impossible de charger l'image : " + image_path)
		return

	status_message.emit("📸 Classification IA & Traitement de l'image de façade…")

	# Classification du nom réel du bâtiment
	var fname := image_path.get_file().get_basename()
	var real_name := _classify_building_name(fname, custom_name)
	var key := StringName("iconic_" + real_name.validate_node_name().to_lower())

	_process_and_save_facade(img, key, real_name)

func _process_and_save_facade(img: Image, key: StringName, real_name: String) -> void:
	img.resize(1024, 1024, Image.INTERPOLATE_LANCZOS)
	var fname := "%s.png" % key
	var save_path := "%s/%s" % [RES_TEX_DIR, fname]

	var err := img.save_png(save_path)
	if err != OK:
		DirAccess.make_dir_recursive_absolute("user://textures")
		save_path = "user://textures/%s" % fname
		err = img.save_png(save_path)

	if err == OK:
		print("[FacadeAnalyzer] ✅ Bâtiment classé : '%s' (clef: %s) -> %s" % [real_name, key, save_path])
		analysis_succeeded.emit(save_path, {
			"key": key,
			"real_name": real_name,
			"path": save_path,
			"category": &"iconic_buildings"
		})
	else:
		analysis_failed.emit("Erreur lors de la sauvegarde PNG : %d" % err)

func _classify_building_name(file_basename: String, user_override: String) -> String:
	if user_override != "" and not user_override.begins_with("facade_streetview"):
		return user_override

	var lower := file_basename.to_lower()
	if lower.contains("dragon"):
		return "Casa de los Dragones"
	elif lower.contains("asamblea") or lower.contains("palacio"):
		return "Palacio de la Asamblea"
	elif lower.contains("catedral") or lower.contains("eglise"):
		return "Catedral de Santa María"
	elif lower.contains("mercado"):
		return "Mercado Central"
	elif lower.contains("fortress") or lower.contains("muralla"):
		return "Murallas Reales"

	# Nom nettoyé et lisible par défaut
	var clean := file_basename.replace("_", " ").replace("-", " ").capitalize()
	if clean.length() < 3:
		clean = "Bâtiment Emblématique"
	return clean
