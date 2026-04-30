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
var _nav_knob_stop: int = 0
var _fuel_valve_stop: int = 0
var _nav_stop_angles := [-60.0, 0.0, 60.0]
var _fuel_stop_angles := [-90.0, -30.0, 30.0, 90.0]

var _scanning: bool = false
var _scan_timer: float = 0.0
var _scan_signal_strength: float = 0.0
var _pre_scan_throttle: int = 0

var _tutorial_step: int = -1
var _tutorial_active: bool = false

var _maintenance_manager: Node = null
var _breaker_viewports: Array = []

var _cooling_stop: int = 0

var _view_arrows: Dictionary = {}

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

func _ready() -> void:
	_load_config()
	_setup_viewports()
	_setup_cameras()
	_setup_camera_fps()
	_bind_viewport_textures()
	_apply_crt_to_cameras()
	_apply_lens_distortion()
	_setup_blackhole()
	_setup_transition()
	_setup_resources()
	_setup_narrative()
	_setup_ship_physics()
	_setup_maintenance()
	_setup_audio()
	_setup_pause_menu()
	_connect_signals()
	_setup_view_arrows()
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
	if _system_panel:
		if _system_panel.scan_requested.is_connected(_on_scan_requested):
			_system_panel.scan_requested.disconnect(_on_scan_requested)
		if _system_panel.thrust_requested.is_connected(_on_thrust_requested):
			_system_panel.thrust_requested.disconnect(_on_thrust_requested)
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
	_pause_menu.set_script(script)
	hud.add_child(_pause_menu)

func _setup_console_panel() -> void:
	var scene := load("res://scenes/console-panel.tscn") as PackedScene
	if scene == null:
		return
	_console_panel = scene.instantiate()
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

func _update_ship_controls() -> void:
	if _ship_physics == null:
		return

	var nav_control: Node = _get_control("nav_knob")
	if nav_control:
		var mesh_inst: MeshInstance3D = nav_control.get_meta("knob_mesh") if nav_control.has_meta("knob_mesh") else null
		if mesh_inst and _nav_knob_stop == 0:
			var angle: float = mesh_inst.rotation_degrees.z
			var turn_val: float = clampf(angle / 90.0, -1.0, 1.0)
			if absf(turn_val) < 0.05:
				turn_val = 0.0
			_ship_physics.set("turn_input", turn_val)
			_ship_physics.set("heading_locked", _nav_knob_stop != 0)

	var fuel_control: Node = _get_control("fuel_valve")
	if fuel_control:
		_ship_physics.set("throttle_position", _fuel_valve_stop)

func _get_control(ctrl_name: String) -> Node:
	if _console_panel and _console_panel.has_method("get_control"):
		return _console_panel.get_control(ctrl_name)
	return null

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
	var mesh_inst: MeshInstance3D = scan_freq_control.get_meta("knob_mesh") if scan_freq_control.has_meta("knob_mesh") else null
	if mesh_inst == null:
		return 0.0
	var rot: float = mesh_inst.rotation_degrees.z
	return clampf((rot + 150.0) / 300.0, 0.0, 1.0)

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

	var mesh_inst: MeshInstance3D = control.get_meta("knob_mesh") if control.has_meta("knob_mesh") else null
	if mesh_inst == null:
		return

	var ctrl_name: String = control.name
	var stops: int = control.get_meta("stops", 0)
	if stops == 0:
		return

	var stop_angles: Array = []
	match ctrl_name:
		"NavKnob":
			stop_angles = _nav_stop_angles
		"FuelValve":
			stop_angles = _fuel_stop_angles
		"CoolingKnob":
			stop_angles = [-60.0, 0.0, 60.0]
		_:
			return

	var current_angle: float = mesh_inst.rotation_degrees.z
	var best_idx: int = 0
	var best_dist: float = 999.0
	for i in range(stop_angles.size()):
		var d: float = absf(current_angle - stop_angles[i])
		if d < best_dist:
			best_dist = d
			best_idx = i

	var target_angle: float = stop_angles[best_idx]
	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)
	tween.tween_property(mesh_inst, "rotation_degrees:z", target_angle, 0.15)

	control.set_meta("current_stop", best_idx)

	match ctrl_name:
		"NavKnob":
			if best_idx != _nav_knob_stop:
				_nav_knob_stop = best_idx
				_on_control_stop_changed(best_idx, "nav_knob")
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
	var can_scan: bool = nav_system.can_scan() if nav_system else false
	var scan_cost: float = config.get("actions", {}).get("scan_fuel_cost", 8.0)
	if ship_resources and ship_resources.has_method("can_consume_fuel"):
		if not ship_resources.can_consume_fuel(scan_cost):
			can_scan = false
	if _system_panel:
		_system_panel.set_selected_channel(channel_id, can_scan)

