class_name OSMFetcher
extends Node

signal fetch_succeeded(json_text: String)
signal fetch_failed(reason: String)
signal status_message(message: String)

const MIRRORS := [
	"https://overpass-api.de/api/interpreter",
	"https://overpass.kumi.systems/api/interpreter",
]
const CACHE_DIR := "user://ai_cache"
const USER_AGENT := "DefendEuropeMapEditor/1.0 (Godot 4, module OSM)"
const REQUEST_TIMEOUT := 30

var _http: HTTPRequest = null
var _mirror_idx := 0
var _query := ""
var _cache_path := ""

func fetch(lat: float, lng: float, bbox: String) -> void:
	DirAccess.make_dir_recursive_absolute(CACHE_DIR)
	_cache_path = cache_path_for(lat, lng)
	if FileAccess.file_exists(_cache_path):
		var txt := FileAccess.get_file_as_string(_cache_path)
		if txt.length() > 200 and txt.contains("\"elements\""):
			status_message.emit("📦 Cache local utilisé")
			fetch_succeeded.emit(txt)
			return
	_query = "[out:json][timeout:25];(way[\"building\"](%s);way[\"highway\"](%s);way[\"leisure\"~\"park|playground\"](%s);node[\"place\"~\"square\"](%s););out geom;" % [bbox, bbox, bbox, bbox]
	_mirror_idx = 0
	_do_request()

func cancel() -> void:
	if _http and is_instance_valid(_http):
		_http.cancel_request()

static func cache_path_for(lat: float, lng: float) -> String:
	return "%s/%s.json" % [CACHE_DIR, "%.5f_%.5f" % [lat, lng]]

static func clear_cache(lat: float, lng: float) -> void:
	var p := cache_path_for(lat, lng)
	if FileAccess.file_exists(p):
		DirAccess.remove_absolute(p)

func _do_request() -> void:
	if _http and is_instance_valid(_http):
		_http.queue_free()
		_http = null
	_http = HTTPRequest.new()
	# ★ FIX PRINCIPAL : DNS + TLS + transfert sur un thread dédié.
	# Sans ça, la phase de connexion bloque le thread principal (beachball macOS).
	_http.use_threads = true
	_http.accept_gzip = true
	_http.timeout = REQUEST_TIMEOUT
	add_child(_http)
	_http.request_completed.connect(_on_completed)
	var headers := [
		"Content-Type: application/x-www-form-urlencoded",
		"User-Agent: " + USER_AGENT,   # ★ exigé par la politique d'usage Overpass
		"Accept: application/json",
	]
	print("[OSMFetcher] → requête %s" % MIRRORS[_mirror_idx])
	var err := _http.request(MIRRORS[_mirror_idx], headers, HTTPClient.METHOD_POST, "data=" + _query.uri_encode())
	if err != OK:
		_try_next_mirror("erreur requête %d" % err)

func _on_completed(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	print("[OSMFetcher] ← résultat=%d code=%d octets=%d" % [result, code, body.size()])
	if result == HTTPRequest.RESULT_SUCCESS and code == 200:
		var txt := body.get_string_from_utf8()
		if txt.contains("\"elements\""):
			var f := FileAccess.open(_cache_path, FileAccess.WRITE)
			if f:
				f.store_string(txt)
				f.close()
			fetch_succeeded.emit(txt)
			return
		_try_next_mirror("réponse invalide (%d octets)" % body.size())
		return
	var reason := "HTTP %d" % code if result == HTTPRequest.RESULT_SUCCESS else "erreur réseau %d" % result
	_try_next_mirror(reason)

func _try_next_mirror(reason: String) -> void:
	_mirror_idx += 1
	if _mirror_idx < MIRRORS.size():
		status_message.emit("⚠ Miroir %d indisponible (%s) — essai miroir %d…" % [_mirror_idx, reason, _mirror_idx + 1])
		_do_request()
	else:
		fetch_failed.emit("Tous les miroirs Overpass ont échoué (%s).\nVérifiez votre connexion Internet." % reason)
