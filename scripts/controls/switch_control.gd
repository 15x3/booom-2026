extends "res://scripts/controls/base_control.gd"

signal toggled(is_on: bool)

@export var initial_state: bool = false
@export var switch_width: float = 0.02
@export var switch_height: float = 0.06
@export var switch_depth: float = 0.04
@export var toggle_angle: float = 30.0
@export var toggle_duration: float = 0.15

var _is_on: bool = false

func _ready() -> void:
	_is_on = initial_state
	super._ready()
	_update_visual_state(false)

func _create_visual() -> void:
	var base_mesh := BoxMesh.new()
	base_mesh.size = Vector3(switch_width * 1.5, 0.01, switch_depth * 1.5)
	var base_mi := MeshInstance3D.new()
	base_mi.mesh = base_mesh
	add_child(base_mi)
	base_mi.position.y = 0.005
	
	var lever_mesh := BoxMesh.new()
	lever_mesh.size = Vector3(switch_width, switch_height, switch_depth)
	
	var shape := BoxShape3D.new()
	shape.size = Vector3(switch_width * 2.0, switch_height * 1.5, switch_depth * 2.0)
	
	_mesh_instance = MeshInstance3D.new()
	_mesh_instance.mesh = lever_mesh
	add_child(_mesh_instance)
	_mesh_instance.position.y = switch_height * 0.5
	
	_static_body = StaticBody3D.new()
	_static_body.collision_layer = 2
	_static_body.collision_mask = 0
	add_child(_static_body)
	
	_collision_shape = CollisionShape3D.new()
	_collision_shape.shape = shape
	_static_body.add_child(_collision_shape)
	_collision_shape.position.y = switch_height * 0.5

func activate() -> void:
	if not _enabled:
		return
	_toggle()
	super.activate()

func set_value(v: float) -> void:
	var new_state: bool = v > 0.5
	if new_state != _is_on:
		_is_on = new_state
		_update_visual_state(true)
		toggled.emit(_is_on)
	_value = 1.0 if _is_on else 0.0

func is_on() -> bool:
	return _is_on

func _toggle() -> void:
	_is_on = not _is_on
	_value = 1.0 if _is_on else 0.0
	_update_visual_state(true)
	toggled.emit(_is_on)
	value_changed.emit(_value)

func _update_visual_state(animate: bool) -> void:
	if _mesh_instance == null:
		return
	var target_angle: float = -toggle_angle if _is_on else toggle_angle
	if animate:
		var tween := create_tween()
		tween.set_ease(Tween.EASE_IN_OUT)
		tween.tween_property(_mesh_instance, "rotation_degrees:z", target_angle, toggle_duration)
	else:
		_mesh_instance.rotation_degrees.z = target_angle
