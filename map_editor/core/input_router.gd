class_name InputRouter
extends Node

## SEUL nœud à lire l'input "monde".

const ORBIT_DEADZONE := 6.0

var _camera: EditorCamera
var _sm: EditorStateMachine
var _editor: MapEditor
var _ui: EditorUI

var _orbiting := false
var _panning := false
var _rmb_press_pos := Vector2.ZERO
var _rmb_moved := false

func setup(camera: EditorCamera, sm: EditorStateMachine, editor: MapEditor, ui: EditorUI) -> void:
	_camera = camera
	_sm = sm
	_editor = editor
	_ui = ui

func _process(delta: float) -> void:
	if _ui == null or _ui.is_modal_open():
		return
	if get_viewport().gui_get_focus_owner() != null:
		return
	# WASD horizontal
	var d := Vector2.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_LEFT): d.y += 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_RIGHT): d.y -= 1.0
	if Input.is_key_pressed(KEY_A): d.x -= 1.0
	if Input.is_key_pressed(KEY_D): d.x += 1.0
	if d != Vector2.ZERO:
		if Input.is_key_pressed(KEY_SHIFT):
			d *= 2.5
		_camera.pan(d.normalized(), delta)
	# Flèches haut/bas : élévation caméra
	if Input.is_key_pressed(KEY_UP):
		_camera.pan_vertical(6.0 * delta)
	if Input.is_key_pressed(KEY_DOWN):
		_camera.pan_vertical(-6.0 * delta)

func _unhandled_input(event: InputEvent) -> void:
	if _ui == null or _ui.is_modal_open():
		return
	if event is InputEventKey:
		var k := event as InputEventKey
		if not k.pressed or k.echo:
			return
		if _handle_shortcuts(k):
			return
		if _sm.active and _sm.active.on_key(k):
			get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton:
		_handle_mouse_button(event as InputEventMouseButton)
		return
	if event is InputEventMouseMotion:
		_handle_mouse_motion(event as InputEventMouseMotion)

func _handle_shortcuts(k: InputEventKey) -> bool:
	if k.is_command_or_control_pressed():
		match k.keycode:
			KEY_Z:
				if k.shift_pressed: _editor.undo.redo()
				else: _editor.undo.undo()
			KEY_Y: _editor.undo.redo()
			KEY_D: _editor.duplicate_selected()
			KEY_C: _editor.copy_selected()
			KEY_V: pass # géré par ToolSelect.on_key
			KEY_S: _editor.save_map()
			_: return false
		get_viewport().set_input_as_handled()
		return true
	match k.keycode:
		KEY_ESCAPE:
			if _sm.active_name != &"select": _sm.activate(&"select")
			else: _editor.selection.deselect()
		KEY_F: _editor.focus_selection_or_origin()
		KEY_F1:
			_ui.toggle_help()
			get_viewport().set_input_as_handled()
			return true
		_: return false
	get_viewport().set_input_as_handled()
	return true

func _handle_mouse_button(mb: InputEventMouseButton) -> void:
	match mb.button_index:
		MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN:
			if mb.pressed:
				var steps := 1 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else -1
				if _sm.active and _sm.active.has_method("on_wheel") and _sm.active.on_wheel(steps):
					get_viewport().set_input_as_handled()
					return
				_camera.zoom(steps)
				get_viewport().set_input_as_handled()
		MOUSE_BUTTON_MIDDLE:
			_panning = mb.pressed
			get_viewport().set_input_as_handled()
		MOUSE_BUTTON_RIGHT:
			if mb.pressed:
				_rmb_press_pos = mb.position
				_rmb_moved = false
				if _sm.active and _sm.active.on_right_press():
					pass
				else:
					_orbiting = true
				get_viewport().set_input_as_handled()
			else:
				if _orbiting and not _rmb_moved:
					_editor.request_context_menu(mb.position)
				_orbiting = false
				get_viewport().set_input_as_handled()
		MOUSE_BUTTON_LEFT:
			if mb.pressed:
				get_viewport().gui_release_focus()
				var wp := _editor.screen_to_ground(mb.position)
				if _sm.active and _sm.active.on_left_press(wp, mb.position):
					get_viewport().set_input_as_handled()
			else:
				if _sm.active:
					_sm.active.on_left_release(_editor.screen_to_ground(mb.position), mb.position)
				get_viewport().set_input_as_handled()

func _handle_mouse_motion(mm: InputEventMouseMotion) -> void:
	if _orbiting:
		if not _rmb_moved and (mm.position - _rmb_press_pos).length() > ORBIT_DEADZONE:
			_rmb_moved = true
		if _rmb_moved:
			_camera.orbit(mm.relative)
		get_viewport().set_input_as_handled()
		return
	if _panning:
		_camera.pan_pixels(mm.relative)
		get_viewport().set_input_as_handled()
		return
	var wp := _editor.screen_to_ground(mm.position)
	_ui.set_coords(wp)
	if _sm.active:
		_sm.active.on_pointer_move(wp, mm.position)
