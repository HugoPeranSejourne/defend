class_name EditorTool
extends RefCounted

var editor: MapEditor

func enter(_args := {}) -> void: pass
func exit() -> void: pass
func on_pointer_move(_world_pos: Vector3, _screen_pos: Vector2) -> void: pass
func on_left_press(_world_pos: Vector3, _screen_pos: Vector2) -> bool: return false
func on_left_release(_world_pos: Vector3, _screen_pos: Vector2) -> void: pass
func on_right_press() -> bool: return false
func on_key(_event: InputEventKey) -> bool: return false
