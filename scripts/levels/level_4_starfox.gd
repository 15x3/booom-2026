extends Node3D

signal level_completed
signal level_failed
signal sfx_requested(sfx_name: String)

var config: Dictionary = {}
var hp: float = 100.0
var hp_max: float = 100.0
var score: int = 0

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
var base_fov: float = 70.0

var shake_engine_amp: float = 0.01
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
var _crosshair_depth_default: float = 25.0
var _crosshair_locked: bool = false
var _crosshair_ring: MeshInstance3D = null
var _crosshair_ring_mat: StandardMaterial3D = null
var fire_timer: float = 0.0
var _track_length: float = 0.0
var _wave_spawned: Dictionary = {}
var _wave_triggers: Dictionary = {}
var _alive: bool = true
var _time: float = 0.0
var _asteroid_spawned: Dictionary = {}
var _asteroid_config: Dictionary = {}

var _shake_fire_elapsed: float = -1.0
var _shake_hit_elapsed: float = -1.0

var _bullet_player_scene: PackedScene
var _bullet_enemy_scene: PackedScene
var _enemy_small_scene: PackedScene
var _enemy_medium_scene: PackedScene
var _enemy_boss_scene: PackedScene
var _asteroid_scene: PackedScene
var _explosion_script: GDScript

var _barrel_roll_active: bool = false
var _barrel_roll_cooldown: float = 0.0
var _barrel_roll_duration: float = 0.4
var _barrel_roll_cooldown_time: float = 1.5
var _barrel_roll_timer: float = 0.0
var _is_invincible: bool = false

var _finishing: bool = false
var _finish_timer: float = 0.0
var _finish_delay: float = 2.0
var _dying: bool = false
var _death_timer: float = 0.0
var _death_delay: float = 1.5

func _ready() -> void:
	_load_config()
	_load_scenes()
	_setup_scene()
	_setup_starfield()

func _load_config() -> void:
	var file := FileAccess.open("res://assets/data/game_config.json", FileAccess.READ)
	if file:
		var json := JSON.new()
		json.parse(file.get_as_text())
		var data: Dictionary = json.data
		if data.has("starfox"):
			config = data["starfox"]
			hp_max = float(config.get("hp_max", 100.0))
			hp = hp_max
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
			base_fov = float(config.get("base_fov", 70.0))
			shake_engine_amp = float(config.get("shake_engine_amp", 0.01))
			shake_engine_freq_x = float(config.get("shake_engine_freq_x", 13.0))
			shake_engine_freq_y = float(config.get("shake_engine_freq_y", 17.0))
			shake_fire_amp = float(config.get("shake_fire_amp", 0.02))
			shake_fire_duration = float(config.get("shake_fire_duration", 0.08))
			shake_hit_amp = float(config.get("shake_hit_amp", 0.15))
			shake_hit_duration = float(config.get("shake_hit_duration", 0.3))
			shake_hit_decay = float(config.get("shake_hit_decay", 8.0))
			shake_threshold = float(config.get("shake_threshold", 0.001))
			_crosshair_depth_default = float(config.get("crosshair_depth_default", 25.0))
			_barrel_roll_duration = float(config.get("barrel_roll_duration", 0.4))
			_barrel_roll_cooldown_time = float(config.get("barrel_roll_cooldown", 1.5))
			if config.has("wave_triggers"):
				_wave_triggers = config["wave_triggers"]
			if config.has("asteroid"):
				_asteroid_config = config["asteroid"]
			_finish_delay = float(config.get("finish_delay", 2.0))
			_death_delay = float(config.get("death_delay", 1.5))
		file.close()

func _load_scenes() -> void:
	_bullet_player_scene = load("res://scenes/level4/bullet-player.tscn") as PackedScene
	_bullet_enemy_scene = load("res://scenes/level4/bullet-enemy.tscn") as PackedScene
	_enemy_small_scene = load("res://scenes/level4/enemy-small.tscn") as PackedScene
	_enemy_medium_scene = load("res://scenes/level4/enemy-medium.tscn") as PackedScene
	_enemy_boss_scene = load("res://scenes/level4/enemy-boss.tscn") as PackedScene
	_asteroid_scene = load("res://scenes/level4/asteroid.tscn") as PackedScene
	_explosion_script = load("res://scripts/levels/level4_explosion.gd") as GDScript

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
		_crosshair_ring = crosshair.get_node_or_null("Ring")
		if _crosshair_ring and _crosshair_ring.material_override:
			_crosshair_ring_mat = _crosshair_ring.material_override.duplicate()
			_crosshair_ring.material_override = _crosshair_ring_mat

	if track_path:
		if track_path.curve == null or track_path.curve.point_count < 3 or track_path.curve.get_baked_length() < 100.0:
			_build_track_curve()
		if track_path.curve:
			track_path.curve.bake_interval = 1.0
			_track_length = track_path.curve.get_baked_length()

	if ship_instance:
		var ship_hitbox: Area3D = ship_instance.get_node("Hitbox")
		if ship_hitbox:
			ship_hitbox.area_entered.connect(_on_ship_hit)

	if camera:
		camera.current = true
		camera.fov = base_fov

