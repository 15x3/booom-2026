extends Control

var _player_pos: Vector3 = Vector3.ZERO
var _player_heading: float = 0.0
var _enemies: Array = []
var _end_point_pos: Vector3 = Vector3.ZERO

var _max_range: float = 1600.0

var _player_label: Label
var _exit_label: Label
var _enemy_label: Label
var _enemy_pool: Array[Label] = []
var _exit_arrow_label: Label
var _labels_reset: bool = false

func _ready() -> void:
	_player_label = get_node_or_null("Player")
	_exit_label = get_node_or_null("Exit")
	_enemy_label = get_node_or_null("Enemy")

	_exit_arrow_label = Label.new()
	_exit_arrow_label.name = "ExitArrow"
	_exit_arrow_label.add_theme_color_override("font_color", Color(1, 0.56, 0, 1))
	_exit_arrow_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_exit_arrow_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_exit_arrow_label.text = ""
	add_child(_exit_arrow_label)
	if _exit_label:
		var font: Font = _exit_label.get_theme_font("font")
		if font:
			_exit_arrow_label.add_theme_font_override("font", font)

	_reset_scene_labels()

func _reset_scene_labels() -> void:
	if _labels_reset:
		return
	_labels_reset = true
	var scene_labels: Array[Label] = []
	if _player_label:
		scene_labels.append(_player_label)
	if _exit_label:
		scene_labels.append(_exit_label)
	if _enemy_label:
		scene_labels.append(_enemy_label)
	for lbl in scene_labels:
		lbl.set_anchors_preset(Control.PRESET_TOP_LEFT)
		lbl.offset_left = 0.0
		lbl.offset_right = 0.0
		lbl.offset_top = 0.0
		lbl.offset_bottom = 0.0
		lbl.grow_horizontal = Control.GROW_DIRECTION_BOTH
		lbl.grow_vertical = Control.GROW_DIRECTION_BOTH
		lbl.size = Vector2.ZERO

func update_data(player_pos: Vector3, heading: float, enemies: Array, end_pos: Vector3) -> void:
	_player_pos = player_pos
	_player_heading = heading
	_enemies = enemies
	_end_point_pos = end_pos
	_refresh()

func _refresh() -> void:
	var sz: Vector2 = size
	if sz.x < 1 or sz.y < 1:
		return

	var center := sz * 0.5
	var half_w: float = sz.x * 0.45
	var half_h: float = sz.y * 0.45
	var margin: float = 16.0

	if _enemy_label:
		_enemy_label.visible = false

	_update_player(center)

	while _enemy_pool.size() < _enemies.size():
		var lbl := Label.new()
		lbl.name = "DynEnemy%d" % _enemy_pool.size()
		if _player_label:
			var font: Font = _player_label.get_theme_font("font")
			if font:
				lbl.add_theme_font_override("font", font)
			var fs := _player_label.get_theme_font_size("font_size")
			if fs > 0:
				lbl.add_theme_font_size_override("font_size", fs)
		lbl.add_theme_color_override("font_color", Color(1, 0.56, 0, 1))
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		add_child(lbl)
		_enemy_pool.append(lbl)

	for i in _enemy_pool.size():
		if i < _enemies.size() and _enemies[i].get("alive", false):
			var epos: Vector3 = _enemies[i].get("position", Vector3.ZERO)
			var rel := _world_to_map_unclamped(epos, center, half_w, half_h)
			if _is_inside(rel, margin, sz):
				_enemy_pool[i].text = "E"
				_place_at(_enemy_pool[i], rel)
				_enemy_pool[i].visible = true
			else:
				_enemy_pool[i].visible = false
		else:
			_enemy_pool[i].visible = false

	_update_exit(center, half_w, half_h, margin, sz)

func _place_at(lbl: Label, pos: Vector2) -> void:
	lbl.position = pos - lbl.size * 0.5

func _update_player(center: Vector2) -> void:
	if _player_label == null:
		return
	var h_norm: float = fmod(_player_heading + 360.0, 360.0)
	var arrow: String
	if h_norm < 45.0 or h_norm >= 315.0:
		arrow = "^"
	elif h_norm >= 45.0 and h_norm < 135.0:
		arrow = ">"
	elif h_norm >= 135.0 and h_norm < 225.0:
		arrow = "v"
	else:
		arrow = "<"
	_player_label.text = arrow
	_place_at(_player_label, center)

func _update_exit(center: Vector2, half_w: float, half_h: float, margin: float, sz: Vector2) -> void:
	if _exit_label == null:
		return
	var ep_rel := _world_to_map_unclamped(_end_point_pos, center, half_w, half_h)
	var ep_inside: bool = _is_inside(ep_rel, margin, sz)
	var t: float = fmod(Time.get_ticks_msec() / 500.0, 2.0)
	var blink_alpha: float = 0.5 + 0.5 * sin(t * PI)

	if ep_inside:
		_exit_label.text = "( ( EXIT ) )"
		_place_at(_exit_label, ep_rel)
		_exit_label.visible = true
		_exit_label.modulate.a = blink_alpha
		if _exit_arrow_label:
			_exit_arrow_label.visible = false
	else:
		var clamped := _clamp_to_edge(ep_rel, margin, sz)
		var dir := (ep_rel - center).normalized()
		var arrow_char: String = _get_arrow_char(dir)
		_exit_label.text = "EXIT"
		_place_at(_exit_label, clamped)
		_exit_label.visible = true
		_exit_label.modulate.a = blink_alpha
		if _exit_arrow_label:
			_exit_arrow_label.text = arrow_char
			_place_at(_exit_arrow_label, clamped + Vector2(40, 0))
			_exit_arrow_label.visible = true
			_exit_arrow_label.modulate.a = blink_alpha

func _world_to_map_unclamped(world_pos: Vector3, center: Vector2, half_w: float, half_h: float) -> Vector2:
	var rel := world_pos - _player_pos
	var map_x: float = rel.x / _max_range * half_w
	var map_y: float = -rel.z / _max_range * half_h
	return center + Vector2(map_x, map_y)

func _is_inside(pos: Vector2, margin: float, sz: Vector2) -> bool:
	return pos.x > margin and pos.x < sz.x - margin and pos.y > margin and pos.y < sz.y - margin

func _clamp_to_edge(pos: Vector2, margin: float, sz: Vector2) -> Vector2:
	var x: float = clampf(pos.x, margin + 4.0, sz.x - margin - 4.0)
	var y: float = clampf(pos.y, margin + 4.0, sz.y - margin - 4.0)
	return Vector2(x, y)

func _get_arrow_char(dir: Vector2) -> String:
	var angle: float = rad_to_deg(atan2(dir.x, -dir.y))
	if angle < 0.0:
		angle += 360.0
	if angle < 45.0 or angle >= 315.0:
		return "^"
	elif angle >= 45.0 and angle < 135.0:
		return ">"
	elif angle >= 135.0 and angle < 225.0:
		return "v"
	else:
		return "<"
