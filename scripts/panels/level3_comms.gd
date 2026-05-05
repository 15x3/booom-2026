extends Control

signal command_submitted(cmd: String)

const ORANGE := Color(1.0, 0.5, 0.0)
const ORANGE_DIM := Color(0.6, 0.3, 0.0)
const ORANGE_BRIGHT := Color(1.0, 0.7, 0.2)
const CYAN := Color(0.2, 0.8, 1.0)

var comm_lines: Array[String] = []
var max_comm_lines: int = 5
var command_buffer: String = ""
var command_history: Array[String] = []
var history_index: int = -1

var output_label: RichTextLabel
var input_label: Label
var status_label: Label

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_ui()

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.02, 0.04, 0.06, 1.0)
	add_child(bg)

	output_label = RichTextLabel.new()
	output_label.name = "CommOutput"
	output_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	output_label.offset_top = 16
	output_label.offset_bottom = -18
	output_label.offset_left = 4
	output_label.offset_right = -4
	output_label.bbcode_enabled = true
	output_label.add_theme_font_size_override("normal_font_size", 10)
	output_label.add_theme_color_override("default_color", ORANGE)
	output_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	output_label.add_theme_constant_override("outline_size", 1)
	add_child(output_label)

	input_label = Label.new()
	input_label.name = "InputLine"
	input_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	input_label.offset_top = -18
	input_label.offset_left = 4
	input_label.offset_right = -4
	input_label.add_theme_font_size_override("font_size", 11)
	input_label.add_theme_color_override("font_color", ORANGE_BRIGHT)
	input_label.text = "> _"
	add_child(input_label)

	status_label = Label.new()
	status_label.name = "StatusBar"
	status_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	status_label.offset_bottom = 16
	status_label.offset_left = 4
	status_label.add_theme_font_size_override("font_size", 10)
	status_label.add_theme_color_override("font_color", CYAN)
	add_child(status_label)

func print_line(text: String) -> void:
	comm_lines.append(text)
	if comm_lines.size() > max_comm_lines:
		comm_lines.pop_front()
	if output_label:
		output_label.clear()
		output_label.append_text("\n".join(PackedStringArray(comm_lines)))

func update_status(data: Dictionary) -> void:
	if not status_label:
		return
	var hp_val: float = data.get("hp", 0.0)
	var hp_max_val: float = data.get("hp_max", 100.0)
	var sh_val: float = data.get("shield", 0.0)
	var sh_max_val: float = data.get("shield_max", 50.0)
	var en_val: float = data.get("energy", 0.0)
	var cr: int = int(data.get("credits", 0))
	var toll: int = int(data.get("toll_fee", 1000))
	var spd: float = data.get("speed", 0.0)
	var tl: int = int(data.get("thrust_level", 0))
	var toll_st: String = "PAID" if data.get("toll_paid", false) else "%dcr" % toll
	status_label.text = "CR:%d | HP:%.0f SH:%.0f EN:%.0f | SPD:%.0f THR:%d | TOLL:%s" % [cr, hp_val, sh_val, en_val, spd, tl, toll_st]

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
