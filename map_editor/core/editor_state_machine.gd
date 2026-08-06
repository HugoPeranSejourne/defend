class_name EditorStateMachine
extends RefCounted

signal tool_changed(name: StringName)

var active_name := &"select"
var active: EditorTool = null
var _tools: Dictionary = {}

func register(name: StringName, tool: EditorTool, editor: MapEditor) -> void:
	tool.editor = editor
	_tools[name] = tool

func activate(name: StringName, args := {}) -> void:
	if not _tools.has(name):
		push_error("[StateMachine] Tool inconnu : " + String(name))
		return
	if active:
		active.exit()
	active_name = name
	active = _tools[name]
	active.enter(args)
	tool_changed.emit(name)

func cancel() -> void:
	activate(&"select")

func count() -> int:
	return _tools.size()
