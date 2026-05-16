extends Control

@onready var _hull_progress_bar: Sprite2D = $HullProgressBar
@onready var _hull_label: Label = $Hull2
@onready var _start_point: Sprite2D = $StartPoint
@onready var _end_point: Sprite2D = $EndPoint
@onready var _current_position: Sprite2D = $CurrentPosition

var _hull_bar_mat: ShaderMaterial = null
var _start_x: float = 0.0
var _end_x: float = 0.0
var _base_y: float = 0.0

func _ready() -> void:
	if _hull_progress_bar and _hull_progress_bar.material is ShaderMaterial:
		_hull_bar_mat = _hull_progress_bar.material as ShaderMaterial
	if _start_point:
		_start_x = _start_point.position.x
	if _end_point:
		_end_x = _end_point.position.x
	if _start_point:
		_base_y = _start_point.position.y

func setup(size: Vector2i) -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	set_size(Vector2(size.x, size.y))

func update_status(data: Dictionary) -> void:
	if data.has("hp") and data.has("hp_max"):
		var hp_ratio: float = float(data["hp"]) / float(data["hp_max"])
		if _hull_bar_mat:
			_hull_bar_mat.set_shader_parameter("progress", hp_ratio)

	if data.has("progress") and _current_position:
		var p: float = float(data["progress"])
		var new_x: float = lerpf(_start_x, _end_x, p)
		_current_position.position.x = new_x

func set_mission(_text: String) -> void:
	pass

func clear_mission() -> void:
	pass
