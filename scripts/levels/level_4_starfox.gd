extends Node3D

signal level_completed
signal level_failed
signal sfx_requested(sfx_name: String)
signal outro_started
signal hit_received(amount: float)

var config: Dictionary = {}
var hp: float = 100.0
var hp_max: float = 100.0
var base_hp_max: float = 100.0
var score: int = 0
var upgrade_system: Node = null
var run_hp: float = -1.0
var node_environment: String = ""

var track_path: Path3D
var path_follow: PathFollow3D
var crosshair: Node3D
var ship_anchor: Node3D
var ship_instance: Node3D
var camera: Camera3D
var camera_rig: Node3D
var shake_container: Node3D
var enemies_container: Node3D
var projectiles_container: Node3D
var obstacles_container: Node3D

var track_speed: float = 30.0
var crosshair_range_x: float = 7.5
var crosshair_range_y: float = 5.5
var fire_cooldown: float = 0.15
var bullet_speed: float = 150.0
var bullet_life: float = 2.0
var enemy_bullet_speed: float = 80.0
var enemy_bullet_life: float = 4.0
var obstacle_damage: float = 20.0

var ship_follow_weight: float = 0.08
var ship_snap_threshold: float = 0.01
var bank_angle: float = 0.6109
var bank_speed: float = 0.1
var camera_follow_weight: float = 0.05
var camera_lookahead: float = 10.0
var base_fov: float = 85.0
var cockpit_offset := Vector3(0.0, 0.3, -0.3)
var cockpit_roll_max: float = 0.0873
var cockpit_roll_speed: float = 5.0
var aim_offset_ratio: float = 0.1

var shake_engine_amp: float = 0.02
var shake_engine_freq_x: float = 13.0
var shake_engine_freq_y: float = 17.0
var shake_fire_amp: float = 0.02
var shake_fire_duration: float = 0.08
var shake_hit_amp: float = 0.15
var shake_hit_duration: float = 0.3
var shake_hit_decay: float = 8.0
var shake_threshold: float = 0.001

var crosshair_offset: Vector2 = Vector2.ZERO
var _crosshair_vel: Vector2 = Vector2.ZERO
var _crosshair_accel: float = 800.0
var _crosshair_damping: float = 0.88
var _crosshair_soft_edge_ratio: float = 0.8
var _crosshair_spring: float = 5.0
var _crosshair_centering: float = 0.6
var _crosshair_locked: bool = false
var _crosshair_ring: MeshInstance3D = null
var _crosshair_ring_mat: StandardMaterial3D = null

var _drift_offset: Vector2 = Vector2.ZERO
var _drift_speed: float = 4.0
var _drift_max: float = 8.0
var _drift_return_mult: float = 1.5
var _drift_shake_amp: float = 0.03
var _cursor_sprite: Sprite2D = null
var _aim_sprite: Sprite2D = null
var _aim_position: Vector2 = Vector2.ZERO
var _aim_damp_weight: float = 0.15
var _muzzle_flash_l: ColorRect = null
var _muzzle_flash_r: ColorRect = null
var _muzzle_flash_elapsed: float = -1.0
var _muzzle_flash_duration: float = 0.06
var _gun_side: bool = false
var _gun_port_offset: Vector3 = Vector3(1.0, -0.2, -1.5)
var _screen_margin: float = 50.0
var _viewport_size := Vector2(1152.0, 648.0)
var fire_timer: float = 0.0
var _track_length: float = 0.0
var _alive: bool = true
var _time: float = 0.0
var _asteroid_spawned: Dictionary = {}
var _asteroid_config: Dictionary = {}

var _shake_fire_elapsed: float = -1.0
var _shake_hit_elapsed: float = -1.0

var spawn_regions: Dictionary = {}
var _spawn_queue: Array = []
var _waves_config: Array = []
var _wave_queue_spawned: Dictionary = {}

var _segments_config: Array = []
var _segments_pool: Array = []
var _current_segment_idx: int = 0
var _segment_end_progress: float = 0.0
var _segment_start_progress: float = 0.0
var _segment_wave_spawned: Dictionary = {}
var _segment_asteroid_spawned: Dictionary = {}
var _next_appended: bool = false
var _boss_pending: bool = false
var _total_segments_to_run: int = 7

var _bullet_player_scene: PackedScene
var _bullet_enemy_scene: PackedScene
var _enemy_small_scene: PackedScene
var _enemy_medium_scene: PackedScene
var _enemy_boss_scene: PackedScene
var _enemy_boss_ship_scene: PackedScene
var _enemy_lateral_scene: PackedScene
var _asteroid_scene: PackedScene
var _laser_wall_scene: PackedScene
var _explosion_script: GDScript

var _barrel_roll_active: bool = false
var _barrel_roll_cooldown: float = 0.0
var _barrel_roll_duration: float = 0.4
var _barrel_roll_cooldown_time: float = 1.5
var _barrel_roll_timer: float = 0.0
var _is_invincible: bool = false

var _turret_timer: float = 0.0
var _turret_interval: float = 0.5
var _missile_scene: PackedScene
var _missile_cooldown: float = 0.0
var _missile_cooldown_max: float = 10.0
var _laser_heat: float = 0.0
var _laser_max_heat: float = 100.0
var _laser_heat_rate: float = 40.0
var _laser_cooldown_rate: float = 33.3
var _laser_overheated: bool = false
var _laser_cooldown_delay: float = 3.0
var _laser_beam_instance: MeshInstance3D = null

var _finishing: bool = false
var _finish_timer: float = 0.0
var _finish_delay: float = 2.0
var _dying: bool = false
var _death_timer: float = 0.0
var _death_delay: float = 1.5

enum PlayState { COMBAT, OUTRO, FINISHED }
var _play_state: PlayState = PlayState.COMBAT
var _level_timer: float = 0.0
var _level_duration: float = 60.0
var _outro_timer: float = 0.0
var _outro_duration: float = 2.5
var _outro_speed_mult: float = 5.0
var _stop_spawning: bool = false

var _world_env: WorldEnvironment = null
var _current_env_instance: Node3D = null
var _current_env_path: String = ""
var _starfield_parent: Node3D = null

var _hp_bar_mat: ShaderMaterial = null
var _score_label: Label = null
var _segment_label: Label = null
var _heat_label: Label = null
var _missile_label: Label = null

func _ready() -> void:
	_load_config()
	_load_scenes()
	_setup_scene()
	_setup_starfield()
	_init_segment_system()

func _load_config() -> void:
	var file := FileAccess.open("res://assets/data/game_config.json", FileAccess.READ)
	if file:
		var json := JSON.new()
		json.parse(file.get_as_text())
		var data: Dictionary = json.data
		if data.has("starfox"):
			config = data["starfox"]
			base_hp_max = float(config.get("hp_max", 100.0))
			hp_max = _get_stat(base_hp_max, "hp_max")
			hp = hp_max if run_hp < 0.0 else minf(run_hp, hp_max)
			track_speed = float(config.get("track_speed", 30.0))
			fire_cooldown = float(config.get("fire_cooldown", 0.15))
			bullet_speed = float(config.get("bullet_speed", 150.0))
			bullet_life = float(config.get("bullet_life", 2.0))
			enemy_bullet_speed = float(config.get("enemy_bullet_speed", 80.0))
			enemy_bullet_life = float(config.get("enemy_bullet_life", 4.0))
			obstacle_damage = float(config.get("obstacle_damage", 20.0))
			ship_follow_weight = float(config.get("ship_follow_weight", 0.08))
			ship_snap_threshold = float(config.get("ship_snap_threshold", 0.01))
			bank_angle = deg_to_rad(float(config.get("bank_angle_deg", 35.0)))
			bank_speed = float(config.get("bank_speed", 0.1))
			camera_follow_weight = float(config.get("camera_follow_weight", 0.05))
			camera_lookahead = float(config.get("camera_lookahead", 10.0))
			base_fov = float(config.get("base_fov", 85.0))
			var co: Dictionary = config.get("cockpit_offset", {})
			cockpit_offset = Vector3(
				float(co.get("x", 0.0)),
				float(co.get("y", 0.3)),
				float(co.get("z", -0.3))
			)
			cockpit_roll_max = deg_to_rad(float(config.get("cockpit_roll_max_deg", 5.0)))
			cockpit_roll_speed = float(config.get("cockpit_roll_speed", 5.0))
			var gp: Dictionary = config.get("gun_port_offset", {})
			_gun_port_offset = Vector3(
				float(gp.get("x", 1.0)),
				float(gp.get("y", -0.2)),
				float(gp.get("z", -1.5))
			)
			_aim_damp_weight = float(config.get("aim_damp_weight", 0.15))
			_screen_margin = float(config.get("screen_margin", 50.0))
			_muzzle_flash_duration = float(config.get("muzzle_flash_duration", 0.06))
			aim_offset_ratio = float(config.get("aim_offset_ratio", 0.1))
			shake_engine_amp = float(config.get("shake_engine_amp", 0.02))
			shake_engine_freq_x = float(config.get("shake_engine_freq_x", 13.0))
			shake_engine_freq_y = float(config.get("shake_engine_freq_y", 17.0))
			shake_fire_amp = float(config.get("shake_fire_amp", 0.02))
			shake_fire_duration = float(config.get("shake_fire_duration", 0.08))
			shake_hit_amp = float(config.get("shake_hit_amp", 0.15))
			shake_hit_duration = float(config.get("shake_hit_duration", 0.3))
			shake_hit_decay = float(config.get("shake_hit_decay", 8.0))
			shake_threshold = float(config.get("shake_threshold", 0.001))
			_barrel_roll_duration = float(config.get("barrel_roll_duration", 0.4))
			_barrel_roll_cooldown_time = float(config.get("barrel_roll_cooldown", 1.5))
			_drift_speed = float(config.get("drift_speed", 4.0))
			_drift_max = float(config.get("drift_max", 8.0))
			_drift_return_mult = float(config.get("drift_return_mult", 1.5))
			_drift_shake_amp = float(config.get("drift_shake_amp", 0.03))
			if config.has("segments"):
				_segments_config = config["segments"]
			if config.has("waves"):
				_waves_config = config["waves"]
			if config.has("asteroid"):
				_asteroid_config = config["asteroid"]
			_finish_delay = float(config.get("finish_delay", 2.0))
			_death_delay = float(config.get("death_delay", 1.5))
		file.close()

