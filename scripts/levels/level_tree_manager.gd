extends Node

signal run_completed
signal run_started

var _nodes: Array = []
var _current_index: int = -1
var _level_duration: float = 60.0
var _heal_ratio: float = 0.3

func load_tree(config: Dictionary) -> void:
	_nodes.clear()
	_current_index = -1
	_level_duration = config.get("level_duration", 60.0)
	_heal_ratio = config.get("heal_ratio", 0.3)
	var node_list: Array = config.get("nodes", [])
	for node_data: Dictionary in node_list:
		_nodes.append(node_data)

func start_run() -> void:
	_current_index = 0
	run_started.emit()

func get_current_node() -> Dictionary:
	if _current_index < 0 or _current_index >= _nodes.size():
		return {}
	return _nodes[_current_index]

func get_current_id() -> String:
	var node := get_current_node()
	return node.get("id", "")

func advance() -> void:
	if _current_index < 0 or _current_index >= _nodes.size():
		return
	_current_index += 1
	if _current_index >= _nodes.size():
		run_completed.emit()

func is_current_last() -> bool:
	return _current_index >= _nodes.size() - 1

func is_current_boss() -> bool:
	var node := get_current_node()
	return node.get("is_boss", false)

func get_level_duration() -> float:
	return _level_duration

func get_heal_ratio() -> float:
	return _heal_ratio

func get_current_index() -> int:
	return _current_index

func get_total_nodes() -> int:
	return _nodes.size()

func get_run_progress() -> float:
	if _nodes.is_empty():
		return 0.0
	return float(maxi(0, _current_index)) / float(_nodes.size())
