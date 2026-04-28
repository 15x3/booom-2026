extends Node

var _comm_panel: Control = null
var _config: Dictionary = {}
var _nodes_data: Array = []
var _message_queue: Array = []
var _is_showing: bool = false
var _wreck_scanned: bool = false

var _ending_texts: Dictionary = {
	"escape": "弹弓机动成功。已脱离引力捕获。\n\n前方：星光。\n引擎：在线。\n方向：未知。\n\n……但至少，是向外的。",
	"drift": "弹弓机动偏差。引擎燃料耗尽。\n\n方向：未知。\n速度：递减。\n引力：减弱中。\n\n系统日志：漂流中。无救援信号。",
	"consumed": "事件视界——不可逆边界。\n\n前方摄像头最终记录：\n纯粹的黑暗，越来越大。\n\n系统日志已自动保存。\n没有人会读到。"
}

func setup(comm_panel: Control, config: Dictionary, nodes_data: Array) -> void:
	_comm_panel = comm_panel
	_config = config.get("narrative", {})
	_nodes_data = nodes_data
	if _comm_panel:
		_comm_panel.message_completed.connect(_on_message_completed)

func show_intro(node_data: Dictionary) -> void:
	var text: String = node_data.get("narrative_intro", "")
	if text == "":
		return
	_enqueue("[SYS] " + text)

func show_wreck_log(text: String) -> void:
	_wreck_scanned = true
	_enqueue("[LOG] " + text)

func show_ending(ending_type: String) -> void:
	var text: String = _ending_texts.get(ending_type, "")
	if text == "":
		text = "结束。"
	_enqueue(text)

func show_text(prefix: String, text: String) -> void:
	_enqueue(prefix + text)

func clear() -> void:
	_message_queue.clear()
	if _comm_panel and _comm_panel.has_method("clear"):
		_comm_panel.clear()
	_is_showing = false

func is_showing() -> bool:
	return _is_showing

func _enqueue(text: String) -> void:
	_message_queue.append(text)
	if not _is_showing:
		_show_next()

func _show_next() -> void:
	if _message_queue.is_empty():
		_is_showing = false
		return
	_is_showing = true
	var text: String = _message_queue.pop_front()
	if _comm_panel and _comm_panel.has_method("show_message"):
		var speed: float = _config.get("char_speed", 0.04)
		_comm_panel.show_message(text, speed)
	else:
		_is_showing = false
		_show_next()

func _on_message_completed() -> void:
	var pause: float = _config.get("message_pause", 1.0)
	if pause > 0.0 and not _message_queue.is_empty():
		get_tree().create_timer(pause).timeout.connect(_show_next)
	else:
		_show_next()
