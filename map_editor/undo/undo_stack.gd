class_name UndoStack
extends RefCounted

signal changed

const MAX := 100

var _undo: Array[Dictionary] = []
var _redo: Array[Dictionary] = []

## Exécute do_c immédiatement, puis empile la commande.
func push(do_c: Callable, undo_c: Callable, label := "") -> void:
	_redo.clear()
	_undo.append({"do": do_c, "undo": undo_c, "label": label})
	if _undo.size() > MAX:
		_undo.pop_front()
	do_c.call()
	changed.emit()

func undo() -> void:
	if _undo.is_empty():
		return
	var c: Dictionary = _undo.pop_back()
	(c.undo as Callable).call()
	_redo.append(c)
	changed.emit()

func redo() -> void:
	if _redo.is_empty():
		return
	var c: Dictionary = _redo.pop_back()
	(c["do"] as Callable).call()
	_undo.append(c)
	changed.emit()

func can_undo() -> bool: return not _undo.is_empty()
func can_redo() -> bool: return not _redo.is_empty()

func clear() -> void:
	_undo.clear()
	_redo.clear()
	changed.emit()
