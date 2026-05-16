extends Node3D

@onready var forward_viewport: SubViewport = $ForwardViewport
@onready var rear_viewport: SubViewport = $RearViewport
@onready var main_monitor_viewport: SubViewport = $MainMonitorViewport

@onready var main_screen: MeshInstance3D = $CockpitInterior/MainScreenSlot
@onready var left_screen: MeshInstance3D = $CockpitInterior/LeftScreenSlot
@onready var right_screen: MeshInstance3D = $CockpitInterior/RightScreenSlot
@onready var level4_left_vp: SubViewport = $Level4LeftViewport
@onready var level4_right_vp: SubViewport = $Level4RightViewport
@onready var level4_left_cam: Camera3D = $Level4LeftViewport/CamRig/LeftWingCam
@onready var level4_right_cam: Camera3D = $Level4RightViewport/CamRig/RightWingCam

@onready var forward_cam: Camera3D = $ForwardViewport/CamRig/ForwardCam
@onready var rear_cam: Camera3D = $RearViewport/CamRig/RearCam
@onready var player_cam: Camera3D = $PlayerCamera

@onready var nav_system: Node = $NavigationSystem
@onready var transition_player: Control = $HUD/TransitionPlayer
@onready var system_panel_viewport: SubViewport = $SystemPanelViewport
@onready var system_panel_slot: MeshInstance3D = $CockpitInterior/SystemPanelSlot
@onready var ship_resources: Node = $ShipResources
@onready var comm_viewport: SubViewport = $CommViewport
@onready var comm_screen_slot: MeshInstance3D = $CockpitInterior/CommScreenSlot
@onready var narrative_manager: Node = $NarrativeManager

var config: Dictionary = {}
var _camera_fps_timer: Timer
var _camera_vps: Array = []
var _mini_map: Control = null
var _system_panel: Control = null
var _input_locked: bool = false
var _crt_materials: Array = []
var _lens_materials: Array = []
var _lens_strength: float = 0.0
var _accretion_material: ShaderMaterial = null
var _blackhole_node: MeshInstance3D = null
var _selected_channel_id: String = ""
var _game_over: bool = false
var _storm_braked: bool = false
var _storm_accepting_brake: bool = false
var _storm_active: bool = false

var _console_panel: Node = null
var _active_drag: Node = null
var _last_mouse_pos: Vector2 = Vector2.ZERO

var _ship_physics: Node = null
var _fuel_valve_stop: int = 0

var _scanning: bool = false
var _scan_timer: float = 0.0
var _scan_signal_strength: float = 0.0
var _pre_scan_throttle: int = 0

var _tutorial_step: int = -1
var _tutorial_active: bool = false

var _maintenance_manager: Node = null
var _breaker_viewports: Array = []

var _cooling_stop: int = 0

var _audio_manager: Node = null
var _pause_menu: Control = null

var _sling_state: String = ""
var _sling_hud: Control = null
var _sling_progress: float = 0.0
var _sling_timer: float = 0.0
var _sling_duration: float = 8.0
var _sling_optimal_start: float = 0.4
var _sling_optimal_end: float = 0.6
var _sling_thrust_min: float = 0.5
var _sling_thrust_max: float = 0.8
var _sling_base_lens: float = 0.0

var level_mode: String = ""
var _level2_game: Node3D = null
var _level2_terminal: Control = null
var _level2_minimap: Control = null
var _level2_system_panel: Control = null
var _level2_game_vp: SubViewport = null
var _level2_comm_vp: SubViewport = null
var _level2_map_vp: SubViewport = null
var _level2_system_vp: SubViewport = null
var _level2_fps_timer: Timer = null

var _level3_game: Node3D = null
var _level3_comms: Control = null
var _level3_radar: Control = null
var _level3_game_vp: SubViewport = null
var _level3_comm_vp: SubViewport = null
var _level3_map_vp: SubViewport = null
var _level3_update_timer: Timer = null

var _level4_game: Node3D = null
var _level4_game_vp: SubViewport = null
var _level4_system_vp: SubViewport = null
var _level4_system_panel: Control = null
var _level4_comm_vp: SubViewport = null
var _level4_comm_panel: Control = null
var _level4_update_timer: Timer = null
var _wing_sync_logged: bool = false

var _run_tree: Node = null
var _run_upgrade: Node = null
var _run_hp: float = -1.0
var _run_score: int = 0
var _overlay_panel: Control = null
var _upgrade_select: Control = null
var _progress_panel: Control = null

func _ready() -> void:
	_load_config()
	if has_meta("level_mode"):
		level_mode = get_meta("level_mode")
	if level_mode == "spasim":
		_setup_level2()
		return
	if level_mode == "elite":
		_setup_level3()
		return
	if level_mode == "starfox":
		_setup_level4()
		return
	if level_mode == "spacewar":
		return
	_setup_viewports()
	_setup_cameras()
	_setup_camera_fps()
	_bind_viewport_textures()
	_apply_crt_to_cameras()
	_apply_lens_distortion()
	_setup_blackhole()
	_setup_environment()
	_setup_transition()
	_setup_resources()
	_setup_narrative()
	_setup_ship_physics()
	_setup_maintenance()
	_setup_audio()
	_setup_pause_menu()
	_connect_signals()
	_setup_view_arrows()
	_setup_focus_system()
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
	_mini_map = main_monitor_viewport.get_node("MiniMapPanel")
	if _mini_map:
		_mini_map.load_config(config)
		_mini_map.destination_reached.connect(_on_destination_reached)
		_mini_map.debris_collision.connect(_on_debris_collision)
	_system_panel = system_panel_viewport.get_node("SystemPanel")
	if nav_system:
		nav_system.node_changed.connect(_on_node_changed)
		nav_system.travel_started.connect(_on_travel_started)
		nav_system.special_event_requested.connect(_on_special_event)
		nav_system.bad_ending_requested.connect(_on_bad_ending)
	if transition_player:
		transition_player.transition_completed.connect(_on_transition_completed)
	if player_cam and not player_cam.object_clicked.is_connected(_on_object_clicked):
		player_cam.object_clicked.connect(_on_object_clicked)
	_setup_console_panel()

func _setup_ship_physics() -> void:
	var script := load("res://scripts/ship_physics.gd")
	if script == null:
		push_error("ship_physics.gd not found")
		return
	_ship_physics = Node.new()
	_ship_physics.name = "ShipPhysics"
	_ship_physics.set_script(script)
	add_child(_ship_physics)
	_ship_physics.load_config(config)
	_ship_physics.position_changed.connect(_on_ship_position_changed)

func _setup_maintenance() -> void:
	_breaker_viewports = [forward_viewport, rear_viewport, main_monitor_viewport, system_panel_viewport]
	var script := load("res://scripts/maintenance_manager.gd")
	if script == null:
		push_error("maintenance_manager.gd not found")
		return
	_maintenance_manager = Node.new()
	_maintenance_manager.name = "MaintenanceManager"
	_maintenance_manager.set_script(script)
	add_child(_maintenance_manager)
	await get_tree().process_frame
	if _maintenance_manager == null:
		return
	_maintenance_manager.load_config(config)
	_maintenance_manager.setup(ship_resources, _ship_physics)
	_maintenance_manager.breaker_tripped.connect(_on_breaker_tripped)
	_maintenance_manager.breaker_reset.connect(_on_breaker_reset)
	_maintenance_manager.o2_supply_started.connect(_on_o2_supply_started)
	_maintenance_manager.o2_supply_completed.connect(_on_o2_supply_completed)

func _setup_audio() -> void:
	_audio_manager = get_node_or_null("AudioManager")
	if _audio_manager == null:
		var script := load("res://scripts/audio_manager.gd")
		if script == null:
			return
		_audio_manager = Node.new()
		_audio_manager.name = "AudioManager"
		_audio_manager.set_script(script)
		add_child(_audio_manager)

func _setup_pause_menu() -> void:
	var hud: CanvasLayer = get_node_or_null("HUD")
	if hud == null:
		return
	var script := load("res://scripts/pause_menu.gd")
	if script == null:
		return
	_pause_menu = Control.new()
	_pause_menu.name = "PauseMenu"
	_pause_menu.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pause_menu.set_script(script)
	hud.add_child(_pause_menu)

func _setup_focus_system() -> void:
	if player_cam and player_cam.has_method("setup_focus_targets"):
		player_cam.setup_focus_targets(main_screen, left_screen, right_screen)

func _setup_console_panel() -> void:
	var scene := load("res://scenes/console-panel.tscn") as PackedScene
	if scene == null:
		return
	_console_panel = scene.instantiate()
	if _console_panel.has_method("set_external_root"):
		_console_panel.set_external_root(self)
	add_child(_console_panel)
	await get_tree().process_frame
	if _console_panel == null:
		return
	var controls: Dictionary = _console_panel.get_all_controls() if _console_panel.has_method("get_all_controls") else {}
	if _console_panel.has_signal("control_interacted"):
		_console_panel.control_interacted.connect(_on_control_interacted)
	if _console_panel.has_signal("control_toggled"):
		_console_panel.control_toggled.connect(_on_control_toggled)
	if _console_panel.has_signal("control_stop_changed"):
		_console_panel.control_stop_changed.connect(_on_control_stop_changed)
	for control_name: String in controls:
		var ctrl: Node = controls[control_name]
		if ctrl.has_signal("interacted"):
			ctrl.interacted.connect(_on_control_interacted.bind(control_name))
		if ctrl.has_signal("value_changed"):
			ctrl.value_changed.connect(_on_control_value_changed.bind(control_name))
		if ctrl.has_signal("toggled"):
			ctrl.toggled.connect(_on_control_toggled.bind(control_name))
		if ctrl.has_signal("stop_changed"):
			ctrl.stop_changed.connect(_on_control_stop_changed.bind(control_name))