func _build_track_curve() -> void:
	var curve := Curve3D.new()
	var pts: Array[Dictionary] = [
		{"pos": Vector3(0, 0, 0), "in": Vector3.ZERO, "out": Vector3(0, 0, -60)},
		{"pos": Vector3(0, 0, -200), "in": Vector3(0, 0, 60), "out": Vector3(0, 0, -60)},
		{"pos": Vector3(20, 0, -400), "in": Vector3(0, 0, 60), "out": Vector3(5, 0, -30)},
		{"pos": Vector3(40, 3, -600), "in": Vector3(-5, 0, 30), "out": Vector3(0, 0, -60)},
		{"pos": Vector3(10, 0, -770), "in": Vector3(0, 0, 60), "out": Vector3(0, 0, -40)},
		{"pos": Vector3(-30, 0, -940), "in": Vector3(0, 0, 40), "out": Vector3(0, 0, -30)},
		{"pos": Vector3(-30, 0, -1100), "in": Vector3(0, 0, 30), "out": Vector3(0, 0, -50)},
		{"pos": Vector3(-20, 0, -1260), "in": Vector3(0, 0, 50), "out": Vector3(0, 0, -60)},
		{"pos": Vector3(0, 0, -1420), "in": Vector3(0, 0, 60), "out": Vector3(0, 0, -40)},
		{"pos": Vector3(-30, -8, -1580), "in": Vector3(0, 0, 40), "out": Vector3(0, 0, -40)},
		{"pos": Vector3(-40, -8, -1720), "in": Vector3(0, 0, 40), "out": Vector3(-10, 12, 40)},
		{"pos": Vector3(-20, 5, -1870), "in": Vector3(10, -12, -40), "out": Vector3(0, 0, -60)},
		{"pos": Vector3(0, 10, -2020), "in": Vector3(0, 0, 60), "out": Vector3(0, 0, -50)},
		{"pos": Vector3(10, 5, -2170), "in": Vector3(0, 0, 50), "out": Vector3(0, 0, 0)},
		{"pos": Vector3(0, 0, -2320), "in": Vector3(0, 0, 0), "out": Vector3(20, 0, -30)},
		{"pos": Vector3(20, 0, -2440), "in": Vector3(-20, 0, 30), "out": Vector3(-20, 0, -30)},
		{"pos": Vector3(-20, 0, -2520), "in": Vector3(20, 0, 30), "out": Vector3(0, 0, -60)},
		{"pos": Vector3(0, 0, -2700), "in": Vector3(0, 0, 60), "out": Vector3.ZERO},
	]
	for p in pts:
		curve.add_point(p["pos"], p["in"], p["out"])
	curve.bake_interval = 1.0
	track_path.curve = curve

func _setup_starfield() -> void:
	var far_stars := $TrackPath/PathFollow3D/Starfield/Stars as GPUParticles3D
	if far_stars:
		var far_mat := ParticleProcessMaterial.new()
		far_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
		far_mat.emission_box_extents = Vector3(200, 200, 400)
		far_mat.direction = Vector3(0, 0, 0)
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
	$TrackPath/PathFollow3D/Starfield.add_child(near_stars)
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

func _physics_process(delta: float) -> void:
	if _finishing:
		_process_finishing(delta)
		return
	if _dying:
		_process_dying(delta)
		return
	if not _alive:
		return
	_time += delta
	_move_track(delta)
	_update_crosshair(delta)
	_update_ship(delta)
	_update_camera(delta)
	_update_shake(delta)
	_handle_shooting(delta)
	_update_barrel_roll(delta)
	_check_waves()
	_check_asteroid_spawns()
	_cleanup_behind()

func _move_track(delta: float) -> void:
	if path_follow and _track_length > 0:
		var current_speed := track_speed
		if path_follow.progress_ratio > 0.9:
			var slowdown := (path_follow.progress_ratio - 0.9) / 0.1
			current_speed = track_speed * (1.0 - slowdown * 0.7)
		path_follow.progress += current_speed * delta
		if path_follow.progress_ratio >= 1.0:
			_finishing = true
			_finish_timer = 0.0
			_alive = false

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
	if crosshair == null:
		return
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
	crosshair.position.x = crosshair_offset.x
	crosshair.position.y = crosshair_offset.y
	_update_crosshair_depth()

