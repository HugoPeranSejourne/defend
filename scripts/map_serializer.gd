extends Node
class_name MapSerializer

const MAPS_DIR := "user://maps/"

static func ensure_maps_dir() -> void:
	if not DirAccess.dir_exists_absolute(MAPS_DIR):
		DirAccess.make_dir_recursive_absolute(MAPS_DIR)

static func save_map(map_name: String, category: String, author: String, blocks_data: Array) -> String:
	ensure_maps_dir()
	
	var clean_name := map_name.strip_edges().validate_filename()
	if clean_name == "":
		clean_name = "custom_map_" + str(Time.get_unix_time_from_system())
		
	var file_path := MAPS_DIR + clean_name + ".json"
	
	var map_dict := {
		"name": map_name,
		"category": category,
		"author": author if author != "" else "Joueur",
		"created_at": Time.get_datetime_string_from_system(),
		"blocks": blocks_data
	}
	
	var json_str := JSON.stringify(map_dict, "\t")
	var file := FileAccess.open(file_path, FileAccess.WRITE)
	if file:
		file.store_string(json_str)
		file.close()
		print("[MAP SERIALIZER] Carte enregistrée avec succès : ", file_path)
		return file_path
	else:
		push_error("[MAP SERIALIZER] Erreur d'écriture du fichier carte : " + file_path)
		return ""

static func load_map(map_path: String) -> Dictionary:
	if not FileAccess.file_exists(map_path):
		push_error("[MAP SERIALIZER] Fichier carte introuvable : " + map_path)
		return {}
		
	var file := FileAccess.open(map_path, FileAccess.READ)
	if not file:
		return {}
		
	var content := file.get_as_text()
	file.close()
	
	var json := JSON.new()
	var error := json.parse(content)
	if error == OK and json.data is Dictionary:
		return json.data as Dictionary
	else:
		push_error("[MAP SERIALIZER] Erreur de parsing JSON pour la carte : " + map_path)
		return {}

static func get_all_maps() -> Array:
	ensure_maps_dir()
	var maps_list := []
	var dir := DirAccess.open(MAPS_DIR)
	if dir:
		dir.list_dir_begin()
		var file_name := dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and file_name.ends_with(".json"):
				var path := MAPS_DIR + file_name
				var data := load_map(path)
				if not data.is_empty():
					data["file_path"] = path
					maps_list.append(data)
			file_name = dir.get_next()
	return maps_list
