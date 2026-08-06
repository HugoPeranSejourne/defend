class_name ToolPlace
extends EditorTool

var _entry: Dictionary = {}
var _quarter := 0
var _cell := Vector2i.ZERO
var _fp := Vector2i.ONE
var _valid := false

func enter(args := {}) -> void:
	_entry = args.get("entry", {})
	_quarter = 0
	_refresh_footprint()
	var size := Vector3(_fp.x * editor.grid.cell_size, _entry.get("size", Vector3.ONE).y, _fp.y * editor.grid.cell_size)
	editor.ghost.configure(editor.catalog.create_mesh(_entry, size), _entry.get("size", Vector3.ONE).y)
	editor.ghost.visible = true
	editor.ui.set_status("Pose : %s — clic gauche : placer • R / Maj+R : pivoter • clic droit ou Échap : terminer" % _entry.get("label", "Objet"))

func exit() -> void:
	editor.ghost.visible = false

func on_pointer_move(world_pos: Vector3, _sp: Vector2) -> void:
	if world_pos == Vector3.INF:
		return
	_cell = editor.grid.world_to_cell(world_pos) - _fp / 2
	_refresh_validity()

func on_left_press(_wp: Vector3, _sp: Vector2) -> bool:
	if _valid:
		editor.place_block(_entry.key, _cell, _quarter)
	else:
		editor.ui.set_status("⛔ Emplacement invalide (occupé ou hors limites).")
	return true

func on_right_press() -> bool:
	editor.state_machine.activate(&"select")
	return true

func on_key(e: InputEventKey) -> bool:
	if e.keycode == KEY_R:
		_quarter = posmod(_quarter + (-1 if e.shift_pressed else 1), 4)
		_refresh_footprint()
		_refresh_validity()
		return true
	return false

func _refresh_footprint() -> void:
	_fp = _entry.get("footprint", Vector2i.ONE)
	if _quarter % 2 == 1:
		_fp = Vector2i(_fp.y, _fp.x)

func _refresh_validity() -> void:
	_valid = editor.grid.can_place(_cell, _fp)
	editor.ghost.position = editor.grid.cell_to_world(_cell, _fp)
	editor.ghost.rotation.y = _quarter * PI * 0.5
	editor.ghost.set_valid(_valid)
