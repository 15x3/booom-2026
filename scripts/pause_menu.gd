extends Control

signal resume_requested
signal restart_requested
signal quit_requested

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.name = "Background"
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.0, 0.0, 0.0, 0.7)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg)

	var center := CenterContainer.new()
	center.name = "Center"
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	var vbox := VBoxContainer.new()
	vbox.name = "Buttons"
	vbox.add_theme_constant_override("separation", 12)
	center.add_child(vbox)

	var font: Font = ThemeDB.fallback_font

	var title_label := Label.new()
	title_label.name = "Title"
	title_label.text = "暂  停"
	title_label.horizontal_alignment = HorizontalAlignment.HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 32)
	title_label.add_theme_color_override("font_color", Color(0.0, 0.9, 0.6, 0.9))
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(title_label)

	var sep := HSeparator.new()
	sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(sep)

	var btn_data: Array = [
		["▶  继续游戏", "_on_resume"],
		["↺  重新开始", "_on_restart"],
		["✕  返回标题", "_on_quit"],
	]
	for data: Array in btn_data:
		var btn := Button.new()
		btn.text = data[0]
		btn.custom_minimum_size = Vector2(200, 40)
		btn.add_theme_font_size_override("font_size", 18)
		btn.flat = false
		btn.mouse_filter = Control.MOUSE_FILTER_STOP
		btn.pressed.connect(Callable(self, data[1]))
		vbox.add_child(btn)

func show_menu() -> void:
	visible = true
	get_tree().paused = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func hide_menu() -> void:
	visible = false
	get_tree().paused = false

func _on_resume() -> void:
	hide_menu()
	resume_requested.emit()

func _on_restart() -> void:
	hide_menu()
	get_tree().reload_current_scene()

func _on_quit() -> void:
	hide_menu()
	get_tree().change_scene_to_file("res://scenes/title-screen.tscn")

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed:
		var key: int = event.keycode if event.keycode != 0 else event.physical_keycode
		if key == KEY_ESCAPE:
			_on_resume()
			get_viewport().set_input_as_handled()
