class_name ToolSpawn
extends EditorTool

var _is_player := true
var _cell := Vector2i.ZERO

func enter(args := {}) -> void:
	_is_player = args.get("is_player", true)
	var label := "🟢 Zone de déploiement JOUEUR" if _is_player else "🔴 Spawn ENNEMI"
	editor.ui.set_status("%s — clic gauche : placer • clic droit : terminer" % label)
	var sm := SphereMesh.new()
	sm.radius = 1.0
	sm.height = 2.0
	editor.ghost.configure(sm, 2.0)
	editor.ghost.visible = true

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
	editor.place_spawn(pos, _is_player)
	return true

func on_right_press() -> bool:
	editor.state_machine.activate(&"select")
	return true