func _get_stat(base_val: float, stat_name: String) -> float:
	if upgrade_system and upgrade_system.has_method("get_stat"):
		return upgrade_system.get_stat(base_val, stat_name)
	return base_val

func _load_scenes() -> void:
	_bullet_player_scene = load("res://scenes/level4/bullet-player.tscn") as PackedScene
	_bullet_enemy_scene = load("res://scenes/level4/bullet-enemy.tscn") as PackedScene
	_enemy_small_scene = load("res://scenes/level4/enemy-small.tscn") as PackedScene
	_enemy_medium_scene = load("res://scenes/level4/enemy-medium.tscn") as PackedScene
	_enemy_boss_scene = load("res://scenes/level4/enemy-boss.tscn") as PackedScene
	_enemy_boss_ship_scene = load("res://scenes/level4/enemy-boss-ship.tscn") as PackedScene
	_enemy_lateral_scene = load("res://scenes/level4/enemy-lateral.tscn") as PackedScene
	_asteroid_scene = load("res://scenes/level4/asteroid.tscn") as PackedScene
	_laser_wall_scene = load("res://scenes/level4/obstacle-laser-wall.tscn") as PackedScene
	_explosion_script = load("res://scripts/levels/level4_explosion.gd") as GDScript
	_missile_scene = load("res://scenes/level4/missile.tscn") as PackedScene

func _setup_scene() -> void:
	track_path = $TrackPath
	path_follow = $TrackPath/PathFollow3D
	crosshair = $TrackPath/PathFollow3D/Crosshair
	ship_anchor = $TrackPath/PathFollow3D/ShipAnchor
	ship_instance = $TrackPath/PathFollow3D/ShipAnchor/Ship
	camera_rig = $TrackPath/PathFollow3D/CameraRig
	shake_container = $TrackPath/PathFollow3D/CameraRig/ShakeContainer
	camera = $TrackPath/PathFollow3D/CameraRig/ShakeContainer/Camera3D
	enemies_container = $Enemies
	projectiles_container = $Projectiles
	obstacles_container = $Obstacles

	if crosshair:
		crosshair.visible = false
		_crosshair_ring = crosshair.get_node_or_null("Ring")
		if _crosshair_ring and _crosshair_ring.material_override:
			_crosshair_ring_mat = _crosshair_ring.material_override.duplicate()
			_crosshair_ring.material_override = _crosshair_ring_mat

	if track_path and track_path.curve:
		track_path.curve.bake_interval = 1.0
		_track_length = track_path.curve.get_baked_length()

	if ship_instance:
		ship_instance.visible = false
		var ship_hitbox: Area3D = ship_instance.get_node("Hitbox")
		if ship_hitbox:
			ship_hitbox.area_entered.connect(_on_ship_hit)

	if camera:
		camera.current = true
		camera.fov = base_fov
		camera.position = cockpit_offset
		camera.rotation = Vector3.ZERO
	var left_cam := shake_container.get_node_or_null("LeftCamera") as Camera3D
	if left_cam:
		left_cam.current = false
	var right_cam := shake_container.get_node_or_null("RightCamera") as Camera3D
	if right_cam:
		right_cam.current = false

	_world_env = $WorldEnvironment
	_starfield_parent = $TrackPath/PathFollow3D/Starfield

	var combat_bounds_area: Area3D = get_node_or_null("TrackPath/PathFollow3D/CombatBounds")
	if combat_bounds_area:
		var cb_cs: CollisionShape3D = combat_bounds_area.get_node_or_null("CollisionShape3D")
		if cb_cs and cb_cs.shape is BoxShape3D:
			var box: BoxShape3D = cb_cs.shape
			crosshair_range_x = box.size.x * 0.5
			crosshair_range_y = box.size.y * 0.5

	var ui_root := $Control/Ui as Control
	if ui_root:
		var hp_bar := ui_root.get_node_or_null("HullProgressBar") as Sprite2D
		if hp_bar and hp_bar.material is ShaderMaterial:
			_hp_bar_mat = hp_bar.material as ShaderMaterial
		_score_label = ui_root.get_node_or_null("ScoreLabel") as Label
		_segment_label = ui_root.get_node_or_null("SegmentLabel") as Label
		_cursor_sprite = ui_root.get_node_or_null("Cursor") as Sprite2D
		_aim_sprite = ui_root.get_node_or_null("Aim") as Sprite2D
		if _cursor_sprite:
			_cursor_sprite.modulate = Color(0.2, 0.6, 1.0, 1.0)
		if _aim_sprite:
			_aim_sprite.modulate = Color(0.0, 1.0, 0.8, 1.0)
		_setup_muzzle_flash(ui_root)
	_heat_label = Label.new()
	_heat_label.position = Vector2(10.0, 60.0)
	_heat_label.add_theme_font_size_override("font_size", 18)
	_heat_label.add_theme_color_override("font_color", Color(0.3, 0.7, 1.0, 0.9))
	_heat_label.visible = false
	ui_root.add_child(_heat_label)
	_missile_label = Label.new()
	_missile_label.position = Vector2(10.0, 85.0)
	_missile_label.add_theme_font_size_override("font_size", 18)
	_missile_label.add_theme_color_override("font_color", Color(1.0, 0.6, 0.2, 0.9))
	_missile_label.visible = false
	ui_root.add_child(_missile_label)
	_viewport_size = ui_root.get_viewport().get_visible_rect().size
	_aim_position = _viewport_size * 0.5

	var spawn_area_node := $TrackPath/PathFollow3D/SpawnArea
	if spawn_area_node:
		spawn_regions = {
			"FrontSpawn": spawn_area_node.get_node("FrontSpawn"),
			"LeftSpawn": spawn_area_node.get_node("LeftSpawn"),
			"RightSpawn": spawn_area_node.get_node("RightSpawn"),
			"TopSpawn": spawn_area_node.get_node("TopSpawn"),
			"DownSpawn": spawn_area_node.get_node("DownSpawn"),
		}

func _setup_starfield() -> void:
	pass

func _setup_muzzle_flash(parent: Control) -> void:
	_muzzle_flash_l = ColorRect.new()
	_muzzle_flash_l.name = "MuzzleFlashL"
	_muzzle_flash_l.color = Color(1.0, 0.9, 0.4, 0.0)
	_muzzle_flash_l.size = Vector2(120.0, _viewport_size.y)
	_muzzle_flash_l.position = Vector2(0.0, 0.0)
	_muzzle_flash_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(_muzzle_flash_l)
	_muzzle_flash_r = ColorRect.new()
	_muzzle_flash_r.name = "MuzzleFlashR"
	_muzzle_flash_r.color = Color(1.0, 0.9, 0.4, 0.0)
	_muzzle_flash_r.size = Vector2(120.0, _viewport_size.y)
	_muzzle_flash_r.position = Vector2(_viewport_size.x - 120.0, 0.0)
	_muzzle_flash_r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(_muzzle_flash_r)

