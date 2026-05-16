extends Camera3D

signal screen_clicked(screen_name: String, uv: Vector2)
signal object_clicked(collider: CollisionObject3D, hit_pos: Vector3)

enum FocusState { DEFAULT, MAIN_SCREEN, LEFT_SCREEN, RIGHT_SCREEN }

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

var _shake_tween: Tween = null
var _shake_intensity: float = 0.0
var _base_h_offset: float = 0.0
var _base_v_offset: float = 0.0

@export var focus_distance: float = 0.6
@export var focus_duration: float = 0.4
@export var focus_offset_main: Vector3 = Vector3.ZERO
@export var focus_offset_left: Vector3 = Vector3.ZERO
@export var focus_offset_right: Vector3 = Vector3.ZERO

var _focus: int = FocusState.DEFAULT
var _default_pos: Vector3
var _default_basis: Basis
var _focus_tween: Tween = null

var _hover_target: int = FocusState.DEFAULT
var _highlight_shader: Shader
var _highlight_materials: Dictionary = {}
var _focus_targets: Dictionary = {}

var _blink_period: float = 5.0
var _blink_min_energy: float = 0.25
var _blink_max_energy: float = 0.6
var _hover_energy: float = 1.2

var _aim_target_x: float = 0.0
var _aim_target_y: float = 0.0
var _aim_current_x: float = 0.0
var _aim_current_y: float = 0.0
var _aim_strength: float = 0.06
var _aim_smooth: float = 8.0

var _flight_vibration: bool = false
var _shake_player: AnimationPlayer = null

func _ready() -> void:
	_base_fov = fov
	_default_pos = global_position
	_default_basis = global_transform.basis
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_setup_flashlight()
	_setup_highlight()
	_setup_flight_shake()

func _setup_flight_shake() -> void:
	_shake_player = get_node_or_null("ShakePlayer")
	if _shake_player == null:
		return
	var anim := Animation.new()
	anim.length = 2.4
	anim.loop_mode = Animation.LOOP_LINEAR
	var track_idx: int = anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(track_idx, ":h_offset")
	anim.track_set_interpolation_type(track_idx, Animation.INTERPOLATION_LINEAR)
	var keys_h := [0.0, 0.008, 0.3, -0.012, 0.6, 0.01, 0.9, -0.008, 1.2, 0.014, 1.5, -0.006, 1.8, 0.01, 2.1, -0.01, 2.4, 0.008]
	for i in range(0, keys_h.size(), 2):
		anim.track_insert_key(track_idx, keys_h[i], keys_h[i + 1])
	var track_idx_v: int = anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(track_idx_v, ":v_offset")
	anim.track_set_interpolation_type(track_idx_v, Animation.INTERPOLATION_LINEAR)
	var keys_v := [0.0, -0.006, 0.2, 0.01, 0.5, -0.009, 0.8, 0.012, 1.0, -0.008, 1.3, 0.006, 1.6, -0.011, 1.9, 0.009, 2.2, -0.007, 2.4, -0.006]
	for i in range(0, keys_v.size(), 2):
		anim.track_insert_key(track_idx_v, keys_v[i], keys_v[i + 1])
	var track_idx_rot: int = anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(track_idx_rot, ":rotation")
	anim.track_set_interpolation_type(track_idx_rot, Animation.INTERPOLATION_LINEAR)
	var keys_r := [0.0, Vector3(0.004, 0.002, -0.006), 0.3, Vector3(-0.003, -0.001, 0.008), 0.6, Vector3(0.005, 0.003, -0.004), 0.9, Vector3(-0.002, -0.003, 0.007), 1.2, Vector3(0.003, 0.001, -0.005), 1.5, Vector3(-0.004, 0.002, 0.006), 1.8, Vector3(0.002, -0.002, -0.003), 2.1, Vector3(-0.003, 0.003, 0.004), 2.4, Vector3(0.004, 0.002, -0.006)]
	for i in range(0, keys_r.size(), 2):
		anim.track_insert_key(track_idx_rot, keys_r[i], keys_r[i + 1])
	var lib := AnimationLibrary.new()
	lib.add_animation("flight_shake", anim)
	_shake_player.add_animation_library("", lib)

func _setup_flashlight() -> void:
	_flashlight = SpotLight3D.new()
	_flashlight.spot_angle = 45.0
	_flashlight.spot_range = 15.0
	_flashlight.light_energy = 5.0
	_flashlight.light_color = Color(1.0, 0.95, 0.85)
	_flashlight.visible = false
	add_child(_flashlight)

