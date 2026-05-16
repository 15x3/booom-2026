extends Control

signal resume_requested
signal quit_requested

var _showing_credits: bool = false
var _pause_instance: Control = null
var _credits_instance: Control = null
var _credits_scene: PackedScene = null

func _ready() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	_credits_scene = load("res://scenes/panels/credits.tscn")
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pause_scene: PackedScene = load("res://scenes/panels/pause.tscn")
	_pause_instance = pause_scene.instantiate()
	add_child(_pause_instance)
	var btn_resume: Button = _pause_instance.get_node("Button")
	var btn_credits: Button = _pause_instance.get_node("Button2")
	var btn_quit: Button = _pause_instance.get_node("Button3")
	if btn_resume:
		btn_resume.pressed.connect(_on_resume)
	if btn_credits:
		btn_credits.pressed.connect(_on_credits)
	if btn_quit:
		btn_quit.pressed.connect(_on_quit)

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

func _on_credits() -> void:
	if _showing_credits:
		return
	_showing_credits = true
	if _pause_instance:
		_pause_instance.visible = false
	_credits_instance = _credits_scene.instantiate()
	add_child(_credits_instance)
	var back_btn := Button.new()
	back_btn.text = "\u8fd4\u56de"
	back_btn.position = Vector2(20, get_viewport().get_visible_rect().size.y - 60)
	back_btn.add_theme_font_size_override("font_size", 24)
	_credits_instance.add_child(back_btn)
	back_btn.pressed.connect(_close_credits)

func _close_credits() -> void:
	if _credits_instance:
		_credits_instance.queue_free()
		_credits_instance = null
	_showing_credits = false
	if _pause_instance:
		_pause_instance.visible = true

func _on_quit() -> void:
	hide_menu()
	get_tree().change_scene_to_file("res://scenes/title-screen.tscn")

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if _showing_credits:
		if event is InputEventKey and event.pressed:
			var key: int = event.keycode if event.keycode != 0 else event.physical_keycode
			if key == KEY_ESCAPE:
				_close_credits()
				get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed:
		var key: int = event.keycode if event.keycode != 0 else event.physical_keycode
		if key == KEY_ESCAPE:
			_on_resume()
			get_viewport().set_input_as_handled()
