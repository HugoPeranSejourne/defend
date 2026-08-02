extends CanvasLayer

@onready var fps_label: Label = $TopLeftMargin/VBoxContainer/FPSLabel
@onready var draw_calls_label: Label = $TopLeftMargin/VBoxContainer/DrawCallsLabel
@onready var memory_label: Label = $TopLeftMargin/VBoxContainer/MemoryLabel
@onready var vram_label: Label = $TopLeftMargin/VBoxContainer/VRAMLabel
@onready var entities_label: Label = $TopLeftMargin/VBoxContainer/EntitiesLabel
@onready var warning_label: Label = $TopLeftMargin/VBoxContainer/WarningLabel
@onready var debug_3d_label: Label = $TopLeftMargin/VBoxContainer/Debug3DLogLabel

var _log_timer: float = 0.0

func _process(delta: float) -> void:
	var fps := Engine.get_frames_per_second()
	var frame_ms := delta * 1000.0
	var draw_calls := Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	var static_mem_mb := Performance.get_monitor(Performance.MEMORY_STATIC) / (1024.0 * 1024.0)
	var vram_mem_mb := Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / (1024.0 * 1024.0)
	
	var enemies := get_tree().get_nodes_in_group("enemies")
	var units := get_tree().get_nodes_in_group("units")
	
	if fps_label:
		fps_label.text = "FPS : %d (%.1f ms)" % [fps, frame_ms]
		if fps >= 55:
			fps_label.add_theme_color_override("font_color", Color(0.3, 0.95, 0.4, 1.0))
		elif fps >= 40:
			fps_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2, 1.0))
		else:
			fps_label.add_theme_color_override("font_color", Color(1.0, 0.25, 0.25, 1.0))
			
	if draw_calls_label:
		draw_calls_label.text = "Draw Calls : %d" % draw_calls
	if memory_label:
		memory_label.text = "RAM Statique : %.1f MB (Pas de fuite)" % static_mem_mb
	if vram_label:
		vram_label.text = "VRAM Textures : %.1f MB" % vram_mem_mb
	if entities_label:
		entities_label.text = "Ennemis : %d | Soldats : %d" % [enemies.size(), units.size()]

	# Diagnostic 3D en direct
	if debug_3d_label and not units.is_empty():
		var first_unit := units[0] as Node3D
		if is_instance_valid(first_unit):
			var mi := first_unit.find_child("vanguard_Mesh", true, false) as MeshInstance3D
			var skel := first_unit.find_child("Skeleton3D", true, false) as Skeleton3D
			var anim := first_unit.find_child("AnimationPlayer", true, false) as AnimationPlayer
			
			var vis_str := "N/A"
			var scale_str := "N/A"
			var skel_str := "N/A"
			var anim_str := "N/A"
			
			if mi:
				vis_str = str(mi.is_visible_in_tree())
				scale_str = str(mi.global_transform.basis.get_scale())
			if skel:
				skel_str = "%d os" % skel.get_bone_count()
			if anim:
				anim_str = anim.current_animation if anim.current_animation != "" else "STOP"

			debug_3d_label.text = "[3D DIAG] Visible: %s | Scale: %s | Skel: %s | Anim: %s" % [vis_str, scale_str, skel_str, anim_str]

	_log_timer += delta
	if _log_timer >= 2.0:
		_log_timer = 0.0
		_print_detailed_console_diagnostics(units, enemies)

func _print_detailed_console_diagnostics(units: Array, enemies: Array) -> void:
	print("========== [DIAGNOSTIC RUNTIME RENDU 3D] ==========")
	print("Nombre total d'unités alliées actives : ", units.size())
	print("Nombre total d'ennemis actifs : ", enemies.size())
	
	if not units.is_empty():
		var u := units[0] as Node3D
		var mi := u.find_child("vanguard_Mesh", true, false) as MeshInstance3D
		if mi:
			print("  [ALLIÉ 1] Node: ", mi.name)
			print("    - Visibilité globale (is_visible_in_tree) : ", mi.is_visible_in_tree())
			print("    - Position globale 3D : ", mi.global_position)
			print("    - Échelle globale 3D : ", mi.global_transform.basis.get_scale())
			print("    - Squelette parent : ", mi.skeleton)
			print("    - Extra Cull Margin : ", mi.extra_cull_margin)
			print("    - Matériau d'override : ", mi.material_override)
		else:
			print("  [ALLIÉ 1] WARN: Mesh 'vanguard_Mesh' introuvable sous ", u.name)
			
	if not enemies.is_empty():
		var e := enemies[0] as Node3D
		var mi_e := e.find_child("vanguard_Mesh", true, false) as MeshInstance3D
		if mi_e:
			print("  [ENNEMI 1] Node: ", mi_e.name)
			print("    - Visibilité globale : ", mi_e.is_visible_in_tree())
			print("    - Position globale 3D : ", mi_e.global_position)
			print("    - Échelle globale 3D : ", mi_e.global_transform.basis.get_scale())
		else:
			print("  [ENNEMI 1] WARN: Mesh 'vanguard_Mesh' introuvable sous ", e.name)
	print("====================================================")
