extends CanvasLayer

@onready var fps_label: Label = $TopLeftMargin/VBoxContainer/FPSLabel
@onready var draw_calls_label: Label = $TopLeftMargin/VBoxContainer/DrawCallsLabel
@onready var memory_label: Label = $TopLeftMargin/VBoxContainer/MemoryLabel
@onready var vram_label: Label = $TopLeftMargin/VBoxContainer/VRAMLabel
@onready var entities_label: Label = $TopLeftMargin/VBoxContainer/EntitiesLabel
@onready var warning_label: Label = $TopLeftMargin/VBoxContainer/WarningLabel

var _log_timer: float = 0.0

func _process(delta: float) -> void:
	var fps := Engine.get_frames_per_second()
	var frame_ms := delta * 1000.0
	var draw_calls := Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	var static_mem_mb := Performance.get_monitor(Performance.MEMORY_STATIC) / (1024.0 * 1024.0)
	var vram_mem_mb := Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / (1024.0 * 1024.0)
	
	var enemies := get_tree().get_nodes_in_group("enemies").size()
	var units := get_tree().get_nodes_in_group("units").size()
	
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
		entities_label.text = "Ennemis : %d | Soldats : %d" % [enemies, units]

	_log_timer += delta
	if _log_timer >= 1.5:
		_log_timer = 0.0
		if fps < 50:
			var msg := ""
			if enemies > 100:
				msg = "[PERF LOG] Baisse FPS (%d) - Charge physique (%d ennemis)" % [fps, enemies]
			elif draw_calls > 150:
				msg = "[PERF LOG] Baisse FPS (%d) - Appels de rendu (%d draw calls)" % [fps, draw_calls]
			else:
				msg = "[PERF LOG] Baisse FPS détectée : %d FPS" % fps
				
			print(msg)
			if warning_label:
				warning_label.text = msg
				warning_label.visible = true
		else:
			if warning_label:
				warning_label.visible = false