func _physics_process(delta: float) -> void:
	match _play_state:
		PlayState.OUTRO:
			_process_outro(delta)
			return
		PlayState.FINISHED:
			return
	if _finishing:
		_process_finishing(delta)
		return
	if _dying:
		_process_dying(delta)
		return
	if not _alive:
		return
	_time += delta
	_level_timer += delta
	if _level_timer >= _level_duration:
		_enter_outro()
		return
	_move_track(delta)
	_update_crosshair(delta)
	_update_ship(delta)
	_update_camera(delta)
	_update_shake(delta)
	_handle_shooting(delta)
	_update_barrel_roll(delta)
	_update_turret(delta)
	_update_missile(delta)
	if not _stop_spawning:
		_check_waves_queue(delta)
		_check_asteroid_spawns()
	_cleanup_behind()
	_update_ui()

func _move_track(delta: float) -> void:
	if path_follow and _track_length > 0:
		var current_speed := track_speed
		if _segments_pool.is_empty():
			if path_follow.progress_ratio > 0.9:
				var slowdown := (path_follow.progress_ratio - 0.9) / 0.1
				current_speed = track_speed * (1.0 - slowdown * 0.7)
		else:
			var remaining := _segment_end_progress - path_follow.progress
			var slowdown_dist := track_speed * 2.0
			if _current_segment_idx >= _segments_pool.size() - 1 and remaining < slowdown_dist:
				var t := 1.0 - (remaining / slowdown_dist)
				current_speed = track_speed * (1.0 - t * 0.7)
		path_follow.progress += current_speed * delta
		_check_segment_transition()
		if path_follow.progress >= _track_length - 1.0:
			_finishing = true
			_finish_timer = 0.0
			_alive = false

func _enter_outro() -> void:
	_play_state = PlayState.OUTRO
	_stop_spawning = true
	_outro_timer = 0.0
	_spawn_queue.clear()
	_clear_all_field_objects()
	outro_started.emit()

func _clear_all_field_objects() -> void:
	if enemies_container:
		for child in enemies_container.get_children():
			child.queue_free()
	if projectiles_container:
		for child in projectiles_container.get_children():
			child.queue_free()
	if obstacles_container:
		for child in obstacles_container.get_children():
			child.queue_free()

func _process_outro(delta: float) -> void:
	_outro_timer += delta
	var t := clampf(_outro_timer / _outro_duration, 0.0, 1.0)
	var speed: float = track_speed * lerpf(1.0, _outro_speed_mult, t)
	if path_follow:
		path_follow.progress += speed * delta
	if camera:
		camera.fov = lerp(base_fov, 110.0, t)
	_update_shake(delta)
	_cleanup_behind()
	if _outro_timer >= _outro_duration:
		_play_state = PlayState.FINISHED
		level_completed.emit()

func _process_finishing(delta: float) -> void:
	_update_shake(delta)
	_cleanup_behind()
	_finish_timer += delta
	if _finish_timer >= _finish_delay:
		level_completed.emit()
		_finishing = false

func _process_dying(delta: float) -> void:
	_update_shake(delta)
	_cleanup_behind()
	_death_timer += delta
	if _death_timer >= _death_delay:
		level_failed.emit()
		_dying = false

func _update_crosshair(delta: float) -> void:
	var input := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	_crosshair_vel.x += input.x * _crosshair_accel * delta
	_crosshair_vel.y -= input.y * _crosshair_accel * delta
	_crosshair_vel.x += -crosshair_offset.x * _crosshair_centering * delta
	_crosshair_vel.y += -crosshair_offset.y * _crosshair_centering * delta
	var soft_x: float = crosshair_range_x * _crosshair_soft_edge_ratio
	var soft_y: float = crosshair_range_y * _crosshair_soft_edge_ratio
	if absf(crosshair_offset.x) > soft_x:
		var excess: float = crosshair_offset.x - signf(crosshair_offset.x) * soft_x
		_crosshair_vel.x -= excess * _crosshair_spring * delta
	if absf(crosshair_offset.y) > soft_y:
		var excess: float = crosshair_offset.y - signf(crosshair_offset.y) * soft_y
		_crosshair_vel.y -= excess * _crosshair_spring * delta
	var damp_factor: float = pow(_crosshair_damping, delta * 60.0)
	_crosshair_vel.x *= damp_factor
	_crosshair_vel.y *= damp_factor
	crosshair_offset.x += _crosshair_vel.x * delta
	crosshair_offset.y += _crosshair_vel.y * delta
	crosshair_offset.x = clampf(crosshair_offset.x, -crosshair_range_x, crosshair_range_x)
	crosshair_offset.y = clampf(crosshair_offset.y, -crosshair_range_y, crosshair_range_y)
	if absf(crosshair_offset.x) >= crosshair_range_x:
		_crosshair_vel.x = 0.0
	if absf(crosshair_offset.y) >= crosshair_range_y:
		_crosshair_vel.y = 0.0
	_update_drift(delta, input)
	_apply_crosshair_offset()
	_update_crosshair_depth()
	_update_muzzle_flash(delta)

func _update_drift(delta: float, input: Vector2) -> void:
	var effective_drift_max := _get_stat(_drift_max, "drift_max")
	var edge_x := absf(crosshair_offset.x) >= crosshair_range_x * 0.95
	var edge_y := absf(crosshair_offset.y) >= crosshair_range_y * 0.95
	if edge_x and absf(input.x) > 0.1:
		var sign_x := signf(crosshair_offset.x)
		var same_dir := signf(input.x) == sign_x
		var drift_ratio := 1.0 - absf(_drift_offset.x) / effective_drift_max
		var speed := _drift_speed * drift_ratio
		if same_dir:
			_drift_offset.x += sign_x * speed * delta
		else:
			_drift_offset.x += signf(input.x) * speed * _drift_return_mult * delta
	else:
		if absf(input.x) > 0.1:
			_drift_offset.x += signf(input.x) * _drift_speed * _drift_return_mult * delta
	if edge_y and absf(input.y) > 0.1:
		var sign_y := signf(-crosshair_offset.y)
		var same_dir := signf(-input.y) == sign_y
		var drift_ratio := 1.0 - absf(_drift_offset.y) / effective_drift_max
		var speed := _drift_speed * drift_ratio
		if same_dir:
			_drift_offset.y += sign_y * speed * delta
		else:
			_drift_offset.y += signf(-input.y) * speed * _drift_return_mult * delta
	else:
		if absf(input.y) > 0.1:
			_drift_offset.y += signf(-input.y) * _drift_speed * _drift_return_mult * delta
	_drift_offset.x = clampf(_drift_offset.x, -effective_drift_max, effective_drift_max)
	_drift_offset.y = clampf(_drift_offset.y, -effective_drift_max, effective_drift_max)

func _apply_crosshair_offset() -> void:
	if crosshair == null or camera == null:
		return
	var cam_right := camera.global_basis.x
	var cam_up := camera.global_basis.y
	var target := path_follow.global_position + cam_right * crosshair_offset.x + cam_up * crosshair_offset.y
	var local := path_follow.global_transform.affine_inverse() * target
	crosshair.position.x = local.x
	crosshair.position.y = local.y

func _update_crosshair_depth() -> void:
	if crosshair == null:
		return
	crosshair.position.z = -50.0
	_set_crosshair_locked(false)

func _update_cursor_position() -> void:
	if _cursor_sprite == null:
		return
	var half_w: float = _viewport_size.x * 0.5
	var half_h: float = _viewport_size.y * 0.5
	var range_ratio_x: float = (half_w - _screen_margin) / crosshair_range_x
	var range_ratio_y: float = (half_h - _screen_margin) / crosshair_range_y
	var screen_x: float = half_w + crosshair_offset.x * range_ratio_x
	var screen_y: float = half_h - crosshair_offset.y * range_ratio_y
	screen_x = clampf(screen_x, _screen_margin, _viewport_size.x - _screen_margin)
	screen_y = clampf(screen_y, _screen_margin, _viewport_size.y - _screen_margin)
	_cursor_sprite.position = Vector2(screen_x, screen_y)
	if _aim_sprite:
		_aim_sprite.position = _viewport_size * 0.5
	var drift_ratio_x := _drift_offset.x / _drift_max if _drift_max > 0.0 else 0.0
	var stretch_x := 1.0 + absf(drift_ratio_x) * 0.3
	var stretch_y := 1.0 / sqrt(stretch_x)
	if _cursor_sprite:
		_cursor_sprite.scale = Vector2(stretch_x, stretch_y)
	if _aim_sprite:
		_aim_sprite.scale = Vector2(stretch_x, stretch_y)

