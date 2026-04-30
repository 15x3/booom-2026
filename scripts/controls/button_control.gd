extends "res://scripts/controls/base_control.gd"

@export var button_width: float = 0.05
@export var button_height: float = 0.02
@export var button_depth: float = 0.05
@export var press_depth: float = 0.01
@export var press_duration: float = 0.08
@export var return_duration: float = 0.12

var _is_pressed: bool = false

func _create_visual() -> void:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(button_width, button_height, button_depth)
	
	var shape := BoxShape3D.new()
	shape.size = Vector3(button_width * 1.2, button_height * 2.0, button_depth * 1.2)
	
	_create_mesh_with_collision(mesh, shape)
	_collision_shape.position.y = button_height * 0.5
	if _mesh_instance:
		_mesh_instance.position.y = button_height * 0.5

func activate() -> void:
	if not _enabled:
		return
	_play_press_animation()
	super.activate()

func set_value(v: float) -> void:
	_value = v

func _play_press_animation() -> void:
	if _mesh_instance == null:
		return
	_is_pressed = true
	var tween := create_tween()
	tween.set_ease(Tween.EASE_IN)
	tween.tween_property(_mesh_instance, "position:y", -press_depth, press_duration)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(_mesh_instance, "position:y", button_height * 0.5, return_duration)
	tween.tween_callback(func(): _is_pressed = false)

func is_pressed() -> bool:
	return _is_pressed
