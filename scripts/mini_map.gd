extends Control

signal destination_reached(channel_id: String)
signal debris_collision(damage: float)

var _map_data: Dictionary = {}
var _debris: Array = []
var _destinations: Array = []
var _scan_frequency: float = 0.5

var _ship_pos: Vector2 = Vector2(0.5, 0.75)
var _ship_heading: float = 0.0
var _ship_speed: float = 0.0

var _data_fresh: bool = true
var _data_age: float = 0.0
var _freshness_duration: float = 15.0
var _debris_drift_speed: float = 0.01

var _signal_strength: float = 0.0
var _show_signal: bool = false

var _config: Dictionary = {}
var _collision_cooldown: float = 0.0
var _arrival_cooldown: float = 0.0
var _overlay: Control = null

func _ready() -> void:
	_overlay = Control.new()
	_overlay.name = "DrawOverlay"
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_PASS
	_overlay.draw.connect(_draw_map)
	add_child(_overlay)
	move_child(_overlay, get_child_count() - 1)

func load_config(cfg: Dictionary) -> void:
	_config = cfg
	var scan_cfg: Dictionary = cfg.get("scan", {})
	_freshness_duration = scan_cfg.get("data_freshness", 15.0)
	_debris_drift_speed = scan_cfg.get("debris_drift_speed", 5.0) / 480.0

func setup_node(map_data: Dictionary) -> void:
	_map_data = map_data
	_debris.clear()
	_destinations.clear()
	_data_fresh = true
	_data_age = 0.0
	_collision_cooldown = 0.0
	_arrival_cooldown = 0.0

	for d: Dictionary in map_data.get("debris", []):
		var pos: Array = d["pos"]
		_debris.append({
			"pos": Vector2(pos[0], pos[1]),
			"r": d.get("r", 0.025),
			"original_pos": Vector2(pos[0], pos[1])
		})

	for dest: Dictionary in map_data.get("destinations", []):
		var pos: Array = dest["pos"]
		_destinations.append({
			"pos": Vector2(pos[0], pos[1]),
			"r": dest.get("r", 0.05),
			"channel_id": dest.get("channel_id", ""),
			"visible": dest.get("visible", true)
		})

	_scan_frequency = map_data.get("scan_frequency", 0.5)
	_signal_strength = 0.0
	_show_signal = false

func update_ship(pos: Vector2, heading: float, speed: float) -> void:
	_ship_pos = pos
	_ship_heading = heading
	_ship_speed = speed

func set_signal_display(is_show: bool, strength: float) -> void:
	_show_signal = is_show
	_signal_strength = strength

func refresh_scan(signal_strength: float) -> void:
	_data_fresh = true
	_data_age = 0.0
	_signal_strength = signal_strength

	for d: Dictionary in _debris:
		var orig: Vector2 = d["original_pos"]
		var accuracy: float = clampf(signal_strength, 0.0, 1.0)
		var offset := Vector2(randf_range(-1, 1), randf_range(-1, 1)) * (1.0 - accuracy) * 0.03
		d["pos"] = orig + offset

	for dest: Dictionary in _destinations:
		if signal_strength > 0.3:
			dest["visible"] = true

func _process(delta: float) -> void:
	if _overlay:
		_overlay.queue_redraw()

	if not _debris.is_empty():
		_data_age += delta
		if _data_age > _freshness_duration:
			_data_fresh = false

	if not _data_fresh:
		for d: Dictionary in _debris:
			var drift := Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
			d["pos"] += drift * _debris_drift_speed * delta
			d["pos"].x = clampf(d["pos"].x, 0.02, 0.98)
			d["pos"].y = clampf(d["pos"].y, 0.02, 0.98)

	if _collision_cooldown > 0.0:
		_collision_cooldown -= delta
	if _arrival_cooldown > 0.0:
		_arrival_cooldown -= delta

	_check_collisions()
	_check_destinations()

func _check_collisions() -> void:
	if _collision_cooldown > 0.0 or _debris.is_empty():
		return

	var damage_cfg: Dictionary = _config.get("damage", {})
	var base_dmg: float = damage_cfg.get("base_collision_damage", 2.0)
	var high_speed_thresh: float = damage_cfg.get("high_speed_threshold", 0.7)
	var high_speed_mult: float = damage_cfg.get("high_speed_damage_mult", 2.5)

	for d: Dictionary in _debris:
		var dist: float = _ship_pos.distance_to(d["pos"])
		var hit_r: float = d["r"] + 0.012
		if dist < hit_r:
			var speed_ratio: float = _ship_speed / 120.0
			var dmg: float = base_dmg
			if speed_ratio > high_speed_thresh:
				dmg *= high_speed_mult
			debris_collision.emit(dmg)
			_collision_cooldown = 0.5
			break