func _set_crosshair_locked(locked: bool) -> void:
	if locked == _crosshair_locked:
		return
	_crosshair_locked = locked
	if _crosshair_ring == null:
		return
	var scale_target := Vector3(0.7, 0.7, 0.7) if locked else Vector3(1.0, 1.0, 1.0)
	_crosshair_ring.scale = scale_target
	if _crosshair_ring_mat:
		var col := Color(1.0, 0.3, 0.2) if locked else Color(0.0, 1.0, 0.8)
		_crosshair_ring_mat.albedo_color = col
		_crosshair_ring_mat.emission = col

func _update_muzzle_flash(delta: float) -> void:
	if _muzzle_flash_elapsed >= 0.0:
		_muzzle_flash_elapsed += delta
		if _muzzle_flash_elapsed < _muzzle_flash_duration:
			var t: float = 1.0 - _muzzle_flash_elapsed / _muzzle_flash_duration
			var alpha: float = t * 0.25
			var col := Color(1.0, 0.9, 0.4, alpha)
			if _muzzle_flash_l:
				_muzzle_flash_l.color = col
			if _muzzle_flash_r:
				_muzzle_flash_r.color = col
		else:
			_muzzle_flash_elapsed = -1.0
			if _muzzle_flash_l:
				_muzzle_flash_l.color = Color(1.0, 0.9, 0.4, 0.0)
			if _muzzle_flash_r:
				_muzzle_flash_r.color = Color(1.0, 0.9, 0.4, 0.0)

func _update_ship(_delta: float) -> void:
	if ship_anchor == null:
		return
	var target_pos := Vector3(crosshair_offset.x + _drift_offset.x, crosshair_offset.y + _drift_offset.y, 0.0)
	var cam_right := camera.global_basis.x if camera else Vector3.RIGHT
	var cam_up := camera.global_basis.y if camera else Vector3.UP
	var target_world := path_follow.global_position + cam_right * target_pos.x + cam_up * target_pos.y
	var target_local := path_follow.global_transform.affine_inverse() * target_world
	var current_pos := ship_anchor.position
	var diff := target_local - current_pos
	if diff.length() < ship_snap_threshold:
		ship_anchor.position = target_local
	else:
		ship_anchor.position = current_pos.lerp(target_local, ship_follow_weight)

func _update_camera(delta: float) -> void:
	if camera_rig == null or ship_anchor == null:
		return
	camera_rig.position.x = ship_anchor.position.x
	camera_rig.position.y = ship_anchor.position.y
	camera_rig.position.z = ship_anchor.position.z
	var lateral_diff: float = crosshair_offset.x / crosshair_range_x if crosshair_range_x > 0.0 else 0.0
	var target_roll: float = -lateral_diff * cockpit_roll_max
	camera.rotation.z = lerpf(camera.rotation.z, target_roll, minf(1.0, cockpit_roll_speed * delta))
	if _aim_sprite and path_follow:
		var path_roll: float = path_follow.global_basis.get_euler().z
		_aim_sprite.rotation = lerpf(_aim_sprite.rotation, path_roll, minf(1.0, delta / 3.0))
		var center := _viewport_size * 0.5
		var off_x: float = (crosshair_offset.x / crosshair_range_x) * _viewport_size.x * aim_offset_ratio if crosshair_range_x > 0.0 else 0.0
		var off_y: float = (-crosshair_offset.y / crosshair_range_y) * _viewport_size.y * aim_offset_ratio if crosshair_range_y > 0.0 else 0.0
		_aim_sprite.position = center + Vector2(off_x, off_y)

func _update_shake(delta: float) -> void:
	if shake_container == null:
		return
	shake_container.position = Vector3.ZERO
	var offset := Vector3.ZERO
	offset.x = sin(_time * shake_engine_freq_x) * shake_engine_amp
	offset.y = sin(_time * shake_engine_freq_y) * shake_engine_amp
	var sway_z := sin(_time * 0.8) * 0.015 + sin(_time * 1.3 + 2.0) * 0.008
	var sway_x := sin(_time * 0.6 + 1.0) * 0.008
	var sway_y := sin(_time * 0.5 + 0.7) * 0.005
	shake_container.rotation = Vector3(sway_x, sway_y, sway_z)
	offset.y += sin(_time * 0.7 + 1.5) * 0.008
	var drift_ratio := _drift_offset.length() / _drift_max if _drift_max > 0.0 else 0.0
	if drift_ratio > 0.01:
		offset.x += randf_range(-1.0, 1.0) * _drift_shake_amp * drift_ratio
		offset.y += randf_range(-1.0, 1.0) * _drift_shake_amp * drift_ratio
	if _shake_fire_elapsed >= 0.0:
		_shake_fire_elapsed += delta
		if _shake_fire_elapsed < shake_fire_duration:
			var t: float = 1.0 - _shake_fire_elapsed / shake_fire_duration
			offset.y += shake_fire_amp * t
		else:
			_shake_fire_elapsed = -1.0
	if _shake_hit_elapsed >= 0.0:
		_shake_hit_elapsed += delta
		if _shake_hit_elapsed < shake_hit_duration:
			var t: float = exp(-shake_hit_decay * _shake_hit_elapsed)
			if t > shake_threshold:
				offset.x += shake_hit_amp * t * randf_range(-1.0, 1.0)
				offset.y += shake_hit_amp * t * randf_range(-1.0, 1.0)
			else:
				_shake_hit_elapsed = -1.0
		else:
			_shake_hit_elapsed = -1.0
	shake_container.position = offset

func _handle_shooting(delta: float) -> void:
	if upgrade_system and upgrade_system.has_method("has_upgrade") and upgrade_system.has_upgrade("laser_beam"):
		if _laser_beam_instance == null:
			_setup_laser_beam()
		_handle_laser(delta)
		return
	fire_timer -= delta
	if Input.is_key_pressed(KEY_SPACE) and fire_timer <= 0.0 and _bullet_player_scene:
		fire_timer = _get_stat(fire_cooldown, "fire_cooldown")
		_fire_player_bullet()

func _fire_player_bullet() -> void:
	if camera == null or crosshair == null:
		return
	var bullet: Node3D = _bullet_player_scene.instantiate()
	projectiles_container.add_child(bullet)
	var aim_pos := crosshair.global_position
	var shoot_dir: Vector3 = (aim_pos - camera.global_position)
	if shoot_dir.length_squared() < 0.01:
		shoot_dir = -camera.global_basis.z
	else:
		shoot_dir = shoot_dir.normalized()
	var side_x: float = _gun_port_offset.x if _gun_side else -_gun_port_offset.x
	_gun_side = not _gun_side
	var basis := camera.global_basis
	var spawn_pos: Vector3 = camera.global_position + basis.x * side_x + basis.y * _gun_port_offset.y + basis.z * _gun_port_offset.z
	bullet.global_position = spawn_pos
	bullet.velocity = shoot_dir * bullet_speed
	bullet.lifetime = bullet_life
	bullet.is_player_bullet = true
	if upgrade_system and upgrade_system.has_method("has_upgrade") and upgrade_system.has_upgrade("bullet_magnet"):
		bullet.magnet_radius = float(config.get("bullet_magnet_radius", 5.0))
		bullet.magnet_strength = float(config.get("bullet_magnet_strength", 3.0))
	else:
		bullet.magnet_radius = 0.0
		bullet.magnet_strength = 0.0
	bullet.add_to_group("player_bullet")
	var hitbox: Area3D = bullet.get_node("Hitbox")
	if hitbox:
		hitbox.area_entered.connect(_on_player_bullet_hit.bind(bullet))
	_shake_fire_elapsed = 0.0
	sfx_requested.emit("player_fire")

func _on_player_bullet_hit(area: Area3D, bullet: Node3D) -> void:
	var target: Node3D = area.get_parent() as Node3D
	if target == null:
		return
	if target.is_in_group("enemy"):
		if target.has_method("take_damage"):
			target.take_damage(1.0)
		_spawn_spark(area.global_position)
		if is_instance_valid(bullet):
			bullet.queue_free()
	elif target.is_in_group("obstacle"):
		if target.has_method("take_damage"):
			target.take_damage(1.0)
		_spawn_spark(area.global_position)
		if is_instance_valid(bullet):
			bullet.queue_free()

func _on_ship_hit(area: Area3D) -> void:
	var source: Node3D = area.get_parent() as Node3D
	if source == null:
		return
	if source.is_in_group("enemy_bullet"):
		take_damage(float(config.get("enemy_bullet_damage", 10.0)))
		source.queue_free()
	elif source.is_in_group("obstacle"):
		take_damage(obstacle_damage)