func _update_crosshair_depth() -> void:
	if crosshair == null or ship_anchor == null:
		return
	var from := ship_anchor.global_position
	var aim_offset := Vector3(crosshair_offset.x, crosshair_offset.y, -_crosshair_depth_default)
	var target_global := path_follow.global_transform * aim_offset
	var dir := (target_global - from)
	if dir.length_squared() < 0.01:
		crosshair.position.z = -_crosshair_depth_default
		_set_crosshair_locked(false)
		return
	dir = dir.normalized()
	var max_dist := _crosshair_depth_default + 10.0
	var space_state := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(from, from + dir * max_dist)
	query.collision_mask = 2
	query.collide_with_areas = true
	var result := space_state.intersect_ray(query)
	if result and result.has("position") and result.has("collider"):
		var hit_pos: Vector3 = result["position"]
		var local_hit := path_follow.global_transform.affine_inverse() * hit_pos
		crosshair.position.z = local_hit.z
		_set_crosshair_locked(true)
	else:
		crosshair.position.z = -_crosshair_depth_default
		_set_crosshair_locked(false)

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

func _update_ship(_delta: float) -> void:
	if ship_anchor == null or ship_instance == null:
		return
	var target_pos := Vector3(crosshair_offset.x, crosshair_offset.y, 0.0)
	var current_pos := ship_anchor.position
	var diff := target_pos - current_pos
	if diff.length() < ship_snap_threshold:
		ship_anchor.position = target_pos
	else:
		ship_anchor.position = current_pos.lerp(target_pos, ship_follow_weight)
	var lateral_diff: float = target_pos.x - current_pos.x
	var target_bank: float = -clampf(lateral_diff * 2.0, -1.0, 1.0) * bank_angle
	if not _barrel_roll_active:
		ship_instance.rotation.z = lerp(ship_instance.rotation.z, target_bank, bank_speed)

func _update_camera(_delta: float) -> void:
	if camera_rig == null or camera == null or ship_anchor == null:
		return
	var target_x := ship_anchor.position.x
	camera_rig.position.x = lerp(camera_rig.position.x, target_x, camera_follow_weight)
	var look_target := ship_anchor.global_position + Vector3(0.0, 0.0, -camera_lookahead)
	var cam_pos := camera.global_position
	var to_target := look_target - cam_pos
	if to_target.length_squared() < 0.001:
		return
	var target_basis := camera.global_transform.looking_at(cam_pos + to_target.normalized(), Vector3.UP)
	camera.global_transform = camera.global_transform.interpolate_with(target_basis, camera_follow_weight)

func _update_shake(delta: float) -> void:
	if shake_container == null:
		return
	shake_container.position = Vector3.ZERO
	var offset := Vector3.ZERO
	offset.x = sin(_time * shake_engine_freq_x) * shake_engine_amp
	offset.y = sin(_time * shake_engine_freq_y) * shake_engine_amp
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
			var t: float = exp(-shake_hit_decay * _shake_fire_elapsed)
			if t > shake_threshold:
				offset.x += shake_hit_amp * t * randf_range(-1.0, 1.0)
				offset.y += shake_hit_amp * t * randf_range(-1.0, 1.0)
			else:
				_shake_hit_elapsed = -1.0
		else:
			_shake_hit_elapsed = -1.0
	shake_container.position = offset

func _handle_shooting(delta: float) -> void:
	fire_timer -= delta
	if Input.is_key_pressed(KEY_SPACE) and fire_timer <= 0.0 and _bullet_player_scene:
		fire_timer = fire_cooldown
		_fire_player_bullet()

func _fire_player_bullet() -> void:
	var bullet: Node3D = _bullet_player_scene.instantiate()
	projectiles_container.add_child(bullet)
	var ship_pos := ship_anchor.global_position
	var aim_pos := crosshair.global_position
	var dir := (aim_pos - ship_pos)
	if dir.length_squared() < 0.01:
		dir = -path_follow.global_basis.z
	else:
		dir = dir.normalized()
	bullet.global_position = ship_pos + dir * 1.5
	bullet.velocity = dir * bullet_speed
	bullet.lifetime = bullet_life
	bullet.is_player_bullet = true
	bullet.magnet_radius = float(config.get("bullet_magnet_radius", 3.0))
	bullet.magnet_strength = float(config.get("bullet_magnet_strength", 3.0))
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

func _check_waves() -> void:
	if path_follow == null:
		return
	var ratio := path_follow.progress_ratio
	for wave_name: String in _wave_triggers:
		if _wave_spawned.has(wave_name):
			continue
		var trigger: float = _wave_triggers[wave_name]
		if trigger < 0:
			continue
		if ratio >= trigger:
			_wave_spawned[wave_name] = true
			_spawn_wave(wave_name)

