extends Control

signal channel_clicked(channel_id: String)

var _channels: Array = []
var _node_data: Dictionary = {}
var _selected_channel_idx: int = -1
var _hover_channel_idx: int = -1
var _click_threshold: float = 50.0
var _overlay: Control = null

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
	for i in range(_channels.size()):
		var ch: Dictionary = _channels[i]
		var wps: Array = ch.get("waypoints", [])
		if wps.size() < 2:
			continue
		var pts := PackedVector2Array()
		for wp: Array in wps:
			pts.append(Vector2(wp[0] * sz.x, wp[1] * sz.y))
		var c: Color = Color(ch["color"][0], ch["color"][1], ch["color"][2])
		var w: float = 3.0
		if i == _selected_channel_idx:
			c = c.lightened(0.5)
			w = 5.0
		elif i == _hover_channel_idx:
			c = c.lightened(0.3)
			w = 4.0
		_overlay.draw_polyline(pts, c, w, true)
		var end: Vector2 = pts[pts.size() - 1]
		_overlay.draw_circle(end, 6.0, c)
		_overlay.draw_circle(end, 3.0, Color(1, 1, 1, 0.9))
		var font: Font = ThemeDB.fallback_font
		var label: String = ch.get("label", "")
		_overlay.draw_string(font, end + Vector2(12, 4), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, c)
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

func update_display(node_data: Dictionary) -> void:
	_node_data = node_data
	_channels = node_data.get("channels", [])
	_selected_channel_idx = -1
	_hover_channel_idx = -1
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
		channel_clicked.emit(_channels[best_idx]["id"])
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