func _get_path_point_at_z(target_z: float) -> Vector3:
	if track_path == null or track_path.curve == null:
		return Vector3.ZERO
	var curve := track_path.curve
	var baked_len := curve.get_baked_length()
	if baked_len <= 0.0:
		return Vector3.ZERO
	var best_dist := INF
	var best_point := Vector3.ZERO
	var steps := int(baked_len / 2.0)
	for i: int in range(steps + 1):
		var d := (float(i) / float(steps)) * baked_len
		var pt := curve.sample_baked(d)
		var dz := absf(pt.z - target_z)
		if dz < best_dist:
			best_dist = dz
			best_point = pt
	return best_point

func _spawn_typed_enemy(enemy_type: String, world_pos: Vector3, spawn_face: String = "FrontSpawn", entry_z: float = -30.0) -> void:
	if enemy_type == "obstacle_laser_wall":
		_spawn_laser_wall(entry_z)
		return
	var scene: PackedScene = null
	match enemy_type:
		"enemy_small":
			scene = _enemy_small_scene
		"enemy_medium":
			scene = _enemy_medium_scene
		"enemy_boss":
			scene = _enemy_boss_scene
		"enemy_boss_ship":
			scene = _enemy_boss_ship_scene
		"enemy_lateral":
			scene = _enemy_lateral_scene
		"enemy_lateral_far":
			scene = _enemy_lateral_scene
	if scene == null:
		return
	var enemy: Node3D = scene.instantiate()
	enemies_container.add_child(enemy)
	enemy.global_position = world_pos
	var enemy_cfg: Dictionary = config.get(enemy_type, {})
	var pts: int = int(enemy_cfg.get("score", 10))
	if enemy.has_signal("destroyed"):
		if enemy_type == "enemy_boss" or enemy_type == "enemy_boss_ship":
			enemy.destroyed.connect(_on_boss_destroyed.bind(enemy))
		else:
			enemy.destroyed.connect(_on_enemy_destroyed.bind(enemy, pts))
	if enemy.has_method("setup"):
		enemy.setup(ship_anchor, path_follow, enemy_cfg, track_speed, Vector2(crosshair_range_x, crosshair_range_y), spawn_face, entry_z)
		if enemy.has_signal("fire_bullet"):
			enemy.fire_bullet.connect(_on_enemy_fire)

func _on_enemy_fire(pos: Vector3, dir: Vector3) -> void:
	if _bullet_enemy_scene == null:
		return
	var bullet: Node3D = _bullet_enemy_scene.instantiate()
	projectiles_container.add_child(bullet)
	bullet.global_position = pos
	bullet.velocity = dir * enemy_bullet_speed
	bullet.lifetime = enemy_bullet_life
	bullet.add_to_group("enemy_bullet")
	sfx_requested.emit("enemy_fire")

func _on_enemy_destroyed(enemy: Node3D, pts: int) -> void:
	score += pts
	_spawn_explosion(enemy.global_position, Color(1.0, 0.7, 0.2), false)
	sfx_requested.emit("explosion")
	if upgrade_system and upgrade_system.has_method("has_upgrade") and upgrade_system.has_upgrade("vampirism"):
		hp = minf(hp + hp_max * 0.01, hp_max)

func _on_boss_destroyed(boss: Node3D) -> void:
	score += int(config.get("enemy_boss", {}).get("score", 500))
	var boss_pos := boss.global_position if (boss and is_instance_valid(boss)) else Vector3.ZERO
	_spawn_explosion(boss_pos, Color(1.0, 0.3, 0.1), true)
	sfx_requested.emit("explosion_boss")
	await get_tree().create_timer(1.0).timeout
	_finishing = true
	_finish_timer = 0.0
	_alive = false

func _spawn_laser_wall(entry_z: float) -> void:
	if _laser_wall_scene == null or obstacles_container == null:
		return
	var wall := _laser_wall_scene.instantiate() as Node3D
	obstacles_container.add_child(wall)
	if wall.has_method("setup"):
		wall.setup(path_follow, track_speed, entry_z)
	if wall.has_signal("hit_player"):
		wall.hit_player.connect(_on_laser_wall_hit)

func _on_laser_wall_hit() -> void:
	take_damage(1.0)

func _spawn_explosion(pos: Vector3, color: Color, is_boss: bool) -> void:
	if _explosion_script == null:
		return
	var node := Node3D.new()
	node.set_script(_explosion_script)
	enemies_container.get_parent().add_child(node)
	node.global_position = pos
	if node.has_method("setup"):
		var dur := float(config.get("explosion_duration", 0.8))
		node.setup(color, is_boss, dur)

func _spawn_spark(pos: Vector3) -> void:
	if _explosion_script == null:
		return
	var node := Node3D.new()
	node.set_script(_explosion_script)
	enemies_container.get_parent().add_child(node)
	node.global_position = pos
	if node.has_method("setup"):
		node.setup(Color(1.0, 1.0, 0.5), false, 0.3)

func _check_asteroid_spawns() -> void:
	if path_follow == null or _asteroid_config.is_empty():
		return
	if not _asteroid_config.has("spawn_triggers") or not _asteroid_config.has("patterns"):
		return
	var ratio := path_follow.progress_ratio
	var triggers: Array = _asteroid_config["spawn_triggers"]
	for i: int in triggers.size():
		var key := "ast_%d" % i
		if _asteroid_spawned.has(key):
			continue
		var trigger: float = float(triggers[i])
		if ratio >= trigger:
			_asteroid_spawned[key] = true
			_spawn_asteroid_pattern(i)

func _spawn_asteroid_pattern(index: int) -> void:
	if _asteroid_scene == null:
		return
	var patterns: Array = _asteroid_config.get("patterns", [])
	if index >= patterns.size():
		return
	var pattern: Dictionary = patterns[index % patterns.size()]
	var count: int = int(pattern.get("count", 4))
	var x_min: float = float(pattern.get("x_range", [-5.0, 5.0])[0])
	var x_max: float = float(pattern.get("x_range", [-5.0, 5.0])[1])
	var y_min: float = float(pattern.get("y_range", [-3.0, 3.0])[0])
	var y_max: float = float(pattern.get("y_range", [-3.0, 3.0])[1])
	var z_spread: float = float(pattern.get("z_spread", 15.0))
	var size_min: float = float(pattern.get("size_range", [0.5, 1.5])[0])
	var size_max: float = float(pattern.get("size_range", [0.5, 1.5])[1])
	var ast_hp: float = float(pattern.get("hp", 2.0))
	var base_z: float = path_follow.global_position.z - 80.0
	var path_base := _get_path_point_at_z(base_z)
	var debris_count := int(_asteroid_config.get("debris_count", 4))
	var debris_lifetime := float(_asteroid_config.get("debris_lifetime", 0.6))
	var debris_speed := float(_asteroid_config.get("debris_speed", 5.0))
	var ast_score := int(_asteroid_config.get("score", 5))
	for _j: int in count:
		var ast: Node3D = _asteroid_scene.instantiate()
		obstacles_container.add_child(ast)
		var ast_z: float = base_z + randf_range(-z_spread * 0.5, z_spread * 0.5)
		var pt := _get_path_point_at_z(ast_z) if (z_spread > 5.0) else path_base
		ast.global_position = Vector3(
			pt.x + randf_range(x_min, x_max),
			pt.y + randf_range(y_min, y_max),
			ast_z
		)
		var s: float = randf_range(size_min, size_max)
		ast.scale = Vector3(s, s, s)
		if ast.has_method("setup"):
			ast.setup({
				"hp": ast_hp,
				"score": ast_score,
				"debris_count": debris_count,
				"debris_lifetime": debris_lifetime,
				"debris_speed": debris_speed,
			})
		if ast.has_signal("destroyed"):
			ast.destroyed.connect(_on_asteroid_destroyed)

func _on_asteroid_destroyed(_pos: Vector3, pts: int) -> void:
	score += pts

func _update_barrel_roll(delta: float) -> void:
	_barrel_roll_cooldown = maxf(0.0, _barrel_roll_cooldown - delta)
	if _barrel_roll_active:
		_barrel_roll_timer += delta
		if _barrel_roll_timer >= _barrel_roll_duration:
			_barrel_roll_active = false
			_barrel_roll_timer = 0.0
			_is_invincible = false
			if camera:
				camera.rotation.z = 0.0
		return
	if not _barrel_roll_active and (Input.is_key_pressed(KEY_Q) or Input.is_key_pressed(KEY_E)):
		if _barrel_roll_cooldown <= 0.0:
			_start_barrel_roll()