func _setup_resources() -> void:
	if ship_resources and ship_resources.has_method("load_config"):
		ship_resources.load_config(config)
		ship_resources.resources_changed.connect(_on_resources_changed)
		ship_resources.resource_depleted.connect(_on_resource_depleted)

func _setup_view_arrows() -> void:
	var hud: CanvasLayer = get_node_or_null("HUD")
	if hud == null or player_cam == null:
		return
	var vp_size: Vector2 = get_viewport().get_visible_rect().size
	var btn_size := Vector2(48, 36)
	var margin := 8.0
	var alpha := 0.4
	var left_btn := Button.new()
	left_btn.text = "< Q"
	left_btn.position = Vector2(margin, vp_size.y * 0.5 - btn_size.y * 0.5)
	left_btn.size = btn_size
	left_btn.modulate.a = alpha
	left_btn.flat = true
	left_btn.pressed.connect(func(): player_cam.cycle_view(-1))
	hud.add_child(left_btn)
	var right_btn := Button.new()
	right_btn.text = "E >"
	right_btn.position = Vector2(vp_size.x - btn_size.x - margin, vp_size.y * 0.5 - btn_size.y * 0.5)
	right_btn.size = btn_size
	right_btn.modulate.a = alpha
	right_btn.flat = true
	right_btn.pressed.connect(func(): player_cam.cycle_view(1))
	hud.add_child(right_btn)

func _setup_narrative() -> void:
	var comm_panel: Control = comm_viewport.get_node_or_null("CommPanel")
	if comm_panel == null:
		comm_panel = comm_viewport.get_node_or_null("CommPanelRoot/CommPanel")
	if narrative_manager and narrative_manager.has_method("setup"):
		var nodes_data: Array = []
		if nav_system and nav_system.has_method("get_node_data"):
			for i in range(7):
				var nd: Dictionary = nav_system.get_node_data(i)
				if not nd.is_empty():
					nodes_data.append(nd)
		narrative_manager.setup(comm_panel, config, nodes_data)

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
	_bind_screen(system_panel_slot, system_panel_viewport)
	_bind_screen(comm_screen_slot, comm_viewport)

func _bind_screen(screen: MeshInstance3D, vp: SubViewport) -> void:
	var tex := vp.get_texture()
	var existing := screen.material_override
	if existing is ShaderMaterial:
		existing.set_shader_parameter("viewport_texture", tex)
		return
	var mat := existing as StandardMaterial3D
	if mat == null:
		mat = StandardMaterial3D.new()
		screen.material_override = mat
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.emission_enabled = true
	mat.emission = Color(1, 1, 1, 1)
	mat.albedo_texture = tex
	mat.emission_texture = tex

func apply_screen_shader(screen: MeshInstance3D, shader: Shader) -> void:
	var current_mat := screen.material_override
	var tex: Texture2D = null
	if current_mat is StandardMaterial3D:
		tex = current_mat.albedo_texture
	elif current_mat is ShaderMaterial:
		tex = current_mat.get_shader_parameter("viewport_texture")
	var mat := ShaderMaterial.new()
	mat.shader = shader
	if tex:
		mat.set_shader_parameter("viewport_texture", tex)
	screen.material_override = mat

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
		_crt_materials.append(mat)
		overlay.material = mat

func _apply_lens_distortion() -> void:
	var lens_shader_path := "res://assets/shaders/lens_distortion.gdshader"
	if not ResourceLoader.exists(lens_shader_path):
		push_warning("Lens distortion shader not found")
		return
	var shader := load(lens_shader_path) as Shader

	for vp: SubViewport in _camera_vps:
		var overlay: ColorRect = _find_lens_overlay(vp)
		if overlay == null:
			continue
		var mat := ShaderMaterial.new()
		mat.shader = shader
		mat.set_shader_parameter("strength", 0.0)
		mat.set_shader_parameter("time", 0.0)
		mat.set_shader_parameter("blackout", 0.0)
		_lens_materials.append(mat)
		overlay.material = mat

func _find_lens_overlay(vp: SubViewport) -> ColorRect:
	for child: Node in vp.get_children():
		if child is ColorRect and child.name == "LensDistortionOverlay":
			return child as ColorRect
	return null

func _setup_blackhole() -> void:
	var shader_path := "res://assets/shaders/accretion_disk.gdshader"
	if not ResourceLoader.exists(shader_path):
		push_warning("Accretion disk shader not found")
		return
	var shader := load(shader_path) as Shader
	_blackhole_node = get_node_or_null("SpaceEnvironment/BlackHolePlaceholder")
	if _blackhole_node == null:
		return
	var disk: MeshInstance3D = _blackhole_node.get_node_or_null("AccretionDisk")
	if disk == null:
		return
	_accretion_material = ShaderMaterial.new()
	_accretion_material.shader = shader
	_accretion_material.set_shader_parameter("inner_color", Vector3(1.0, 0.95, 0.7))
	_accretion_material.set_shader_parameter("outer_color", Vector3(1.0, 0.2, 0.02))
	_accretion_material.set_shader_parameter("inner_radius", 2.2)
	_accretion_material.set_shader_parameter("outer_radius", 4.0)
	_accretion_material.set_shader_parameter("intensity", 4.0)
	disk.material_override = _accretion_material

func _setup_environment() -> void:
	var we: WorldEnvironment = get_node_or_null("SpaceEnvironment/WorldEnvironment")
	if we == null:
		return
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.01, 0.01, 0.02)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.25, 0.25, 0.35)
	env.ambient_light_energy = 1.2
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	we.environment = env

func _process(delta: float) -> void:
	if not _lens_materials.is_empty():
		var t: float = Time.get_ticks_msec() / 1000.0
		for mat: ShaderMaterial in _lens_materials:
			mat.set_shader_parameter("time", t)

	if _active_drag:
		var current_pos: Vector2 = get_viewport().get_mouse_position()
		var drag_delta: Vector2 = current_pos - _last_mouse_pos
		_handle_control_drag(_active_drag, drag_delta)
		_last_mouse_pos = current_pos

	_update_ship_controls()
	_update_signal_display()

	if _scanning:
		_scan_timer -= delta
		if _scan_timer <= 0.0:
			_complete_scan()

	if _ship_physics and _ship_physics.has_method("get_fuel_drain"):
		var drain: float = _ship_physics.get_fuel_drain() * delta
		if drain > 0.0 and ship_resources and ship_resources.has_method("consume_fuel"):
			ship_resources.consume_fuel(drain)

	_update_slingshot(delta)

	if level4_left_cam or level4_right_cam:
		_sync_level4_wing_cameras()

func _update_ship_controls() -> void:
	if _ship_physics == null:
		return

	var nav_control: Node = _get_control("nav_knob")
	if nav_control:
		var val: float = nav_control.get_meta("drag_value", 0.5)
		var turn_val: float = clampf((val - 0.5) * 2.0, -1.0, 1.0)
		if absf(turn_val) < 0.05:
			turn_val = 0.0
		_ship_physics.set("turn_input", turn_val)
		_ship_physics.set("heading_locked", false)

	var fuel_control: Node = _get_control("fuel_valve")
	if fuel_control:
		_ship_physics.set("throttle_position", _fuel_valve_stop)

func _get_control(ctrl_name: String) -> Node:
	if _console_panel and _console_panel.has_method("get_control"):
		return _console_panel.get_control(ctrl_name)
	return null

func _scrub_anim(control: Node, value: float) -> void:
	control.set_meta("drag_value", value)
	var anim: AnimationPlayer = control.get_meta("anim_player") if control.has_meta("anim_player") else null
	if anim:
		var length: float = anim.get_animation("drag").length
		anim.seek(value * length, true)

func _update_signal_display() -> void:
	if _mini_map == null or not _mini_map.has_method("set_signal_display"):
		return
	var left_panel: Node = _get_control("left_panel")
	if left_panel == null:
		_mini_map.set_signal_display(false, 0.0)
		return
	var is_open: bool = left_panel.get_meta("is_open", false)
	if not is_open:
		if not _scanning:
			_mini_map.set_signal_display(false, 0.0)
		return
	var strength: float = _get_scan_signal_strength()
	_mini_map.set_signal_display(true, strength)

func _start_scan() -> void:
	if _scanning or _input_locked or _game_over:
		return
	var scan_cost: float = config.get("actions", {}).get("scan_fuel_cost", 8.0)
	if ship_resources and ship_resources.has_method("can_consume_fuel"):
		if not ship_resources.can_consume_fuel(scan_cost):
			return
		ship_resources.consume_fuel(scan_cost)

	_scanning = true
	_scan_signal_strength = _get_scan_signal_strength()
	if _scan_signal_strength < 0.3:
		_scanning = false
		_reset_scan_switch()
		return

	var scan_cfg: Dictionary = config.get("scan", {})
	if _scan_signal_strength > 0.7:
		_scan_timer = scan_cfg.get("scan_time_fast", 3.0)
	else:
		_scan_timer = scan_cfg.get("scan_time_slow", 5.0)

	_pre_scan_throttle = _fuel_valve_stop
	if _ship_physics:
		_ship_physics.driving_enabled = false

func _complete_scan() -> void:
	_scanning = false
	_scan_timer = 0.0

	if _mini_map and _mini_map.has_method("refresh_scan"):
		_mini_map.refresh_scan(_scan_signal_strength)

	if _ship_physics:
		_ship_physics.driving_enabled = true

	_reset_scan_switch()
	_check_wreck_scan()

func _reset_scan_switch() -> void:
	var scan_switch: Node = _get_control("scan_switch")
	if scan_switch == null:
		return
	scan_switch.set_meta("is_on", false)
	var lever: MeshInstance3D = scan_switch.get_meta("lever_mesh") if scan_switch.has_meta("lever_mesh") else null
	if lever:
		var tween := create_tween()
		tween.set_ease(Tween.EASE_IN_OUT)
		tween.tween_property(lever, "rotation_degrees:z", 30.0, 0.15)

