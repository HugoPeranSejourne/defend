extends CanvasLayer

static var instance: Node = null

@onready var log_label: Label = $PanelContainer/VBox/ScrollContainer/LogLabel
@onready var clear_btn: Button = $PanelContainer/VBox/ClearLogBtn

var _logs: Array = []

func _ready() -> void:
	instance = self
	layer = 100 # S'affiche au-dessus de TOUT le reste
	if clear_btn: clear_btn.pressed.connect(clear_logs)
	log_msg("=== CONSOLE DE LOGS EN JEU INITIALISÉE ===")

static func print_log(message: String) -> void:
	print(message)
	if instance and instance.has_method("log_msg"):
		instance.call("log_msg", message)

func log_msg(msg: String) -> void:
	var time_stamp := "%.2f" % (Time.get_ticks_msec() / 1000.0)
	var formatted := "[%s s] %s" % [time_stamp, msg]
	_logs.append(formatted)
	if _logs.size() > 25:
		_logs.pop_front()
		
	if log_label:
		log_label.text = "\n".join(_logs)

func clear_logs() -> void:
	_logs.clear()
	if log_label:
		log_label.text = ""