func _start_barrel_roll() -> void:
	_barrel_roll_active = true
	_barrel_roll_timer = 0.0
	_is_invincible = true
	_barrel_roll_cooldown = _barrel_roll_cooldown_time
	sfx_requested.emit("barrel_roll")
	if camera == null:
		return
	var direction: float = -1.0 if Input.is_key_pressed(KEY_Q) else 1.0
	var start_rot: float = camera.rotation.z
	var end_rot: float = start_rot + direction * TAU
	var tween := create_tween()
	tween.tween_property(camera, "rotation:z", end_rot, _barrel_roll_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tween.tween_callback(func() -> void:
		if is_instance_valid(camera):
			camera.rotation.z = 0.0
	)
	_deflect_nearby_bullets()

func _deflect_nearby_bullets() -> void:
	if ship_anchor == null or projectiles_container == null:
		return
	var reflect_radius := float(config.get("barrel_roll_reflect_radius", 3.0))
	var ship_pos := ship_anchor.global_position
	for child: Node in projectiles_container.get_children():
		if not child.is_in_group("enemy_bullet"):
			continue
		var bullet: Node3D = child as Node3D
		if bullet == null:
			continue
		var dist_sq := (bullet.global_position - ship_pos).length_squared()
		if dist_sq < reflect_radius * reflect_radius:
			if bullet.has_method("get") and "velocity" in bullet:
				bullet.velocity = -bullet.velocity
				bullet.remove_from_group("enemy_bullet")

func _find_nearest_enemy() -> Node3D:
	if enemies_container == null:
		return null
	var ship_pos := ship_anchor.global_position if ship_anchor else global_position
	var best: Node3D = null
	var best_dist_sq: float = 9000000.0
	for child: Node in enemies_container.get_children():
		var enemy: Node3D = child as Node3D
		if enemy == null or not is_instance_valid(enemy):
			continue
		if not enemy.has_method("take_damage"):
			continue
		var dist_sq := (enemy.global_position - ship_pos).length_squared()
		if dist_sq < best_dist_sq:
			best_dist_sq = dist_sq
			best = enemy
	return best

func _update_turret(delta: float) -> void:
	if upgrade_system == null or not upgrade_system.has_method("has_upgrade"):
		return
	if not upgrade_system.has_upgrade("auto_turret"):
		return
	_turret_timer += delta
	if _turret_timer < _turret_interval:
		return
	_turret_timer = 0.0
	var target := _find_nearest_enemy()
	if target == null:
		return
	_fire_turret_bullet(target)

func _fire_turret_bullet(target: Node3D) -> void:
	if _bullet_player_scene == null or camera == null:
		return
	var bullet: Node3D = _bullet_player_scene.instantiate()
	projectiles_container.add_child(bullet)
	var spawn_pos := camera.global_position + Vector3(0.0, 0.5, 0.0)
	bullet.global_position = spawn_pos
	var shoot_dir := (target.global_position - spawn_pos).normalized()
	bullet.velocity = shoot_dir * bullet_speed
	bullet.lifetime = bullet_life
	bullet.is_player_bullet = true
	bullet.magnet_radius = 0.0
	bullet.magnet_strength = 0.0
	bullet.add_to_group("player_bullet")
	var hitbox: Area3D = bullet.get_node("Hitbox")
	if hitbox:
		hitbox.area_entered.connect(_on_player_bullet_hit.bind(bullet))

func _update_missile(delta: float) -> void:
	if upgrade_system == null or not upgrade_system.has_method("has_upgrade"):
		return
	if not upgrade_system.has_upgrade("homing_missile"):
		return
	_missile_cooldown = maxf(0.0, _missile_cooldown - delta)
	if Input.is_key_pressed(KEY_R) and _missile_cooldown <= 0.0 and _missile_scene:
		_missile_cooldown = _missile_cooldown_max
		_fire_missile()

func _fire_missile() -> void:
	if camera == null:
		return
	var missile: Node3D = _missile_scene.instantiate()
	projectiles_container.add_child(missile)
	var spawn_pos := camera.global_position - camera.global_basis.z * 1.5
	missile.global_position = spawn_pos
	missile.speed = bullet_speed * 0.8
	missile.lifetime = 4.0
	missile.damage = 5.0
	missile.add_to_group("player_bullet")
	sfx_requested.emit("missile_fire")

func _handle_laser(delta: float) -> void:
	if _laser_overheated:
		_laser_heat -= _laser_cooldown_rate * delta
		if _laser_heat <= 0.0:
			_laser_heat = 0.0
			_laser_overheated = false
		_update_laser_beam(false)
		return
	if Input.is_key_pressed(KEY_SPACE):
		_laser_heat += _laser_heat_rate * delta
		if _laser_heat >= _laser_max_heat:
			_laser_heat = _laser_max_heat
			_laser_overheated = true
		_fire_laser()
		_update_laser_beam(true)
	else:
		_laser_heat = maxf(0.0, _laser_heat - _laser_cooldown_rate * delta)
		_update_laser_beam(false)

func _fire_laser() -> void:
	if camera == null:
		return
	var space_state := camera.get_world_3d().direct_space_state
	var from := camera.global_position
	var to := from + (-camera.global_basis.z) * 200.0
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = 10
	var result: Dictionary = space_state.intersect_ray(query)
	if result.is_empty():
		return
	var collider: Object = result.get("collider", null)
	if collider == null:
		return
	var target: Node3D = collider.get_parent() as Node3D
	if target == null:
		return
	if target.is_in_group("enemy") and target.has_method("take_damage"):
		target.take_damage(0.5)

func _update_laser_beam(active: bool) -> void:
	if _laser_beam_instance == null:
		return
	_laser_beam_instance.visible = active
	if not active:
		return
	if camera == null:
		return
	var from := camera.global_position
	var to := from + (-camera.global_basis.z) * 200.0
	var space_state := camera.get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = 10
	var result: Dictionary = space_state.intersect_ray(query)
	var end_pos: Vector3 = result.get("position", to) if not result.is_empty() else to
	var mid := (from + end_pos) * 0.5
	_laser_beam_instance.global_position = mid
	_laser_beam_instance.look_at(end_pos, Vector3.UP)
	var dist := from.distance_to(end_pos)
	_laser_beam_instance.scale = Vector3(0.05, 0.05, dist)

func _setup_laser_beam() -> void:
	_laser_beam_instance = MeshInstance3D.new()
	_laser_beam_instance.mesh = CylinderMesh.new()
	_laser_beam_instance.mesh.top_radius = 0.02
	_laser_beam_instance.mesh.bottom_radius = 0.02
	_laser_beam_instance.mesh.height = 1.0
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.3, 0.7, 1.0, 0.8)
	mat.emission = Color(0.3, 0.7, 1.0)
	mat.emission_energy = 2.0
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_laser_beam_instance.material_override = mat
	_laser_beam_instance.visible = false
	add_child(_laser_beam_instance)

func _cleanup_behind() -> void:
	if path_follow == null:
		return
	var fwd := -path_follow.global_basis.z
	var ship_pos := path_follow.global_position
	for child: Node in enemies_container.get_children():
		var to_enemy: Vector3 = child.global_position - ship_pos
		if to_enemy.dot(fwd) < -30.0:
			child.queue_free()
	for child: Node in projectiles_container.get_children():
		var to_bullet: Vector3 = child.global_position - ship_pos
		if to_bullet.dot(fwd) < -20.0:
			child.queue_free()
	if obstacles_container:
		for child: Node in obstacles_container.get_children():
			var to_obs: Vector3 = child.global_position - ship_pos
			if to_obs.dot(fwd) < -30.0:
				child.queue_free()

func take_damage(amount: float) -> void:
	if _is_invincible or not _alive:
		return
	hp = maxf(0.0, hp - amount)
	_shake_hit_elapsed = 0.0
	hit_received.emit(amount)
	sfx_requested.emit("player_hit")
	if hp <= 0.0:
		_alive = false
		_dying = true
		_death_timer = 0.0
		_spawn_queue.clear()
		if ship_anchor:
			_spawn_explosion(ship_anchor.global_position, Color(1.0, 0.4, 0.1), true)
		sfx_requested.emit("player_death")

func get_player_position() -> Vector3:
	if path_follow:
		return path_follow.global_position
	return Vector3.ZERO

func get_player_heading() -> float:
	if path_follow:
		return path_follow.global_rotation.y
	return 0.0

func get_track_progress() -> float:
	if path_follow:
		return path_follow.progress_ratio
	return 0.0

func get_hp() -> float:
	return hp

func get_score() -> int:
	return score

