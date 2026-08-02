extends Control
class_name SelectionManager

@export var camera: Node3D
@export var possession_panel: PanelContainer
@export var possession_button: Button
@export var fps_hud: Control

## Styles du rectangle de sélection
@export var border_color: Color = Color(0.2, 0.9, 0.4, 0.9)
@export var fill_color: Color = Color(0.2, 0.9, 0.4, 0.15)
@export var border_width: float = 2.0

var selected_units: Array = []
var possessed_unit: Node = null
var is_in_fps_mode: bool = false

var _is_dragging: bool = false
var _drag_start: Vector2 = Vector2.ZERO
var _drag_end: Vector2 = Vector2.ZERO
const DRAG_THRESHOLD: float = 8.0

func _ready() -> void:
	_locate_camera()
	if possession_panel:
		possession_panel.visible = false
	if possession_button:
		possession_button.pressed.connect(_on_possession_button_pressed)

func _locate_camera() -> void:
	if not camera:
		var cams := get_tree().get_nodes_in_group("rts_cameras")
		if not cams.is_empty() and cams[0] is Node3D:
			camera = cams[0] as Node3D
		else:
			camera = get_node_or_null("/root/MainStage/RTSCamera3D") as Node3D

func _unhandled_input(event: InputEvent) -> void:
	# 1. Gestion des entrées en mode FPS
	if is_in_fps_mode:
		if event.is_action_pressed("toggle_fps_possession"):
			exit_possession_mode()
			get_viewport().set_input_as_handled()
		elif event is InputEventKey and event.is_pressed() and event.keycode == KEY_ESCAPE:
			exit_possession_mode()
			get_viewport().set_input_as_handled()
		return

	# Si le joueur est en train de placer une tourelle/bâtiment, ne pas interférer avec la sélection
	var build_mgrs := get_tree().get_nodes_in_group("build_managers")
	if not build_mgrs.is_empty() and build_mgrs[0].get("selected_turret_type") != "":
		return

	_locate_camera()
	if not camera:
		return

	# Raccourci 'F' / Touche △ pour prendre le contrôle si au moins une unité est sélectionnée
	if event.is_action_pressed("toggle_fps_possession") or (event is InputEventKey and event.is_pressed() and event.keycode == KEY_F):
		if not selected_units.is_empty():
			enter_possession_mode(selected_units[0])
			get_viewport().set_input_as_handled()
			return

	# Clic Gauche (Trackpad / Souris) : Sélection
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.is_pressed():
			_is_dragging = true
			_drag_start = event.position
			_drag_end = event.position
			queue_redraw()
		elif _is_dragging:
			_drag_end = event.position
			_finish_selection(Input.is_key_pressed(KEY_SHIFT))
			_is_dragging = false
			queue_redraw()

	# Mouvement de la souris pendant le glisser du rectangle de sélection
	elif event is InputEventMouseMotion and _is_dragging:
		_drag_end = event.position
		queue_redraw()

	# Clic Droit : Ordre de déplacement de l'escouade
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.is_pressed():
		_command_move_units(event.position)

func enter_possession_mode(unit: Node) -> void:
	if not is_instance_valid(unit):
		return
		
	is_in_fps_mode = true
	possessed_unit = unit
	
	if possession_panel:
		possession_panel.visible = false
		
	if unit.has_method("enter_fps_mode"):
		unit.call("enter_fps_mode")
	elif unit.has_method("enter_possession"):
		unit.call("enter_possession", fps_hud)

func exit_possession_mode() -> void:
	if is_instance_valid(possessed_unit):
		if possessed_unit.has_method("exit_fps_mode"):
			possessed_unit.call("exit_fps_mode")
		elif possessed_unit.has_method("exit_possession"):
			possessed_unit.call("exit_possession", _get_rts_camera_3d())
		
	is_in_fps_mode = false
	possessed_unit = null
	
	_update_possession_overlay()

func _on_possession_button_pressed() -> void:
	if not selected_units.is_empty():
		enter_possession_mode(selected_units[0])