func _check_wreck_scan() -> void:
	if nav_system == null:
		return
	var node_data: Dictionary = nav_system.get_current_node()
	var special: Dictionary = node_data.get("special_action", {})
	if special.is_empty() or special.get("type", "") != "wreck_scan":
		return
	if _scan_signal_strength < 0.5:
		return
	var wreck_freq: float = 0.8
	var knob_val: float = _get_scan_knob_value()
	if absf(knob_val - wreck_freq) > 0.15:
		return
	var fuel_cost: float = special.get("fuel_cost", 5)
	var o2_cost: float = special.get("oxygen_cost", 5)
	if ship_resources and ship_resources.has_method("can_consume"):
		if not ship_resources.can_consume({"fuel": fuel_cost, "oxygen": o2_cost}):
			return
		ship_resources.consume_fuel(fuel_cost)
		ship_resources.consume_oxygen(o2_cost)
	var reveal_text: String = special.get("reveal_text", "")
	if narrative_manager and narrative_manager.has_method("show_wreck_log"):
		narrative_manager.show_wreck_log(reveal_text)

func _get_scan_knob_value() -> float:
	var scan_freq_control: Node = _get_control("scan_freq")
	if scan_freq_control == null:
		return 0.0
	return scan_freq_control.get_meta("drag_value", 0.5)

func _find_crt_overlay(vp: SubViewport) -> ColorRect:
	for child: Node in vp.get_children():
		if child is ColorRect and child.name == "CRTOverlay":
			return child as ColorRect
	return null

func _on_ship_position_changed(pos: Vector2, heading: float, speed: float) -> void:
	if _mini_map and _mini_map.has_method("update_ship"):
		_mini_map.update_ship(pos, heading, speed)

func _on_destination_reached(channel_id: String) -> void:
	if _input_locked or _game_over:
		return
	if _tutorial_active:
		_tutorial_active = false
		_tutorial_step = -1
	_selected_channel_id = channel_id
	if nav_system:
		nav_system.select_channel(channel_id)

func _on_debris_collision(damage: float) -> void:
	if ship_resources and ship_resources.has_method("damage_hull"):
		ship_resources.damage_hull(damage)
	_audio_play("play_collision")

func _on_screen_clicked(screen_name: String, uv: Vector2) -> void:
	if _input_locked or _game_over:
		return
	var vp: SubViewport = null
	match screen_name:
		"MainScreenSlot":
			vp = main_monitor_viewport
		"LeftScreenSlot":
			vp = forward_viewport
		"RightScreenSlot":
			vp = rear_viewport
		"SystemPanelSlot":
			vp = system_panel_viewport
		"CommScreenSlot":
			vp = comm_viewport
	if vp == null:
		return
	_push_viewport_click(vp, uv)

func _push_viewport_click(vp: SubViewport, uv: Vector2) -> void:
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

func _input(event: InputEvent) -> void:
	if level_mode == "spasim":
		if event is InputEventKey:
			if player_cam and player_cam.get_focus_state() != 1:
				get_viewport().set_input_as_handled()
				return
			if _level2_terminal and _level2_terminal.has_method("handle_key_input"):
				_level2_terminal.handle_key_input(event)
			get_viewport().set_input_as_handled()
		return
	if level_mode == "spacewar":
		if event is InputEventKey:
			get_viewport().set_input_as_handled()
		return
	if level_mode == "elite":
		if event is InputEventKey:
			var kc: int = event.keycode if event.keycode != 0 else event.physical_keycode
			if kc == KEY_ENTER and _level3_comms and _level3_comms.has_method("handle_key_input"):
				_level3_comms.handle_key_input(event)
			elif kc == KEY_UP or kc == KEY_DOWN or kc == KEY_BACKSPACE:
				if _level3_comms and _level3_comms.has_method("handle_key_input"):
					_level3_comms.handle_key_input(event)
			else:
				if _level3_game and _level3_game.has_method("handle_input"):
					_level3_game.handle_input(event)
				var ch: String = ""
				if event.unicode >= 32 and event.unicode <= 126:
					ch = char(event.unicode)
				if not ch.is_empty() and _level3_comms and _level3_comms.has_method("handle_key_input"):
					_level3_comms.handle_key_input(event)
		get_viewport().set_input_as_handled()
		return
	if level_mode == "starfox":
		if event is InputEventKey:
			get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed:
		var key: int = event.keycode if event.keycode != 0 else event.physical_keycode
		if key == KEY_ESCAPE:
			if _pause_menu and not _pause_menu.visible:
				_pause_menu.show_menu()
				get_viewport().set_input_as_handled()
				return
			elif _pause_menu and _pause_menu.visible:
				return
	if _game_over and _sling_state == "":
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		if _active_drag:
			_snap_drag_end(_active_drag)
			_active_drag = null
			get_viewport().set_input_as_handled()
			return
	if event is InputEventKey and event.pressed:
		var key: int = event.keycode if event.keycode != 0 else event.physical_keycode
		if key == KEY_SPACE and _storm_accepting_brake:
			_storm_braked = true
			get_viewport().set_input_as_handled()
			return
		if _input_locked:
			return

func _snap_drag_end(control: Node) -> void:
	var ctrl_type: String = control.get_meta("type", "")
	if ctrl_type != "knob":
		return

	var ctrl_name: String = control.name
	var stops: int = control.get_meta("stops", 0)
	if stops == 0:
		return

	var stop_values: Array = []
	match ctrl_name:
		"FuelValve":
			stop_values = [0.0, 0.333, 0.667, 1.0]
		"CoolingKnob":
			stop_values = [0.0, 0.5, 1.0]
		_:
			return

	var current_val: float = control.get_meta("drag_value", 0.5)
	var best_idx: int = 0
	var best_dist: float = 999.0
	for i in range(stop_values.size()):
		var d: float = absf(current_val - stop_values[i])
		if d < best_dist:
			best_dist = d
			best_idx = i

	var target_val: float = stop_values[best_idx]
	var anim: AnimationPlayer = control.get_meta("anim_player") if control.has_meta("anim_player") else null
	if anim:
		var _length: float = anim.get_animation("drag").length
		var tween := create_tween()
		tween.set_ease(Tween.EASE_OUT)
		tween.set_trans(Tween.TRANS_BACK)
		tween.tween_method(func(v: float): _scrub_anim(control, v), current_val, target_val, 0.15)
	else:
		_scrub_anim(control, target_val)

	control.set_meta("current_stop", best_idx)

	match ctrl_name:
		"FuelValve":
			if best_idx != _fuel_valve_stop:
				_fuel_valve_stop = best_idx
				_on_control_stop_changed(best_idx, "fuel_valve")
		"CoolingKnob":
			_on_control_stop_changed(best_idx, "cooling")

func _on_channel_selected(channel_id: String) -> void:
	if _input_locked or _game_over:
		return
	_selected_channel_id = channel_id
	var _can_scan: bool = nav_system.can_scan() if nav_system else false
	var scan_cost: float = config.get("actions", {}).get("scan_fuel_cost", 8.0)
	if ship_resources and ship_resources.has_method("can_consume_fuel"):
		if not ship_resources.can_consume_fuel(scan_cost):
			_can_scan = false

func _get_scan_signal_strength() -> float:
	var knob_value: float = _get_scan_knob_value()

	var node_data: Dictionary = nav_system.get_current_node() if nav_system else {}
	var map_data: Dictionary = node_data.get("map_data", {})
	var target_freq: float = map_data.get("scan_frequency", 0.5)

	var freq_range: float = 0.5
	var strength: float = 1.0 - minf(absf(knob_value - target_freq) / freq_range, 1.0)
	return clampf(strength, 0.0, 1.0)

func _on_scan_completed(channel_id: String, _data: Dictionary) -> void:
	if nav_system:
		nav_system.mark_scanned(channel_id)
	if _system_panel:
		_system_panel.set_scan_complete()

func _on_node_changed(node_data: Dictionary) -> void:
	var map_data: Dictionary = node_data.get("map_data", {})
	if _mini_map and _mini_map.has_method("setup_node") and not map_data.is_empty():
		_mini_map.setup_node(map_data)
	if _ship_physics and _ship_physics.has_method("setup_for_node") and not map_data.is_empty():
		_ship_physics.setup_for_node(map_data)
	_selected_channel_id = ""
	var bh_scale: float = node_data.get("blackhole_scale", 1.0)
	var distortion := clampf((bh_scale - 1.0) / 3.0, 0.0, 1.0)
	_lens_strength = distortion
	for mat: ShaderMaterial in _lens_materials:
		mat.set_shader_parameter("strength", distortion)
	if _blackhole_node:
		var s := Vector3.ONE * bh_scale
		_blackhole_node.scale = s
	if narrative_manager and narrative_manager.has_method("show_intro"):
		narrative_manager.show_intro(node_data)
	var special: Dictionary = node_data.get("special_action", {})
	if not special.is_empty():
		_handle_special_action(node_data, special)
	if _ship_physics:
		var event_type: String = node_data.get("event_type", "")
		if event_type != "":
			_ship_physics.set_active(false)
	if node_data.get("id", -1) == 0:
		_start_tutorial()
	if _maintenance_manager and _maintenance_manager.has_method("set_active"):
		_maintenance_manager.set_active(true)
	if _maintenance_manager and _maintenance_manager.has_method("set_node_index"):
		_maintenance_manager.set_node_index(node_data.get("id", 0))

func _setup_transition() -> void:
	if transition_player:
		var trans_cfg: Dictionary = config.get("transition", {})
		transition_player.load_config(trans_cfg)

