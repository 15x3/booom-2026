extends Control

signal transition_started
signal transition_step(step_name: String)
signal transition_completed

var _overlay: ColorRect
var _name_label: Label
var _subtitle_label: Label
var _config: Dictionary = {}
var _sequence: Tween = null


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_ui()


func _build_ui() -> void:
	_overlay = ColorRect.new()
	_overlay.name = "Overlay"
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.color = Color(0.0, 0.0, 0.0, 0.0)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_overlay)

	var center := CenterContainer.new()
	center.name = "Center"
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	var vbox := VBoxContainer.new()
	vbox.name = "LabelContainer"
	vbox.add_theme_constant_override("separation", 8)
	center.add_child(vbox)

	_name_label = Label.new()
	_name_label.name = "ZoneName"
	_name_label.horizontal_alignment = HorizontalAlignment.HORIZONTAL_ALIGNMENT_CENTER
	_name_label.add_theme_font_size_override("font_size", 42)
	_name_label.modulate = Color(1.0, 1.0, 1.0, 0.0)
	_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(_name_label)

	_subtitle_label = Label.new()
	_subtitle_label.name = "ZoneSubtitle"
	_subtitle_label.horizontal_alignment = HorizontalAlignment.HORIZONTAL_ALIGNMENT_CENTER
	_subtitle_label.add_theme_font_size_override("font_size", 20)
	_subtitle_label.modulate = Color(1.0, 1.0, 1.0, 0.0)
	_subtitle_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(_subtitle_label)


func load_config(cfg: Dictionary) -> void:
	_config = cfg


func is_playing() -> bool:
	return _sequence != null and _sequence.is_running()


func cancel() -> void:
	if _sequence != null:
		_sequence.kill()
	_sequence = null
	_reset()


func begin_sequence() -> void:
	cancel()
	_sequence = create_tween()
	_sequence.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	transition_started.emit()


func end_sequence(on_complete: Callable = Callable()) -> void:
	_sequence.tween_callback(func():
		var cb := on_complete
		_reset()
		_sequence = null
		if cb.is_valid():
			cb.call()
		transition_completed.emit()
	)


func seq_fade_to_black(duration: float) -> void:
	_sequence.tween_property(_overlay, "color:a", 1.0, duration)


func seq_fade_from_black(duration: float) -> void:
	_sequence.tween_property(_overlay, "color:a", 0.0, duration)


func seq_show_text(primary: String, secondary: String, fade_duration: float = 0.4) -> void:
	_sequence.tween_callback(func():
		_name_label.text = primary
		_subtitle_label.text = secondary
	)
	_sequence.tween_property(_name_label, "modulate:a", 1.0, fade_duration)
	_sequence.parallel().tween_property(_subtitle_label, "modulate:a", 1.0, fade_duration)


func seq_hide_text(fade_duration: float = 0.4) -> void:
	_sequence.tween_property(_name_label, "modulate:a", 0.0, fade_duration)
	_sequence.parallel().tween_property(_subtitle_label, "modulate:a", 0.0, fade_duration)


func seq_set_text_color(color: Color) -> void:
	_sequence.tween_callback(func():
		_name_label.add_theme_color_override("font_color", color)
		_subtitle_label.add_theme_color_override("font_color", color)
	)


func seq_wait(duration: float) -> void:
	_sequence.tween_interval(duration)


func seq_callback(cb: Callable) -> void:
	_sequence.tween_callback(cb)


func seq_emit_step(step_name: String) -> void:
	_sequence.tween_callback(func(): transition_step.emit(step_name))


func play_zone_transition(zone_name: String, subtitle: String, on_midpoint: Callable = Callable()) -> void:
	var fade_in: float = _config.get("fade_in_duration", 0.5)
	var hold: float = _config.get("zone_display_duration", 1.5)
	var fade_out: float = _config.get("fade_out_duration", 0.5)

	begin_sequence()
	seq_fade_to_black(fade_in)
	seq_show_text(zone_name, subtitle)
	seq_wait(hold)
	seq_callback(on_midpoint)
	seq_emit_step("midpoint")
	seq_hide_text()
	seq_fade_from_black(fade_out)
	end_sequence()


func play_simple_fade(duration: float, on_midpoint: Callable = Callable()) -> void:
	var half := duration * 0.5
	begin_sequence()
	seq_fade_to_black(half)
	seq_callback(on_midpoint)
	seq_fade_from_black(half)
	end_sequence()


func _reset() -> void:
	_overlay.color = Color(0.0, 0.0, 0.0, 0.0)
	_name_label.modulate = Color(1.0, 1.0, 1.0, 0.0)
	_subtitle_label.modulate = Color(1.0, 1.0, 1.0, 0.0)
	_name_label.text = ""
	_subtitle_label.text = ""
