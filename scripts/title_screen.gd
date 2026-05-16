extends Control

var _started: bool = false
var _popup_type: String = ""
var _menu_instance: Control = null
var _popup_instance: Control = null
var _credits_scene: PackedScene = null
var _guide_scene: PackedScene = null

func _ready() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	_credits_scene = load("res://scenes/panels/Credits.tscn")
	_guide_scene = load("res://scenes/panels/controls-guide.tscn")
	_show_starting_menu()
	set_process(false)

func _show_starting_menu() -> void:
	if _menu_instance:
		return
	var menu_scene: PackedScene = load("res://scenes/panels/startingMenu.tscn")
	_menu_instance = menu_scene.instantiate()
	add_child(_menu_instance)
	var btn_start: Button = _menu_instance.get_node("Button")
	var btn_guide: Button = _menu_instance.get_node("Button4")
	var btn_credits: Button = _menu_instance.get_node("Button2")
	var btn_quit: Button = _menu_instance.get_node("Button3")
	if btn_start:
		btn_start.pressed.connect(_on_start)
	if btn_guide:
		btn_guide.pressed.connect(_on_guide)
	if btn_credits:
		btn_credits.pressed.connect(_on_credits)
	if btn_quit:
		btn_quit.pressed.connect(_on_quit)

func _on_start() -> void:
	if _started:
		return
	_started = true
	ResourceLoader.load_threaded_request("res://scenes/cockpit.tscn")
	set_process(true)

func _process(_delta: float) -> void:
	var status := ResourceLoader.load_threaded_get_status("res://scenes/cockpit.tscn")
	if status == ResourceLoader.THREAD_LOAD_LOADED:
		var scene: PackedScene = ResourceLoader.load_threaded_get("res://scenes/cockpit.tscn")
		var cockpit := scene.instantiate()
		cockpit.set_meta("level_mode", "starfox")
		get_tree().root.add_child(cockpit)
		get_tree().current_scene = cockpit
		get_tree().root.remove_child(self)
		queue_free()

func _on_guide() -> void:
	_show_popup("guide")

func _on_credits() -> void:
	_show_popup("credits")

func _show_popup(type: String) -> void:
	if _popup_instance:
		return
	_popup_type = type
	if _menu_instance:
		_menu_instance.visible = false
	var scene: PackedScene = null
	if type == "guide":
		scene = _guide_scene
	else:
		scene = _credits_scene
	if scene == null:
		return
	_popup_instance = scene.instantiate()
	add_child(_popup_instance)
	var back_btn := Button.new()
	back_btn.text = "\u8fd4\u56de"
	back_btn.position = Vector2(20, get_viewport().get_visible_rect().size.y - 60)
	back_btn.add_theme_font_size_override("font_size", 24)
	_popup_instance.add_child(back_btn)
	back_btn.pressed.connect(_close_popup)

func _close_popup() -> void:
	if _popup_instance:
		_popup_instance.queue_free()
		_popup_instance = null
	_popup_type = ""
	if _menu_instance:
		_menu_instance.visible = true

func _on_quit() -> void:
	get_tree().quit()

func _input(event: InputEvent) -> void:
	if _started:
		return
	if _popup_instance:
		if event is InputEventKey and event.pressed:
			var kc: int = event.keycode if event.keycode != 0 else event.physical_keycode
			if kc == KEY_ESCAPE:
				_close_popup()
				get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed:
		var kc: int = event.keycode if event.keycode != 0 else event.physical_keycode
		if kc == KEY_ESCAPE:
			get_tree().quit()
