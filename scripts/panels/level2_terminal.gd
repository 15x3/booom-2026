extends Control

signal command_submitted(cmd: String)

@onready var terminal_label: RichTextLabel = $History
@onready var input_label: Label = $CommandPanel

var terminal_lines: Array[String] = []
var max_terminal_lines: int = 6
var command_buffer: String = ""
var command_history: Array[String] = []
var history_index: int = -1

func print_line(text: String) -> void:
	terminal_lines.append(text)
	if terminal_lines.size() > max_terminal_lines:
		terminal_lines.pop_front()
	if terminal_label:
		terminal_label.clear()
		terminal_label.append_text("\n".join(PackedStringArray(terminal_lines)))

func handle_key_input(event: InputEventKey) -> void:
	if not event.pressed:
		return
	var kc: int = event.keycode if event.keycode != 0 else event.physical_keycode
	if kc == KEY_ENTER:
		var cmd := command_buffer.strip_edges()
		if not cmd.is_empty():
			print_line("> %s" % cmd.to_upper())
			command_history.push_back(cmd)
			command_submitted.emit(cmd)
		command_buffer = ""
		history_index = -1
	elif kc == KEY_BACKSPACE:
		if command_buffer.length() > 0:
			command_buffer = command_buffer.substr(0, command_buffer.length() - 1)
	elif kc == KEY_UP:
		_navigate_history(-1)
	elif kc == KEY_DOWN:
		_navigate_history(1)
	else:
		var ch: String = ""
		if event.unicode >= 32 and event.unicode <= 126:
			ch = char(event.unicode)
		elif kc >= 0x41 and kc <= 0x5A:
			ch = char(kc + 32)
		elif kc >= 0x61 and kc <= 0x7A:
			ch = char(kc)
		elif kc >= 0x30 and kc <= 0x39:
			ch = char(kc)
		elif kc == 0x20:
			ch = " "
		elif kc == 0xBD or kc == 0x2D:
			ch = "-"
		elif kc == 0xBE or kc == 0x2E:
			ch = "."
		if not ch.is_empty():
			command_buffer += ch

func _navigate_history(direction: int) -> void:
	if command_history.is_empty():
		return
	history_index = clampi(history_index + direction, -1, command_history.size() - 1)
	if history_index < 0:
		command_buffer = ""
	else:
		command_buffer = command_history[command_history.size() - 1 - history_index]

func _process(_delta: float) -> void:
	if input_label:
		input_label.text = "> %s_" % command_buffer
