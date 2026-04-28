extends Control

signal channel_selected(channel_id: String)
signal scan_completed(channel_id: String, data: Dictionary)

var _channels: Array = []
var _node_data: Dictionary = {}
var _selected_channel_idx: int = -1
var _hover_channel_idx: int = -1
var _click_threshold: float = 50.0
var _overlay: Control = null
var _scan_results: Dictionary = {}
var _scanning: bool = false
var _scan_progress: float = 0.0
var _scan_target_idx: int = -1
var _scan_duration: float = 5.0

func _ready() -> void:
	_overlay = Control.new()
	_overlay.name = "ChannelOverlay"
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_PASS
	_overlay.draw.connect(_on_overlay_draw)
	add_child(_overlay)
	move_child(_overlay, get_child_count() - 1)

func _on_overlay_draw() -> void:
	if _channels.is_empty():
		return
	var sz: Vector2 = _overlay.size
	var font: Font = ThemeDB.fallback_font
	for i in range(_channels.size()):
		var ch: Dictionary = _channels[i]
		var wps: Array = ch.get("waypoints", [])
		if wps.size() < 2:
			continue
		var pts := PackedVector2Array()
		for wp: Array in wps:
			pts.append(Vector2(wp[0] * sz.x, wp[1] * sz.y))
		var base_c: Color = Color(ch["color"][0], ch["color"][1], ch["color"][2])
		var c: Color = base_c
		var w: float = 2.0
		var is_scanned: bool = _scan_results.has(ch.get("id", ""))
		if _scanning and i == _scan_target_idx:
			c = base_c.lerp(Color.WHITE, _scan_progress * 0.8)
			w = 2.0 + _scan_progress * 4.0
		elif i == _selected_channel_idx:
			c = base_c.lightened(0.5)
			w = 5.0
		elif is_scanned:
			c = base_c.lightened(0.3)
			w = 3.5
		_overlay.draw_polyline(pts, c, w, true)
		var end: Vector2 = pts[pts.size() - 1]
		_overlay.draw_circle(end, 6.0, c)
		_overlay.draw_circle(end, 3.0, Color(1, 1, 1, 0.9))
		var label: String = ch.get("label", "")
		_overlay.draw_string(font, end + Vector2(12, 4), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, c)
		if is_scanned:
			_draw_scan_result(_overlay, ch, pts, sz, font)
	var sp: Array = _node_data.get("ship_position", [0.5, 0.6])
	var ship_pos: Vector2 = Vector2(sp[0] * sz.x, sp[1] * sz.y)
	_overlay.draw_circle(ship_pos, 7.0, Color(0.2, 0.8, 1.0, 0.5))
	_overlay.draw_circle(ship_pos, 4.0, Color.WHITE)
	var ed: Array = _node_data.get("escape_direction", [])
	if ed.size() >= 2:
		var esc_pos: Vector2 = Vector2(ed[0] * sz.x, ed[1] * sz.y)
		var t: float = fmod(Time.get_ticks_msec() / 1000.0, 2.0) * PI
		var pulse: float = 0.5 + 0.5 * sin(t * 2.0)
		_overlay.draw_circle(esc_pos, 8.0 + pulse * 4.0, Color(1.0, 0.9, 0.0, 0.3))
		_overlay.draw_circle(esc_pos, 4.0, Color(1.0, 0.9, 0.0, 0.9))
	if _scanning:
		_draw_scan_progress_bar(_overlay, sz)

func update_display(node_data: Dictionary) -> void:
	_node_data = node_data
	_channels = node_data.get("channels", [])
	_selected_channel_idx = -1
	_hover_channel_idx = -1
	_scan_results.clear()
	_scanning = false
	_scan_progress = 0.0
	_scan_target_idx = -1
	var display: ColorRect = $BlackHoleDisplay
	if display and display.material:
		display.material.set_shader_parameter("blackhole_scale", node_data.get("blackhole_scale", 1.0))
	var status: Label = $StatusText
	if status:
		status.text = "%s — %s" % [node_data.get("name", ""), node_data.get("subtitle", "")]
	var title: Label = $Title
	if title:
		title.text = "GRAVITY FIELD MAP"
	if _overlay:
		_overlay.queue_redraw()

func _process(_delta: float) -> void:
	if _overlay:
		_overlay.queue_redraw()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_handle_click(event.position)

func _handle_click(click_pos: Vector2) -> void:
	if _scanning:
		return
	var sz: Vector2 = size
	var best_idx: int = -1
	var best_dist: float = _click_threshold
	for i in range(_channels.size()):
		var ch: Dictionary = _channels[i]
		var wps: Array = ch.get("waypoints", [])
		var d: float = _point_to_path_dist(click_pos, wps, sz)
		if d < best_dist:
			best_dist = d
			best_idx = i
	if best_idx >= 0:
		_selected_channel_idx = best_idx
		channel_selected.emit(_channels[best_idx]["id"])
		if _overlay:
			_overlay.queue_redraw()

