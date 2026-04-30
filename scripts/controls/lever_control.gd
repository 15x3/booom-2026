extends "res://scripts/controls/base_control.gd"

@export var min_position: float = 0.0
@export var max_position: float = 0.12
@export var lever_radius: float = 0.015
@export var lever_height: float = 0.12
@export var handle_radius: float = 0.025

var _drag_start_mouse_y: float = 0.0
var _drag_start_value: float = 0.0
var _handle: MeshInstance3D

func _create_visual() -> void:
	var rod_mesh := CylinderMesh.new()
	rod_mesh.top_radius = lever_radius
	rod_mesh.bottom_radius = lever_radius
	rod_mesh.height = lever_height
	rod_mesh.radial_segments = 8
	rod_mesh.rings = 1
	var rod := MeshInstance3D.new()
	rod.mesh = rod_mesh
	add_child(rod)
	rod.position.y = lever_height * 0.5
	
	var handle_mesh := SphereMesh.new()
	handle_mesh.radius = handle_radius
	handle_mesh.height = handle_radius * 2.0
	handle_mesh.radial_segments = 12
	handle_mesh.rings = 6
	_handle = MeshInstance3D.new()
	_handle.mesh = handle_mesh
	add_child(_handle)
	_handle.position.y = lever_height + handle_radius
	
	var shape := BoxShape3D.new()
	shape.size = Vector3(handle_radius * 3.0, lever_height + handle_radius * 2.0, handle_radius * 3.0)
	
	_mesh_instance = _handle
	
	_static_body = StaticBody3D.new()
	_static_body.collision_layer = 2
	_static_body.collision_mask = 0
	add_child(_static_body)
	
	_collision_shape = CollisionShape3D.new()
	_collision_shape.shape = shape
	_static_body.add_child(_collision_shape)
	_collision_shape.position.y = -handle_radius
	
	_update_visual_position()

func set_value(v: float) -> void:
	_value = clampf(v, 0.0, 1.0)
	_update_visual_position()
	value_changed.emit(_value)

func get_value() -> float:
	return _value

func start_drag() -> void:
	super.start_drag()
	_drag_start_mouse_y = 0.0
	_drag_start_value = _value

func handle_drag(delta_mouse: Vector2) -> void:
	if not _enabled:
		return
	if _drag_start_mouse_y == 0.0:
		_drag_start_mouse_y = delta_mouse.y
		_drag_start_value = _value
		return
	
	var sensitivity: float = 3.0
	var dy: float = (delta_mouse.y - _drag_start_mouse_y) * sensitivity
	_value = clampf(_drag_start_value + dy, 0.0, 1.0)
	_update_visual_position()
	value_changed.emit(_value)

func _update_visual_position() -> void:
	var y_offset: float = lerpf(min_position, max_position, _value)
	var handle_y: float = lever_height + handle_radius + y_offset
	if _handle:
		_handle.position.y = handle_y
