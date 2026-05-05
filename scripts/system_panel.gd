extends Control

const SEGMENT_COUNT := 20
const BAR_WIDTH := 152.0
const BAR_HEIGHT := 10.0
const SPARKLINE_POINTS := 60
const SPARKLINE_HEIGHT := 24.0
const TEMP_MAX := 120.0

var _low_threshold := 25.0

@onready var fuel_bar_bg: ColorRect = $FuelBarBg
@onready var hull_bar_bg: ColorRect = $HullBarBg
@onready var o2_bar_bg: ColorRect = $O2BarBg
@onready var fuel_label: Label = $FuelLabel
@onready var hull_label: Label = $HullLabel
@onready var o2_label: Label = $O2Label
@onready var status_text: Label = $StatusText

var _fuel_segments: Array[ColorRect] = []
var _hull_segments: Array[ColorRect] = []
var _o2_segments: Array[ColorRect] = []
var _temp_segments: Array[ColorRect] = []
var _temp_label: Label
var _temp_value: Label
var _breaker_lights: Array = []
var _cooling_label: Label
var _o2_supply_label: Label
var _sparkline_label: Label
var _sparkline_bars: Array[ColorRect] = []
var _sparkline_data: Array[float] = []
var _sparkline_value_label: Label

var _fuel_normal := Color(0.2, 0.8, 1.0)
var _hull_normal := Color(0.3, 0.9, 0.4)
var _o2_normal := Color(0.4, 0.7, 1.0)
var _danger := Color(1.0, 0.2, 0.15)
var _warning := Color(1.0, 0.65, 0.1)
var _caution := Color(0.85, 0.85, 0.2)
var _dim := Color(0.12, 0.12, 0.18)

func _ready() -> void:
	_fuel_segments = _build_segments(fuel_bar_bg.position.x, fuel_bar_bg.position.y, BAR_WIDTH, BAR_HEIGHT, _fuel_normal)
	_hull_segments = _build_segments(hull_bar_bg.position.x, hull_bar_bg.position.y, BAR_WIDTH, BAR_HEIGHT, _hull_normal)
	_o2_segments = _build_segments(o2_bar_bg.position.x, o2_bar_bg.position.y, BAR_WIDTH, BAR_HEIGHT, _o2_normal)

	var info: Label = get_node_or_null("InfoLabel")
	if info:
		info.visible = false
	var fb: Label = get_node_or_null("FuelValue")
	if fb:
		fb.visible = false
	var hb: Label = get_node_or_null("HullValue")
	if hb:
		hb.visible = false
	var ob: Label = get_node_or_null("O2Value")
	if ob:
		ob.visible = false

	_build_maintenance_ui()
	_build_sparkline()

func _build_segments(start_x: float, start_y: float, total_w: float, h: float, _theme_color: Color) -> Array[ColorRect]:
	var gap := 1.0
	var seg_w := (total_w - gap * (SEGMENT_COUNT - 1)) / SEGMENT_COUNT
	var segs: Array[ColorRect] = []
	for i in SEGMENT_COUNT:
		var seg := ColorRect.new()
		seg.position = Vector2(start_x + i * (seg_w + gap), start_y)
		seg.size = Vector2(seg_w, h)
		seg.color = _dim
		add_child(seg)
		segs.append(seg)
	return segs

func _build_maintenance_ui() -> void:
	_temp_label = Label.new()
	_temp_label.text = "TMP"
	_temp_label.position = Vector2(12, 58)
	_temp_label.add_theme_font_size_override("font_size", 10)
	add_child(_temp_label)

	var temp_bg := ColorRect.new()
	temp_bg.position = Vector2(48, 60)
	temp_bg.size = Vector2(BAR_WIDTH, BAR_HEIGHT)
	temp_bg.color = Color(0.1, 0.1, 0.15)
	add_child(temp_bg)

	_temp_segments = _build_segments(48, 60, BAR_WIDTH, BAR_HEIGHT, Color(0.2, 0.6, 1.0))

	_temp_value = Label.new()
	_temp_value.text = "20C"
	_temp_value.position = Vector2(205, 58)
	_temp_value.add_theme_font_size_override("font_size", 10)
	add_child(_temp_value)

	for i in range(4):
		var light := ColorRect.new()
		light.position = Vector2(260 + i * 20, 58)
		light.size = Vector2(14, 14)
		light.color = Color(0.1, 0.4, 0.1)
		add_child(light)
		_breaker_lights.append(light)

		var bl := Label.new()
		bl.text = "B%d" % (i + 1)
		bl.position = Vector2(260 + i * 20, 74)
		bl.add_theme_font_size_override("font_size", 8)
		add_child(bl)

	_cooling_label = Label.new()
	_cooling_label.text = "COOL:OFF"
	_cooling_label.position = Vector2(350, 58)
	_cooling_label.add_theme_font_size_override("font_size", 10)
	add_child(_cooling_label)

	_o2_supply_label = Label.new()
	_o2_supply_label.text = ""
	_o2_supply_label.position = Vector2(430, 58)
	_o2_supply_label.add_theme_font_size_override("font_size", 10)
	_o2_supply_label.modulate = Color(0.4, 0.7, 1.0)
	add_child(_o2_supply_label)

