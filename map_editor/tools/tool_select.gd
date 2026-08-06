class_name ToolSelect
extends EditorTool

var _dragging := false
var _drag_id := -1
var _drag_start_cell := Vector2i.ZERO

func enter(_args := {}) -> void:
	editor.ui.set_status("Sélection : clic • glisser : déplacer • Suppr : supprimer • R : pivoter • [ ] : taille • Ctrl+D : dupliquer • clic droit glissé : orbite")

func exit() -> void:
	_dragging = false
	_drag_id = -1

func on_left_press(_wp: Vector3, screen_pos: Vector2) -> bool:
	var node := editor.pick_block(screen_pos)
	if node == null:
		editor.selection.deselect()
		return true
	var id := int(node.get_meta("block_id"))
	editor.selection.select(id, node)
	_dragging = true
	_drag_id = id
	_drag_start_cell = editor.get_block(id).get("cell", Vector2i.ZERO)
	return true

func on_pointer_move(world_pos: Vector3, _sp: Vector2) -> void:
	if not _dragging or world_pos == Vector3.INF:
		return
	var block := editor.get_block(_drag_id)
	if block.is_empty():
		return
	var fp: Vector2i = block.get("footprint", Vector2i.ONE)
	var cell := editor.grid.world_to_cell(world_pos) - fp / 2
	editor.preview_block_position(_drag_id, cell)

func on_left_release(world_pos: Vector3, _sp: Vector2) -> void:
	if not _dragging:
		return
	_dragging = false
	var block := editor.get_block(_drag_id)
	if not block.is_empty() and world_pos != Vector3.INF:
		var fp: Vector2i = block.get("footprint", Vector2i.ONE)
		var cell := editor.grid.world_to_cell(world_pos) - fp / 2
		editor.commit_move(_drag_id, _drag_start_cell, cell)
	_drag_id = -1

func on_right_press() -> bool:
	return false # clic droit libre -> orbite caméra gérée par le router

func on_key(e: InputEventKey) -> bool:
	match e.keycode:
		KEY_DELETE, KEY_BACKSPACE:
			editor.delete_selected()
			return true
		KEY_R:
			editor.rotate_selected(-1 if e.shift_pressed else 1)
			return true
		KEY_BRACKETLEFT:
			editor.resize_selected(-1)
			return true
		KEY_BRACKETRIGHT:
			editor.resize_selected(1)
			return true
	return false