func _on_scan_requested() -> void:
	_start_scan()

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

func _on_thrust_requested() -> void:
	if _input_locked or _game_over or _selected_channel_id == "":
		return
	var thrust_fuel: float = config.get("actions", {}).get("thrust_fuel_cost", 5.0)
	var thrust_o2: float = config.get("actions", {}).get("thrust_oxygen_cost", 3.0)
	if ship_resources and ship_resources.has_method("can_consume"):
		if not ship_resources.can_consume({"fuel": thrust_fuel, "oxygen": thrust_o2}):
			return
		ship_resources.consume_fuel(thrust_fuel)
		ship_resources.consume_oxygen(thrust_o2)
	if _system_panel:
		_system_panel.lock_buttons()
	if nav_system:
		nav_system.select_channel(_selected_channel_id)

func _on_node_changed(node_data: Dictionary) -> void:
	var map_data: Dictionary = node_data.get("map_data", {})
	if _mini_map and _mini_map.has_method("setup_node") and not map_data.is_empty():
		_mini_map.setup_node(map_data)
	if _ship_physics and _ship_physics.has_method("setup_for_node") and not map_data.is_empty():
		_ship_physics.setup_for_node(map_data)
	_selected_channel_id = ""
	if _system_panel:
		_system_panel.set_selected_channel("", false)
		_system_panel.unlock_buttons()
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
	if _system_panel:
		_system_panel.lock_buttons()
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
	if _system_panel:
		_system_panel.unlock_buttons()

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
	if _system_panel:
		_system_panel.lock_buttons()
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
	if _system_panel:
		_system_panel.lock_buttons()
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
	if _system_panel:
		_system_panel.unlock_buttons()
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
	if _system_panel:
		_system_panel.lock_buttons()

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
	var hints: Array = []
	if _fuel_valve_stop != 3:
		hints.append("燃料阀门 → HIGH")
	if _nav_knob_stop != 2:
		hints.append("导航旋钮 → SLING")
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
		if _fuel_valve_stop == 3 and _nav_knob_stop == 2 and thrust_val >= _sling_thrust_min and thrust_val <= _sling_thrust_max:
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
	if _system_panel:
		_system_panel.lock_buttons()
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
		var mesh_inst: MeshInstance3D = control.get_meta("knob_mesh")
		if mesh_inst:
			mesh_inst.rotation_degrees.z += delta.x * 0.5
			mesh_inst.rotation_degrees.z = clampf(mesh_inst.rotation_degrees.z, -150.0, 150.0)
			if absf(delta.x) > 2.0:
				_audio_play("play_knob_turn")
	elif ctrl_type == "lever":
		var handle: MeshInstance3D = control.get_meta("handle_mesh")
		var rod_h: float = control.get_meta("rod_height", 0.15)
		var handle_r: float = control.get_meta("handle_radius", 0.03)
		if handle:
			var current_y: float = handle.position.y
			handle.position.y = clampf(current_y + delta.y * 0.005, rod_h + handle_r, rod_h + handle_r + 0.2)
			var val: float = (handle.position.y - rod_h - handle_r) / 0.2
			control.set_meta("value", val)

func _on_control_interacted(control_name: String) -> void:
	if control_name == "ignition":
		if _storm_accepting_brake:
			_storm_braked = true
		elif _sling_state == "ARMED" or _sling_state == "TIMING":
			_sling_fire()
		else:
			_on_thrust_requested()

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
			if nav_control and absf(_nav_knob_stop - 0) < 0.01:
				var mesh_inst: MeshInstance3D = nav_control.get_meta("knob_mesh") if nav_control.has_meta("knob_mesh") else null
				if mesh_inst and absf(mesh_inst.rotation_degrees.z) > 10.0:
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
