extends Control

var _blink_timer: float = 0.0
var _show_prompt: bool = true
var _started: bool = false
var _prompt_label: Label = null

func _ready() -> void:
	_build_ui()

func _build_ui() -> void:
	var vp_size: Vector2 = get_viewport().get_visible_rect().size
	position = Vector2.ZERO
	size = vp_size

	var vbox := VBoxContainer.new()
	vbox.position = Vector2.ZERO
	vbox.size = vp_size
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 6)
	add_child(vbox)

	var title1 := _make_label("E V E N T", 44, Color(0.0, 0.9, 0.6, 0.9))
	title1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(title1)

	var title2 := _make_label("H O R I Z O N", 44, Color(0.0, 0.9, 0.6, 0.9))
	title2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(title2)

	var spacer1 := Control.new()
	spacer1.custom_minimum_size.y = 8
	vbox.add_child(spacer1)

	var subtitle := _make_label("-- 事 件 视 界 --", 22, Color(0.7, 0.85, 1.0, 0.7))
	subtitle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(subtitle)

	var spacer2 := Control.new()
	spacer2.custom_minimum_size.y = 40
	vbox.add_child(spacer2)

	var controls_data: Array = [
		"Q / E        切换视角",
		"鼠标左键      操控面板",
		"F / 中键      手电筒",
		"ESC          暂停",
	]
	for line: String in controls_data:
		var lbl := _make_label(line, 16, Color(0.6, 0.6, 0.65, 0.6))
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		vbox.add_child(lbl)

	var spacer3 := Control.new()
	spacer3.custom_minimum_size.y = 50
	vbox.add_child(spacer3)

	_prompt_label = _make_label("[ 点击任意位置开始 ]", 18, Color(1.0, 1.0, 1.0, 0.8))
	_prompt_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(_prompt_label)

func _make_label(text: String, font_size: int, color: Color) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.horizontal_alignment = HorizontalAlignment.HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", color)
	return lbl

func _process(delta: float) -> void:
	_blink_timer += delta
	if _blink_timer >= 0.8:
		_blink_timer = 0.0
		_show_prompt = not _show_prompt
		if _prompt_label:
			_prompt_label.modulate.a = 0.9 if _show_prompt else 0.0

func _input(event: InputEvent) -> void:
	if _started:
		return
	if event is InputEventMouseButton and event.pressed:
		_start_game()
	elif event is InputEventKey and event.pressed:
		_start_game()

func _start_game() -> void:
	_started = true
	get_tree().change_scene_to_file("res://scenes/cockpit.tscn")
