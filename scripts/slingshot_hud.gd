extends Control

var _progress: float = 0.0
var _duration: float = 8.0
var _optimal_start: float = 0.4
var _optimal_end: float = 0.6
var _active: bool = false
var _bar_rect: Rect2
var _bar_height: float = 12.0
var _bar_margin: float = 40.0
var _marker_width: float = 4.0

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false

func start(duration: float, optimal_start: float, optimal_end: float) -> void:
	_duration = maxf(duration, 0.1)
	_optimal_start = clampf(optimal_start, 0.0, 1.0)
	_optimal_end = clampf(optimal_end, optimal_start, 1.0)
	_progress = 0.0
	_active = true
	visible = true
	queue_redraw()

func stop() -> void:
	_active = false
	visible = false

func set_progress(v: float) -> void:
	_progress = clampf(v, 0.0, 1.0)
	queue_redraw()

func get_progress() -> float:
	return _progress

func is_in_optimal() -> bool:
	return _progress >= _optimal_start and _progress <= _optimal_end

func is_active() -> bool:
	return _active

func _draw() -> void:
	if not _active:
		return

	var vp_size: Vector2 = size
	var bar_y: float = vp_size.y - _bar_margin
	var bar_x: float = _bar_margin
	var bar_w: float = vp_size.x - _bar_margin * 2.0

	_bar_rect = Rect2(bar_x, bar_y, bar_w, _bar_height)

	var bg_color := Color(0.1, 0.1, 0.1, 0.8)
	draw_rect(_bar_rect, bg_color)

	var optimal_x: float = bar_x + _optimal_start * bar_w
	var optimal_w: float = (_optimal_end - _optimal_start) * bar_w
	var optimal_rect := Rect2(optimal_x, bar_y - 2.0, optimal_w, _bar_height + 4.0)
	var optimal_color := Color(0.0, 0.8, 0.3, 0.4)
	draw_rect(optimal_rect, optimal_color)

	var optimal_border := Color(0.0, 1.0, 0.4, 0.7)
	draw_rect(optimal_rect, optimal_border, false, 1.0)

	var fill_w: float = _progress * bar_w
	var fill_rect := Rect2(bar_x, bar_y, fill_w, _bar_height)
	var bar_color := Color(1.0, 0.6, 0.1, 0.9)
	if is_in_optimal():
		bar_color = Color(0.0, 1.0, 0.4, 0.9)
	draw_rect(fill_rect, bar_color)

	var marker_x: float = bar_x + _progress * bar_w - _marker_width * 0.5
	var marker_rect := Rect2(marker_x, bar_y - 4.0, _marker_width, _bar_height + 8.0)
	var marker_color := Color(1.0, 1.0, 1.0, 0.9)
	draw_rect(marker_rect, marker_color)

	var label_color := Color(1.0, 1.0, 1.0, 0.6)
	var font: Font = ThemeDB.fallback_font
	var font_size: int = 14
	var pct_text: String = "%d%%" % int(_progress * 100.0)
	draw_string(font, Vector2(bar_x + bar_w + 8.0, bar_y + _bar_height - 1.0), pct_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, label_color)
