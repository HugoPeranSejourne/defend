extends Node3D

@export var move_speed: float = 35.0
@export var zoom_speed: float = 8.0
@export var min_zoom: float = 10.0
@export var max_zoom: float = 450.0
@export var min_pitch: float = 15.0
@export var max_pitch: float = 85.0

@onready var camera: Camera3D = $Camera3D

var current_zoom: float = 40.0
var target_zoom: float = 40.0
var _is_fps_active: bool = false

func _ready() -> void:
	add_to_group("rts_cameras")
	current_zoom = 40.0
	target_zoom = 40.0
	_update_camera_transform()
	if camera:
		camera.current = true
		camera.far = 3500.0

func set_fps_active(active: bool) -> void:
	_is_fps_active = active
	visible = not active
	if camera:
		camera.current = not active

func raycast_from_screen(screen_pos: Vector2, collision_mask: int = 1) -> Dictionary:
	if not camera:
		return {}
	var from := camera.project_ray_origin(screen_pos)
	var to := from + camera.project_ray_normal(screen_pos) * 2500.0
	var space_state := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(from, to, collision_mask)
	return space_state.intersect_ray(query)

func _unhandled_input(event: InputEvent) -> void:
	if _is_fps_active:
		return
		
	# Molette de souris classique & Trackpad Mac
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			target_zoom = clamp(target_zoom - zoom_speed * event.factor, min_zoom, max_zoom)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			target_zoom = clamp(target_zoom + zoom_speed * event.factor, min_zoom, max_zoom)
			
	# Gestes Trackpad Mac (Défillement 2 doigts & Pincement)
	elif event is InputEventPanGesture:
		target_zoom = clamp(target_zoom + event.delta.y * zoom_speed * 1.5, min_zoom, max_zoom)
	elif event is InputEventMagnifyGesture:
		var zoom_factor: float = (1.0 - (event.factor - 1.0) * 2.0)
		target_zoom = clamp(target_zoom * zoom_factor, min_zoom, max_zoom)

func _process(delta: float) -> void:
	if _is_fps_active:
		return

	# Support Zoom Manette PS5 (L1 / R1)
	if Input.is_action_pressed("camera_zoom_in"):
		target_zoom = clamp(target_zoom - zoom_speed * delta * 8.0, min_zoom, max_zoom)
	elif Input.is_action_pressed("camera_zoom_out"):
		target_zoom = clamp(target_zoom + zoom_speed * delta * 8.0, min_zoom, max_zoom)

	var move_dir := Vector3.ZERO

	# Clavier WASD / Flèches
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		move_dir.z -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		move_dir.z += 1.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		move_dir.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		move_dir.x += 1.0

	# Support Stick Gauche Manette PS5
	var joy_x := Input.get_joy_axis(0, JOY_AXIS_LEFT_X)
	var joy_y := Input.get_joy_axis(0, JOY_AXIS_LEFT_Y)
	if abs(joy_x) > 0.2:
		move_dir.x += joy_x
	if abs(joy_y) > 0.2:
		move_dir.z += joy_y

	if move_dir.length_squared() > 0.001:
		move_dir = move_dir.normalized()
		var speed_mult := 1.0 + (current_zoom / 100.0) * 0.8
		global_position += move_dir * move_speed * speed_mult * delta

	# Contraintes de la carte 360x360m
	global_position.x = clamp(global_position.x, -160.0, 160.0)
	global_position.z = clamp(global_position.z, -160.0, 160.0)

	current_zoom = lerp(current_zoom, target_zoom, delta * 8.0)
	_update_camera_transform()

func _update_camera_transform() -> void:
	var t: float = (current_zoom - min_zoom) / (max_zoom - min_zoom)
	var pitch_deg: float = lerp(min_pitch, max_pitch, t)
	rotation_degrees.x = -pitch_deg
	
	if camera:
		camera.position = Vector3(0, 0, current_zoom)