func get_status_data() -> Dictionary:
	return {
		"hp": hp,
		"hp_max": _get_stat(base_hp_max, "hp_max"),
		"score": score,
		"progress": _level_timer / _level_duration if _level_duration > 0.0 else 0.0,
		"sector": _current_segment_idx + 1,
		"sector_total": _total_segments_to_run,
		"aim_x": crosshair_offset.x / crosshair_range_x if crosshair_range_x > 0.0 else 0.0,
		"aim_y": crosshair_offset.y / crosshair_range_y if crosshair_range_y > 0.0 else 0.0,
	}

func get_random_local_in_box(region_name: String) -> Vector3:
	var area: Area3D = spawn_regions.get(region_name)
	if area == null:
		return Vector3.ZERO
	var cs: CollisionShape3D = area.get_node_or_null("CollisionShape3D")
	if cs == null or cs.shape == null:
		return Vector3.ZERO
	var shape: BoxShape3D = cs.shape as BoxShape3D
	if shape == null:
		return Vector3.ZERO
	var half := shape.size * 0.5
	return Vector3(
		randf_range(-half.x, half.x),
		randf_range(-half.y, half.y),
		randf_range(-half.z, half.z)
	)

func get_spawn_position(region_name: String, entry_z: float, offset: Vector3 = Vector3.ZERO) -> Vector3:
	var area: Area3D = spawn_regions.get(region_name)
	if area == null or path_follow == null:
		return Vector3.ZERO
	var local_in_area := get_random_local_in_box(region_name) + offset
	var local_in_path: Vector3 = area.transform * local_in_area
	local_in_path.z = entry_z
	return path_follow.global_transform * local_in_path

func _get_formation_offsets(formation: String, count: int, spacing: float) -> Array:
	var offsets: Array = []
	match formation:
		"v_shape":
			offsets.append(Vector3.ZERO)
			for i in range(1, count):
				var side: float = 1.0 if i % 2 == 1 else -1.0
				var row: float = ceilf(float(i) / 2.0)
				offsets.append(Vector3(side * spacing * row, spacing * row * 0.3, spacing * row))
		"line":
			for i in range(count):
				offsets.append(Vector3((float(i) - (float(count) - 1.0) * 0.5) * spacing, 0.0, 0.0))
		"stagger":
			for i in range(count):
				var stagger_x: float = 0.0 if i % 2 == 0 else spacing * 0.5
				offsets.append(Vector3(stagger_x + (float(i) - (float(count) - 1.0) * 0.5) * spacing, 0.0, float(i % 3 - 1) * spacing * 0.5))
		_:
			for i in range(count):
				offsets.append(Vector3.ZERO)
	return offsets

func _check_waves_queue(delta: float) -> void:
	if _waves_config.is_empty() or path_follow == null:
		return
	var seg_length := _segment_end_progress - _segment_start_progress
	if seg_length <= 0.0:
		return
	var seg_ratio := clampf((path_follow.progress - _segment_start_progress) / seg_length, 0.0, 1.0)
	for i in range(_waves_config.size()):
		if _wave_queue_spawned.has(i):
			continue
		var wave: Dictionary = _waves_config[i]
		var trigger: float = float(wave.get("trigger_progress", 1.0))
		if seg_ratio >= trigger:
			_wave_queue_spawned[i] = true
			_enqueue_wave(wave)
	_process_spawn_queue(delta)

func _enqueue_wave(wave: Dictionary) -> void:
	var enemies: Array = wave.get("enemies", [])
	var diff_mult := _get_difficulty_multiplier()
	for entry in enemies:
		var raw_count := int(entry.get("count", 1))
		var adj_count := clampi(int(float(raw_count) * diff_mult), 1, 8)
		_spawn_queue.append({
			"time_remaining": float(entry.get("delay", 0.0)),
			"type": str(entry.get("type", "enemy_small")),
			"region": str(entry.get("region", "FrontSpawn")),
			"count": adj_count,
			"formation": str(entry.get("formation", "scatter")),
			"spacing": float(entry.get("spacing", 2.0)),
			"entry_z": float(entry.get("entry_z", -30.0)),
		})

func _process_spawn_queue(delta: float) -> void:
	var remaining: Array = []
	for entry in _spawn_queue:
		entry["time_remaining"] = float(entry["time_remaining"]) - delta
		if float(entry["time_remaining"]) <= 0.0:
			_spawn_formation(entry)
		else:
			remaining.append(entry)
	_spawn_queue = remaining

func _spawn_formation(entry: Dictionary) -> void:
	var region_name: String = str(entry.get("region", "FrontSpawn"))
	var enemy_type: String = str(entry.get("type", "enemy_small"))
	var formation: String = str(entry.get("formation", "scatter"))
	var count: int = int(entry.get("count", 1))
	var spacing: float = float(entry.get("spacing", 2.0))
	var entry_z: float = float(entry.get("entry_z", -30.0))
	var offsets: Array = _get_formation_offsets(formation, count, spacing)
	if formation == "scatter":
		for i in range(count):
			var jitter_z: float = entry_z + randf_range(-2.0, 2.0)
			var world_pos := get_spawn_position(region_name, jitter_z)
			_spawn_typed_enemy(enemy_type, world_pos, region_name, jitter_z)
	else:
		var _base_offset := get_random_local_in_box(region_name)
		for i in range(count):
			var offset: Vector3 = offsets[i] if i < offsets.size() else Vector3.ZERO
			var jitter_z: float = entry_z + randf_range(-2.0, 2.0)
			var world_pos := get_spawn_position(region_name, jitter_z, offset)
			_spawn_typed_enemy(enemy_type, world_pos, region_name, jitter_z)

func _init_segment_system() -> void:
	if _segments_config.is_empty():
		_segment_end_progress = _track_length
		return
	var combat_segs: Array = []
	var boss_seg: Dictionary = {}
	for seg in _segments_config:
		if seg.get("is_boss", false):
			boss_seg = seg
		else:
			combat_segs.append(seg)
	combat_segs.shuffle()
	_segments_pool = combat_segs.duplicate(true)
	if not boss_seg.is_empty():
		_segments_pool.append(boss_seg)
	_total_segments_to_run = _segments_pool.size()
	track_path.curve = _build_segment_curve(_segments_pool[0])
	track_path.curve.bake_interval = 1.0
	_track_length = track_path.curve.get_baked_length()
	_segment_end_progress = _track_length
	_segment_start_progress = 0.0
	_load_segment_content(0)
	if not node_environment.is_empty():
		_switch_environment(node_environment)
	_current_segment_idx = 0
	_next_appended = false

func _build_segment_curve(seg: Dictionary) -> Curve3D:
	var curve_type: String = seg.get("curve_type", "straight")
	var curve := Curve3D.new()
	match curve_type:
		"straight":
			_curve_straight(curve)
		"canyon":
			_curve_canyon(curve)
		"swoop":
			_curve_swoop(curve)
		"boss_arena":
			_curve_boss_arena(curve)
		_, "straight":
			_curve_straight(curve)
	return curve

func _curve_straight(curve: Curve3D) -> void:
	var pts := [
		Vector3(0, 0, 0),
		Vector3(5, 2, -100),
		Vector3(-8, -1, -220),
		Vector3(10, 3, -340),
		Vector3(-5, -2, -460),
		Vector3(8, 1, -580),
		Vector3(-10, 3, -700),
		Vector3(5, -1, -820),
		Vector3(-3, 2, -940),
		Vector3(0, 0, -1050),
		Vector3(7, -2, -1200),
		Vector3(0, 0, -1350),
	]
	for p in pts:
		curve.add_point(p)
	_curve_auto_tangents(curve)

func _curve_canyon(curve: Curve3D) -> void:
	var pts := [
		Vector3(0, 0, 0),
		Vector3(-15, 0, -100),
		Vector3(-30, 2, -220),
		Vector3(-10, -1, -340),
		Vector3(20, 3, -460),
		Vector3(35, 0, -580),
		Vector3(15, -2, -700),
		Vector3(-10, 1, -820),
		Vector3(-30, 3, -940),
		Vector3(-10, 0, -1050),
		Vector3(20, -1, -1200),
		Vector3(0, 0, -1350),
	]
	for p in pts:
		curve.add_point(p)
	_curve_auto_tangents(curve)

func _curve_swoop(curve: Curve3D) -> void:
	var pts := [
		Vector3(0, 0, 0),
		Vector3(10, -8, -100),
		Vector3(-5, -15, -220),
		Vector3(-15, -5, -340),
		Vector3(0, 5, -460),
		Vector3(15, 15, -580),
		Vector3(10, 5, -700),
		Vector3(-5, -8, -820),
		Vector3(-15, -12, -940),
		Vector3(-5, 0, -1050),
		Vector3(10, 8, -1200),
		Vector3(0, 0, -1350),
	]
	for p in pts:
		curve.add_point(p)
	_curve_auto_tangents(curve)

