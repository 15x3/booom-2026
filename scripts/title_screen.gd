extends Control

var _started: bool = false

const LEVELS: Array[Dictionary] = [
	{"name": "SPACEWAR", "year": "1962", "scene": "res://scenes/levels/level-1-spacewar.tscn"},
	{"name": "SPASIM", "year": "1974", "scene": "res://scenes/levels/level-2-spasim.tscn"},
	{"name": "ELITE", "year": "1984", "scene": "res://scenes/levels/level-3-elite.tscn"},
	{"name": "STAR FOX", "year": "1993", "scene": "res://scenes/levels/level-4-starfox.tscn"},
	{"name": "Y2K BOSS", "year": "1999", "scene": "res://scenes/levels/level-5-boss.tscn"},
]

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
	vbox.add_theme_constant_override("separation", 4)
	add_child(vbox)

	var title1 := _make_label("E V E N T", 44, Color(0.0, 0.9, 0.6, 0.9))
	title1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(title1)

	var title2 := _make_label("H O R I Z O N", 44, Color(0.0, 0.9, 0.6, 0.9))
	title2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(title2)

	var spacer1 := Control.new()
	spacer1.custom_minimum_size.y = 6
	vbox.add_child(spacer1)

	var subtitle := _make_label("-- \u4e8b \u4ef6 \u89c6 \u754c --", 22, Color(0.7, 0.85, 1.0, 0.7))
	subtitle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(subtitle)

	var spacer2 := Control.new()
	spacer2.custom_minimum_size.y = 30
	vbox.add_child(spacer2)

	for i in LEVELS.size():
		var lvl: Dictionary = LEVELS[i]
		var btn := Button.new()
		btn.text = "%s  [%s]" % [lvl["name"], lvl["year"]]
		btn.alignment = HorizontalAlignment.HORIZONTAL_ALIGNMENT_CENTER
		btn.add_theme_font_size_override("font_size", 18)
		btn.add_theme_color_override("font_color", Color(1.0, 0.7, 0.2, 0.9))
		btn.add_theme_color_override("font_hover_color", Color(1.0, 0.9, 0.4))
		btn.add_theme_color_override("font_pressed_color", Color(1.0, 1.0, 1.0))
		btn.add_theme_color_override("font_focus_color", Color(1.0, 0.7, 0.2))
		btn.add_theme_stylebox_override("normal", _make_btn_style(Color(0.15, 0.08, 0.0, 0.6)))
		btn.add_theme_stylebox_override("hover", _make_btn_style(Color(0.25, 0.12, 0.0, 0.8)))
		btn.add_theme_stylebox_override("pressed", _make_btn_style(Color(0.4, 0.2, 0.0, 0.9)))
		btn.add_theme_stylebox_override("focus", _make_btn_style(Color(0.2, 0.1, 0.0, 0.7)))
		btn.custom_minimum_size.y = 36
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.pressed.connect(_on_level_selected.bind(i))
		vbox.add_child(btn)

	var spacer3 := Control.new()
	spacer3.custom_minimum_size.y = 20
	vbox.add_child(spacer3)

	var hint := _make_label("[ ESC \u8fd4\u56de\u6807\u9898 ]", 14, Color(0.5, 0.5, 0.55, 0.5))
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(hint)

func _make_label(text: String, font_size: int, color: Color) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.horizontal_alignment = HorizontalAlignment.HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", color)
	return lbl

func _make_btn_style(bg: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.corner_radius_top_left = 4
	s.corner_radius_top_right = 4
	s.corner_radius_bottom_left = 4
	s.corner_radius_bottom_right = 4
	s.content_margin_top = 4
	s.content_margin_bottom = 4
	s.content_margin_left = 12
	s.content_margin_right = 12
	return s

var _pending_level: int = -1

func _on_level_selected(idx: int) -> void:
	if _started:
		return
	_started = true
	_pending_level = idx
	if idx == 1 or idx == 2:
		ResourceLoader.load_threaded_request("res://scenes/cockpit.tscn")
		set_process(true)
	else:
		var scene_path: String = LEVELS[idx]["scene"]
		get_tree().change_scene_to_file(scene_path)

func _process(_delta: float) -> void:
	if _pending_level == 1 or _pending_level == 2:
		var status := ResourceLoader.load_threaded_get_status("res://scenes/cockpit.tscn")
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			var scene: PackedScene = ResourceLoader.load_threaded_get("res://scenes/cockpit.tscn")
			var cockpit := scene.instantiate()
			var mode := "spasim" if _pending_level == 1 else "elite"
			cockpit.set_meta("level_mode", mode)
			get_tree().root.add_child(cockpit)
			get_tree().current_scene = cockpit
			get_tree().root.remove_child(self)
			queue_free()
			_pending_level = -1

func _input(event: InputEvent) -> void:
	if _started:
		return
	if event is InputEventKey and event.pressed:
		var kc: int = event.keycode if event.keycode != 0 else event.physical_keycode
		if kc == KEY_ESCAPE:
			get_tree().quit()
