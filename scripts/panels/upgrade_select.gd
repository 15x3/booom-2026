extends Control

signal upgrade_selected(upgrade_id: String)

var _offers: Array = []
var _cards: Array = []
var _card_scene: PackedScene

func _ready() -> void:
	hide()
	_card_scene = load("res://scenes/panels/UpgradeCard.tscn") as PackedScene

func show_offers(offers: Array) -> void:
	_offers = offers
	for child in get_children():
		child.queue_free()
	_cards.clear()
	if _card_scene == null:
		return
	var vp_size: Vector2 = get_viewport().get_visible_rect().size
	var card_w: float = vp_size.x / 3.5
	var card_h: float = vp_size.y * 0.6
	var gap := 20.0
	var count := mini(offers.size(), 3)
	var total_w := card_w * float(count) + gap * float(count - 1)
	var start_x := (vp_size.x - total_w) / 2.0
	var start_y := (vp_size.y - card_h) / 2.0
	for i: int in range(count):
		var offer: Dictionary = offers[i]
		var card: Control = _card_scene.instantiate()
		card.anchor_left = 0.0
		card.anchor_right = 0.0
		card.anchor_top = 0.0
		card.anchor_bottom = 0.0
		card.offset_left = start_x + float(i) * (card_w + gap)
		card.offset_top = start_y
		card.offset_right = card.offset_left + card_w
		card.offset_bottom = start_y + card_h
		card.mouse_filter = Control.MOUSE_FILTER_STOP
		var icon: Sprite2D = card.get_node_or_null("Icon")
		if icon:
			var tex_path: String = offer.get("icon", "")
			if not tex_path.is_empty():
				icon.texture = load(tex_path) as Texture2D
				icon.visible = true
			else:
				icon.visible = false
			icon.position = Vector2(card_w * 0.5, card_h * 0.35)
			if icon.texture:
				var tex_size: Vector2 = icon.texture.get_size()
				var fit: float = minf(card_w * 0.6 / tex_size.x, card_h * 0.3 / tex_size.y)
				icon.scale = Vector2(fit, fit)
		var label: Label = card.get_node_or_null("Label")
		if label:
			label.text = offer.get("name", "???") + "\n" + offer.get("desc", "")
			label.offset_left = 8.0
			label.offset_right = card_w - 8.0
			label.offset_top = card_h * 0.6
			label.offset_bottom = card_h - 8.0
		var id: String = offer.get("id", "")
		card.gui_input.connect(_on_card_input.bind(id))
		add_child(card)
		_cards.append(card)
	show()

func _on_card_input(event: InputEvent, upgrade_id: String) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		upgrade_selected.emit(upgrade_id)
		hide()