func _on_travel_started(_from_id: int, to_id: int) -> void:
	_input_locked = true
	if _ship_physics:
		_ship_physics.set_active(false)
	if _maintenance_manager and _maintenance_manager.has_method("set_active"):
		_maintenance_manager.set_active(false)
	_apply_channel_consequences()
	var flicker_dur: float = config.get("transition", {}).get("crt_flicker_duration", 0.5)
	_play_crt_flicker(flicker_dur)
	var target_data: Dictionary = nav_system.get_node_data(to_id)
	var zone_name: String = target_data.get("name", "")
	var subtitle: String = target_data.get("subtitle", "")
	transition_player.play_zone_transition(zone_name, subtitle, func():
		nav_system.complete_travel()
	)

func _on_transition_completed() -> void:
	if _storm_active:
		return
	_input_locked = false
	if _ship_physics:
		_ship_physics.set_active(true)
	if _maintenance_manager and _maintenance_manager.has_method("set_active"):
		_maintenance_manager.set_active(true)

func _play_crt_flicker(duration: float) -> void:
	var flick_count := 4
	var step := duration / float(flick_count * 2)
	for mat: ShaderMaterial in _crt_materials:
		var orig_noise: float = mat.get_shader_parameter("noise_opacity")
		var orig_static: float = mat.get_shader_parameter("static_noise_intensity")
		var tween := create_tween()
		for _i in range(flick_count):
			tween.tween_callback(func(): mat.set_shader_parameter("noise_opacity", 1.0))
			tween.tween_callback(func(): mat.set_shader_parameter("static_noise_intensity", 0.5))
			tween.tween_interval(step)
			tween.tween_callback(func(): mat.set_shader_parameter("noise_opacity", orig_noise))
			tween.tween_callback(func(): mat.set_shader_parameter("static_noise_intensity", orig_static))
			tween.tween_interval(step)

func _on_resources_changed(fuel: float, hull: float, oxygen: float, engine_temp: float) -> void:
	if _system_panel and _system_panel.has_method("update_resources"):
		_system_panel.update_resources(fuel, hull, oxygen)
	if _system_panel and _system_panel.has_method("update_engine_temp"):
		_system_panel.update_engine_temp(engine_temp)
	if oxygen < 40.0 and oxygen > 0.0:
		_audio_alarm("o2")
	if engine_temp > 70.0:
		_audio_alarm("temp")

func _on_resource_depleted(resource_type: String) -> void:
	if _game_over:
		return
	_game_over = true
	_input_locked = true
	if _ship_physics:
		_ship_physics.set_active(false)
	if _maintenance_manager and _maintenance_manager.has_method("set_active"):
		_maintenance_manager.set_active(false)
	push_warning("RESOURCE DEPLETED: %s — GAME OVER" % resource_type.to_upper())

func _apply_channel_consequences() -> void:
	if _selected_channel_id == "" or not nav_system:
		return
	var ch: Dictionary = nav_system.get_channel_by_id(_selected_channel_id)
	if ch.is_empty():
		return
	var consequences: Dictionary = ch.get("consequences", {})
	if consequences.is_empty():
		return
	if ship_resources and ship_resources.has_method("damage_hull"):
		var hull_dmg: float = consequences.get("hull_damage", 0.0)
		if hull_dmg > 0.0:
			ship_resources.damage_hull(hull_dmg)
	if ship_resources and ship_resources.has_method("consume_fuel"):
		var fuel_pen: float = consequences.get("fuel_penalty", 0.0)
		if fuel_pen > 0.0:
			ship_resources.consume_fuel(fuel_pen)

func _on_special_event(node_index: int, event_type: String) -> void:
	if _game_over:
		return
	var node_data: Dictionary = nav_system.get_node_data(node_index)
	match event_type:
		"storm":
			_handle_storm(node_data)
		"slingshot":
			_handle_slingshot_placeholder(node_data)

func _handle_storm(node_data: Dictionary) -> void:
	_input_locked = true
	_storm_active = true
	if _ship_physics:
		_ship_physics.set_active(false)
	if narrative_manager and narrative_manager.has_method("show_intro"):
		narrative_manager.show_intro(node_data)
	get_tree().create_timer(2.0).timeout.connect(_storm_begin)

func _storm_begin() -> void:
	var flicker_count: int = int(config.get("monitor", {}).get("storm_flicker_count", 3))
	var blackout_base: float = config.get("monitor", {}).get("storm_blackout_duration", 3.0)
	var window_base: float = config.get("monitor", {}).get("storm_window_duration", 1.5)
	var hit_damage: float = config.get("damage", {}).get("storm_hit_damage", 8.0)
	var min_wear: float = config.get("damage", {}).get("storm_min_wear", 3.0)
	_storm_braked = false
	transition_player.begin_sequence()
	for round_idx in range(flicker_count):
		var blackout_dur: float = maxf(blackout_base - round_idx * 0.5, 1.0)
		var window_dur: float = maxf(window_base - round_idx * 0.4, 0.5)
		var r: int = round_idx
		transition_player.seq_callback(func(): _play_crt_flicker(0.3))
		transition_player.seq_fade_to_black(0.2)
		transition_player.seq_show_text("引力场扰动中...", "")
		transition_player.seq_wait(blackout_dur)
		transition_player.seq_hide_text()
		transition_player.seq_fade_from_black(0.1)
		transition_player.seq_callback(func(): _storm_start_window())
		transition_player.seq_show_text("⚠ 碎片接近！", "按 SPACE 减速")
		transition_player.seq_wait(window_dur)
		transition_player.seq_callback(func(): _storm_end_window())
		transition_player.seq_hide_text()
		transition_player.seq_callback(func(): _storm_judge_round(r, hit_damage, min_wear))
		transition_player.seq_wait(0.5)
	transition_player.seq_fade_to_black(0.3)
	transition_player.seq_show_text("引力场趋稳", "继续前进...")
	transition_player.seq_wait(1.5)
	transition_player.seq_hide_text()
	transition_player.seq_fade_from_black(0.5)
	transition_player.seq_callback(_storm_finish)
	transition_player.end_sequence()

func _storm_start_window() -> void:
	_storm_braked = false
	_storm_accepting_brake = true
	_audio_alarm("storm")

func _storm_end_window() -> void:
	_storm_accepting_brake = false

func _storm_judge_round(_round_idx: int, hit_damage: float, min_wear: float) -> void:
	var wear_per_round: float = min_wear / maxf(float(int(config.get("monitor", {}).get("storm_flicker_count", 3))), 1.0)
	if _storm_braked:
		if ship_resources and ship_resources.has_method("damage_hull"):
			ship_resources.damage_hull(wear_per_round)
		var brake_fuel: float = config.get("actions", {}).get("brake_fuel_cost", 3.0)
		if ship_resources and ship_resources.has_method("consume_fuel"):
			ship_resources.consume_fuel(brake_fuel)
		if narrative_manager and narrative_manager.has_method("show_text"):
			narrative_manager.show_text("[SYS] ", "减速成功。轻微磨损。")
	else:
		if ship_resources and ship_resources.has_method("damage_hull"):
			ship_resources.damage_hull(hit_damage)
		if narrative_manager and narrative_manager.has_method("show_text"):
			narrative_manager.show_text("[SYS] ", "撞击！船体损伤 -%d%%" % int(hit_damage))
	_storm_braked = false

func _storm_finish() -> void:
	_storm_active = false
	_storm_accepting_brake = false
	_input_locked = false
	var node_data: Dictionary = nav_system.get_current_node()
	var auto_to: int = node_data.get("auto_advance_to", -1)
	if auto_to >= 0 and nav_system:
		get_tree().create_timer(0.5).timeout.connect(func():
			nav_system.force_advance_to(auto_to)
		)

func _handle_slingshot_placeholder(node_data: Dictionary) -> void:
	_input_locked = true
	_game_over = true
	if _ship_physics:
		_ship_physics.set_active(false)
	if _maintenance_manager and _maintenance_manager.has_method("set_active"):
		_maintenance_manager.set_active(false)

	var sling_cfg: Dictionary = config.get("slingshot", {})
	_sling_duration = sling_cfg.get("duration", 8.0)
	_sling_optimal_start = sling_cfg.get("optimal_zone_start", 0.4)
	_sling_optimal_end = sling_cfg.get("optimal_zone_end", 0.6)
	_sling_thrust_min = sling_cfg.get("optimal_thrust_min", 0.5)
	_sling_thrust_max = sling_cfg.get("optimal_thrust_max", 0.8)
	_sling_base_lens = _lens_strength

	if narrative_manager and narrative_manager.has_method("show_text"):
		narrative_manager.show_text("", node_data.get("narrative_intro", ""))
	transition_player.play_zone_transition("EVENT HORIZON", "弹弓窗口", func():
		_sling_state = "SETUP"
		_sling_check_readiness()
	)

func _sling_check_readiness() -> void:
	var nav_control: Node = _get_control("nav_knob")
	var nav_val: float = nav_control.get_meta("drag_value", 0.5) if nav_control else 0.5
	var hints: Array = []
	if _fuel_valve_stop != 3:
		hints.append("燃料阀门 → HIGH")
	if nav_val < 0.9:
		hints.append("方向盘 → 右满舵")
	var thrust_lever: Node = _get_control("thrust_lever")
	var thrust_val: float = thrust_lever.get_meta("value") if thrust_lever else 0.0
	if thrust_val < _sling_thrust_min or thrust_val > _sling_thrust_max:
		hints.append("推力拉杆 → %.1f-%.1f" % [_sling_thrust_min, _sling_thrust_max])
	if not hints.is_empty():
		if narrative_manager and narrative_manager.has_method("show_text"):
			narrative_manager.show_text("[SYS] ", "弹弓准备：" + " | ".join(hints))
		_sling_state = "SETUP"
		return
	_sling_enter_armed()

