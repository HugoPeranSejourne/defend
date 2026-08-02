extends CanvasLayer

@onready var minimap_draw: Control = $BottomLeftMargin/MinimapPanel/MinimapDraw

func _process(_delta: float) -> void:
	if minimap_draw:
		minimap_draw.queue_redraw()
