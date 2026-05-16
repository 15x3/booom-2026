extends Control

signal branch_selected(node_id: String)

var _children_data: Array = []

func _ready() -> void:
	hide()

func show_branches(children: Array) -> void:
	_children_data = children
	for child in get_children():
		child.queue_free()
	var vp_width: float = get_viewport().get_visible_rect().size.x
	var title := Label.new()
	title.text = "SELECT DESTINATION"
	title.position = Vector2(vp_width / 2.0 - 100.0, 20.0)
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(0.3, 0.8, 1.0))
	add_child(title)
	var count := mini(children.size(), 3)
	var card_width := 200.0
	var gap := 20.0
	var total_width := card_width * float(count) + gap * float(count - 1)
	var start_x := (vp_width - total_width) / 2.0
	for i: int in range(count):
		var child_data: Dictionary = children[i]
		var card := _create_card(child_data)
		card.position = Vector2(start_x + i * (card_width + gap), 80.0)
		add_child(card)
	show()

func _create_card(child_data: Dictionary) -> Panel:
	var card := Panel.new()
	card.custom_minimum_size = Vector2(200.0, 260.0)
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	var name_label := Label.new()
	name_label.text = child_data.get("name", "???")
	name_label.position = Vector2(15.0, 15.0)
	name_label.add_theme_font_size_override("font_size", 22)
	name_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
	card.add_child(name_label)
	var risk: int = child_data.get("risk_level", 1)
	var risk_label: String = child_data.get("risk_label", "")
	var risk_color: Color
	match risk:
		1: risk_color = Color(0.3, 1.0, 0.3)
		2: risk_color = Color(0.8, 0.9, 0.3)
		3: risk_color = Color(1.0, 0.6, 0.2)
		4: risk_color = Color(1.0, 0.3, 0.2)
		5: risk_color = Color(1.0, 0.1, 0.8)
		_: risk_color = Color(0.7, 0.7, 0.7)
	var risk_lbl := Label.new()
	risk_lbl.text = risk_label
	risk_lbl.position = Vector2(15.0, 50.0)
	risk_lbl.add_theme_font_size_override("font_size", 16)
	risk_lbl.add_theme_color_override("font_color", risk_color)
	card.add_child(risk_lbl)
	var id: String = child_data.get("id", "")
	card.gui_input.connect(_on_card_input.bind(id))
	return card

func _on_card_input(event: InputEvent, node_id: String) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		branch_selected.emit(node_id)
		hide()