func _sling_enter_armed() -> void:
	_sling_state = "ARMED"
	if narrative_manager and narrative_manager.has_method("show_text"):
		narrative_manager.show_text("[SYS] ", "弹弓参数就绪。按点火启动。")

func _sling_start_timing() -> void:
	_sling_state = "TIMING"
	_sling_progress = 0.0
	_sling_timer = 0.0
	var hud: CanvasLayer = get_node_or_null("HUD")
	if hud:
		var sling_hud_script := load("res://scripts/slingshot_hud.gd")
		if sling_hud_script:
			var new_hud := Control.new()
			new_hud.set_script(sling_hud_script)
			hud.add_child(new_hud)
			_sling_hud = new_hud
			_sling_hud.start(_sling_duration, _sling_optimal_start, _sling_optimal_end)
	if player_cam and player_cam.has_method("shake"):
		player_cam.shake(0.02, _sling_duration + 1.0)
	if narrative_manager and narrative_manager.has_method("show_text"):
		narrative_manager.show_text("[SYS] ", "弹弓倒计时——在绿色区间按点火！")
	_audio_play("play_sling_beep")

func _update_slingshot(delta: float) -> void:
	if _sling_state == "SETUP":
		var thrust_lever: Node = _get_control("thrust_lever")
		var thrust_val: float = thrust_lever.get_meta("value") if thrust_lever else 0.0
		var nav_control: Node = _get_control("nav_knob")
		var nav_val: float = nav_control.get_meta("drag_value", 0.5) if nav_control else 0.5
		if _fuel_valve_stop == 3 and nav_val >= 0.9 and thrust_val >= _sling_thrust_min and thrust_val <= _sling_thrust_max:
			_sling_enter_armed()
		return

	if _sling_state != "TIMING":
		return

	_sling_timer += delta
	_sling_progress = clampf(_sling_timer / _sling_duration, 0.0, 1.0)

	if _sling_hud and _sling_hud.has_method("set_progress"):
		_sling_hud.set_progress(_sling_progress)

	var intensity: float = _sling_progress
	var target_lens: float = _sling_base_lens + intensity * 0.5
	for mat: ShaderMaterial in _lens_materials:
		mat.set_shader_parameter("strength", target_lens)
	for mat: ShaderMaterial in _crt_materials:
		mat.set_shader_parameter("noise_opacity", lerpf(0.3, 0.9, intensity))
		mat.set_shader_parameter("static_noise_intensity", lerpf(0.1, 0.5, intensity))

	if player_cam and player_cam.has_method("set_shake_intensity"):
		player_cam.set_shake_intensity(intensity * 0.08)

	if _sling_progress >= 1.0:
		_sling_judge()

func _sling_fire() -> void:
	if _sling_state == "ARMED":
		_sling_start_timing()
		return
	if _sling_state == "TIMING":
		_sling_judge()

func _sling_judge() -> void:
	_sling_state = "JUDGMENT"

	if _sling_hud and _sling_hud.has_method("stop"):
		_sling_hud.stop()
	if player_cam and player_cam.has_method("stop_shake"):
		player_cam.stop_shake()

	var thrust_lever: Node = _get_control("thrust_lever")
	var thrust_val: float = thrust_lever.get_meta("value") if thrust_lever else 0.0
	var timing: float = _sling_progress

	var ending: String = ""
	if thrust_val >= _sling_thrust_min and thrust_val <= _sling_thrust_max and timing >= _sling_optimal_start and timing <= _sling_optimal_end:
		ending = "escape"
	elif thrust_val < 0.3 or timing < 0.35:
		ending = "consumed"
	else:
		ending = "drift"

	for mat: ShaderMaterial in _lens_materials:
		mat.set_shader_parameter("strength", _sling_base_lens)
	for mat: ShaderMaterial in _crt_materials:
		mat.set_shader_parameter("noise_opacity", 0.3)
		mat.set_shader_parameter("static_noise_intensity", 0.1)

	transition_player.begin_sequence()
	transition_player.seq_fade_to_black(0.5)
	match ending:
		"escape":
			transition_player.seq_show_text("弹弓机动", "成功脱出")
		"drift":
			transition_player.seq_show_text("弹弓机动", "偏差——漂流")
		"consumed":
			transition_player.seq_show_text("弹弓机动", "失败——坠入")
	transition_player.seq_wait(2.0)
	transition_player.seq_hide_text()
	transition_player.seq_callback(func():
		if narrative_manager and narrative_manager.has_method("show_ending"):
			narrative_manager.show_ending(ending)
	)
	transition_player.seq_fade_from_black(0.5)
	transition_player.end_sequence()

func _on_bad_ending(ending_type: String) -> void:
	_input_locked = true
	_game_over = true
	if _ship_physics:
		_ship_physics.set_active(false)
	if narrative_manager and narrative_manager.has_method("show_ending"):
		narrative_manager.show_ending(ending_type)
	transition_player.play_zone_transition("ENDING", ending_type.to_upper(), func():
		pass
	)

func _handle_special_action(_node_data: Dictionary, special: Dictionary) -> void:
	var action_type: String = special.get("type", "")
	if action_type == "wreck_scan":
		if narrative_manager and narrative_manager.has_method("show_text"):
			narrative_manager.show_text("[SYS] ", "检测到残骸信号——航行记录仪仍在工作。扫描可获取前人航行数据。(燃料 -%d%%, 氧气 -%d%%)" % [int(special.get("fuel_cost", 5)), int(special.get("oxygen_cost", 5))])

func _on_object_clicked(collider: CollisionObject3D, _hit_pos: Vector3) -> void:
	var control_node: Node = _find_control_node(collider)
	if control_node:
		_handle_control_click(control_node)

func _on_breaker_tripped(breaker_index: int) -> void:
	if breaker_index < 0 or breaker_index >= _breaker_viewports.size():
		return
	var vp: SubViewport = _breaker_viewports[breaker_index]
	if vp:
		vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	if _system_panel and _system_panel.has_method("set_breaker_state"):
		_system_panel.set_breaker_state(breaker_index, true)
	if narrative_manager and narrative_manager.has_method("show_text"):
		narrative_manager.show_text("[SYS] ", "断路器 %d 跳闸！" % (breaker_index + 1))
	_audio_play("play_breaker_trip")

func _on_breaker_reset(breaker_index: int) -> void:
	if breaker_index < 0 or breaker_index >= _breaker_viewports.size():
		return
	var vp: SubViewport = _breaker_viewports[breaker_index]
	if vp:
		if vp == forward_viewport or vp == rear_viewport:
			vp.render_target_update_mode = SubViewport.UPDATE_ONCE
		else:
			vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	if _system_panel and _system_panel.has_method("set_breaker_state"):
		_system_panel.set_breaker_state(breaker_index, false)
	if narrative_manager and narrative_manager.has_method("show_text"):
		narrative_manager.show_text("[SYS] ", "断路器 %d 已复位。" % (breaker_index + 1))

func _on_o2_supply_started() -> void:
	if _system_panel and _system_panel.has_method("set_o2_supplying"):
		_system_panel.set_o2_supplying(true)
	if narrative_manager and narrative_manager.has_method("show_text"):
		narrative_manager.show_text("[SYS] ", "氧气补给中...")

func _on_o2_supply_completed() -> void:
	if _system_panel and _system_panel.has_method("set_o2_supplying"):
		_system_panel.set_o2_supplying(false)
	if narrative_manager and narrative_manager.has_method("show_text"):
		narrative_manager.show_text("[SYS] ", "氧气补给完成。")

func _find_control_node(collider: CollisionObject3D) -> Node:
	var current: Node = collider
	while current != null:
		if current.has_meta("type"):
			return current
		current = current.get_parent()
		if current == self or current == null:
			break
	return null

func _handle_control_click(control: Node) -> void:
	var ctrl_type: String = control.get_meta("type", "")
	if ctrl_type == "knob" or ctrl_type == "lever":
		_active_drag = control
		_last_mouse_pos = get_viewport().get_mouse_position()
	elif ctrl_type == "switch":
		if _console_panel and _console_panel.has_method("toggle_switch_by_node"):
			_console_panel.toggle_switch_by_node(control)
			_audio_play("play_switch_toggle")
	elif ctrl_type == "button":
		if _console_panel and _console_panel.has_method("press_button_by_node"):
			_console_panel.press_button_by_node(control)
			_audio_play("play_click")
	elif ctrl_type == "side_panel":
		var ctrl_name: String = control.name
		var reg_name: String = ""
		match ctrl_name:
			"LeftPanel":
				reg_name = "left_panel"
			"RightPanel":
				reg_name = "right_panel"
		if reg_name != "" and _console_panel and _console_panel.has_method("toggle_panel"):
			_console_panel.toggle_panel(reg_name)
			_audio_play("play_panel_toggle")

func _handle_control_drag(control: Node, delta: Vector2) -> void:
	var ctrl_type: String = control.get_meta("type", "")
	if ctrl_type == "knob":
		var val: float = control.get_meta("drag_value", 0.5)
		val += delta.x * 0.003
		val = clampf(val, 0.0, 1.0)
		_scrub_anim(control, val)
		if absf(delta.x) > 2.0:
			_audio_play("play_knob_turn")
	elif ctrl_type == "lever":
		var val: float = control.get_meta("drag_value", 0.0)
		val -= delta.y * 0.003
		val = clampf(val, 0.0, 1.0)
		_scrub_anim(control, val)
		control.set_meta("value", val)

