extends Control

var map_world_size: float = 360.0

func _draw() -> void:
	var rect_size := get_size()
	var center := rect_size * 0.5
	var scale_factor := rect_size.x / map_world_size

	# Fond radar sombre avec quadrillage tactique
	draw_rect(Rect2(Vector2.ZERO, rect_size), Color(0.04, 0.08, 0.12, 0.85), true)
	draw_rect(Rect2(Vector2.ZERO, rect_size), Color(0.2, 0.8, 1.0, 0.6), false, 2.0)
	
	# Cercles concentriques radar
	draw_arc(center, rect_size.x * 0.25, 0, TAU, 32, Color(0.2, 0.8, 1.0, 0.25), 1.0)
	draw_arc(center, rect_size.x * 0.45, 0, TAU, 32, Color(0.2, 0.8, 1.0, 0.25), 1.0)

	# 1. Base QG (Carré Vert)
	var bases := get_tree().get_nodes_in_group("base")
	for b in bases:
		if is_instance_valid(b) and b is Node3D:
			var pos_2d := _world_to_minimap((b as Node3D).global_position, center, scale_factor)
			draw_rect(Rect2(pos_2d - Vector2(6, 6), Vector2(12, 12)), Color(0.2, 0.9, 0.4, 0.95), true)

	# 2. Barricades (Lignes Jaunes)
	var barricades := get_tree().get_nodes_in_group("barricades")
	for wall in barricades:
		if is_instance_valid(wall) and wall is Node3D:
			var pos_2d := _world_to_minimap((wall as Node3D).global_position, center, scale_factor)
			draw_line(pos_2d - Vector2(10, 0), pos_2d + Vector2(10, 0), Color(1.0, 0.85, 0.2, 0.95), 3.0)

	# 3. Soldats Alliés (Points Bleus)
	var units := get_tree().get_nodes_in_group("units")
	for u in units:
		if is_instance_valid(u) and u is Node3D:
			var pos_2d := _world_to_minimap((u as Node3D).global_position, center, scale_factor)
			draw_circle(pos_2d, 3.5, Color(0.2, 0.6, 1.0, 0.95))

	# 4. Ennemis Insurgés (Points Rouges)
	var enemies := get_tree().get_nodes_in_group("enemies")
	for e in enemies:
		if is_instance_valid(e) and e is Node3D:
			var pos_2d := _world_to_minimap((e as Node3D).global_position, center, scale_factor)
			var col := Color(1.0, 0.25, 0.25, 0.95)
			if e.get("unit_name") == "BOSS MASTODONTE BLINDÉ":
				draw_circle(pos_2d, 7.0, Color(1.0, 0.1, 0.9, 1.0))
			elif e.get("unit_name") == "Bélier à Bouclier":
				draw_circle(pos_2d, 4.5, Color(1.0, 0.5, 0.1, 0.95))
			else:
				draw_circle(pos_2d, 2.5, col)

	# 5. Cône de vision de la Caméra RTS
	var cams := get_tree().get_nodes_in_group("rts_cameras")
	if not cams.is_empty() and is_instance_valid(cams[0]) and cams[0] is Node3D:
		var cam_pos := _world_to_minimap((cams[0] as Node3D).global_position, center, scale_factor)
		draw_arc(cam_pos, 8.0, 0, TAU, 16, Color(1.0, 1.0, 1.0, 0.8), 1.5)

func _world_to_minimap(world_pos: Vector3, center: Vector2, scale_factor: float) -> Vector2:
	return center + Vector2(world_pos.x * scale_factor, world_pos.z * scale_factor)
