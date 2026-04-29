extends Node3D

signal opened
signal closed

@export var side: String = "left"
@export var panel_width: float = 0.5
@export var panel_height: float = 0.6
@export var panel_depth: float = 0.02
@export var handle_width: float = 0.04
@export var handle_height: float = 0.08
@export var open_angle: float = 85.0
@export var anim_duration: float = 0.5

var _is_open: bool = false
var _pivot: Node3D
var _panel_mesh: MeshInstance3D
var _handle_body: StaticBody3D
var _interior: Node3D

func _ready() -> void:
	_build_panel()

func is_panel_open() -> bool:
	return _is_open

func open() -> void:
	if _is_open:
		return
	_is_open = true
	_animate_panel(true)
	opened.emit()

func close() -> void:
	if not _is_open:
		return
	_is_open = false
	_animate_panel(false)
	closed.emit()

func get_interior() -> Node3D:
	return _interior

func _build_panel() -> void:
	_pivot = Node3D.new()
	add_child(_pivot)
	
	var side_sign: float = -1.0 if side == "left" else 1.0
	
	_panel_mesh = MeshInstance3D.new()
	var panel_msh := BoxMesh.new()
	panel_msh.size = Vector3(panel_width, panel_height, panel_depth)
	_panel_mesh.mesh = panel_msh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.25, 0.25, 0.3, 1)
	mat.roughness = 0.9
	mat.metallic = 0.2
	_panel_mesh.material_override = mat
	_pivot.add_child(_panel_mesh)
	_panel_mesh.position = Vector3(side_sign * panel_width * 0.5, panel_height * 0.5, 0)
	
	var handle_mi := MeshInstance3D.new()
	var handle_msh := BoxMesh.new()
	handle_msh.size = Vector3(handle_width, handle_height, panel_depth * 2.0)
	handle_mi.mesh = handle_msh
	var handle_mat := StandardMaterial3D.new()
	handle_mat.albedo_color = Color(0.6, 0.6, 0.65, 1)
	handle_mat.roughness = 0.7
	handle_mat.metallic = 0.4
	handle_mi.material_override = handle_mat
	_pivot.add_child(handle_mi)
	handle_mi.position = Vector3(side_sign * (panel_width - handle_width * 0.5), panel_height * 0.5, 0)
	
	_handle_body = StaticBody3D.new()
	_handle_body.collision_layer = 2
	_handle_body.collision_mask = 0
	handle_mi.add_child(_handle_body)
	
	var handle_shape := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(handle_width * 2.0, handle_height * 1.5, panel_depth * 4.0)
	handle_shape.shape = shape
	_handle_body.add_child(handle_shape)
	
	_handle_body.mouse_entered.connect(_on_handle_hover.bind(true))
	_handle_body.mouse_exited.connect(_on_handle_hover.bind(false))
	_handle_body.input_event.connect(_on_handle_input)
	
	_interior = Node3D.new()
	_pivot.add_child(_interior)
	_interior.position = Vector3(side_sign * panel_width * 0.3, panel_height * 0.3, -panel_depth * 0.5)
	
	_pivot.position.x = -side_sign * panel_width * 0.5

func _on_handle_hover(_entering: bool) -> void:
	pass

func _on_handle_input(_camera: Camera3D, event: InputEvent, _position: Vector3, _normal: Vector3, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if _is_open:
			close()
		else:
			open()

func _animate_panel(opening: bool) -> void:
	if _pivot == null:
		return
	var target: float = open_angle if opening else 0.0
	var side_sign: float = -1.0 if side == "left" else 1.0
	target *= side_sign
	var tween := create_tween()
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.set_trans(Tween.TRANS_QUAD)
	tween.tween_property(_pivot, "rotation_degrees:y", target, anim_duration)