func _do_thrust() -> void:
	if _input_locked or _game_over or _selected_channel_id == "":
		return
	var thrust_fuel: float = config.get("actions", {}).get("thrust_fuel_cost", 5.0)
	var thrust_o2: float = config.get("actions", {}).get("thrust_oxygen_cost", 3.0)
	if ship_resources and ship_resources.has_method("can_consume"):
		if not ship_resources.can_consume({"fuel": thrust_fuel, "oxygen": thrust_o2}):
			return
		ship_resources.consume_fuel(thrust_fuel)
		ship_resources.consume_oxygen(thrust_o2)
	if nav_system:
		nav_system.select_channel(_selected_channel_id)

func _on_control_interacted(control_name: String) -> void:
	if control_name == "ignition":
		if _storm_accepting_brake:
			_storm_braked = true
		elif _sling_state == "ARMED" or _sling_state == "TIMING":
			_sling_fire()
		else:
			_do_thrust()

func _on_control_value_changed(_new_value: float, _control_name: String) -> void:
	pass

func _on_control_toggled(is_on: bool, control_name: String) -> void:
	if control_name == "scan_switch" and is_on:
		_start_scan()
	elif control_name == "o2_valve":
		if _maintenance_manager and _maintenance_manager.has_method("start_o2_supply") and is_on:
			_maintenance_manager.start_o2_supply()
		elif _maintenance_manager and _maintenance_manager.has_method("stop_o2_supply") and not is_on:
			_maintenance_manager.stop_o2_supply()
	elif control_name.begins_with("breaker_"):
		var idx_str: String = control_name.substr(8)
		var idx: int = idx_str.to_int() - 1
		if _maintenance_manager and _maintenance_manager.has_method("reset_breaker") and not is_on:
			_maintenance_manager.reset_breaker(idx)

func _on_control_stop_changed(stop_index: int, control_name: String) -> void:
	if control_name == "cooling":
		_cooling_stop = stop_index
		if _maintenance_manager and _maintenance_manager.has_method("set_cooling_stop"):
			_maintenance_manager.set_cooling_stop(stop_index)
		if _system_panel and _system_panel.has_method("set_cooling_level"):
			_system_panel.set_cooling_level(stop_index)
	elif control_name == "fuel_valve":
		if _audio_manager and _audio_manager.has_method("engine_set_throttle"):
			_audio_manager.engine_set_throttle(stop_index)
	if _tutorial_active:
		_check_tutorial_progress()

func _start_tutorial() -> void:
	_tutorial_step = 0
	_tutorial_active = true
	_show_tutorial_step()

func _show_tutorial_step() -> void:
	var steps := [
		"[SYS] 导航系统已启动。查看主屏幕上的小地图。",
		"[SYS] 拖拽中央的导航旋钮来转向飞船。",
		"[SYS] 旋转燃料阀门控制飞船速度。试试 LOW 档。",
		"[SYS] 将飞船驶向绿色标记的目的地。",
	]
	if _tutorial_step < 0 or _tutorial_step >= steps.size():
		return
	if narrative_manager and narrative_manager.has_method("show_text"):
		narrative_manager.show_text("", steps[_tutorial_step])

func _check_tutorial_progress() -> void:
	if not _tutorial_active:
		return
	match _tutorial_step:
		0:
			_tutorial_step = 1
			_show_tutorial_step()
		1:
			var nav_control: Node = _get_control("nav_knob")
			if nav_control:
				var val: float = nav_control.get_meta("drag_value", 0.5)
				if absf(val - 0.5) > 0.1:
					_tutorial_step = 2
					_show_tutorial_step()
		2:
			if _fuel_valve_stop >= 1:
				_tutorial_step = 3
				_show_tutorial_step()
		3:
			pass

func _audio_play(method: String) -> void:
	if _audio_manager and _audio_manager.has_method(method):
		_audio_manager.call(method)

func _audio_alarm(type: String) -> void:
	if _audio_manager and _audio_manager.has_method("play_alarm"):
		_audio_manager.call("play_alarm", type)

func _setup_level2() -> void:
	_setup_audio()
	player_cam.current = true
	_setup_level2_game_viewport()
	_setup_level2_comm_viewport()
	_setup_level2_map_viewport()
	_setup_level2_system_viewport()
	_setup_level2_hint_viewport()
	_setup_level2_input()
	_setup_level2_update_timer()
	_init_level2_game_camera()
	_setup_focus_system()

func _init_level2_game_camera() -> void:
	if _level2_game == null:
		return
	var scene_cam: Camera3D = _level2_game.camera
	if scene_cam == null:
		return
	scene_cam.projection = Camera3D.PROJECTION_PERSPECTIVE
	scene_cam.fov = 90.0
	scene_cam.position = Vector3(0.0, 300.0, 300.0)
	scene_cam.rotation_degrees = Vector3(-45.0, 0.0, 0.0)
	scene_cam.cull_mask = 0b11111111
	scene_cam.current = true

func _setup_level2_game_viewport() -> void:
	_level2_game_vp = SubViewport.new()
	_level2_game_vp.name = "Level2GameViewport"
	_level2_game_vp.size = Vector2i(640, 480)
	_level2_game_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	_level2_game_vp.transparent_bg = false
	_level2_game_vp.own_world_3d = true
	add_child(_level2_game_vp)

	var level2_scene := load("res://scenes/levels/level-2-spasim.tscn") as PackedScene
	if level2_scene == null:
		push_error("Level 2 scene not found")
		return
	_level2_game = level2_scene.instantiate()
	_level2_game_vp.add_child(_level2_game)

	_bind_screen(main_screen, _level2_game_vp)

	_level2_game.terminal_output.connect(_on_level2_terminal_output)
	_level2_game.level_completed.connect(_on_level2_completed)
	_level2_game.level_failed.connect(_on_level2_failed)

func _setup_level2_comm_viewport() -> void:
	_level2_comm_vp = SubViewport.new()
	_level2_comm_vp.name = "Level2CommViewport"
	_level2_comm_vp.size = Vector2i(640, 140)
	_level2_comm_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	_level2_comm_vp.transparent_bg = false
	add_child(_level2_comm_vp)

	var comm_panel_scene := load("res://scenes/panels/level2-comm-panel.tscn") as PackedScene
	if comm_panel_scene == null:
		push_error("Level 2 comm panel scene not found")
		return
	_level2_terminal = comm_panel_scene.instantiate()
	_level2_comm_vp.add_child(_level2_terminal)
	_level2_terminal.command_submitted.connect(_on_level2_command)

	_bind_screen(comm_screen_slot, _level2_comm_vp)

func _setup_level2_map_viewport() -> void:
	_level2_map_vp = level4_left_vp
	_level2_map_vp.size = Vector2i(210, 300)
	_level2_map_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	_level2_map_vp.transparent_bg = false

	for child in _level2_map_vp.get_children():
		child.queue_free()

	var map_scene := load("res://scenes/panels/level2-left-panel.tscn") as PackedScene
	if map_scene:
		_level2_minimap = map_scene.instantiate()
		_level2_minimap.set_anchors_preset(Control.PRESET_FULL_RECT)
		_level2_minimap.offset_left = 0.0
		_level2_minimap.offset_right = 0.0
		_level2_minimap.offset_top = 0.0
		_level2_minimap.offset_bottom = 0.0
		_level2_minimap.grow_horizontal = Control.GROW_DIRECTION_BOTH
		_level2_minimap.grow_vertical = Control.GROW_DIRECTION_BOTH
		var map_script := load("res://scripts/panels/level2_minimap.gd") as Script
		_level2_minimap.set_script(map_script)
		_level2_map_vp.add_child(_level2_minimap)
	else:
		push_warning("Level 2 left panel scene not found")

	_bind_screen(left_screen, _level2_map_vp)

func _setup_level2_system_viewport() -> void:
	_level2_system_vp = SubViewport.new()
	_level2_system_vp.name = "Level2SystemViewport"
	_level2_system_vp.size = Vector2i(560, 120)
	_level2_system_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_level2_system_vp.transparent_bg = false
	add_child(_level2_system_vp)

	var sys_panel_scene := load("res://scenes/panels/level2-system-panel.tscn") as PackedScene
	if sys_panel_scene == null:
		push_error("Level 2 system panel scene not found")
		return
	_level2_system_panel = sys_panel_scene.instantiate()
	_level2_system_vp.add_child(_level2_system_panel)

	_bind_screen(system_panel_slot, _level2_system_vp)

func _setup_level2_input() -> void:
	set_process_input(true)

func _setup_level2_hint_viewport() -> void:
	var hint_vp: SubViewport = level4_right_vp
	hint_vp.size = Vector2i(210, 300)
	hint_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	hint_vp.transparent_bg = false

	for child in hint_vp.get_children():
		child.queue_free()

	var hint_scene := load("res://scenes/panels/level2-right-panel.tscn") as PackedScene
	if hint_scene:
		var hint_panel := hint_scene.instantiate()
		hint_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
		hint_panel.offset_left = 0.0
		hint_panel.offset_right = 0.0
		hint_panel.offset_top = 0.0
		hint_panel.offset_bottom = 0.0
		hint_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
		hint_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
		hint_vp.add_child(hint_panel)
	else:
		push_warning("Level 2 right panel scene not found")

	_bind_screen(right_screen, hint_vp)

func _setup_level2_update_timer() -> void:
	var target_fps: int = 10
	var spasim_cfg: Dictionary = config.get("spasim", {})
	if spasim_cfg.has("target_fps"):
		target_fps = int(spasim_cfg["target_fps"])
	_level2_fps_timer = Timer.new()
	_level2_fps_timer.wait_time = 1.0 / target_fps
	_level2_fps_timer.autostart = true
	_level2_fps_timer.one_shot = false
	_level2_fps_timer.timeout.connect(_on_level2_fps_tick)
	add_child(_level2_fps_timer)

