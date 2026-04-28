extends Node

enum State { CHOOSING, TRAVELLING, ARRIVING }

var current_state: State = State.CHOOSING
var current_node_index: int = -1
var nodes_data: Array = []

signal node_changed(node_data: Dictionary)
signal travel_started(from_id: int, to_id: int)
signal travel_completed(node_id: int)
signal special_event_requested(node_index: int, event_type: String)
signal bad_ending_requested(ending_type: String)

var _pending_target: int = -1
var _scanned_channel_id: String = ""

func _ready() -> void:
	_load_nodes()

func start() -> void:
	if not nodes_data.is_empty() and current_node_index < 0:
		arrive_at(0)

func _load_nodes() -> void:
	var path := "res://assets/data/nodes.json"
	if not FileAccess.file_exists(path):
		push_error("Nodes file not found: " + path)
		return
	var file := FileAccess.open(path, FileAccess.READ)
	var json := JSON.new()
	var err := json.parse(file.get_as_text())
	if err != OK:
		push_error("Nodes parse error: " + json.get_error_message())
		return
	var data: Dictionary = json.data
	nodes_data = data.get("nodes", [])

func get_current_node() -> Dictionary:
	if current_node_index >= 0 and current_node_index < nodes_data.size():
		return nodes_data[current_node_index]
	return {}

func get_channel_by_id(channel_id: String) -> Dictionary:
	var node := get_current_node()
	for ch: Dictionary in node.get("channels", []):
		if ch.get("id", "") == channel_id:
			return ch
	return {}

func select_channel(channel_id: String) -> void:
	var ch := get_channel_by_id(channel_id)
	if ch.is_empty():
		return
	var ending: String = ch.get("ending", "")
	if ending != "":
		current_state = State.TRAVELLING
		bad_ending_requested.emit(ending)
		return
	var target: int = ch.get("target_node", -1)
	if target < 0 or target >= nodes_data.size():
		push_warning("Invalid target node: %d" % target)
		return
	current_state = State.TRAVELLING
	_pending_target = target
	travel_started.emit(current_node_index, target)

func complete_travel() -> void:
	if _pending_target < 0 or _pending_target >= nodes_data.size():
		return
	arrive_at(_pending_target)
	_pending_target = -1

func force_advance_to(node_index: int) -> void:
	arrive_at(node_index)

func get_node_data(node_index: int) -> Dictionary:
	if node_index >= 0 and node_index < nodes_data.size():
		return nodes_data[node_index]
	return {}

func can_scan() -> bool:
	if _scanned_channel_id != "":
		return false
	var node := get_current_node()
	var channels: Array = node.get("channels", [])
	return not channels.is_empty()

func mark_scanned(channel_id: String) -> void:
	_scanned_channel_id = channel_id

func get_scanned_channel() -> String:
	return _scanned_channel_id

func arrive_at(node_index: int) -> void:
	if node_index < 0 or node_index >= nodes_data.size():
		return
	current_node_index = node_index
	current_state = State.ARRIVING
	_scanned_channel_id = ""
	var node_data: Dictionary = nodes_data[current_node_index]
	node_changed.emit(node_data)
	travel_completed.emit(node_index)
	current_state = State.CHOOSING
	var event_type: String = node_data.get("event_type", "")
	if event_type != "":
		special_event_requested.emit(node_index, event_type)
