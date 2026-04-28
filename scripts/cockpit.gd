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
var _gravity_map: Control = null
var _system_panel: Control = null
var _input_locked: bool = false
var _crt_materials: Array = []
var _lens_materials: Array = []
var _lens_strength: float = 0.0
var _accretion_material: ShaderMaterial = null
var _blackhole_node: MeshInstance3D = null
var _selected_channel_id: String = ""
var _game_over: bool = false

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
		_gravity_map.channel_selected.connect(_on_channel_selected)
		_gravity_map.scan_completed.connect(_on_scan_completed)
	_system_panel = system_panel_viewport.get_node("SystemPanel")
	if _system_panel:
		_system_panel.scan_requested.connect(_on_scan_requested)
		_system_panel.thrust_requested.connect(_on_thrust_requested)
	if nav_system:
		nav_system.node_changed.connect(_on_node_changed)
		nav_system.travel_started.connect(_on_travel_started)
		nav_system.special_event_requested.connect(_on_special_event)
		nav_system.bad_ending_requested.connect(_on_bad_ending)
	if transition_player:
		transition_player.transition_completed.connect(_on_transition_completed)

func _setup_resources() -> void:
	if ship_resources and ship_resources.has_method("load_config"):
		ship_resources.load_config(config)
		ship_resources.resources_changed.connect(_on_resources_changed)
		ship_resources.resource_depleted.connect(_on_resource_depleted)

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

func _process(_delta: float) -> void:
	if _lens_materials.is_empty():
		return
	var t: float = Time.get_ticks_msec() / 1000.0
	for mat: ShaderMaterial in _lens_materials:
		mat.set_shader_parameter("time", t)

func _find_crt_overlay(vp: SubViewport) -> ColorRect:
	for child: Node in vp.get_children():
		if child is ColorRect and child.name == "CRTOverlay":
			return child as ColorRect
	return null

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
	if _game_over:
		return
	if event is InputEventKey and event.pressed:
		var key: int = event.keycode if event.keycode != 0 else event.physical_keycode
		if key == KEY_S:
			_on_scan_requested()
			get_viewport().set_input_as_handled()
		elif key == KEY_T:
			_on_thrust_requested()
			get_viewport().set_input_as_handled()
		elif key == KEY_W:
			_do_wreck_scan()
			get_viewport().set_input_as_handled()

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
		var can_thrust: bool = channel_id != ""
		var thrust_fuel: float = config.get("actions", {}).get("thrust_fuel_cost", 5.0)
		var thrust_o2: float = config.get("actions", {}).get("thrust_oxygen_cost", 3.0)
		if ship_resources and ship_resources.has_method("can_consume"):
			if not ship_resources.can_consume({"fuel": thrust_fuel, "oxygen": thrust_o2}):
				can_thrust = false
		_system_panel.set_selected_channel(channel_id, can_scan)
		if not can_thrust and _system_panel.has_method("set_thrust_enabled"):
			_system_panel.set_thrust_enabled(false)

func _on_scan_requested() -> void:
	if _input_locked or _game_over or _selected_channel_id == "":
		return
	var scan_cost: float = config.get("actions", {}).get("scan_fuel_cost", 8.0)
	if ship_resources and ship_resources.has_method("can_consume_fuel"):
		if not ship_resources.can_consume_fuel(scan_cost):
			return
		ship_resources.consume_fuel(scan_cost)
	if _system_panel:
		_system_panel.lock_buttons()
	var scan_time: float = config.get("actions", {}).get("scan_time", 5.0)
	if _gravity_map and _gravity_map.has_method("start_scan"):
		_gravity_map.start_scan(_selected_channel_id, scan_time)

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
	if _gravity_map and _gravity_map.has_method("update_display"):
		_gravity_map.update_display(node_data)
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

func _setup_transition() -> void:
	if transition_player:
		var trans_cfg: Dictionary = config.get("transition", {})
		transition_player.load_config(trans_cfg)

func _on_travel_started(_from_id: int, to_id: int) -> void:
	_input_locked = true
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
	_input_locked = false
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

func _on_resources_changed(fuel: float, hull: float, oxygen: float) -> void:
	if _system_panel and _system_panel.has_method("update_resources"):
		_system_panel.update_resources(fuel, hull, oxygen)

func _on_resource_depleted(resource_type: String) -> void:
	if _game_over:
		return
	_game_over = true
	_input_locked = true
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
			_handle_storm_placeholder(node_data)
		"slingshot":
			_handle_slingshot_placeholder(node_data)

func _handle_storm_placeholder(node_data: Dictionary) -> void:
	_input_locked = true
	if _system_panel:
		_system_panel.lock_buttons()
	var auto_to: int = node_data.get("auto_advance_to", -1)
	var zone_name: String = node_data.get("name", "")
	var subtitle: String = node_data.get("subtitle", "")
	var flicker_dur: float = config.get("transition", {}).get("crt_flicker_duration", 0.5)
	_play_crt_flicker(flicker_dur)
	transition_player.play_zone_transition(zone_name, subtitle, func():
		if auto_to >= 0 and nav_system:
			nav_system.force_advance_to(auto_to)
	)

func _handle_slingshot_placeholder(node_data: Dictionary) -> void:
	_input_locked = true
	_game_over = true
	if _system_panel:
		_system_panel.lock_buttons()
	if narrative_manager and narrative_manager.has_method("show_text"):
		narrative_manager.show_text("", node_data.get("narrative_intro", ""))
	transition_player.play_zone_transition("EVENT HORIZON", "弹弓窗口", func():
		if narrative_manager and narrative_manager.has_method("show_ending"):
			narrative_manager.show_ending("escape")
	)

func _on_bad_ending(ending_type: String) -> void:
	_input_locked = true
	_game_over = true
	if _system_panel:
		_system_panel.lock_buttons()
	if narrative_manager and narrative_manager.has_method("show_ending"):
		narrative_manager.show_ending(ending_type)
	transition_player.play_zone_transition("ENDING", ending_type.to_upper(), func():
		pass
	)

func _handle_special_action(node_data: Dictionary, special: Dictionary) -> void:
	var action_type: String = special.get("type", "")
	if action_type == "wreck_scan":
		if narrative_manager and narrative_manager.has_method("show_text"):
			narrative_manager.show_text("[SYS] ", "检测到残骸信号——航行记录仪仍在工作。扫描可获取前人航行数据。(燃料 -%d%%, 氧气 -%d%%)" % [int(special.get("fuel_cost", 5)), int(special.get("oxygen_cost", 5))])

func _do_wreck_scan() -> void:
	var node_data: Dictionary = nav_system.get_current_node()
	var special: Dictionary = node_data.get("special_action", {})
	if special.is_empty():
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