func _on_level2_fps_tick() -> void:
	if _level2_game_vp:
		_level2_game_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	if _level2_comm_vp:
		_level2_comm_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	if _level2_map_vp:
		_level2_map_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	if _level2_game and _level2_minimap:
		var player_pos: Vector3 = _level2_game.get_player_position()
		var heading: float = _level2_game.heading
		var enemies: Array = _level2_game.get_enemies_for_map()
		var end_pos: Vector3 = _level2_game.get_end_point_position()
		_level2_minimap.update_data(player_pos, heading, enemies, end_pos)
	if _level2_game and _level2_system_panel:
		var status: Dictionary = _level2_game.get_status_data()
		_level2_system_panel.update_hp(
			status.get("hp", 0.0), status.get("hp_max", 100.0)
		)

func _on_level2_terminal_output(text: String) -> void:
	if _level2_terminal and _level2_terminal.has_method("print_line"):
		_level2_terminal.print_line(text)

func _on_level2_command(cmd: String) -> void:
	if _level2_game and _level2_game.has_method("execute_command"):
		_level2_game.execute_command(cmd)

func _on_level2_completed() -> void:
	if _level2_terminal:
		_level2_terminal.print_line("[color=green]=== LEVEL COMPLETE ===[/color]")
		_level2_terminal.print_line("Returning to title...")
		var tween := create_tween()
		tween.tween_callback(func(): get_tree().change_scene_to_file("res://scenes/title-screen.tscn")).set_delay(3.0)

func _on_level2_failed() -> void:
	if _level2_terminal:
		_level2_terminal.print_line("[color=red]=== GAME OVER ===[/color]")
		_level2_terminal.print_line("Returning to title...")
		var tween := create_tween()
		tween.tween_callback(func(): get_tree().change_scene_to_file("res://scenes/title-screen.tscn")).set_delay(3.0)

func _setup_level3() -> void:
	_setup_audio()
	player_cam.current = true
	_setup_level3_game_viewport()
	_setup_level3_comm_viewport()
	_setup_level3_map_viewport()
	_setup_level3_update_timer()
	_init_level3_game_camera()

func _setup_level3_game_viewport() -> void:
	_level3_game_vp = SubViewport.new()
	_level3_game_vp.name = "Level3GameViewport"
	_level3_game_vp.size = Vector2i(640, 480)
	_level3_game_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	_level3_game_vp.transparent_bg = false
	_level3_game_vp.own_world_3d = true
	add_child(_level3_game_vp)

	var level3_scene := load("res://scenes/levels/level-3-elite.tscn") as PackedScene
	if level3_scene == null:
		push_error("Level 3 scene not found")
		return
	_level3_game = level3_scene.instantiate()
	_level3_game_vp.add_child(_level3_game)

	_bind_screen(main_screen, _level3_game_vp)

	_level3_game.comm_output.connect(_on_level3_comm_output)
	_level3_game.level_completed.connect(_on_level3_completed)
	_level3_game.level_failed.connect(_on_level3_failed)
	_level3_game.sfx_requested.connect(_on_level3_sfx)

func _setup_level3_comm_viewport() -> void:
	_level3_comm_vp = SubViewport.new()
	_level3_comm_vp.name = "Level3CommViewport"
	_level3_comm_vp.size = Vector2i(480, 100)
	_level3_comm_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	_level3_comm_vp.transparent_bg = false
	add_child(_level3_comm_vp)

	var comms_script := load("res://scripts/panels/level3_comms.gd") as Script
	_level3_comms = Control.new()
	_level3_comms.name = "Level3Comms"
	_level3_comms.size = Vector2(480, 100)
	_level3_comms.set_script(comms_script)
	_level3_comm_vp.add_child(_level3_comms)
	_level3_comms.command_submitted.connect(_on_level3_command)

	_bind_screen(comm_screen_slot, _level3_comm_vp)

func _setup_level3_map_viewport() -> void:
	_level3_map_vp = level4_left_vp
	_level3_map_vp.size = Vector2i(210, 300)
	_level3_map_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	_level3_map_vp.transparent_bg = false

	for child in _level3_map_vp.get_children():
		child.queue_free()

	var radar_script := load("res://scripts/panels/level3_radar.gd") as Script
	_level3_radar = Control.new()
	_level3_radar.name = "Level3Radar"
	_level3_radar.size = Vector2(210, 300)
	_level3_radar.set_script(radar_script)
	_level3_map_vp.add_child(_level3_radar)

	_bind_screen(left_screen, _level3_map_vp)

func _init_level3_game_camera() -> void:
	if _level3_game == null:
		return
	var scene_cam: Camera3D = _level3_game.camera
	if scene_cam == null:
		return
	scene_cam.cull_mask = 0b11111111
	scene_cam.current = true

func _setup_level3_update_timer() -> void:
	var target_fps: int = 20
	var elite_cfg: Dictionary = config.get("elite", {})
	if elite_cfg.has("target_fps"):
		target_fps = int(elite_cfg["target_fps"])
	_level3_update_timer = Timer.new()
	_level3_update_timer.wait_time = 1.0 / target_fps
	_level3_update_timer.autostart = true
	_level3_update_timer.one_shot = false
	_level3_update_timer.timeout.connect(_on_level3_update_tick)
	add_child(_level3_update_timer)

func _on_level3_update_tick() -> void:
	if _level3_game_vp:
		_level3_game_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	if _level3_comm_vp:
		_level3_comm_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	if _level3_map_vp:
		_level3_map_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	if _level3_game and _level3_radar:
		var player_pos: Vector3 = _level3_game.get_player_position()
		var heading: float = _level3_game.get_player_heading()
		var enemies: Array = _level3_game.get_enemies_for_radar()
		var stations: Array = _level3_game.get_stations_for_radar()
		var exit_pos: Vector3 = _level3_game.get_exit_position()
		_level3_radar.update_data(player_pos, heading, enemies, stations, exit_pos)
	if _level3_game and _level3_comms:
		var status: Dictionary = _level3_game.get_status_data()
		_level3_comms.update_status(status)

func _on_level3_comm_output(text: String) -> void:
	if _level3_comms and _level3_comms.has_method("print_line"):
		_level3_comms.print_line(text)

func _on_level3_command(cmd: String) -> void:
	if _level3_game and _level3_game.has_method("execute_trade_command"):
		_level3_game.execute_trade_command(cmd)

func _on_level3_completed() -> void:
	if _level3_comms:
		_level3_comms.print_line("[color=green]=== LEVEL COMPLETE ===[/color]")
		_level3_comms.print_line("Returning to title...")
		var tween := create_tween()
		tween.tween_callback(func(): get_tree().change_scene_to_file("res://scenes/title-screen.tscn")).set_delay(3.0)

func _on_level3_failed() -> void:
	if _level3_comms:
		_level3_comms.print_line("[color=red]=== SHIP DESTROYED ===[/color]")
		_level3_comms.print_line("Returning to title...")
		var tween := create_tween()
		tween.tween_callback(func(): get_tree().change_scene_to_file("res://scenes/title-screen.tscn")).set_delay(3.0)

func _on_level3_sfx(_sfx_name: String) -> void:
	pass

func _setup_level4() -> void:
	_setup_audio()
	player_cam.current = true
	_run_tree = Node.new()
	_run_tree.name = "LevelTreeManager"
	_run_tree.set_script(load("res://scripts/levels/level_tree_manager.gd"))
	add_child(_run_tree)
	var tree_cfg: Dictionary = config.get("level_tree", {})
	_run_tree.load_tree(tree_cfg)
	_run_upgrade = Node.new()
	_run_upgrade.name = "UpgradeSystem"
	_run_upgrade.set_script(load("res://scripts/levels/upgrade_system.gd"))
	add_child(_run_upgrade)
	var pool: Array = config.get("upgrade_pool", [])
	var excl: Dictionary = config.get("upgrade_exclusions", {})
	_run_upgrade.load_pool(pool, excl)
	_setup_level4_game_viewport()
	_setup_level4_wing_viewports()
	_setup_level4_system_viewport()
	_setup_level4_comm_viewport()
	_setup_level4_update_timer()
	_setup_level4_overlay()
	_start_level4_node()

func _setup_level4_game_viewport() -> void:
	_level4_game_vp = SubViewport.new()
	_level4_game_vp.name = "Level4GameViewport"
	_level4_game_vp.size = Vector2i(640, 480)
	_level4_game_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_level4_game_vp.transparent_bg = false
	_level4_game_vp.own_world_3d = true
	add_child(_level4_game_vp)

	var level4_scene := load("res://scenes/levels/level-4-starfox.tscn") as PackedScene
	if level4_scene == null:
		push_error("Level 4 scene not found")
		return
	_level4_game = level4_scene.instantiate()
	_level4_game.upgrade_system = _run_upgrade
	_level4_game.run_hp = _run_hp
	_level4_game_vp.add_child(_level4_game)

	_bind_screen(main_screen, _level4_game_vp)

	_level4_game.level_completed.connect(_on_level4_completed)
	_level4_game.level_failed.connect(_on_level4_failed)
	_level4_game.sfx_requested.connect(_on_level4_sfx)
	_level4_game.outro_started.connect(_on_level4_outro_started)

func _setup_level4_wing_viewports() -> void:
	if _level4_game_vp == null:
		return
	remove_child(level4_left_vp)
	_level4_game_vp.add_child(level4_left_vp)
	level4_left_vp.own_world_3d = false
	level4_left_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	level4_left_vp.transparent_bg = false
	level4_left_cam.current = true
	level4_left_cam.fov = 45.0

	remove_child(level4_right_vp)
	_level4_game_vp.add_child(level4_right_vp)
	level4_right_vp.own_world_3d = false
	level4_right_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	level4_right_vp.transparent_bg = false
	level4_right_cam.current = true
	level4_right_cam.fov = 45.0

	_bind_screen(left_screen, level4_left_vp)
	_bind_screen(right_screen, level4_right_vp)
	print("[Level4Wing] Reparented wing vps into game_vp. left_own=" + str(level4_left_vp.own_world_3d) + " right_own=" + str(level4_right_vp.own_world_3d))