func _build_sparkline() -> void:
	_sparkline_label = Label.new()
	_sparkline_label.text = "HIS"
	_sparkline_label.position = Vector2(12, 90)
	_sparkline_label.add_theme_font_size_override("font_size", 10)
	add_child(_sparkline_label)

	var spark_bg := ColorRect.new()
	spark_bg.position = Vector2(48, 92)
	spark_bg.size = Vector2(BAR_WIDTH, SPARKLINE_HEIGHT)
	spark_bg.color = Color(0.08, 0.08, 0.12)
	add_child(spark_bg)

	for i in SPARKLINE_POINTS:
		var bar := ColorRect.new()
		bar.position = Vector2(48 + i * (BAR_WIDTH / SPARKLINE_POINTS), 92)
		bar.size = Vector2(maxf(BAR_WIDTH / SPARKLINE_POINTS - 1.0, 1.0), 0)
		bar.color = Color(0.2, 0.6, 1.0)
		add_child(bar)
		_sparkline_bars.append(bar)

	_sparkline_value_label = Label.new()
	_sparkline_value_label.text = ""
	_sparkline_value_label.position = Vector2(205, 90)
	_sparkline_value_label.add_theme_font_size_override("font_size", 10)
	add_child(_sparkline_value_label)

	_sparkline_data.resize(SPARKLINE_POINTS)
	for i in SPARKLINE_POINTS:
		_sparkline_data[i] = 20.0

func _process(_delta: float) -> void:
	pass

func update_resources(fuel: float, hull: float, oxygen: float) -> void:
	_apply_segments(_fuel_segments, fuel / 100.0, _fuel_normal)
	_apply_segments(_hull_segments, hull / 100.0, _hull_normal)
	_apply_segments(_o2_segments, oxygen / 100.0, _o2_normal)
	var warnings: PackedStringArray = []
	if fuel <= _low_threshold:
		warnings.append("LOW FUEL")
		fuel_label.modulate = _danger
	else:
		fuel_label.modulate = Color.WHITE
	if hull <= _low_threshold:
		warnings.append("HULL DMG")
		hull_label.modulate = _danger
	else:
		hull_label.modulate = Color.WHITE
	if oxygen <= _low_threshold:
		warnings.append("LOW O2")
		o2_label.modulate = _danger
	else:
		o2_label.modulate = Color.WHITE
	if warnings.is_empty():
		status_text.text = "NOMINAL"
		status_text.modulate = Color.WHITE
	else:
		status_text.text = " ".join(warnings)
		status_text.modulate = _danger

func update_engine_temp(temp: float) -> void:
	_apply_segments(_temp_segments, clampf(temp / TEMP_MAX, 0.0, 1.0), Color(0.2, 0.6, 1.0))
	if _temp_value:
		_temp_value.text = "%dC" % int(temp)
		if temp >= 90.0:
			_temp_value.modulate = _danger
		elif temp >= 70.0:
			_temp_value.modulate = _warning
		else:
			_temp_value.modulate = Color.WHITE
	_push_sparkline(temp)

func _push_sparkline(temp: float) -> void:
	_sparkline_data.pop_front()
	_sparkline_data.append(temp)
	var spark_y := 92.0
	for i in SPARKLINE_POINTS:
		var t: float = _sparkline_data[i]
		var pct := clampf(t / TEMP_MAX, 0.0, 1.0)
		var h := SPARKLINE_HEIGHT * pct
		var bar: ColorRect = _sparkline_bars[i]
		bar.position.y = spark_y + (SPARKLINE_HEIGHT - h)
		bar.size.y = h
		bar.color = _temp_color(t)
	if _sparkline_value_label:
		_sparkline_value_label.text = "%dC" % int(temp)
		_sparkline_value_label.modulate = _temp_color(temp)

func _temp_color(temp: float) -> Color:
	if temp >= 90.0:
		return _danger
	elif temp >= 70.0:
		return _warning
	else:
		return Color(0.2, 0.6, 1.0)

func set_scan_complete() -> void:
	pass

func set_breaker_state(index: int, tripped: bool) -> void:
	if index < 0 or index >= _breaker_lights.size():
		return
	var light: ColorRect = _breaker_lights[index]
	if tripped:
		light.color = _danger
	else:
		light.color = Color(0.1, 0.4, 0.1)

func set_cooling_level(level: int) -> void:
	if _cooling_label == null:
		return
	var labels := ["OFF", "LOW", "HIGH"]
	if level >= 0 and level < labels.size():
		_cooling_label.text = "COOL:" + labels[level]
		if level == 2:
			_cooling_label.modulate = Color(0.3, 0.8, 1.0)
		elif level == 1:
			_cooling_label.modulate = Color(0.5, 0.7, 0.8)
		else:
			_cooling_label.modulate = Color.WHITE

func set_o2_supplying(active: bool) -> void:
	if _o2_supply_label == null:
		return
	if active:
		_o2_supply_label.text = "O2+"
		_o2_supply_label.modulate = Color(0.3, 0.9, 0.5)
	else:
		_o2_supply_label.text = ""

func _apply_segments(segments: Array[ColorRect], pct: float, theme_color: Color) -> void:
	var filled := int(pct * SEGMENT_COUNT)
	for i in SEGMENT_COUNT:
		var seg: ColorRect = segments[i]
		if i < filled:
			var ratio := float(i) / float(SEGMENT_COUNT)
			if ratio < 0.25:
				seg.color = _danger
			elif ratio < 0.5:
				seg.color = _warning
			elif ratio < 0.75:
				seg.color = _caution
			else:
				seg.color = theme_color
		else:
			seg.color = _dim
