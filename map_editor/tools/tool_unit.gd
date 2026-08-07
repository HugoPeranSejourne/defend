class_name ToolUnit
extends EditorTool

var _entry: Dictionary = {}
var _cell := Vector2i.ZERO

func enter(args := {}) -> void:
	_entry = args.get("entry", {})
	var sm := CapsuleMesh.new()
	sm.radius = float(_entry.get("radius", 0.5))
	sm.height = float(_entry.get("height", 1.8))
	editor.ghost.configure(sm, float(_entry.get("height", 1.8)))
	editor.ghost.visible = true
	editor.ui.set_status("Pose : %s — clic gauche : placer • clic droit : terminer" % String(_entry.get("label", "Unité")))

func exit() -> void:
	editor.ghost.visible = false

func on_pointer_move(world_pos: Vector3, _sp: Vector2) -> void:
	if world_pos == Vector3.INF:
		return
	_cell = editor.grid.world_to_cell(world_pos)
	var pos := editor.grid.cell_to_world(_cell, Vector2i.ONE)
	editor.ghost.position = pos
	editor.ghost.set_valid(editor.grid.is_inside(_cell))

func on_left_press(_wp: Vector3, _sp: Vector2) -> bool:
	if not editor.grid.is_inside(_cell):
		return true
	var pos := editor.grid.cell_to_world(_cell, Vector2i.ONE)
	editor.place_unit(_entry, pos)
	return true

func on_right_press() -> bool:
	editor.state_machine.activate(&"select")
	return true
