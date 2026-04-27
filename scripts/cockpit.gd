extends Node3D

@onready var forward_viewport: SubViewport = $ForwardViewport
@onready var rear_viewport: SubViewport = $RearViewport
@onready var main_monitor_viewport: SubViewport = $MainMonitorViewport

@onready var main_screen: MeshInstance3D = $CockpitInterior/MainScreenSlot
@onready var left_screen: MeshInstance3D = $CockpitInterior/LeftScreenSlot
@onready var right_screen: MeshInstance3D = $CockpitInterior/RightScreenSlot

@onready var forward_cam: Camera3D = $ForwardViewport/CamRig/ForwardCam
@onready var rear_cam: Camera3D = $RearViewport/CamRig/RearCam
@onready var player_cam: Camera3D = $PlayerCamera

@onready var nav_system: Node = $NavigationSystem

var config: Dictionary = {}
var _camera_fps_timer: Timer
var _camera_vps: Array = []
var _gravity_map: Control = null

func _ready() -> void:
	_load_config()
	_setup_viewports()
	_setup_cameras()
	_setup_camera_fps()
	_bind_viewport_textures()
	_apply_crt_to_cameras()
	_connect_signals()
	if nav_system and nav_system.has_method("start"):
		nav_system.start()

func _load_config() -> void:
	var path := "res://assets/data/game_config.json"
	if not FileAccess.file_exists(path):
		push_error("Config file not found: " + path)
		return
	var file := FileAccess.open(path, FileAccess.READ)
	var json := JSON.new()
	var err := json.parse(file.get_as_text())
	if err != OK:
		push_error("Config parse error: " + json.get_error_message())
		return
	config = json.data

func _connect_signals() -> void:
	_gravity_map = main_monitor_viewport.get_node("GravityMapPanel")
	if _gravity_map:
		_gravity_map.channel_clicked.connect(_on_channel_clicked)
	if nav_system:
		nav_system.node_changed.connect(_on_node_changed)

func _setup_viewports() -> void:
	var main_world := get_viewport().get_world_3d()
	var cam_res: Array = config.get("monitor", {}).get("camera_resolution", [320, 240])
	var vp_size := Vector2i(int(cam_res[0]), int(cam_res[1]))

	for vp: SubViewport in [forward_viewport, rear_viewport]:
		vp.world_3d = main_world
		vp.size = vp_size
		vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS

	main_monitor_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS

func _setup_cameras() -> void:
	var space_layer := 0b0000_0000_0000_0000_0001
	player_cam.cull_mask = 0b0000_0000_0000_0000_0011
	forward_cam.cull_mask = space_layer
	rear_cam.cull_mask = space_layer

func _setup_camera_fps() -> void:
	_camera_vps = [forward_viewport, rear_viewport]
	var fps: float = config.get("monitor", {}).get("camera_fps", 15)
	if fps <= 0:
		fps = 15
	var interval := 1.0 / fps
	_camera_fps_timer = Timer.new()
	_camera_fps_timer.wait_time = interval
	_camera_fps_timer.autostart = true
	_camera_fps_timer.one_shot = false
	_camera_fps_timer.timeout.connect(_on_camera_fps_tick)
	add_child(_camera_fps_timer)
	for vp: SubViewport in _camera_vps:
		vp.render_target_update_mode = SubViewport.UPDATE_ONCE

func _on_camera_fps_tick() -> void:
	for vp: SubViewport in _camera_vps:
		vp.render_target_update_mode = SubViewport.UPDATE_ONCE

func _bind_viewport_textures() -> void:
	_bind_screen(left_screen, forward_viewport)
	_bind_screen(right_screen, rear_viewport)
	_bind_screen(main_screen, main_monitor_viewport)

func _bind_screen(screen: MeshInstance3D, vp: SubViewport) -> void:
	var mat := screen.material_override as StandardMaterial3D
	if mat == null:
		mat = StandardMaterial3D.new()
		screen.material_override = mat
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.emission_enabled = true
	mat.emission = Color(1, 1, 1, 1)
	var tex := vp.get_texture()
	mat.albedo_texture = tex
	mat.emission_texture = tex

func _apply_crt_to_cameras() -> void:
	var crt_shader_path := "res://assets/shaders/CRT.gdshader"
	if not ResourceLoader.exists(crt_shader_path):
		push_warning("CRT shader not found")
		return
	var shader := load(crt_shader_path) as Shader
	var crt_cfg: Dictionary = config.get("crt", {})

	for vp: SubViewport in _camera_vps:
		var overlay: ColorRect = _find_crt_overlay(vp)
		if overlay == null:
			continue
		var mat := ShaderMaterial.new()
		mat.shader = shader
		mat.set_shader_parameter("overlay", false)
		mat.set_shader_parameter("resolution", Vector2(vp.size))
		for key: String in crt_cfg:
			var value: Variant = crt_cfg[key]
			if value is float:
				mat.set_shader_parameter(key, value)
			elif value is bool:
				mat.set_shader_parameter(key, value)
		overlay.material = mat

func _find_crt_overlay(vp: SubViewport) -> ColorRect:
	for child: Node in vp.get_children():
		if child is ColorRect and child.name == "CRTOverlay":
			return child as ColorRect
	return null

func _on_screen_clicked(screen_name: String, uv: Vector2) -> void:
	var vp: SubViewport = null
	match screen_name:
		"MainScreenSlot":
			vp = main_monitor_viewport
		"LeftScreenSlot":
			vp = forward_viewport
		"RightScreenSlot":
			vp = rear_viewport
	if vp == null:
		return
	var pixel_pos := Vector2(uv.x * float(vp.size.x), uv.y * float(vp.size.y))
	var press := InputEventMouseButton.new()
	press.position = pixel_pos
	press.global_position = pixel_pos
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	vp.push_input(press)
	var release := press.duplicate()
	release.pressed = false
	vp.push_input(release)

func _on_channel_clicked(channel_id: String) -> void:
	if nav_system:
		nav_system.select_channel(channel_id)

func _on_node_changed(node_data: Dictionary) -> void:
	if _gravity_map and _gravity_map.has_method("update_display"):
		_gravity_map.update_display(node_data)
