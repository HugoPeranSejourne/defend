extends PanelContainer

signal action_move(target_node: Node3D)
signal action_texture(target_node: Node3D)
signal action_resize(target_node: Node3D)
signal action_delete(target_node: Node3D)

@onready var title_label: Label = $VBox/TitleLabel
@onready var move_btn: Button = $VBox/MoveBtn
@onready var texture_btn: Button = $VBox/TextureBtn
@onready var resize_btn: Button = $VBox/ResizeBtn
@onready var delete_btn: Button = $VBox/DeleteBtn
@onready var cancel_btn: Button = $VBox/CancelBtn

var _target_node: Node3D = null

func _ready() -> void:
	visible = false
	if move_btn: move_btn.pressed.connect(_on_move_pressed)
	if texture_btn: texture_btn.pressed.connect(_on_texture_pressed)
	if resize_btn: resize_btn.pressed.connect(_on_resize_pressed)
	if delete_btn: delete_btn.pressed.connect(_on_delete_pressed)
	if cancel_btn: cancel_btn.pressed.connect(hide_menu)

func open_at_mouse(target: Node3D, mouse_pos: Vector2) -> void:
	_target_node = target
	if not _target_node: return
	
	var node_title := _target_node.name
	if _target_node.has_meta("primitive_type"):
		node_title = "Forme " + str(_target_node.get_meta("primitive_type")).capitalize()
	elif _target_node.has_meta("block_key"):
		node_title = str(_target_node.get_meta("block_key")).capitalize()
	elif _target_node.has_meta("unit_key"):
		node_title = "Unité " + str(_target_node.get_meta("unit_key")).capitalize()
		
	if title_label:
		title_label.text = "📍 " + node_title
		
	position = mouse_pos
	visible = true

func hide_menu() -> void:
	visible = false
	_target_node = null

func _on_move_pressed() -> void:
	if _target_node:
		emit_signal("action_move", _target_node)
	hide_menu()

func _on_texture_pressed() -> void:
	if _target_node:
		emit_signal("action_texture", _target_node)
	hide_menu()

func _on_resize_pressed() -> void:
	if _target_node:
		emit_signal("action_resize", _target_node)
	hide_menu()

func _on_delete_pressed() -> void:
	if _target_node:
		emit_signal("action_delete", _target_node)
	hide_menu()