func _get_rts_camera_3d() -> Camera3D:
	_locate_camera()
	if camera:
		if camera is Camera3D:
			return camera as Camera3D
		var cam_node := camera.get_node_or_null("Camera3D") as Camera3D
		if cam_node:
			return cam_node
		return camera.get_node_or_null("PitchPivot/Camera3D") as Camera3D
	return null

func _draw() -> void:
	if not is_in_fps_mode and _is_dragging and _drag_start.distance_to(_drag_end) > DRAG_THRESHOLD:
		var rect := _get_selection_rect()
		draw_rect(rect, fill_color, true)
		draw_rect(rect, border_color, false, border_width)

func _get_selection_rect() -> Rect2:
	var top_left := Vector2(min(_drag_start.x, _drag_end.x), min(_drag_start.y, _drag_end.y))
	var size := Vector2(abs(_drag_start.x - _drag_end.x), abs(_drag_start.y - _drag_end.y))
	return Rect2(top_left, size)

func _finish_selection(is_shift_held: bool) -> void:
	var is_box_selection := _drag_start.distance_to(_drag_end) > DRAG_THRESHOLD

	if not is_shift_held:
		_deselect_all()

	var cam3d := _get_rts_camera_3d()
	if not cam3d:
		return

	if is_box_selection:
		var selection_rect := _get_selection_rect()
		var all_units := get_tree().get_nodes_in_group("units")
		
		for unit in all_units:
			if unit is Node3D:
				if not cam3d.is_position_behind(unit.global_position):
					var screen_pos := cam3d.unproject_position(unit.global_position)
					if selection_rect.has_point(screen_pos):
						_select_unit(unit)
	else:
		# Raycast avec le masque 5 (Layer 1 Sol + Layer 4 Unités)
		var hit: Dictionary = camera.call("raycast_from_screen", _drag_start, 5) if camera and camera.has_method("raycast_from_screen") else {}
		if not hit.is_empty() and hit.has("collider"):
			var collider = hit["collider"]
			if collider.has_method("set_selected"):
				_select_unit(collider)
			elif collider.get_parent() and collider.get_parent().has_method("set_selected"):
				_select_unit(collider.get_parent())
				
	_update_possession_overlay()

func _select_unit(unit: Node) -> void:
	if not selected_units.has(unit):
		selected_units.append(unit)
		if unit.has_method("set_selected"):
			unit.set_selected(true)

func _deselect_all() -> void:
	for unit in selected_units:
		if is_instance_valid(unit) and unit.has_method("set_selected"):
			unit.set_selected(false)
	selected_units.clear()
	_update_possession_overlay()

func _update_possession_overlay() -> void:
	if possession_panel:
		possession_panel.visible = not selected_units.is_empty() and not is_in_fps_mode

func _command_move_units(screen_pos: Vector2) -> void:
	if selected_units.is_empty() or is_in_fps_mode:
		return

	_locate_camera()
	var hit: Dictionary = camera.call("raycast_from_screen", screen_pos, 1) if camera and camera.has_method("raycast_from_screen") else {}
	if not hit.is_empty() and hit.has("position"):
		var target_point: Vector3 = hit["position"]
		var count := selected_units.size()
		
		if count == 1:
			var unit = selected_units[0]
			if unit.has_method("move_to_position"):
				unit.move_to_position(target_point)
			elif unit.has_method("move_to"):
				unit.move_to(target_point)
		else:
			var cols := int(ceil(sqrt(count)))
			var spacing := 1.6
			
			for i in range(count):
				var unit = selected_units[i]
				if not is_instance_valid(unit):
					continue
				
				var row := i / cols
				var col := i % cols
				var offset_x := (col - (cols - 1) / 2.0) * spacing
				var offset_z := (row - (count / cols) / 2.0) * spacing
				var unit_target := target_point + Vector3(offset_x, 0.0, offset_z)
				
				if unit.has_method("move_to_position"):
					unit.move_to_position(unit_target)
				elif unit.has_method("move_to"):
					unit.move_to(unit_target)
