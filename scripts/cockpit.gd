extends Node3D

enum MonitorMode { GRAVITY_MAP, FORWARD_CAM, SCAN_RESULT }

@onready var forward_viewport: SubViewport = $ForwardViewport
@onready var rear_viewport: SubViewport = $RearViewport
@onready var main_monitor_viewport: SubViewport = $MainMonitorViewport

@onready var main_screen: MeshInstance3D = $CockpitInterior/MainScreenSlot
@onready var left_screen: MeshInstance3D = $CockpitInterior/LeftScreenSlot
@onready var right_screen: MeshInstance3D = $CockpitInterior/RightScreenSlot

@onready var forward_cam: Camera3D = $ForwardViewport/CamRig/ForwardCam
@onready var rear_cam: Camera3D = $RearViewport/CamRig/RearCam
@onready var player_cam: Camera3D = $PlayerCamera

@onready var monitor_label: Label = $HUD/MonitorSwitchLabel

var config: Dictionary = {}
var current_mode: MonitorMode = MonitorMode.GRAVITY_MAP
var _camera_fps_timer: Timer
var _camera_vps: Array = []

func _ready() -> void:
	_load_config()
	_setup_viewports()
	_setup_cameras()
	_setup_camera_fps()
	_bind_viewport_textures()
	_apply_crt_to_cameras()
	_update_monitor_label()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("monitor_gravity"):
		current_mode = MonitorMode.GRAVITY_MAP
		_update_monitor_label()
	elif event.is_action_pressed("monitor_forward"):
		current_mode = MonitorMode.FORWARD_CAM
		_update_monitor_label()
	elif event.is_action_pressed("monitor_scan"):
		current_mode = MonitorMode.SCAN_RESULT
		_update_monitor_label()

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

	var test_mesh: MeshInstance3D = $TestViewportMesh
	if test_mesh:
		_bind_screen(test_mesh, $TestViewport)

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
	print("[cockpit] ", screen.name, " bound: tex_size=", tex.get_size())

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
		print("[cockpit] CRT applied to ", vp.name)

func _find_crt_overlay(vp: SubViewport) -> ColorRect:
	for child: Node in vp.get_children():
		if child is ColorRect and child.name == "CRTOverlay":
			return child as ColorRect
	return null

func _update_monitor_label() -> void:
	if monitor_label == null:
		return
	match current_mode:
		MonitorMode.GRAVITY_MAP:
			monitor_label.text = "主监视器: 引力场图 [1]"
		MonitorMode.FORWARD_CAM:
			monitor_label.text = "主监视器: 前方实况 [2]"
		MonitorMode.SCAN_RESULT:
			monitor_label.text = "主监视器: 扫描结果 [3]"
