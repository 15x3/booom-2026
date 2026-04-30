extends Node3D

signal interacted
signal value_changed(new_value: float)

var control_name: String = ""
var highlight_color: Color = Color(0.3, 0.8, 1.0, 1.0)
var _enabled: bool = true
var _value: float = 0.0
var _mesh_instance: MeshInstance3D
var _static_body: StaticBody3D
var _collision_shape: CollisionShape3D

func _ready() -> void:
	_create_visual()

func _create_visual() -> void:
	pass

func get_value() -> float:
	return _value

func set_value(v: float) -> void:
	_value = v

func activate() -> void:
	if not _enabled:
		return
	interacted.emit()

func start_drag() -> void:
	pass

func end_drag() -> void:
	pass

func handle_drag(_delta_mouse: Vector2) -> void:
	pass

func _create_mesh_with_collision(mesh: Mesh, shape: Shape3D) -> void:
	_mesh_instance = MeshInstance3D.new()
	_mesh_instance.mesh = mesh
	add_child(_mesh_instance)
	_static_body = StaticBody3D.new()
	_static_body.collision_layer = 2
	_static_body.collision_mask = 0
	add_child(_static_body)
	_collision_shape = CollisionShape3D.new()
	_collision_shape.shape = shape
	_static_body.add_child(_collision_shape)
