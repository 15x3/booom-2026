extends Control

var _player_pos: Vector3 = Vector3.ZERO
var _player_heading: float = 0.0
var _enemies: Array = []
var _stations: Array = []
var _exit_pos: Vector3 = Vector3.ZERO

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.01, 0.03, 0.06, 1.0)
	add_child(bg)

	var overlay := Control.new()
	overlay.name = "DrawOverlay"
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_PASS
	overlay.draw.connect(_draw_radar)
	add_child(overlay)

func update_data(player_pos: Vector3, heading: float, enemies: Array, stations: Array, exit_pos: Vector3) -> void:
	_player_pos = player_pos
	_player_heading = heading
	_enemies = enemies
	_stations = stations
	_exit_pos = exit_pos

func _draw_radar() -> void:
	var overlay: Control = get_node_or_null("DrawOverlay")
	if overlay == null:
		return
	var sz: Vector2 = overlay.size
	if sz.x < 1 or sz.y < 1:
		return

	var font: Font = ThemeDB.fallback_font
	var center := sz * 0.5
	var radar_r: float = minf(sz.x, sz.y) * 0.42
	var max_range: float = 3000.0

	overlay.draw_arc(center, radar_r, 0.0, TAU, 64, Color(0.2, 0.5, 0.8, 0.4), 1.5, true)
	for frac: float in [0.33, 0.66]:
		var r: float = radar_r * frac
		overlay.draw_arc(center, r, 0.0, TAU, 48, Color(0.15, 0.3, 0.5, 0.3), 1.0, true)

	overlay.draw_line(Vector2(center.x, center.y - radar_r), Vector2(center.x, center.y + radar_r), Color(0.15, 0.3, 0.5, 0.3), 1.0)
	overlay.draw_line(Vector2(center.x - radar_r, center.y), Vector2(center.x + radar_r, center.y), Color(0.15, 0.3, 0.5, 0.3), 1.0)

	overlay.draw_string(font, Vector2(4, 14), "SCANNER", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.3, 0.6, 0.9, 0.7))

	for e in _enemies:
		if not e.get("alive", false):
			continue
		var epos: Vector3 = e.get("position", Vector3.ZERO)
		var rel := _world_to_radar(epos, center, max_range, radar_r)
		if rel.distance_to(center) > radar_r:
			continue
		overlay.draw_circle(rel, 4.0, Color(1.0, 0.2, 0.1, 0.8))

	for s in _stations:
		var spos: Vector3 = s.get("position", Vector3.ZERO)
		var rel := _world_to_radar(spos, center, max_range, radar_r)
		if rel.distance_to(center) > radar_r:
			continue
		overlay.draw_rect(Rect2(rel - Vector2(4, 4), Vector2(8, 8)), Color(0.2, 0.9, 0.3, 0.8))

	var ep_rel := _world_to_radar(_exit_pos, center, max_range, radar_r)
	var t: float = fmod(Time.get_ticks_msec() / 1000.0, 2.0) * PI
	var pulse: float = 0.5 + 0.5 * sin(t * 2.0)
	if ep_rel.distance_to(center) <= radar_r:
		overlay.draw_circle(ep_rel, 6.0 + pulse * 3.0, Color(0.3, 1.0, 0.4, 0.3))
		overlay.draw_circle(ep_rel, 3.0, Color(0.3, 1.0, 0.4, 0.9))

	var heading_rad: float = deg_to_rad(-_player_heading + 90.0)
	var ship_tip := center + Vector2(cos(heading_rad), sin(heading_rad)) * 12.0
	var ship_left := center + Vector2(cos(heading_rad + 2.5), sin(heading_rad + 2.5)) * 7.0
	var ship_right := center + Vector2(cos(heading_rad - 2.5), sin(heading_rad - 2.5)) * 7.0
	var pts := PackedVector2Array([ship_tip, ship_left, ship_right])
	overlay.draw_colored_polygon(pts, Color(0.2, 0.8, 1.0))
	overlay.draw_circle(center, 2.0, Color.WHITE)

	var fwd_end := center + Vector2(cos(heading_rad), sin(heading_rad)) * 30.0
	overlay.draw_dashed_line(center, fwd_end, Color(0.2, 0.6, 1.0, 0.4), 1.0, 4.0)

	var range_labels: Array[float] = [1000.0, 2000.0]
	for i in range_labels.size():
		var r: float = radar_r * (range_labels[i] / max_range)
		overlay.draw_string(font, center + Vector2(r + 2, -4), "%.0f" % range_labels[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.3, 0.4, 0.5, 0.5))

func _world_to_radar(world_pos: Vector3, center: Vector2, max_range: float, radar_r: float) -> Vector2:
	var rel := world_pos - _player_pos
	var map_x: float = rel.x / max_range * radar_r
	var map_y: float = rel.z / max_range * radar_r
	return center + Vector2(map_x, map_y)

func _process(_delta: float) -> void:
	var overlay: Control = get_node_or_null("DrawOverlay")
	if overlay:
		overlay.queue_redraw()