func _point_to_path_dist(point: Vector2, wps: Array, sz: Vector2) -> float:
	var min_d: float = 999999.0
	var pts := []
	for wp: Array in wps:
		pts.append(Vector2(wp[0] * sz.x, wp[1] * sz.y))
	for i in range(pts.size() - 1):
		var d: float = _point_to_seg_dist(point, pts[i], pts[i + 1])
		min_d = minf(min_d, d)
	return min_d

func _point_to_seg_dist(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab: Vector2 = b - a
	var ap: Vector2 = p - a
	var ab_sq: float = ab.dot(ab)
	if ab_sq < 0.001:
		return p.distance_to(a)
	var t: float = clampf(ap.dot(ab) / ab_sq, 0.0, 1.0)
	var closest: Vector2 = a + t * ab
	return p.distance_to(closest)


func get_selected_channel_id() -> String:
	if _selected_channel_idx >= 0 and _selected_channel_idx < _channels.size():
		return _channels[_selected_channel_idx].get("id", "")
	return ""

func start_scan(channel_id: String, duration: float) -> void:
	var idx: int = -1
	for i in range(_channels.size()):
		if _channels[i].get("id", "") == channel_id:
			idx = i
			break
	if idx < 0:
		return
	_scanning = true
	_scan_progress = 0.0
	_scan_target_idx = idx
	_scan_duration = duration
	var tween := create_tween()
	tween.tween_property(self, "_scan_progress", 1.0, duration)
	tween.tween_callback(_on_scan_finished)

func _on_scan_finished() -> void:
	_scanning = false
	if _scan_target_idx < 0 or _scan_target_idx >= _channels.size():
		return
	var ch: Dictionary = _channels[_scan_target_idx]
	var ch_id: String = ch.get("id", "")
	var result: Dictionary = ch.get("scan_result", {})
	var revealed: Dictionary = {}
	var stability: float = result.get("stability", 0.0)
	revealed["stability"] = "%.0f%%" % stability
	var debris: float = result.get("debris_density", 0.0)
	var variance: float = debris * 0.3
	var lo: float = maxf(debris - variance, 0.0)
	var hi: float = minf(debris + variance, 100.0)
	revealed["debris"] = "%.0f~%.0f%%" % [lo, hi]
	var gravity: float = result.get("gravity_strength", 0.0)
	revealed["gravity"] = "%.0f%%" % gravity
	_scan_results[ch_id] = revealed
	scan_completed.emit(ch_id, revealed)
	if _overlay:
		_overlay.queue_redraw()

func _draw_scan_result(overlay: Control, ch: Dictionary, pts: PackedVector2Array, _sz: Vector2, font: Font) -> void:
	var ch_id: String = ch.get("id", "")
	var data: Dictionary = _scan_results.get(ch_id, {})
	if data.is_empty():
		return
	var mid_idx: int = int(pts.size() / 2.0)
	var anchor: Vector2 = pts[mid_idx]
	var offset := Vector2(15.0, -10.0)
	var pos: Vector2 = anchor + offset
	var text_color := Color(0.7, 0.9, 1.0)
	var font_size: int = 11
	var keys := ["stability", "debris", "gravity"]
	var labels := {"stability": "STA", "debris": "DEB", "gravity": "GRV"}
	for key: String in keys:
		if not data.has(key):
			continue
		var line: String = "%s: %s" % [labels.get(key, key), data[key]]
		overlay.draw_string(font, pos, line, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, text_color)
		pos.y += 14.0

func _draw_scan_progress_bar(overlay: Control, sz: Vector2) -> void:
	var bar_w: float = sz.x * 0.6
	var bar_h: float = 4.0
	var bar_x: float = (sz.x - bar_w) * 0.5
	var bar_y: float = sz.y - 20.0
	overlay.draw_rect(Rect2(bar_x, bar_y, bar_w, bar_h), Color(0.2, 0.3, 0.4), false)
	var fill_w: float = bar_w * _scan_progress
	var fill_color := Color(0.2, 0.8, 1.0)
	if _scan_progress > 0.9:
		fill_color = Color(0.3, 1.0, 0.5)
	overlay.draw_rect(Rect2(bar_x, bar_y, fill_w, bar_h), fill_color)
	var label_pos := Vector2(bar_x + bar_w * 0.5 - 20.0, bar_y - 4.0)
	overlay.draw_string(ThemeDB.fallback_font, label_pos, "SCANNING", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, fill_color)
