extends Node

enum State { CHOOSING, TRAVELLING, ARRIVING }

var current_state: State = State.CHOOSING
var current_node_index: int = -1
var nodes_data: Array = []

signal node_changed(node_data: Dictionary)
signal travel_started(from_id: int, to_id: int)
signal travel_completed(node_id: int)

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
	var target: int = ch.get("target_node", -1)
	if target < 0 or target >= nodes_data.size():
		push_warning("Invalid target node: %d" % target)
		return
	current_state = State.TRAVELLING
	travel_started.emit(current_node_index, target)
	travel_to(target)

func travel_to(target_node: int) -> void:
	current_state = State.TRAVELLING
	await get_tree().create_timer(0.5).timeout
	arrive_at(target_node)

func arrive_at(node_index: int) -> void:
	if node_index < 0 or node_index >= nodes_data.size():
		return
	current_node_index = node_index
	current_state = State.ARRIVING
	var node_data: Dictionary = nodes_data[current_node_index]
	node_changed.emit(node_data)
	travel_completed.emit(node_index)
	current_state = State.CHOOSING