func _setup_highlight() -> void:
	_highlight_shader = load("res://assets/shaders/highlight.gdshader") as Shader
	if _highlight_shader == null:
		push_warning("Highlight shader not found")
		return
	for key: String in ["MainScreenSlot", "LeftScreenSlot", "RightScreenSlot"]:
		var mat := ShaderMaterial.new()
		mat.shader = _highlight_shader
		mat.set_shader_parameter("glow_color", Color(0.2, 0.8, 1.0, 1.0))
		mat.set_shader_parameter("glow_energy", 0.0)
		mat.set_shader_parameter("fresnel_power", 3.0)
		_highlight_materials[key] = mat

func setup_focus_targets(main_screen: MeshInstance3D, left_screen: MeshInstance3D, right_screen: MeshInstance3D) -> void:
	_focus_targets = {
		"MainScreenSlot": main_screen,
		"LeftScreenSlot": left_screen,
		"RightScreenSlot": right_screen,
	}
	for key: String in _focus_targets:
		var mesh_inst: MeshInstance3D = _focus_targets[key]
		if mesh_inst and _highlight_materials.has(key):
			mesh_inst.material_overlay = _highlight_materials[key]

func get_focus_state() -> int:
	return _focus

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
		if _focus != FocusState.DEFAULT:
			return
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
			if _focus != FocusState.DEFAULT:
				if event.pressed:
					_return_to_default()
				get_viewport().set_input_as_handled()
				return
			_aiming = event.pressed
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_MIDDLE and event.pressed:
			toggle_flashlight()
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_handle_left_click()
			get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	if _focus == FocusState.DEFAULT:
		var target_fov: float = _zoom_fov if _aiming else _base_fov
		fov = lerpf(fov, target_fov, _zoom_speed * delta)
	_update_hover()
	_update_blink()
	_aim_current_x = lerpf(_aim_current_x, _aim_target_x, _aim_smooth * delta)
	_aim_current_y = lerpf(_aim_current_y, _aim_target_y, _aim_smooth * delta)
	if _focus == FocusState.DEFAULT and (_focus_tween == null or not _focus_tween.is_valid()):
		var offset := Vector3(
			_aim_current_x * _aim_strength,
			_aim_current_y * _aim_strength,
			0.0
		)
		global_position = _default_pos + offset
	if not _flight_vibration:
		rotation = Vector3.ZERO

func _handle_left_click() -> void:
	if _focus != FocusState.DEFAULT:
		_raycast_click_focused()
		return
	var hit_focus: int = _raycast_hover()
	if hit_focus != FocusState.DEFAULT:
		focus_on(hit_focus)
		return
	_raycast_click()

func focus_on(target: int) -> void:
	if _focus == target:
		return
	_focus = target
	var screen_name: String = ""
	match target:
		FocusState.MAIN_SCREEN:
			screen_name = "MainScreenSlot"
		FocusState.LEFT_SCREEN:
			screen_name = "LeftScreenSlot"
		FocusState.RIGHT_SCREEN:
			screen_name = "RightScreenSlot"
		_:
			_return_to_default()
			return
	var target_pos: Vector3 = _compute_focus_pos(screen_name)
	var target_basis: Basis = _compute_focus_basis(screen_name)
	_tween_to(target_pos, target_basis)

func _return_to_default() -> void:
	_focus = FocusState.DEFAULT
	_tween_to(_default_pos, _default_basis)

func _tween_to(target_pos: Vector3, target_basis: Basis) -> void:
	if _focus_tween:
		_focus_tween.kill()
	_focus_tween = create_tween()
	_focus_tween.set_ease(Tween.EASE_IN_OUT)
	_focus_tween.set_trans(Tween.TRANS_QUAD)
	_focus_tween.set_parallel(true)
	_focus_tween.tween_property(self, "global_position", target_pos, focus_duration)
	var from_q := Quaternion(global_transform.basis)
	var to_q := Quaternion(target_basis)
	_focus_tween.tween_method(_apply_quat, from_q, to_q, focus_duration)

func _apply_quat(q: Quaternion) -> void:
	global_transform.basis = Basis(q)

func _get_focus_offset(screen_name: String) -> Vector3:
	match screen_name:
		"MainScreenSlot":
			return focus_offset_main
		"LeftScreenSlot":
			return focus_offset_left
		"RightScreenSlot":
			return focus_offset_right
	return Vector3.ZERO

func _compute_focus_pos(screen_name: String) -> Vector3:
	var mesh_inst: MeshInstance3D = _focus_targets.get(screen_name)
	if mesh_inst == null:
		return _default_pos
	var t: Transform3D = mesh_inst.global_transform
	var face_normal: Vector3 = t.basis.y
	return t.origin - face_normal * focus_distance + _get_focus_offset(screen_name)

