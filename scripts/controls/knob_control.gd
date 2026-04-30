extends "res://scripts/controls/base_control.gd"

signal stop_changed(stop_index: int)

@export var stops: int = 0
@export var min_angle: float = -150.0
@export var max_angle: float = 150.0
@export var knob_radius: float = 0.04
@export var knob_height: float = 0.02

var _current_angle: float = 0.0
var _drag_start_mouse_x: float = 0.0
var _drag_start_angle: float = 0.0
var _current_stop: int = 0

func _create_visual() -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = knob_radius
	mesh.bottom_radius = knob_radius
	mesh.height = knob_height
	mesh.radial_segments = 16
	mesh.rings = 1
	
	var shape := CylinderShape3D.new()
	shape.radius = knob_radius * 1.2
	shape.height = knob_height * 3.0
	
	_create_mesh_with_collision(mesh, shape)
	_collision_shape.position.y = knob_height * 0.5
	
	if _mesh_instance:
		_mesh_instance.rotation.x = -PI / 2.0
		_mesh_instance.position.y = knob_height * 0.5

func set_value(v: float) -> void:
	_value = clampf(v, 0.0, 1.0)
	_current_angle = lerpf(min_angle, max_angle, _value)
	_update_rotation()
	_update_stop()

func get_value() -> float:
	return _value

func activate() -> void:
	super.activate()

func get_current_stop() -> int:
	return _current_stop

func set_to_stop(index: int) -> void:
	if stops <= 0:
		return
	index = clampi(index, 0, stops - 1)
	_current_stop = index
	_value = float(index) / float(maxi(stops - 1, 1))
	_current_angle = lerpf(min_angle, max_angle, _value)
	_animate_to_angle(_current_angle)

func start_drag() -> void:
	super.start_drag()
	_drag_start_mouse_x = 0.0
	_drag_start_angle = _current_angle

func handle_drag(delta_mouse: Vector2) -> void:
	if not _enabled:
		return
	if _drag_start_mouse_x == 0.0:
		_drag_start_mouse_x = delta_mouse.x
		_drag_start_angle = _current_angle
		return
	
	var sensitivity: float = 0.5
	var delta_angle: float = (delta_mouse.x - _drag_start_mouse_x) * sensitivity
	var target_angle: float = _drag_start_angle + delta_angle
	target_angle = clampf(target_angle, min_angle, max_angle)
	
	_current_angle = target_angle
	_value = inverse_lerp(min_angle, max_angle, _current_angle)
	_value = clampf(_value, 0.0, 1.0)
	_update_rotation()
	value_changed.emit(_value)

func end_drag() -> void:
	if stops > 0:
		_snap_to_nearest_stop()
	else:
		super.end_drag()
		return
	super.end_drag()

func _update_rotation() -> void:
	if _mesh_instance:
		_mesh_instance.rotation_degrees.z = _current_angle

func _update_stop() -> void:
	if stops <= 0:
		return
	var new_stop: int = roundi(_value * float(stops - 1))
	new_stop = clampi(new_stop, 0, stops - 1)
	if new_stop != _current_stop:
		_current_stop = new_stop
		stop_changed.emit(_current_stop)

func _snap_to_nearest_stop() -> void:
	if stops <= 0:
		return
	_current_stop = clampi(roundi(_value * float(stops - 1)), 0, stops - 1)
	_value = float(_current_stop) / float(maxi(stops - 1, 1))
	_current_angle = lerpf(min_angle, max_angle, _value)
	_animate_to_angle(_current_angle)
	stop_changed.emit(_current_stop)
	value_changed.emit(_value)

func _animate_to_angle(target: float) -> void:
	if _mesh_instance == null:
		return
	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(_mesh_instance, "rotation_degrees:z", target, 0.15)
