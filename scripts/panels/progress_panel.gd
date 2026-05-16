extends Control

signal continue_requested

var _icon_nodes: Array = []
var _node_names: Array = ["深空出发", "星云穿越", "小行星带", "烈焰风暴", "事件视界"]
var _completed_index: int = -1
var _next_index: int = 0

func _ready() -> void:
	hide()
	_icon_nodes = [$Icon, $Icon2, $Icon3, $Icon4, $Icon5]

func show_progress(completed_index: int, total_nodes: int) -> void:
	_completed_index = completed_index
	_next_index = completed_index + 1
	var label: Label = $Label
	if label:
		if _next_index >= total_nodes:
			label.text = "MISSION COMPLETE"
		else:
			label.text = "PROGRESS"
	_update_icons()
	show()

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		continue_requested.emit()
		hide()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_SPACE:
		continue_requested.emit()
		hide()

func _update_icons() -> void:
	for i: int in range(_icon_nodes.size()):
		var icon: Sprite2D = _icon_nodes[i]
		if icon == null:
			continue
		if i < _completed_index:
			icon.modulate = Color(0.3, 0.3, 0.3, 0.6)
		elif i == _completed_index:
			icon.modulate = Color(0.2, 1.0, 0.4, 1.0)
		elif i == _next_index and _next_index < _icon_nodes.size():
			icon.modulate = Color(1.0, 0.9, 0.3, 1.0)
		else:
			icon.modulate = Color(0.5, 0.5, 0.5, 0.4)
