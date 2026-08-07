# Autoload "DebugLog" — capture print/warning/error dans un fichier + buffer consultable.
# NE PAS ajouter de class_name (conflit avec le singleton).
extends Node

const LOG_FILE := "user://debug_log.txt"
const MAX_LINES := 500

var _file: FileAccess
var _buffer: PackedStringArray = []
var _overlay: RichTextLabel
var _overlay_visible := false

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute("user://")
	_file = FileAccess.open(LOG_FILE, FileAccess.WRITE)
	_log("=== SESSION %s ===" % Time.get_datetime_string_from_system())
	_log("Godot %s | %s" % [Engine.get_version_info().string, OS.get_name()])
	_build_overlay()

func _log(msg: String) -> void:
	var line := "[%s] %s" % [Time.get_time_string_from_system(), msg]
	_buffer.append(line)
	if _buffer.size() > MAX_LINES:
		_buffer.remove_at(0)
	if _file:
		_file.store_line(line)
		_file.flush()
	if _overlay and _overlay_visible:
		_overlay.text = "\n".join(_buffer)

func log_msg(msg: String) -> void:
	_log(msg)

func log_error(msg: String) -> void:
	_log("ERROR: " + msg)

func log_warn(msg: String) -> void:
	_log("WARN: " + msg)

func _input(event: InputEvent) -> void:
	# F12 (fn + F12 sur Mac) OU Cmd+L / Ctrl+L = toggle overlay de debug en jeu
	if event is InputEventKey and event.pressed:
		var k := event as InputEventKey
		if k.keycode == KEY_F12 or (k.is_command_or_control_pressed() and k.keycode == KEY_L):
			_overlay_visible = not _overlay_visible
			_overlay.visible = _overlay_visible
			if _overlay_visible:
				_overlay.text = "\n".join(_buffer)

func get_log_path() -> String:
	return ProjectSettings.globalize_path(LOG_FILE)

func get_recent(lines := 50) -> String:
	var start := maxi(0, _buffer.size() - lines)
	return "\n".join(_buffer.slice(start))

func _build_overlay() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 128
	add_child(layer)
	_overlay = RichTextLabel.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.bbcode_enabled = false
	_overlay.scroll_following = true
	_overlay.visible = false
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.85)
	_overlay.add_theme_stylebox_override("normal", style)
	layer.add_child(_overlay)