func _setup_level4_system_viewport() -> void:
	_level4_system_vp = SubViewport.new()
	_level4_system_vp.name = "Level4SystemViewport"
	_level4_system_vp.size = Vector2i(560, 120)
	_level4_system_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_level4_system_vp.transparent_bg = false
	add_child(_level4_system_vp)

	_level4_system_panel = Control.new()
	_level4_system_panel.name = "Level4HUD"
	_level4_system_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_level4_system_vp.add_child(_level4_system_panel)

	_bind_screen(system_panel_slot, _level4_system_vp)

func _setup_level4_comm_viewport() -> void:
	_level4_comm_vp = SubViewport.new()
	_level4_comm_vp.name = "Level4CommViewport"
	_level4_comm_vp.size = Vector2i(700, 400)
	_level4_comm_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_level4_comm_vp.transparent_bg = false
	add_child(_level4_comm_vp)

	var comm_scene := load("res://scenes/panels/level4-comm-panel.tscn") as PackedScene
	if comm_scene == null:
		return
	_level4_comm_panel = comm_scene.instantiate()
	_level4_comm_vp.add_child(_level4_comm_panel)
	_level4_comm_panel.setup(_level4_comm_vp.size)

	_bind_screen(comm_screen_slot, _level4_comm_vp)

func _setup_level4_update_timer() -> void:
	var target_fps: int = 30
	var starfox_cfg: Dictionary = config.get("starfox", {})
	if starfox_cfg.has("target_fps"):
		target_fps = int(starfox_cfg["target_fps"])
	_level4_update_timer = Timer.new()
	_level4_update_timer.wait_time = 1.0 / target_fps
	_level4_update_timer.autostart = true
	_level4_update_timer.one_shot = false
	_level4_update_timer.timeout.connect(_on_level4_update_tick)
	add_child(_level4_update_timer)

func _on_level4_update_tick() -> void:
	if _level4_game_vp:
		_level4_game_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	if _level4_game:
		var status: Dictionary = _level4_game.get_status_data()
		if _level4_system_vp and _level4_system_panel:
			_draw_level4_hud(status)
		if _level4_comm_panel and _level4_comm_panel.has_method("update_status"):
			_level4_comm_panel.update_status(status)
		if player_cam and player_cam.has_method("set_aim_offset"):
			player_cam.set_aim_offset(float(status.get("aim_x", 0.0)), float(status.get("aim_y", 0.0)))

func _sync_level4_wing_cameras() -> void:
	if _level4_game == null:
		return
	var cam_rig := _level4_game.get_node_or_null("TrackPath/PathFollow3D/CameraRig") as Node3D
	if cam_rig == null:
		return
	var shake := cam_rig.get_node_or_null("ShakeContainer") as Node3D
	if shake == null:
		return
	var src_left := shake.get_node_or_null("LeftCamera") as Camera3D
	var src_right := shake.get_node_or_null("RightCamera") as Camera3D
	var rig_xform := cam_rig.global_transform
	if src_left and level4_left_cam:
		level4_left_cam.global_transform = rig_xform * Transform3D(Basis.from_euler(src_left.rotation), src_left.position)
	if src_right and level4_right_cam:
		level4_right_cam.global_transform = rig_xform * Transform3D(Basis.from_euler(src_right.rotation), src_right.position)
	if not _wing_sync_logged:
		_wing_sync_logged = true
		print("[Level4Wing] sync OK (no-shake) - rig=" + str(cam_rig != null))

func _draw_level4_hud(status: Dictionary) -> void:
	_level4_system_panel.queue_redraw()

func _setup_level4_overlay() -> void:
	var hud: CanvasLayer = get_node_or_null("HUD")
	if hud == null:
		return
	_overlay_panel = Control.new()
	_overlay_panel.name = "Level4Overlay"
	_overlay_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(_overlay_panel)
	var upgrade_scene := load("res://scenes/panels/upgrade-select.tscn") as PackedScene
	if upgrade_scene:
		_upgrade_select = upgrade_scene.instantiate()
		_upgrade_select.set_anchors_preset(Control.PRESET_FULL_RECT)
		_overlay_panel.add_child(_upgrade_select)
		_upgrade_select.upgrade_selected.connect(_on_upgrade_chosen)
	var progress_scene := load("res://scenes/panels/ProgressPanel.tscn") as PackedScene
	if progress_scene:
		_progress_panel = progress_scene.instantiate()
		_progress_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
		_overlay_panel.add_child(_progress_panel)
		_progress_panel.continue_requested.connect(_on_progress_continue)

func _start_level4_node() -> void:
	if _run_tree == null:
		return
	if _run_tree.get_current_id().is_empty():
		_run_tree.start_run()
	var node_data: Dictionary = _run_tree.get_current_node()
	if node_data.is_empty():
		return
	_run_hp = _run_hp if _run_hp >= 0.0 else float(config.get("starfox", {}).get("hp_max", 100.0))
	if _level4_game:
		_level4_game.queue_free()
		_level4_game = null
	var level4_scene := load("res://scenes/levels/level-4-starfox.tscn") as PackedScene
	if level4_scene == null:
		return
	_level4_game = level4_scene.instantiate()
	_level4_game.upgrade_system = _run_upgrade
	_level4_game.run_hp = _run_hp
	_level4_game.node_environment = node_data.get("environment", "")
	_level4_game_vp.add_child(_level4_game)
	_level4_game.level_completed.connect(_on_level4_completed)
	_level4_game.level_failed.connect(_on_level4_failed)
	_level4_game.sfx_requested.connect(_on_level4_sfx)
	_level4_game.outro_started.connect(_on_level4_outro_started)
	_level4_game.hit_received.connect(_on_level4_hit)
	if player_cam and player_cam.has_method("set_flight_vibration"):
		player_cam.set_flight_vibration(true)
	_wing_sync_logged = false

func _on_level4_outro_started() -> void:
	if player_cam and player_cam.has_method("set_flight_vibration"):
		player_cam.set_flight_vibration(false)

func _on_level4_completed() -> void:
	if _level4_game:
		_run_hp = _level4_game.hp
		_run_score = _level4_game.score
	var heal_ratio: float = _run_tree.get_heal_ratio()
	heal_ratio = _run_upgrade.get_stat(heal_ratio, "heal_ratio") if _run_upgrade else heal_ratio
	var hp_max: float = float(config.get("starfox", {}).get("hp_max", 100.0))
	hp_max = _run_upgrade.get_stat(hp_max, "hp_max") if _run_upgrade else hp_max
	_run_hp = minf(_run_hp + hp_max * heal_ratio, hp_max)
	if _run_tree and _run_tree.is_current_last():
		if _progress_panel:
			_progress_panel.show_progress(_run_tree.get_current_index(), _run_tree.get_total_nodes())
			_progress_panel.continue_requested.disconnect(_on_progress_continue)
			_progress_panel.continue_requested.connect(_on_run_complete)
		return
	if _upgrade_select and _run_upgrade:
		var offers = _run_upgrade.get_random_offers(3)
		if offers.size() > 0:
			_upgrade_select.show_offers(offers)
			return
	_advance_to_next_level()

func _on_upgrade_chosen(upgrade_id: String) -> void:
	if _run_upgrade:
		_run_upgrade.apply_upgrade(upgrade_id)
	_show_progress_panel()

func _show_progress_panel() -> void:
	if _progress_panel and _run_tree:
		_progress_panel.show_progress(_run_tree.get_current_index(), _run_tree.get_total_nodes())
	else:
		_advance_to_next_level()

func _on_progress_continue() -> void:
	_advance_to_next_level()

func _on_run_complete() -> void:
	if _run_upgrade:
		_run_upgrade.reset()
	if _progress_panel and _progress_panel.continue_requested.is_connected(_on_run_complete):
		_progress_panel.continue_requested.disconnect(_on_run_complete)
		_progress_panel.continue_requested.connect(_on_progress_continue)
	get_tree().change_scene_to_file("res://scenes/title-screen.tscn")

func _advance_to_next_level() -> void:
	if _run_tree == null:
		return
	_run_tree.advance()
	_start_level4_node()

func _on_level4_failed() -> void:
	if player_cam and player_cam.has_method("set_flight_vibration"):
		player_cam.set_flight_vibration(false)
	var tween := create_tween()
	tween.tween_callback(func(): get_tree().change_scene_to_file("res://scenes/title-screen.tscn")).set_delay(3.0)

func _on_level4_sfx(sfx_name: String) -> void:
	if _audio_manager == null:
		return
	match sfx_name:
		"player_fire": _audio_manager.play_player_fire()
		"enemy_fire": _audio_manager.play_enemy_fire()
		"explosion": _audio_manager.play_explosion()
		"explosion_boss": _audio_manager.play_explosion_boss()
		"player_hit": _audio_manager.play_player_hit()
		"player_death": _audio_manager.play_player_death()
		"barrel_roll": _audio_manager.play_barrel_roll()
		"missile_fire": _audio_manager.play_missile_fire()
		"laser_hum": _audio_manager.play_laser_hum()
		"laser_overheat": _audio_manager.play_laser_overheat()
		"turret_fire": _audio_manager.play_turret_fire()
		"level_complete": _audio_manager.play_level_complete()
		"level_failed": _audio_manager.play_level_failed()
		"upgrade_select": _audio_manager.play_upgrade_select()

func _on_level4_hit(amount: float) -> void:
	if player_cam and player_cam.has_method("shake"):
		player_cam.shake(minf(amount * 0.01, 0.15), 0.3)
