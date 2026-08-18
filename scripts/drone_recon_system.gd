extends Node3D
class_name DroneReconSystem

@export var is_drone_active: bool = false
@export var drone_height: float = 45.0

var _drone_cam: Camera3D = null
var _orig_cam: Camera3D = null

func _ready() -> void:
	add_to_group("drone_systems")
	_setup_drone_camera()

func _setup_drone_camera() -> void:
	_drone_cam = Camera3D.new()
	_drone_cam.name = "DroneCamera"
	_drone_cam.position = Vector3(0, drone_height, 0)
	_drone_cam.rotation_degrees = Vector3(-90, 0, 0)
	add_child(_drone_cam)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_TAB or event.keycode == KEY_C:
			toggle_drone_view()

func toggle_drone_view() -> void:
	is_drone_active = not is_drone_active
	if is_drone_active:
		_orig_cam = get_viewport().get_camera_3d()
		if _drone_cam:
			_drone_cam.make_current()
		_tag_all_enemies()
		print("[DRONE RECON] Vue satellite thermographique activée (100% visibilité vagues) !")
	else:
		if is_instance_valid(_orig_cam):
			_orig_cam.make_current()
		print("[DRONE RECON] Désactivation de la vue satellite.")

func _tag_all_enemies() -> void:
	var enemies := get_tree().get_nodes_in_group("enemies")
	for e in enemies:
		if is_instance_valid(e) and e is EnemyUnit:
			(e as EnemyUnit)._flash_red_hit()
