class_name ToolSelect
extends EditorTool

const DRAG_THRESHOLD := 8.0

var _press_pos := Vector2.ZERO
var _press_world := Vector3.INF
var _press_valid := false
var _pressed_id := -1
var _dragging_block := false
var _rect_selecting := false
var _rect_start := Vector2.ZERO
var _drag_start_cell := Vector2i.ZERO
var _drag_start_pos := Vector3.ZERO

func enter(_args := {}) -> void:
	editor.ui.set_status("Sélection : clic • glisser : déplacer / rectangle • Suppr : supprimer • R : pivoter • [ ] : taille • Ctrl+D : dupliquer • Ctrl+C/V : copier-coller")

func exit() -> void:
	_reset_state()
	editor.ui.hide_selection_rect()

func on_left_press(world_pos: Vector3, screen_pos: Vector2) -> bool:
	_press_pos = screen_pos
	_press_world = world_pos
	_press_valid = world_pos != Vector3.INF
	_dragging_block = false
	_rect_selecting = false

	var node := editor.pick_any(screen_pos)
	if node != null:
		var kind := editor.identify_node(node)
		if kind.begins_with("block:"):
			var id := int(kind.split(":")[1])
			var additive := Input.is_key_pressed(KEY_SHIFT)
			if not additive or not editor.selection.is_selected(id):
				if not additive:
					editor.selection.select_single(id, node)
				else:
					editor.selection.add(id, node)
			_pressed_id = id
			var blk := editor.get_block(id)
			if not blk.is_empty():
				_drag_start_cell = blk.get("cell", Vector2i.ZERO)
				_drag_start_pos = blk.get("pos", Vector3.ZERO)
		else:
			editor.selection.select_marker(kind, node)
			_pressed_id = -1
	else:
		_pressed_id = -1
	return true

func on_pointer_move(world_pos: Vector3, screen_pos: Vector2) -> void:
	if not _dragging_block and not _rect_selecting and _pressed_id < 0:
		if (screen_pos - _press_pos).length() > DRAG_THRESHOLD and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			_rect_selecting = true
			_rect_start = _press_pos
			editor.ui.show_selection_rect(_rect_start, _rect_start)

	if _rect_selecting:
		editor.ui.show_selection_rect(_rect_start, screen_pos)
		return

	if not _dragging_block and _pressed_id >= 0 and _press_valid:
		if (screen_pos - _press_pos).length() > DRAG_THRESHOLD and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			_dragging_block = true

	if _dragging_block and world_pos != Vector3.INF:
		var block := editor.get_block(_pressed_id)
		if block.is_empty():
			return
		var fp: Vector2i = block.get("footprint", Vector2i.ONE)
		var base_y: float = block.get("base_y", 0.0)
		if editor.stack_enabled:
			var cell := editor.grid.world_to_cell(world_pos) - fp / 2
			editor.preview_block_position_stacked(_pressed_id, cell, base_y)
		else:
			var cell := editor.grid.world_to_cell(world_pos) - fp / 2
			editor.preview_block_position(_pressed_id, cell)

func on_left_release(world_pos: Vector3, screen_pos: Vector2) -> void:
	if _rect_selecting:
		_rect_selecting = false
		editor.ui.hide_selection_rect()
		var rect := Rect2(_rect_start, screen_pos - _rect_start).abs()
		var additive := Input.is_key_pressed(KEY_SHIFT)
		editor.select_blocks_in_rect(rect, additive)
		return

	if _dragging_block:
		_dragging_block = false
		var block := editor.get_block(_pressed_id)
		if not block.is_empty() and world_pos != Vector3.INF:
			var fp: Vector2i = block.get("footprint", Vector2i.ONE)
			var base_y: float = block.get("base_y", 0.0)
			var cell := editor.grid.world_to_cell(world_pos) - fp / 2
			if editor.stack_enabled:
				editor.commit_move_stacked(_pressed_id, _drag_start_cell, base_y, cell, base_y)
			else:
				editor.commit_move(_pressed_id, _drag_start_cell, cell)
		_pressed_id = -1
		return

	_pressed_id = -1

func on_right_press() -> bool:
	if editor.selection.count() > 1:
		editor.selection.deselect()
		return true
	return false

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
		KEY_C:
			if e.is_command_or_control_pressed():
				editor.copy_selected()
				return true
		KEY_V:
			if e.is_command_or_control_pressed():
				editor.paste_clipboard()
				return true
	return false

func _reset_state() -> void:
	_press_valid = false
	_pressed_id = -1
	_dragging_block = false
	_rect_selecting = false
