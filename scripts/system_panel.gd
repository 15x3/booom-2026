extends Control

signal scan_requested
signal thrust_requested

var _selected_channel_id: String = ""
var _can_scan: bool = false
var _can_thrust: bool = false
var _warning_active: bool = false
var _warning_visible: bool = true
var _warning_timer: float = 0.0

var _bar_bg_width: float = 152.0
var _low_threshold: float = 25.0

@onready var scan_button: Button = $ScanButton
@onready var thrust_button: Button = $ThrustButton
@onready var fuel_bar_fill: ColorRect = $FuelBarFill
@onready var hull_bar_fill: ColorRect = $HullBarFill
@onready var o2_bar_fill: ColorRect = $O2BarFill
@onready var fuel_value: Label = $FuelValue
@onready var hull_value: Label = $HullValue
@onready var o2_value: Label = $O2Value
@onready var status_text: Label = $StatusText
@onready var warning_label: Label = $WarningLabel
@onready var fuel_label: Label = $FuelLabel
@onready var hull_label: Label = $HullLabel
@onready var o2_label: Label = $O2Label

var _fuel_color_normal := Color(0.2, 0.8, 1.0)
var _hull_color_normal := Color(0.3, 0.9, 0.4)
var _o2_color_normal := Color(0.4, 0.7, 1.0)
var _warning_color := Color(1.0, 0.3, 0.2)

func _ready() -> void:
	_update_buttons()

func _process(delta: float) -> void:
	if _warning_active:
		_warning_timer += delta
		if _warning_timer >= 0.5:
			_warning_timer = 0.0
			_warning_visible = not _warning_visible
			warning_label.visible = _warning_visible
			if _warning_visible:
				var blink_children := [fuel_label, hull_label, o2_label]
				for child: Label in blink_children:
					if child and child.modulate == _warning_color:
						child.visible = not child.visible

func set_selected_channel(channel_id: String, can_scan: bool) -> void:
	_selected_channel_id = channel_id
	_can_scan = can_scan
	_can_thrust = channel_id != ""
	_update_buttons()

func set_scan_complete() -> void:
	_can_scan = false
	_update_buttons()

func lock_buttons() -> void:
	scan_button.disabled = true
	thrust_button.disabled = true

func unlock_buttons() -> void:
	_update_buttons()

func set_thrust_enabled(enabled: bool) -> void:
	_can_thrust = enabled and _selected_channel_id != ""
	if thrust_button:
		thrust_button.disabled = not _can_thrust

func get_selected_channel() -> String:
	return _selected_channel_id

func update_resources(fuel: float, hull: float, oxygen: float) -> void:
	_set_bar(fuel_bar_fill, fuel_value, fuel, $FuelBarBg, fuel_label, _fuel_color_normal)
	_set_bar(hull_bar_fill, hull_value, hull, $HullBarBg, hull_label, _hull_color_normal)
	_set_bar(o2_bar_fill, o2_value, oxygen, $O2BarBg, o2_label, _o2_color_normal)
	var warnings: PackedStringArray = []
	if fuel <= _low_threshold:
		warnings.append("LOW FUEL")
	if hull <= _low_threshold:
		warnings.append("HULL DMG")
	if oxygen <= _low_threshold:
		warnings.append("LOW O2")
	if warnings.is_empty():
		status_text.text = "NOMINAL"
		status_text.modulate = Color.WHITE
		_warning_active = false
		warning_label.text = ""
		warning_label.visible = false
		fuel_label.visible = true
		hull_label.visible = true
		o2_label.visible = true
	else:
		status_text.text = "WARNING"
		status_text.modulate = _warning_color
		warning_label.text = " ".join(warnings)
		_warning_active = true
		_warning_visible = true
		warning_label.visible = true

func _set_bar(fill: ColorRect, val_label: Label, value: float, bg: ColorRect, label_node: Label, normal_color: Color) -> void:
	var pct := clampf(value / 100.0, 0.0, 1.0)
	var fill_w: float = _bar_bg_width * pct
	var bg_pos: Vector2 = bg.position
	fill.position = bg_pos
	fill.size = Vector2(fill_w, bg.size.y)
	val_label.text = "%d%%" % int(value)
	if value <= _low_threshold:
		fill.color = _warning_color
		label_node.modulate = _warning_color
	elif value <= 50.0:
		fill.color = normal_color.lerp(Color(1.0, 0.8, 0.2), 0.4)
		label_node.modulate = Color.WHITE
	else:
		fill.color = normal_color
		label_node.modulate = Color.WHITE

func _update_buttons() -> void:
	if scan_button:
		scan_button.disabled = not _can_scan or _selected_channel_id == ""
	if thrust_button:
		thrust_button.disabled = not _can_thrust

func _on_scan_button_pressed() -> void:
	if _can_scan and _selected_channel_id != "":
		scan_requested.emit()

func _on_thrust_button_pressed() -> void:
	if _can_thrust and _selected_channel_id != "":
		thrust_requested.emit()
