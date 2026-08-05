extends Node
class_name TextureManager

const TEXTURES_DIR := "user://textures/"

static func ensure_textures_dir() -> void:
	if not DirAccess.dir_exists_absolute(TEXTURES_DIR):
		DirAccess.make_dir_recursive_absolute(TEXTURES_DIR)

static func import_texture_from_file(file_path: String) -> Dictionary:
	ensure_textures_dir()
	
	if not FileAccess.file_exists(file_path):
		push_error("[TEXTURE MANAGER] Fichier introuvable : " + file_path)
		return {}
		
	var img := Image.load_from_file(file_path)
	if img == null or img.is_empty():
		push_error("[TEXTURE MANAGER] Impossible de charger l'image : " + file_path)
		return {}
		
	var file_name := file_path.get_file()
	var dest_path := TEXTURES_DIR + file_name
	
	# Copier dans user://textures/
	var dir := DirAccess.open("user://")
	if dir:
		dir.copy(file_path, dest_path)
		
	var tex := ImageTexture.create_from_image(img)
	print("[TEXTURE MANAGER] Texture importée avec succès : ", dest_path)
	
	return {
		"name": file_name.get_basename().capitalize(),
		"path": dest_path,
		"texture": tex
	}

static func load_texture_from_path(path: String) -> Texture2D:
	if path.begins_with("res://"):
		if ResourceLoader.exists(path):
			return load(path) as Texture2D
		return null
		
	if FileAccess.file_exists(path):
		var img := Image.load_from_file(path)
		if img and not img.is_empty():
			return ImageTexture.create_from_image(img)
	return null

static func get_all_imported_textures() -> Array:
	ensure_textures_dir()
	var list := []
	var dir := DirAccess.open(TEXTURES_DIR)
	if dir:
		dir.list_dir_begin()
		var f := dir.get_next()
		while f != "":
			if not dir.current_is_dir() and (f.ends_with(".png") or f.ends_with(".jpg") or f.ends_with(".jpeg")):
				var full_path := TEXTURES_DIR + f
				var tex := load_texture_from_path(full_path)
				if tex:
					list.append({
						"name": f.get_basename().capitalize(),
						"path": full_path,
						"texture": tex
					})
			f = dir.get_next()
	return list
