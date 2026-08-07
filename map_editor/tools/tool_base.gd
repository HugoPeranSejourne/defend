class_name ToolBase
extends EditorTool

var _cell := Vector2i.ZERO

func enter(_args := {}) -> void:
	var bm := BoxMesh.new()
	bm.size = Vector3(4, 3, 4)
	editor.ghost.configure(bm, 3.0)
	editor.ghost.visible = true
	editor.ui.set_status("🏰 Placer la Base à défendre — clic gauche : placer • clic droit : annuler")

func exit() -> void:
	editor.ghost.visible = false

func on_pointer_move(world_pos: Vector3, _sp: Vector2) -> void:
	if world_pos == Vector3.INF:
		return
	_cell = editor.grid.world_to_cell(world_pos)
	var pos := editor.grid.cell_to_world(_cell, Vector2i(2, 2))
	editor.ghost.position = pos
	var valid := editor.grid.can_place(_cell, Vector2i(2, 2))
	editor.ghost.set_valid(valid)

func on_left_press(_wp: Vector3, _sp: Vector2) -> bool:
	if not editor.grid.can_place(_cell, Vector2i(2, 2)):
		editor.ui.set_status("⛔ Emplacement invalide pour la base (2x2 requis)")
		return true
	var pos := editor.grid.cell_to_world(_cell, Vector2i(2, 2))
	editor.place_base(pos)
	editor.state_machine.activate(&"select")
	return true

func on_right_press() -> bool:
	editor.state_machine.activate(&"select")
	return true
