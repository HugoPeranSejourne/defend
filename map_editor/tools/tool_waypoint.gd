class_name ToolWaypoint
extends EditorTool

var _path_id := ""
var _current_wps: Array[Vector3] = []

func enter(args := {}) -> void:
	_path_id = args.get("path_id", "")
	if _path_id == "":
		_path_id = editor.create_new_path_id()
	_current_wps = []
	editor.ui.set_status("🚩 Tracé chemin '%s' — clic gauche : ajouter waypoint • clic droit : terminer (%d points min 2)" % [_path_id, _current_wps.size()])

func exit() -> void:
	_current_wps = []

func on_pointer_move(world_pos: Vector3, _sp: Vector2) -> void:
	if world_pos == Vector3.INF:
		return
	var cell := editor.grid.world_to_cell(world_pos)
	var pos := editor.grid.cell_to_world(cell, Vector2i.ONE)
	editor.ghost.position = pos
	editor.ghost.set_valid(editor.grid.is_inside(cell))

func on_left_press(world_pos: Vector3, _sp: Vector2) -> bool:
	if world_pos == Vector3.INF:
		return true
	var cell := editor.grid.world_to_cell(world_pos)
	if not editor.grid.is_inside(cell):
		return true
	var pos := editor.grid.cell_to_world(cell, Vector2i.ONE)
	_current_wps.append(pos)
	editor.update_path_waypoints(_path_id, _current_wps)
	editor.ui.set_status("🚩 Chemin '%s' — %d waypoints • clic droit : terminer" % [_path_id, _current_wps.size()])
	return true

func on_right_press() -> bool:
	if _current_wps.size() >= 2:
		editor.ui.set_status("✅ Chemin '%s' terminé (%d waypoints)" % [_path_id, _current_wps.size()])
	else:
		editor.remove_path(_path_id)
		editor.ui.set_status("⚠ Chemin annulé (moins de 2 waypoints)")
	editor.state_machine.activate(&"select")
	return true
