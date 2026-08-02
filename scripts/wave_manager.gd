extends Node
class_name WaveManager

signal wave_changed(current_wave: int, total_waves: int)
signal enemy_count_changed(remaining: int, total: int)
signal wave_completed()

@export var enemy_scene: PackedScene
@export var shield_scene: PackedScene
@export var sniper_scene: PackedScene
@export var boss_scene: PackedScene

@export var current_wave: int = 1
@export var max_waves: int = 5

var total_enemies_in_wave: int = 120
var enemies_remaining: int = 120
var enemies_spawned: int = 0

var spawn_points: Array[Vector3] = [
	Vector3(-60.0, 0.0, -140.0),
	Vector3(-35.0, 0.0, -145.0),
	Vector3(0.0, 0.0, -150.0),
	Vector3(35.0, 0.0, -145.0),
	Vector3(60.0, 0.0, -140.0),
	Vector3(0.0, 0.0, -160.0)
]

var balcony_sniper_points: Array[Vector3] = [
	Vector3(-26.0, 8.5, -80.0),
	Vector3(26.0, 8.5, -80.0),
	Vector3(-26.0, 8.5, -30.0),
	Vector3(26.0, 8.5, -30.0)
]

var _spawn_timer: float = 0.0
var spawn_interval: float = 0.16
var is_spawning: bool = false

func _ready() -> void:
	if not enemy_scene: enemy_scene = load("res://scenes/enemy_unit.tscn")
	if not shield_scene: shield_scene = load("res://scenes/enemy_shield.tscn")
	if not sniper_scene: sniper_scene = load("res://scenes/enemy_sniper.tscn")
	if not boss_scene: boss_scene = load("res://scenes/enemy_boss.tscn")

	start_wave(1)

func start_wave(wave_num: int) -> void:
	current_wave = wave_num
	enemies_spawned = 0
	_spawn_timer = 0.0
	
	match current_wave:
		1: total_enemies_in_wave = 120
		2: total_enemies_in_wave = 180
		3: total_enemies_in_wave = 250
		4: total_enemies_in_wave = 320
		_: total_enemies_in_wave = 400

	enemies_remaining = total_enemies_in_wave
	is_spawning = true
	
	emit_signal("wave_changed", current_wave, max_waves)
	emit_signal("enemy_count_changed", enemies_remaining, total_enemies_in_wave)
	
	_announce_wave_in_hud()
	
	# En vague 3+, faire apparaître les snipers sur les balcons
	if current_wave >= 3:
		_spawn_balcony_snipers()
		
	# En vague 5, faire apparaître le Boss Mastodonte !
	if current_wave == 5:
		_spawn_boss_mastodon()

func _announce_wave_in_hud() -> void:
	var huds := get_tree().get_nodes_in_group("main_huds")
	if not huds.is_empty() and huds[0].has_method("update_enemy_count"):
		huds[0].call("update_enemy_count", enemies_remaining, total_enemies_in_wave)

func _spawn_balcony_snipers() -> void:
	if not sniper_scene: return
	for p in balcony_sniper_points:
		var sniper := sniper_scene.instantiate() as Node3D
		if sniper:
			get_tree().root.add_child(sniper)
			sniper.global_position = p
			if sniper.has_signal("enemy_died"):
				sniper.connect("enemy_died", Callable(self, "_on_enemy_died"))

func _spawn_boss_mastodon() -> void:
	if not boss_scene: return
	var boss := boss_scene.instantiate() as Node3D
	if boss:
		get_tree().root.add_child(boss)
		boss.global_position = Vector3(0.0, 0.0, -155.0)
		if boss.has_signal("enemy_died"):
			boss.connect("enemy_died", Callable(self, "_on_enemy_died"))

func _process(delta: float) -> void:
	if not is_spawning:
		return

	_spawn_timer += delta
	if _spawn_timer >= spawn_interval:
		_spawn_timer = 0.0
		_spawn_next_enemy()

func _spawn_next_enemy() -> void:
	if enemies_spawned >= total_enemies_in_wave:
		is_spawning = false
		return

	enemies_spawned += 1
	var spawn_pos := spawn_points[randi() % spawn_points.size()]
	spawn_pos.x += randf_range(-6.0, 6.0)
	spawn_pos.z += randf_range(-4.0, 4.0)

	var selected_scene: PackedScene = enemy_scene
	# Vague 2+ : 25% de béliers à bouclier
	if current_wave >= 2 and randf() < 0.25 and shield_scene:
		selected_scene = shield_scene

	var new_enemy := selected_scene.instantiate() as Node3D
	if new_enemy:
		get_tree().root.add_child(new_enemy)
		new_enemy.global_position = spawn_pos
		if new_enemy.has_signal("enemy_died"):
			new_enemy.connect("enemy_died", Callable(self, "_on_enemy_died"))

func _on_enemy_died(_enemy: Node3D) -> void:
	enemies_remaining = max(0, enemies_remaining - 1)
	emit_signal("enemy_count_changed", enemies_remaining, total_enemies_in_wave)
	_announce_wave_in_hud()

	if enemies_remaining <= 0 and not is_spawning:
		if current_wave < max_waves:
			var timer := get_tree().create_timer(4.0)
			timer.timeout.connect(func(): start_wave(current_wave + 1))
		else:
			emit_signal("wave_completed")
			var huds := get_tree().get_nodes_in_group("main_huds")
			if not huds.is_empty() and huds[0].has_method("show_victory"):
				huds[0].call("show_victory")
