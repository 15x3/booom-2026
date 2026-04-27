extends Camera3D

signal screen_clicked(screen_name: String, uv: Vector2)

var _yaw: float = 0.0
var _pitch: float = 0.0
var _base_sensitivity: float = 0.003
var _sensitivity: float = 0.003
var _yaw_limit: float = deg_to_rad(75)
var _pitch_limit: float = deg_to_rad(40)
var _captured: bool = false

var _base_fov: float = 70.0
var _zoom_fov: float = 35.0
var _zoom_sensitivity: float = 0.001
var _zoom_speed: float = 10.0
var _aiming: bool = false

func _ready() -> void:
	_base_fov = fov
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	_captured = true

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and _captured:
		_yaw -= event.relative.x * _sensitivity
		_pitch -= event.relative.y * _sensitivity
		_yaw = clampf(_yaw, -_yaw_limit, _yaw_limit)
		_pitch = clampf(_pitch, -_pitch_limit, _pitch_limit)
		rotation.y = _yaw
		rotation.x = _pitch
		get_viewport().set_input_as_handled()

	if event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed:
		if _captured:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
			_captured = false
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
			_captured = true
		get_viewport().set_input_as_handled()

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		_aiming = event.pressed
		get_viewport().set_input_as_handled()

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_raycast_click()
		get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	var target_fov: float = _zoom_fov if _aiming else _base_fov
	fov = lerpf(fov, target_fov, _zoom_speed * delta)
	_sensitivity = lerpf(_sensitivity, _zoom_sensitivity if _aiming else _base_sensitivity, _zoom_speed * delta)

func _raycast_click() -> void:
	var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var from: Vector3 = global_position
	var to: Vector3 = from - global_basis.z * 50.0

	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = 0b0000_0000_0000_0000_0010

	var result: Dictionary = space_state.intersect_ray(query)
	if result.is_empty():
		return

	var collider: CollisionObject3D = result["collider"]
	var hit_pos: Vector3 = result["position"]
	var mesh_parent: MeshInstance3D = collider.get_parent() as MeshInstance3D
	if mesh_parent == null:
		return

	var plane: PlaneMesh = mesh_parent.mesh as PlaneMesh
	if plane == null:
		return

	var local_pos: Vector3 = mesh_parent.global_transform.affine_inverse() * hit_pos
	var half_w: float = plane.size.x / 2.0
	var half_h: float = plane.size.y / 2.0

	var uv := Vector2(
		(local_pos.x + half_w) / plane.size.x,
		(local_pos.z + half_h) / plane.size.y
	)
	uv = uv.clamp(Vector2.ZERO, Vector2.ONE)
	screen_clicked.emit(mesh_parent.name, uv)
