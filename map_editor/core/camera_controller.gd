class_name EditorCamera
extends Node3D

## Caméra PASSIVE : ne lit aucun input. Pilotée uniquement par l'InputRouter.

var camera: Camera3D
var yaw := 0.0
var pitch := -0.9
var distance := 45.0
var min_distance := 6.0
var max_distance := 140.0
var pan_speed := 22.0
var orbit_sensitivity := 0.0052
var zoom_factor := 1.12

var _pitch_pivot: Node3D

func _ready() -> void:
	_pitch_pivot = Node3D.new()
	_pitch_pivot.name = "PitchPivot"
	add_child(_pitch_pivot)
	camera = Camera3D.new()
	camera.name = "Camera3D"
	camera.current = true
	camera.fov = 60.0
	camera.near = 0.1
	camera.far = 2000.0
	_pitch_pivot.add_child(camera)
	_apply()

func pan(dir: Vector2, delta: float) -> void:
	var fwd := -global_transform.basis.z; fwd.y = 0.0; fwd = fwd.normalized()
	var right := global_transform.basis.x; right.y = 0.0; right = right.normalized()
	var speed := pan_speed * (distance / 45.0)
	position += (right * dir.x + fwd * dir.y) * speed * delta

func pan_vertical(amount: float) -> void:
	position.y = maxf(2.0, position.y + amount)

func pan_pixels(relative: Vector2) -> void:
	var fwd := -global_transform.basis.z; fwd.y = 0.0; fwd = fwd.normalized()
	var right := global_transform.basis.x; right.y = 0.0; right = right.normalized()
	var f := distance * 0.0016
	position += (-right * relative.x + fwd * relative.y) * f

func orbit(relative: Vector2) -> void:
	yaw -= relative.x * orbit_sensitivity
	pitch = clampf(pitch - relative.y * orbit_sensitivity, -1.45, -0.2)
	_apply()

func zoom(steps: float) -> void:
	distance = clampf(distance * pow(zoom_factor, -steps), min_distance, max_distance)
	_apply()

func focus_on(point: Vector3) -> void:
	position = Vector3(point.x, position.y, point.z)

func _apply() -> void:
	rotation.y = yaw
	_pitch_pivot.rotation.x = pitch
	camera.position = Vector3(0, 0, distance)