func _compute_focus_basis(screen_name: String) -> Basis:
	var mesh_inst: MeshInstance3D = _focus_targets.get(screen_name)
	if mesh_inst == null:
		return _default_basis
	var t: Transform3D = mesh_inst.global_transform
	var face_normal: Vector3 = t.basis.y
	return Basis.looking_at(-face_normal, Vector3.UP)

func _raycast_hover() -> int:
	var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var mouse_pos: Vector2 = get_viewport().get_mouse_position()
	var from: Vector3 = project_ray_origin(mouse_pos)
	var dir: Vector3 = project_ray_normal(mouse_pos)
	var to: Vector3 = from + dir * 50.0

	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = _screen_mask
	var result: Dictionary = space_state.intersect_ray(query)
	if result.is_empty():
		return FocusState.DEFAULT

	var collider: CollisionObject3D = result["collider"]
	var mesh_parent: MeshInstance3D = collider.get_parent() as MeshInstance3D
	if mesh_parent == null:
		return FocusState.DEFAULT

	match mesh_parent.name:
		"MainScreenSlot":
			return FocusState.MAIN_SCREEN
		"LeftScreenSlot":
			return FocusState.LEFT_SCREEN
		"RightScreenSlot":
			return FocusState.RIGHT_SCREEN
	return FocusState.DEFAULT

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

func _raycast_click_focused() -> void:
	var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var mouse_pos: Vector2 = get_viewport().get_mouse_position()
	var from: Vector3 = project_ray_origin(mouse_pos)
	var dir: Vector3 = project_ray_normal(mouse_pos)
	var to: Vector3 = from + dir * 50.0

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

func _update_hover() -> void:
	if _focus != FocusState.DEFAULT:
		_hover_target = _focus
		return
	_hover_target = _raycast_hover()

func _update_blink() -> void:
	if _highlight_materials.is_empty():
		return
	var t: float = Time.get_ticks_msec() / 1000.0
	var pulse: float = (sin(t / _blink_period * TAU) * 0.5 + 0.5)
	var blink_energy: float = lerpf(_blink_min_energy, _blink_max_energy, pulse)

	for key: String in ["MainScreenSlot", "LeftScreenSlot", "RightScreenSlot"]:
		var mat: ShaderMaterial = _highlight_materials.get(key)
		if mat == null:
			continue
		var is_hovered: bool = false
		match _hover_target:
			FocusState.MAIN_SCREEN:
				is_hovered = (key == "MainScreenSlot")
			FocusState.LEFT_SCREEN:
				is_hovered = (key == "LeftScreenSlot")
			FocusState.RIGHT_SCREEN:
				is_hovered = (key == "RightScreenSlot")
		var target_energy: float = _hover_energy if is_hovered else blink_energy
		var current_energy: float = mat.get_shader_parameter("glow_energy") as float
		mat.set_shader_parameter("glow_energy", lerpf(current_energy, target_energy, 0.1))

func toggle_flashlight() -> void:
	_flashlight_on = not _flashlight_on
	_flashlight.visible = _flashlight_on

func is_flashlight_on() -> bool:
	return _flashlight_on

func get_flashlight() -> SpotLight3D:
	return _flashlight

func shake(intensity: float, duration: float) -> void:
	if _shake_tween:
		_shake_tween.kill()
	_shake_intensity = intensity
	_shake_tween = create_tween()
	_shake_tween.set_loops()
	_shake_tween.tween_callback(func():
		h_offset = _base_h_offset + randf_range(-_shake_intensity, _shake_intensity)
		v_offset = _base_v_offset + randf_range(-_shake_intensity, _shake_intensity)
	)
	_shake_tween.tween_interval(0.033)
	get_tree().create_timer(duration).timeout.connect(stop_shake)

func stop_shake() -> void:
	if _shake_tween:
		_shake_tween.kill()
		_shake_tween = null
	h_offset = _base_h_offset
	v_offset = _base_v_offset
	_shake_intensity = 0.0

func set_shake_intensity(intensity: float) -> void:
	_shake_intensity = intensity

func set_aim_offset(x: float, y: float) -> void:
	_aim_target_x = x
	_aim_target_y = y

func set_flight_vibration(enabled: bool) -> void:
	_flight_vibration = enabled
	if _shake_player == null:
		return
	if enabled:
		_shake_player.play("flight_shake")
	else:
		_shake_player.stop()
		h_offset = _base_h_offset
		v_offset = _base_v_offset
		rotation = Vector3.ZERO
		_aim_target_x = 0.0
		_aim_target_y = 0.0
		if _focus == FocusState.DEFAULT and (_focus_tween == null or not _focus_tween.is_valid()):
			global_position = _default_pos