func _curve_boss_arena(curve: Curve3D) -> void:
	var pts := [
		Vector3(0, 0, 0),
		Vector3(0, 0, -150),
		Vector3(0, 0, -350),
		Vector3(0, 0, -550),
		Vector3(0, 0, -750),
		Vector3(0, 0, -950),
		Vector3(0, 0, -1150),
		Vector3(0, 0, -1350),
	]
	for p in pts:
		curve.add_point(p)
	_curve_auto_tangents(curve)

func _curve_auto_tangents(curve: Curve3D) -> void:
	var count := curve.point_count
	if count < 2:
		return
	for i in range(count):
		var pos := curve.get_point_position(i)
		var in_t: Vector3 = Vector3.ZERO
		var out_t: Vector3 = Vector3.ZERO
		if i > 0:
			var prev := curve.get_point_position(i - 1)
			in_t = (prev - pos) * 0.3
		if i < count - 1:
			var next := curve.get_point_position(i + 1)
			out_t = (next - pos) * 0.3
		curve.set_point_in(i, in_t)
		curve.set_point_out(i, out_t)

func _generate_hermite_transition(end_pos: Vector3, end_tangent: Vector3, start_pos: Vector3, start_tangent: Vector3) -> Curve3D:
	var trans := Curve3D.new()
	var dist := (start_pos - end_pos).length()
	var seg_count := 5
	for i in range(seg_count + 1):
		var t := float(i) / float(seg_count)
		var t2 := t * t
		var t3 := t2 * t
		var h00 := 2.0 * t3 - 3.0 * t2 + 1.0
		var h10 := t3 - 2.0 * t2 + t
		var h01 := -2.0 * t3 + 3.0 * t2
		var h11 := t3 - t2
		var p := h00 * end_pos + h10 * end_tangent * dist + h01 * start_pos + h11 * start_tangent * dist
		trans.add_point(p)
	_curve_auto_tangents(trans)
	return trans

func _check_segment_transition() -> void:
	if _segments_pool.is_empty() or _next_appended:
		return
	if path_follow == null or track_path == null or track_path.curve == null:
		return
	var progress := path_follow.progress
	var remaining := _segment_end_progress - progress
	var threshold := track_speed * 3.0
	if remaining > threshold:
		return
	_next_appended = true
	_next_segment()

func _next_segment() -> void:
	_current_segment_idx += 1
	if _current_segment_idx >= _segments_pool.size():
		return
	var next_seg: Dictionary = _segments_pool[_current_segment_idx]
	var next_curve := _build_segment_curve(next_seg)
	var current_curve := track_path.curve
	var last_idx := current_curve.point_count - 1
	var end_pos := current_curve.get_point_position(last_idx)
	var end_tangent := current_curve.get_point_out(last_idx)
	var first_pos := next_curve.get_point_position(0)
	var first_tangent := next_curve.get_point_in(0)
	var offset := end_pos - first_pos
	var transition := _generate_hermite_transition(end_pos, end_tangent * 3.0, first_pos + offset, first_tangent * 3.0)
	for i in range(1, transition.point_count):
		current_curve.add_point(transition.get_point_position(i),
			transition.get_point_in(i), transition.get_point_out(i))
	for i in range(1, next_curve.point_count):
		var p := next_curve.get_point_position(i) + offset
		var inp := next_curve.get_point_in(i)
		var outp := next_curve.get_point_out(i)
		current_curve.add_point(p, inp, outp)
	track_path.curve.bake_interval = 1.0
	var old_end := _segment_end_progress
	_track_length = track_path.curve.get_baked_length()
	_segment_end_progress = _track_length
	_segment_start_progress = old_end
	_load_segment_content(_current_segment_idx)

func _load_segment_content(seg_idx: int) -> void:
	if seg_idx >= _segments_pool.size():
		return
	var seg: Dictionary = _segments_pool[seg_idx]
	_waves_config = seg.get("waves", [])
	_asteroid_config = seg.get("asteroid", {})
	_wave_queue_spawned.clear()
	_asteroid_spawned.clear()
	_segment_wave_spawned.clear()
	_segment_asteroid_spawned.clear()
	_next_appended = false
	_switch_environment(seg.get("environment", ""))
	if _segment_label:
		_segment_label.text = "SECTOR %d/%d" % [seg_idx + 1, _total_segments_to_run]

func _switch_environment(env_path: String) -> void:
	if env_path.is_empty():
		return
	push_warning("[ENV] switch to: %s (current: %s)" % [env_path, _current_env_path])
	if env_path == _current_env_path:
		return
	if _current_env_instance:
		_current_env_instance.queue_free()
		_current_env_instance = null
	_current_env_path = env_path
	_clear_starfield()
	var env_scene := load(env_path) as PackedScene
	if not env_scene:
		push_warning("Failed to load environment: %s" % env_path)
		return
	_current_env_instance = env_scene.instantiate() as Node3D
	add_child(_current_env_instance)
	var env_we: WorldEnvironment = _current_env_instance.get_node_or_null("WorldEnvironment")
	if env_we and _world_env:
		_world_env.environment = env_we.environment
		_current_env_instance.remove_child(env_we)
		env_we.queue_free()
	if env_path.find("space") >= 0:
		_create_space_starfield()

func _clear_starfield() -> void:
	if not _starfield_parent:
		return
	for child in _starfield_parent.get_children():
		child.queue_free()

func _create_space_starfield() -> void:
	if not _starfield_parent:
		return
	var far_stars := GPUParticles3D.new()
	far_stars.name = "FarStars"
	_starfield_parent.add_child(far_stars)
	var far_mat := ParticleProcessMaterial.new()
	far_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	far_mat.emission_box_extents = Vector3(200, 200, 400)
	far_mat.direction = Vector3.ZERO
	far_mat.spread = 0.0
	far_mat.gravity = Vector3.ZERO
	far_mat.initial_velocity_min = 0.0
	far_mat.initial_velocity_max = 0.0
	far_stars.process_material = far_mat
	far_stars.amount = 500
	far_stars.lifetime = 999.0
	far_stars.one_shot = true
	far_stars.explosiveness = 1.0
	var far_mesh := QuadMesh.new()
	far_mesh.size = Vector2(0.3, 0.3)
	var far_draw := StandardMaterial3D.new()
	far_draw.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	far_draw.albedo_color = Color.WHITE
	far_draw.vertex_color_use_as_albedo = true
	far_mesh.material = far_draw
	far_stars.draw_pass_1 = far_mesh
	var near_stars := GPUParticles3D.new()
	near_stars.name = "NearStars"
	_starfield_parent.add_child(near_stars)
	var near_mat := ParticleProcessMaterial.new()
	near_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	near_mat.emission_box_extents = Vector3(30, 30, 50)
	near_mat.direction = Vector3(0, 0, 1)
	near_mat.spread = 5.0
	near_mat.gravity = Vector3.ZERO
	near_mat.initial_velocity_min = 100.0
	near_mat.initial_velocity_max = 150.0
	near_stars.process_material = near_mat
	near_stars.amount = 200
	near_stars.lifetime = 2.0
	var near_mesh := QuadMesh.new()
	near_mesh.size = Vector2(0.08, 0.3)
	var near_draw := StandardMaterial3D.new()
	near_draw.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	near_draw.albedo_color = Color(0.7, 0.85, 1.0, 0.6)
	near_draw.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	near_mesh.material = near_draw
	near_stars.draw_pass_1 = near_mesh

func _update_ui() -> void:
	var effective_hp_max := _get_stat(base_hp_max, "hp_max")
	if _hp_bar_mat:
		_hp_bar_mat.set_shader_parameter("progress", hp / effective_hp_max)
	if _score_label:
		_score_label.text = "SCORE: %d" % score
	if _heat_label:
		var has_laser: bool = upgrade_system != null and upgrade_system.has_method("has_upgrade") and upgrade_system.has_upgrade("laser_beam")
		_heat_label.visible = has_laser
		if has_laser:
			var pct := int(_laser_heat / _laser_max_heat * 100.0)
			_heat_label.text = "HEAT: %d%%" % pct
			if _laser_overheated:
				_heat_label.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2, 0.9))
			else:
				_heat_label.add_theme_color_override("font_color", Color(0.3, 0.7, 1.0, 0.9))
	if _missile_label:
		var has_missile: bool = upgrade_system != null and upgrade_system.has_method("has_upgrade") and upgrade_system.has_upgrade("homing_missile")
		_missile_label.visible = false

func _get_difficulty_multiplier() -> float:
	var hp_ratio := hp / hp_max
	if hp_ratio > 0.8: return 1.3
	if hp_ratio < 0.3: return 0.6
	return 1.0
