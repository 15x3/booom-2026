extends Control

signal message_completed

@onready var message_label: RichTextLabel = $MessageLabel
@onready var cursor_label: Label = $CursorLabel
@onready var bg: ColorRect = $Background

var _char_speed: float = 0.04
var _cursor_blink_speed: float = 0.5
var _cursor_visible: bool = true
var _cursor_timer: float = 0.0
var _current_text: String = ""
var _char_index: int = 0
var _is_typing: bool = false
var _tween: Tween = null

func _ready() -> void:
	if message_label:
		message_label.text = ""
		message_label.add_theme_color_override("default_color", Color(0.2, 0.9, 1.0))
		message_label.add_theme_font_size_override("normal_font_size", 14)
		var font := SystemFont.new()
		font.font_names = PackedStringArray(["JetBrains Mono", "Consolas", "Courier New", "monospace"])
		message_label.add_theme_font_override("normal_font", font)
	if cursor_label:
		cursor_label.text = "_"
		cursor_label.visible = false
		cursor_label.add_theme_color_override("font_color", Color(0.2, 0.9, 1.0))
		cursor_label.add_theme_font_size_override("font_size", 14)
		var cfont := SystemFont.new()
		cfont.font_names = PackedStringArray(["JetBrains Mono", "Consolas", "Courier New", "monospace"])
		cursor_label.add_theme_font_override("font", cfont)
	var prefix_node: Label = get_node_or_null("Prefix")
	if prefix_node:
		prefix_node.add_theme_color_override("font_color", Color(0.2, 0.9, 1.0))
		prefix_node.add_theme_font_size_override("font_size", 14)
		var pfont := SystemFont.new()
		pfont.font_names = PackedStringArray(["JetBrains Mono", "Consolas", "Courier New", "monospace"])
		prefix_node.add_theme_font_override("font", pfont)
	if bg:
		bg.visible = false

func _process(delta: float) -> void:
	if cursor_label and cursor_label.visible:
		_cursor_timer += delta
		if _cursor_timer >= _cursor_blink_speed:
			_cursor_timer = 0.0
			_cursor_visible = not _cursor_visible
			cursor_label.visible = _cursor_visible

func show_message(text: String, speed: float = -1.0) -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
		_tween = null
	var char_speed := speed if speed > 0.0 else _char_speed
	_current_text = text
	_char_index = 0
	_is_typing = true
	if message_label:
		message_label.text = ""
	if bg:
		bg.visible = true
	if cursor_label:
		cursor_label.visible = true
		_cursor_visible = true
		_cursor_timer = 0.0
	_typewrite(char_speed)

func _typewrite(char_speed: float) -> void:
	if _current_text.is_empty():
		_is_typing = false
		message_completed.emit()
		return
	_tween = create_tween()
	var total_chars := _current_text.length()
	for i in range(total_chars):
		_tween.tween_callback(_make_char_reveal(i + 1))
		_tween.tween_interval(char_speed)
	_tween.tween_callback(func():
		_is_typing = false
		message_completed.emit()
	)

func _make_char_reveal(count: int) -> Callable:
	return func():
		if message_label:
			message_label.text = _current_text.substr(0, count)

func skip() -> void:
	if not _is_typing:
		return
	if _tween and _tween.is_valid():
		_tween.kill()
		_tween = null
	if message_label:
		message_label.text = _current_text
	_is_typing = false
	message_completed.emit()

func clear() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
		_tween = null
	if message_label:
		message_label.text = ""
	if bg:
		bg.visible = false
	if cursor_label:
		cursor_label.visible = false
	_current_text = ""
	_char_index = 0
	_is_typing = false

func is_typing() -> bool:
	return _is_typing

func set_style(text_color: Color, bg_color: Color) -> void:
	if message_label:
		message_label.add_theme_color_override("default_color", text_color)
	if bg:
		bg.color = bg_color
