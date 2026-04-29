extends Camera3D

signal screen_clicked(screen_name: String, uv: Vector2)
signal object_clicked(collider: CollisionObject3D, hit_pos: Vector3)

var _view_index: int = 0
var _view_y_angle: float = 0.0
var _step_angle: float = deg_to_rad(90.0)
var _view_tween: Tween = null
var _tween_duration: float = 0.3

var _base_fov: float = 70.0
var _zoom_fov: float = 35.0
var _zoom_speed: float = 10.0
var _aiming: bool = false

var _flashlight: SpotLight3D
var _flashlight_on: bool = false

var _ctrl_mask: int = 0b0000_0000_0000_0000_0010
var _screen_mask: int = 0b0000_0000_0000_0000_0001

func _ready() -> void:
	_base_fov = fov
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_setup_flashlight()

func _setup_flashlight() -> void:
	_flashlight = SpotLight3D.new()
	_flashlight.spot_angle = 45.0
	_flashlight.spot_range = 15.0
	_flashlight.light_energy = 5.0
	_flashlight.light_color = Color(1.0, 0.95, 0.85)
	_flashlight.visible = false
	add_child(_flashlight)

func get_current_view() -> int:
	return _view_index

func cycle_view(direction: int) -> void:
	_view_index = posmod(_view_index + direction, 4)
	_view_y_angle += float(-direction) * _step_angle
	if _view_tween:
		_view_tween.kill()
	_view_tween = create_tween()
	_view_tween.set_ease(Tween.EASE_IN_OUT)
	_view_tween.set_trans(Tween.TRANS_QUAD)
	_view_tween.tween_property(self, "rotation:y", _view_y_angle, _tween_duration)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		var key: int = event.keycode if event.keycode != 0 else event.physical_keycode
		if key == KEY_Q:
			cycle_view(-1)
		elif key == KEY_E:
			cycle_view(1)
		elif key == KEY_F:
			toggle_flashlight()
		get_viewport().set_input_as_handled()

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			_aiming = event.pressed
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_MIDDLE and event.pressed:
			toggle_flashlight()
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_raycast_click()
			get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	var target_fov: float = _zoom_fov if _aiming else _base_fov
	fov = lerpf(fov, target_fov, _zoom_speed * delta)

func toggle_flashlight() -> void:
	_flashlight_on = not _flashlight_on
	_flashlight.visible = _flashlight_on

func is_flashlight_on() -> bool:
	return _flashlight_on

func get_flashlight() -> SpotLight3D:
	return _flashlight

func _raycast_click() -> void:
	var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var mouse_pos: Vector2 = get_viewport().get_mouse_position()
	var from: Vector3 = project_ray_origin(mouse_pos)
	var dir: Vector3 = project_ray_normal(mouse_pos)
	var to: Vector3 = from + dir * 50.0

	var ctrl_query := PhysicsRayQueryParameters3D.create(from, to)
	ctrl_query.collision_mask = _ctrl_mask
	var ctrl_result: Dictionary = space_state.intersect_ray(ctrl_query)
	if not ctrl_result.is_empty():
		object_clicked.emit(ctrl_result["collider"], ctrl_result["position"])
		return

	var scr_query := PhysicsRayQueryParameters3D.create(from, to)
	scr_query.collision_mask = _screen_mask
	var scr_result: Dictionary = space_state.intersect_ray(scr_query)
	if scr_result.is_empty():
		return

	var collider: CollisionObject3D = scr_result["collider"]
	var hit_pos: Vector3 = scr_result["position"]

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