func _spawn_wave(wave_name: String) -> void:
	var wave_node: Node = $SpawnMarkers.get_node_or_null(wave_name)
	if wave_node == null:
		push_warning("Wave %s: no SpawnMarkers child found" % wave_name)
		return
	push_warning("Spawning wave: %s with %d markers" % [wave_name, wave_node.get_child_count()])
	for marker: Marker3D in wave_node.get_children():
		if not marker is Marker3D:
			continue
		var mn: String = marker.name
		var enemy_type: String = ""
		if mn.begins_with("S"):
			enemy_type = "enemy_small"
		elif mn.begins_with("M"):
			enemy_type = "enemy_medium"
		elif mn.begins_with("B"):
			enemy_type = "enemy_boss"
		if enemy_type != "":
			var spawn_pos := _get_path_aligned_position(marker.global_position)
			_spawn_typed_enemy(enemy_type, spawn_pos)

func _get_path_aligned_position(marker_pos: Vector3) -> Vector3:
	if track_path == null or track_path.curve == null:
		return marker_pos
	var curve := track_path.curve
	var baked_len := curve.get_baked_length()
	if baked_len <= 0.0:
		return marker_pos
	var marker_z := marker_pos.z
	var best_dist := INF
	var best_point := marker_pos
	var steps := int(baked_len / 2.0)
	for i: int in range(steps + 1):
		var d := (float(i) / float(steps)) * baked_len
		var pt := curve.sample_baked(d)
		var dz := absf(pt.z - marker_z)
		if dz < best_dist:
			best_dist = dz
			best_point = pt
	return Vector3(
		best_point.x + marker_pos.x,
		best_point.y + marker_pos.y,
		best_point.z
	)

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

func _spawn_typed_enemy(enemy_type: String, world_pos: Vector3) -> void:
	var scene: PackedScene = null
	match enemy_type:
		"enemy_small":
			scene = _enemy_small_scene
		"enemy_medium":
			scene = _enemy_medium_scene
		"enemy_boss":
			scene = _enemy_boss_scene
	if scene == null:
		return
	var enemy: Node3D = scene.instantiate()
	enemies_container.add_child(enemy)
	enemy.global_position = world_pos
	var enemy_cfg: Dictionary = config.get(enemy_type, {})
	var pts: int = int(enemy_cfg.get("score", 10))
	if enemy.has_signal("destroyed"):
		if enemy_type == "enemy_boss":
			enemy.destroyed.connect(_on_boss_destroyed.bind(enemy))
		else:
			enemy.destroyed.connect(_on_enemy_destroyed.bind(enemy, pts))
	if enemy.has_method("setup"):
		enemy.setup(ship_anchor, path_follow, enemy_cfg, track_speed, Vector2(crosshair_range_x * 0.8, crosshair_range_y * 0.8))
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

func _on_boss_destroyed(boss: Node3D) -> void:
	score += int(config.get("enemy_boss", {}).get("score", 500))
	var boss_pos := boss.global_position if (boss and is_instance_valid(boss)) else Vector3.ZERO
	_spawn_explosion(boss_pos, Color(1.0, 0.3, 0.1), true)
	sfx_requested.emit("explosion_boss")
	await get_tree().create_timer(1.0).timeout
	_finishing = true
	_finish_timer = 0.0
	_alive = false

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
			if ship_instance:
				ship_instance.rotation.z = 0.0
		return
	if ship_instance and (Input.is_key_pressed(KEY_Q) or Input.is_key_pressed(KEY_E)):
		if _barrel_roll_cooldown <= 0.0:
			_start_barrel_roll()

func _start_barrel_roll() -> void:
	_barrel_roll_active = true
	_barrel_roll_timer = 0.0
	_is_invincible = true
	_barrel_roll_cooldown = _barrel_roll_cooldown_time
	sfx_requested.emit("barrel_roll")
	if ship_instance == null:
		return
	var direction: float = -1.0 if Input.is_key_pressed(KEY_Q) else 1.0
	var start_rot: float = ship_instance.rotation.z
	var end_rot: float = start_rot + direction * TAU
	var tween := create_tween()
	tween.tween_property(ship_instance, "rotation:z", end_rot, _barrel_roll_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tween.tween_callback(func() -> void:
		if is_instance_valid(ship_instance):
			ship_instance.rotation.z = 0.0
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
	sfx_requested.emit("player_hit")
	if hp <= 0.0:
		_alive = false
		_dying = true
		_death_timer = 0.0
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
		"hp_max": hp_max,
		"score": score,
		"progress": get_track_progress()
	}