func _check_destinations() -> void:
	if _arrival_cooldown > 0.0:
		return
	for dest: Dictionary in _destinations:
		if not dest["visible"]:
			continue
		var dist: float = _ship_pos.distance_to(dest["pos"])
		if dist < dest["r"]:
			destination_reached.emit(dest["channel_id"])
			_arrival_cooldown = 2.0
			return

func _draw_map() -> void:
	if _overlay == null:
		return
	var sz: Vector2 = _overlay.size
	if sz.x < 1 or sz.y < 1:
		return

	_draw_gravity_gradient(sz)

	for d: Dictionary in _debris:
		var px: Vector2 = Vector2(d["pos"].x * sz.x, d["pos"].y * sz.y)
		var pr: float = d["r"] * minf(sz.x, sz.y)
		_overlay.draw_circle(px, pr, Color(0.9, 0.2, 0.1, 0.5))
		_overlay.draw_circle(px, pr * 0.5, Color(1.0, 0.3, 0.2, 0.7))

	for dest: Dictionary in _destinations:
		if not dest["visible"]:
			continue
		var px: Vector2 = Vector2(dest["pos"].x * sz.x, dest["pos"].y * sz.y)
		var pr: float = dest["r"] * minf(sz.x, sz.y)
		var t: float = fmod(Time.get_ticks_msec() / 1000.0, 2.0) * PI
		var pulse: float = 0.5 + 0.5 * sin(t * 2.0)
		_overlay.draw_circle(px, pr + pulse * 4.0, Color(0.2, 0.9, 0.3, 0.25))
		_overlay.draw_circle(px, pr * 0.4, Color(0.3, 1.0, 0.4, 0.9))
		var font: Font = ThemeDB.fallback_font
		_overlay.draw_string(font, px + Vector2(pr + 5, 4), dest["channel_id"], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.3, 1.0, 0.4))

	var spx: Vector2 = Vector2(_ship_pos.x * sz.x, _ship_pos.y * sz.y)
	var ship_size: float = 10.0
	var h: float = _ship_heading
	var tip := spx + Vector2(cos(h), sin(h)) * ship_size
	var left := spx + Vector2(cos(h + 2.5), sin(h + 2.5)) * ship_size * 0.6
	var right := spx + Vector2(cos(h - 2.5), sin(h - 2.5)) * ship_size * 0.6
	var pts := PackedVector2Array([tip, left, right])
	_overlay.draw_colored_polygon(pts, Color(0.2, 0.8, 1.0))
	_overlay.draw_circle(spx, 3.0, Color.WHITE)

	if _show_signal or _signal_strength > 0.0:
		_draw_signal_bar(sz)

	if not _data_fresh:
		_overlay.draw_string(ThemeDB.fallback_font, Vector2(10, sz.y - 15), "DATA STALE", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1.0, 0.5, 0.2))

	var font_sm: Font = ThemeDB.fallback_font
	var title_text: String = _map_data.get("title", "NAVIGATION MAP")
	_overlay.draw_string(font_sm, Vector2(10, 18), title_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.4, 0.6, 0.8))

func _draw_gravity_gradient(sz: Vector2) -> void:
	var steps := 24
	var step_h: float = sz.y / float(steps)
	for i in range(steps):
		var ratio: float = float(i) / float(steps)
		var r: float = lerp(0.01, 0.12, ratio)
		var g: float = lerp(0.04, 0.01, ratio)
		var b: float = lerp(0.10, 0.18, ratio)
		var a: float = lerp(0.2, 0.85, pow(ratio, 1.5))
		var rect := Rect2(0, i * step_h, sz.x, step_h + 1)
		_overlay.draw_rect(rect, Color(r, g, b, a))

func _draw_signal_bar(sz: Vector2) -> void:
	var bar_w: float = 100.0
	var bar_h: float = 6.0
	var bar_x: float = sz.x - bar_w - 10
	var bar_y: float = 10.0
	_overlay.draw_rect(Rect2(bar_x, bar_y, bar_w, bar_h), Color(0.15, 0.15, 0.2))
	var fill_w: float = bar_w * clampf(_signal_strength, 0.0, 1.0)
	var c := Color(0.2, 0.8, 1.0)
	if _signal_strength > 0.7:
		c = Color(0.3, 1.0, 0.5)
	elif _signal_strength < 0.3:
		c = Color(1.0, 0.3, 0.2)
	_overlay.draw_rect(Rect2(bar_x, bar_y, fill_w, bar_h), c)
	_overlay.draw_string(ThemeDB.fallback_font, Vector2(bar_x, bar_y - 2), "SIG", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.6, 0.6, 0.7))
