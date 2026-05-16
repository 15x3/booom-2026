extends Node3D

signal destroyed
signal fire_bullet(pos: Vector3, dir: Vector3)

enum State {
	ENTRY,
	ATTACK,
	EVADE,
	EXIT,
	DYING,
}

var state: State = State.ENTRY

var hp: float = 1.0
var max_hp: float = 1.0
var _alive: bool = true
var _time: float = 0.0
var _state_time: float = 0.0
var _seed: float = 0.0

var _player_ref: Node3D = null
var _path_follow_ref: PathFollow3D = null
var _track_speed: float = 30.0

var _entry_path: Path3D = null
var _entry_path_follow: PathFollow3D = null

var _cfg: Dictionary = {}

var _fire_timer: float = 0.0
var _burst_fired: int = 0
var _burst_pause_timer: float = 0.0
var _phase: int = 0

var _harass_timer: float = 0.0
var _lissa_phase: float = 0.0

var _evade_dir: Vector3 = Vector3.ZERO
var _evade_start: Vector3 = Vector3.ZERO
var _evade_cooldown_timer: float = 0.0
var _evade_telegraph_timer: float = 0.0

var _death_vel: Vector3 = Vector3.ZERO
var _death_spin_axis: Vector3 = Vector3.UP
var _death_spin_speed: float = 5.0
var _death_duration: float = 0.5
var _combat_bounds: Vector2 = Vector2(6.0, 4.4)

func _to_local(world_pos: Vector3) -> Vector3:
	if not _path_follow_ref or not is_instance_valid(_path_follow_ref):
		return world_pos
	return _path_follow_ref.global_transform.affine_inverse() * world_pos

func _to_world(local_pos: Vector3) -> Vector3:
	if not _path_follow_ref or not is_instance_valid(_path_follow_ref):
		return local_pos
	return _path_follow_ref.global_transform * local_pos

var _cached_player_vel: Vector3 = Vector3.ZERO
var _prev_player_pos: Vector3 = Vector3.ZERO
var _lock_timer: float = 0.0
var _player_firing: bool = false
var _attack_center: Vector3 = Vector3.ZERO
var _out_of_view_timer: float = 0.0
var _exit_pull_dir: Vector2 = Vector2.ZERO
var _spawn_face: String = "FrontSpawn"
var _entry_z: float = -30.0
var _straightening: bool = false

func setup(ship_anchor: Node3D, path_follow: PathFollow3D, cfg: Dictionary, track_speed: float, combat_bounds: Vector2 = Vector2(6.0, 4.4), spawn_face: String = "FrontSpawn", entry_z: float = -30.0) -> void:
	_player_ref = ship_anchor
	_path_follow_ref = path_follow
	_cfg = cfg
	_track_speed = track_speed
	_combat_bounds = combat_bounds
	_spawn_face = spawn_face
	_entry_z = entry_z
	_seed = randf() * TAU
	max_hp = float(cfg.get("hp", 1.0))
	hp = max_hp
	_death_spin_speed = float(cfg.get("death_spin_speed", 5.0))
	_death_duration = float(cfg.get("death_duration", 0.5))
	if _player_ref and is_instance_valid(_player_ref):
		_prev_player_pos = _player_ref.global_position
	var entry_offset := float(cfg.get("entry_target_z_offset", -15.0))
	_entry_target_z = entry_offset
	_burst_fired = 0
	_relative_z = entry_z
	if spawn_face != "FrontSpawn":
		_snap_z_to_track()
	match spawn_face:
		"LeftSpawn":
			rotation = Vector3(0.0, deg_to_rad(45.0), 0.3)
		"RightSpawn":
			rotation = Vector3(0.0, deg_to_rad(-45.0), -0.3)
		"TopSpawn":
			rotation = Vector3(deg_to_rad(-25.0), 0.0, 0.0)
		"DownSpawn":
			rotation = Vector3(deg_to_rad(15.0), 0.0, 0.0)

func set_entry_path(path: Path3D) -> void:
	_entry_path = path

func _physics_process(delta: float) -> void:
	if not _alive and state != State.DYING:
		return
	_time += delta
	_state_time += delta
	_update_player_tracking(delta)
	_evade_cooldown_timer = maxf(0.0, _evade_cooldown_timer - delta)

	match state:
		State.ENTRY:
			_process_entry(delta)
		State.ATTACK:
			_process_attack(delta)
		State.EVADE:
			_process_evade(delta)
		State.EXIT:
			_process_exit(delta)
		State.DYING:
			_process_dying(delta)

func _update_player_tracking(delta: float) -> void:
	if _player_ref and is_instance_valid(_player_ref):
		var cur_pos := _player_ref.global_position
		if delta > 0.0:
			_cached_player_vel = (cur_pos - _prev_player_pos) / delta
		_prev_player_pos = cur_pos
	_player_firing = Input.is_key_pressed(KEY_SPACE)

func _snap_z_to_track() -> void:
	if _path_follow_ref and is_instance_valid(_path_follow_ref):
		var z_diff := global_position.z - _path_follow_ref.global_position.z
		_relative_z = z_diff

var _relative_z: float = -50.0
var _entry_target_z: float = -15.0

func _process_entry(delta: float) -> void:
	if _entry_path and _entry_path.curve and _entry_path.curve.get_baked_length() > 0.0:
		if _entry_path_follow == null:
			_entry_path_follow = PathFollow3D.new()
			_entry_path.add_child(_entry_path_follow)
		var entry_speed := float(_cfg.get("entry_speed", 60.0))
		_entry_path_follow.progress += entry_speed * delta
		global_position = _entry_path_follow.global_position
		if _entry_path_follow.progress_ratio >= 1.0:
			_snap_z_to_track()
			_lissa_phase = randf() * TAU
			_attack_center = _to_local(global_position)
			_transition_to(State.ATTACK)
		return
	match _spawn_face:
		"FrontSpawn", _:
			_process_entry_front(delta)
		"LeftSpawn":
			_process_entry_flank(delta, 1.0)
		"RightSpawn":
			_process_entry_flank(delta, -1.0)
		"TopSpawn":
			_process_entry_dive(delta)
		"DownSpawn":
			_process_entry_rise(delta)

func _finish_entry() -> void:
	_snap_z_to_track()
	_lissa_phase = randf() * TAU
	_attack_center = _to_local(global_position)
	_transition_to(State.ATTACK)

func _start_straighten() -> void:
	if _straightening:
		return
	_straightening = true
	var tween := create_tween()
	tween.tween_property(self, "rotation", Vector3.ZERO, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _process_entry_front(delta: float) -> void:
	var ease_weight := float(_cfg.get("entry_ease_weight", 4.0))
	if _path_follow_ref and is_instance_valid(_path_follow_ref):
		_relative_z = lerpf(_relative_z, _entry_target_z, ease_weight * delta)
		var xy_weight := ease_weight * 0.5
		var target_x: float = global_position.x
		var target_y: float = global_position.y
		if _player_ref and is_instance_valid(_player_ref):
			target_x = _player_ref.global_position.x
			target_y = _player_ref.global_position.y
		global_position.x = lerpf(global_position.x, target_x, xy_weight * delta)
		global_position.y = lerpf(global_position.y, target_y, xy_weight * delta)
		global_position.z = _path_follow_ref.global_position.z + _relative_z
		if absf(_relative_z - _entry_target_z) < 1.0:
			_finish_entry()

func _process_entry_flank(delta: float, dir: float) -> void:
	if not _path_follow_ref or not is_instance_valid(_path_follow_ref):
		return
	var entry_weight := float(_cfg.get("entry_ease_weight", 4.0))
	var local_pos := _path_follow_ref.global_transform.affine_inverse() * global_position
	var target_x: float = 0.0
	if _player_ref and is_instance_valid(_player_ref):
		target_x = _player_ref.global_position.x - _path_follow_ref.global_position.x
	local_pos.x = lerpf(local_pos.x, target_x, entry_weight * delta)
	local_pos.y = lerpf(local_pos.y, 0.0, entry_weight * 0.5 * delta)
	_relative_z = lerpf(_relative_z, _entry_target_z, entry_weight * 0.5 * delta)
	local_pos.z = _relative_z
	global_position = _path_follow_ref.global_transform * local_pos
	if absf(local_pos.x) < _combat_bounds.x * 0.8:
		_start_straighten()
	if absf(local_pos.x) < _combat_bounds.x * 0.5 and absf(_relative_z - _entry_target_z) < 2.0:
		_finish_entry()

func _process_entry_dive(delta: float) -> void:
	if not _path_follow_ref or not is_instance_valid(_path_follow_ref):
		return
	var entry_weight := float(_cfg.get("entry_ease_weight", 4.0))
	var local_pos := _path_follow_ref.global_transform.affine_inverse() * global_position
	local_pos.y = lerpf(local_pos.y, 0.0, entry_weight * delta)
	local_pos.x = lerpf(local_pos.x, 0.0, entry_weight * 0.3 * delta)
	_relative_z = lerpf(_relative_z, _entry_target_z, entry_weight * 0.5 * delta)
	local_pos.z = _relative_z
	global_position = _path_follow_ref.global_transform * local_pos
	if absf(local_pos.y) < _combat_bounds.y * 0.8:
		_start_straighten()
	if absf(local_pos.y) < _combat_bounds.y * 0.5 and absf(_relative_z - _entry_target_z) < 2.0:
		_finish_entry()

func _process_entry_rise(delta: float) -> void:
	if not _path_follow_ref or not is_instance_valid(_path_follow_ref):
		return
	var entry_weight := float(_cfg.get("entry_ease_weight", 4.0))
	var local_pos := _path_follow_ref.global_transform.affine_inverse() * global_position
	local_pos.y = lerpf(local_pos.y, 0.0, entry_weight * delta)
	local_pos.x = lerpf(local_pos.x, 0.0, entry_weight * 0.3 * delta)
	_relative_z = lerpf(_relative_z, _entry_target_z, entry_weight * 0.5 * delta)
	local_pos.z = _relative_z
	global_position = _path_follow_ref.global_transform * local_pos
	if absf(local_pos.y) < _combat_bounds.y * 0.8:
		_start_straighten()
	if absf(local_pos.y) < _combat_bounds.y * 0.5 and absf(_relative_z - _entry_target_z) < 2.0:
		_finish_entry()

func _process_attack(delta: float) -> void:
	var attack_type: String = _cfg.get("attack_type", "flyby")
	match attack_type:
		"flyby":
			_attack_flyby(delta)
		"sniping":
			_attack_sniping(delta)
		"reactive":
			_attack_reactive(delta)

	if _cfg.get("attack_type", "") == "reactive":
		_check_evade_trigger(delta)

	_check_out_of_view(delta)


func _check_in_view() -> bool:
	if not _path_follow_ref or not is_instance_valid(_path_follow_ref):
		return true
	var cam_fwd := -_path_follow_ref.global_basis.z
	var to_self := (global_position - _path_follow_ref.global_position)
	var dist := to_self.length()
	if dist < 1.0:
		return true
	var angle := acos(clampf(cam_fwd.dot(to_self / dist), -1.0, 1.0))
	var half_fov := deg_to_rad(35.0)
	return angle < half_fov * 1.3


func _check_out_of_view(delta: float) -> void:
	if _check_in_view():
		_out_of_view_timer = 0.0
		return
	_out_of_view_timer += delta
	if _out_of_view_timer > 2.0:
		_transition_to(State.EXIT)

func _attack_flyby(delta: float) -> void:
	_harass_timer += delta
	var harass_time := float(_cfg.get("harass_time", 8.0))
	var orbit_fx := float(_cfg.get("orbit_freq_x", 1.2))
	var orbit_fy := float(_cfg.get("orbit_freq_y", 0.8))
	var orbit_amp_x := float(_cfg.get("orbit_amp_x", 3.0))
	var orbit_amp_y := float(_cfg.get("orbit_amp_y", 1.5))
	var drift_weight := float(_cfg.get("flyby_drift_weight", 0.3))
	var harass_z := float(_cfg.get("flyby_harass_z", -10.0))

	_lissa_phase += delta
	var orbit_x := cos(_lissa_phase * orbit_fx + _seed) * orbit_amp_x
	var orbit_y := sin(_lissa_phase * orbit_fy + _seed) * orbit_amp_y
	var local_x := clampf(_attack_center.x + orbit_x, -_combat_bounds.x, _combat_bounds.x)
	var local_y := clampf(_attack_center.y + orbit_y, -_combat_bounds.y, _combat_bounds.y)

	if _player_ref and is_instance_valid(_player_ref):
		var player_local := _to_local(_player_ref.global_position)
		local_x = lerpf(local_x, local_x + (player_local.x - _attack_center.x) * drift_weight * delta, 1.0)
		local_y = lerpf(local_y, local_y + (player_local.y - _attack_center.y) * drift_weight * delta, 1.0)
		local_x = clampf(local_x, -_combat_bounds.x, _combat_bounds.x)
		local_y = clampf(local_y, -_combat_bounds.y, _combat_bounds.y)

	var target_world := _to_world(Vector3(local_x, local_y, 0.0))
	global_position.x = lerpf(global_position.x, target_world.x, 3.0 * delta)
	global_position.y = lerpf(global_position.y, target_world.y, 3.0 * delta)

	if _path_follow_ref and is_instance_valid(_path_follow_ref):
		_relative_z = lerpf(_relative_z, harass_z, 1.0 * delta)
		global_position.z = _path_follow_ref.global_position.z + _relative_z

	if _harass_timer >= harass_time:
		_exit_pull_dir = Vector2(
			signf(global_position.x - _player_ref.global_position.x) if (_player_ref and is_instance_valid(_player_ref)) else (1.0 if _seed > 0.0 else -1.0),
			1.0
		).normalized()
		_transition_to(State.EXIT)

func _attack_sniping(delta: float) -> void:
	var sway_freq := float(_cfg.get("sway_freq", 1.5))
	var sway_amp := float(_cfg.get("sway_amp", 3.0))
	var approach_z := float(_cfg.get("sniping_approach_z", -12.0))
	var approach_spd := float(_cfg.get("approach_speed", 0.3))

	var local_x := clampf(_attack_center.x + sin(_time * sway_freq + _seed) * sway_amp, -_combat_bounds.x, _combat_bounds.x)
	var local_y := clampf(_attack_center.y + cos(_time * sway_freq * 0.7 + _seed) * sway_amp * 0.3, -_combat_bounds.y, _combat_bounds.y)
	var target_world := _to_world(Vector3(local_x, local_y, 0.0))
	global_position.x = target_world.x
	global_position.y = target_world.y
	if _path_follow_ref and is_instance_valid(_path_follow_ref):
		_relative_z = lerpf(_relative_z, approach_z, approach_spd * delta)
		global_position.z = _path_follow_ref.global_position.z + _relative_z

	_fire_timer -= delta
	if _fire_timer <= 0.0:
		if not _check_in_view():
			return
		var fire_interval := float(_cfg.get("fire_interval", 1.5))
		_fire_timer = fire_interval
		_fire_predicted()

func _attack_reactive(delta: float) -> void:
	var sway_freq := float(_cfg.get("sway_freq", 0.5))
	var sway_amp := float(_cfg.get("sway_amp", 2.0))
	var phase2_sway_mult := float(_cfg.get("phase2_sway_mult", 1.5))
	var approach_z := float(_cfg.get("reactive_approach_z", -14.0))
	var approach_spd := float(_cfg.get("approach_speed", 0.2))

	var current_sway_amp := sway_amp
	if _phase >= 1:
		current_sway_amp *= phase2_sway_mult

	var local_x := clampf(_attack_center.x + sin(_time * sway_freq + _seed) * current_sway_amp, -_combat_bounds.x, _combat_bounds.x)
	var local_y := clampf(_attack_center.y + cos(_time * sway_freq * 0.6 + _seed) * current_sway_amp * 0.2, -_combat_bounds.y, _combat_bounds.y)
	var target_world := _to_world(Vector3(local_x, local_y, 0.0))
	global_position.x = target_world.x
	global_position.y = target_world.y
	if _path_follow_ref and is_instance_valid(_path_follow_ref):
		_relative_z = lerpf(_relative_z, approach_z, approach_spd * delta)
		global_position.z = _path_follow_ref.global_position.z + _relative_z

	var fire_interval := float(_cfg.get("fire_interval", 0.8))
	if _phase >= 1:
		fire_interval *= float(_cfg.get("phase2_fire_mult", 0.6))

	var burst_count := int(_cfg.get("burst_count", 3))
	var burst_interval := float(_cfg.get("burst_interval", 1.0))

	if _burst_pause_timer > 0.0:
		_burst_pause_timer -= delta
	else:
		_fire_timer -= delta
		if _fire_timer <= 0.0 and _burst_fired < burst_count:
			_fire_timer = fire_interval
			_burst_fired += 1
			_fire_burst(_burst_fired - 1)
			if _burst_fired >= burst_count:
				_burst_fired = 0
				_burst_pause_timer = burst_interval

	_check_phase2()

func _fire_predicted() -> void:
	if not _player_ref or not is_instance_valid(_player_ref):
		return
	if not _path_follow_ref or not is_instance_valid(_path_follow_ref):
		return
	var cam_fwd := -_path_follow_ref.global_basis.z
	var to_self := (global_position - _path_follow_ref.global_position)
	var dist := to_self.length()
	if dist > 1.0:
		var angle := acos(clampf(cam_fwd.dot(to_self / dist), -1.0, 1.0))
		var half_fov := deg_to_rad(35.0)
		if angle > half_fov * 1.3:
			return
	var lead_time := float(_cfg.get("lead_time", 0.3))
	var lead_jitter := float(_cfg.get("lead_jitter", 0.15))
	var actual_lead := lead_time + randf_range(-lead_jitter, lead_jitter)
	if dist > 1.0:
		var angle := acos(clampf(cam_fwd.dot(to_self / dist), -1.0, 1.0))
		var off_axis := angle / deg_to_rad(35.0)
		actual_lead += randf_range(-off_axis * 1.5, off_axis * 1.5)
	var predicted_global := _player_ref.global_position + _cached_player_vel * maxf(actual_lead, 0.0)
	var dir := (predicted_global - global_position).normalized()
	fire_bullet.emit(global_position, dir)

func _fire_burst(index: int) -> void:
	if not _player_ref or not is_instance_valid(_player_ref):
		return
	if not _path_follow_ref or not is_instance_valid(_path_follow_ref):
		return
	var cam_fwd := -_path_follow_ref.global_basis.z
	var to_self := (global_position - _path_follow_ref.global_position)
	var dist := to_self.length()
	if dist > 1.0:
		var angle := acos(clampf(cam_fwd.dot(to_self / dist), -1.0, 1.0))
		var half_fov := deg_to_rad(35.0)
		if angle > half_fov * 1.3:
			return
	var lead_time := float(_cfg.get("lead_time", 0.5))
	var lead_jitter := float(_cfg.get("lead_jitter", 0.1))
	var actual_lead := lead_time + randf_range(-lead_jitter, lead_jitter)
	if dist > 1.0:
		var angle := acos(clampf(cam_fwd.dot(to_self / dist), -1.0, 1.0))
		var off_axis := angle / deg_to_rad(35.0)
		actual_lead += randf_range(-off_axis * 1.5, off_axis * 1.5)
	var predicted_global := _player_ref.global_position + _cached_player_vel * maxf(actual_lead, 0.0)
	var dir := (predicted_global - global_position).normalized()
	var offset_x := 0.0
	match index:
		0:
			offset_x = -2.0
		1:
			offset_x = 0.0
		2:
			offset_x = 2.0
	var fire_pos := global_position + global_basis.x * offset_x
	fire_bullet.emit(fire_pos, dir)

func _check_phase2() -> void:
	if _phase >= 1:
		return
	var phase2_ratio := float(_cfg.get("phase2_hp_ratio", 0.5))
	if hp / max_hp < phase2_ratio:
		_phase = 1

func _check_evade_trigger(delta: float) -> void:
	if _evade_cooldown_timer > 0.0:
		return
	if not _player_firing:
		_lock_timer = 0.0
		return
	var crosshair_node := _get_crosshair()
	if crosshair_node == null:
		return
	var lock_threshold := float(_cfg.get("lock_threshold", 2.0))
	var cross_dist := (global_position - crosshair_node.global_position).length()
	if cross_dist < lock_threshold:
		_lock_timer += delta
		if _lock_timer > 0.15:
			var evade_chance := float(_cfg.get("evade_chance", 0.6))
			if randf() < evade_chance:
				_start_evade()
				_lock_timer = 0.0
	else:
		_lock_timer = maxf(0.0, _lock_timer - delta * 2.0)

func _get_crosshair() -> Node3D:
	if _path_follow_ref and is_instance_valid(_path_follow_ref):
		var ch := _path_follow_ref.get_node_or_null("Crosshair")
		if ch:
			return ch
	return null

func _start_evade() -> void:
	var evade_telegraph := float(_cfg.get("evade_telegraph", 0.1))
	_evade_telegraph_timer = evade_telegraph
	var evade_distance := float(_cfg.get("evade_distance", 3.0))
	var angle := randf() * TAU
	_evade_dir = Vector3(cos(angle), sin(angle) * 0.5, 0.0).normalized() * evade_distance
	_evade_start = global_position
	_evade_cooldown_timer = float(_cfg.get("evade_cooldown", 2.0))
	_transition_to(State.EVADE)

func _process_evade(delta: float) -> void:
	if _evade_telegraph_timer > 0.0:
		_evade_telegraph_timer -= delta
		var bank_target := signf(_evade_dir.x) * 0.5
		rotation.z = lerpf(rotation.z, bank_target, 10.0 * delta)
		return
	var evade_dur := float(_cfg.get("evade_duration", 0.2))
	var t := minf(_state_time / evade_dur, 1.0)
	var eased := 1.0 - (1.0 - t) * (1.0 - t)
	global_position = _evade_start + _evade_dir * eased
	rotation.z = lerpf(rotation.z, 0.0, 5.0 * delta)
	if t >= 1.0:
		rotation.z = 0.0
		_attack_center = _to_local(global_position)
		_transition_to(State.ATTACK)

func _process_exit(delta: float) -> void:
	var exit_speed := float(_cfg.get("exit_speed_mult", 2.0)) * _track_speed
	var pull_up_speed := float(_cfg.get("exit_pull_up_speed", 8.0))
	var pull_side_speed := float(_cfg.get("exit_pull_side_speed", 6.0))
	var bank_speed := float(_cfg.get("exit_bank_speed", 4.0))
	var pitch_speed := float(_cfg.get("exit_pitch_speed", 3.0))
	if _path_follow_ref and is_instance_valid(_path_follow_ref):
		_relative_z += exit_speed * delta
		global_position.z = _path_follow_ref.global_position.z + _relative_z
	else:
		global_position.z += exit_speed * delta
	global_position.x += _exit_pull_dir.x * pull_side_speed * delta
	global_position.y += _exit_pull_dir.y * pull_up_speed * delta
	rotation.z = lerpf(rotation.z, _exit_pull_dir.x * deg_to_rad(50.0), bank_speed * delta)
	rotation.x = lerpf(rotation.x, deg_to_rad(-20.0), pitch_speed * delta)

func _process_dying(delta: float) -> void:
	_death_vel += Vector3.DOWN * float(_cfg.get("death_gravity", 3.0)) * delta
	global_position += _death_vel * delta
	rotation += _death_spin_axis * _death_spin_speed * delta
	if _state_time >= _death_duration:
		queue_free()

func _transition_to(new_state: State) -> void:
	state = new_state
	_state_time = 0.0
	match new_state:
		State.ATTACK:
			_attack_center = _to_local(global_position)
		State.EXIT:
			rotation = Vector3.ZERO
			if _exit_pull_dir == Vector2.ZERO:
				_exit_pull_dir = Vector2(randf_range(-1.0, 1.0), 1.0).normalized()
		State.DYING:
			_enter_dying()

func _enter_dying() -> void:
	_alive = false
	destroyed.emit()
	_death_vel = Vector3(randf_range(-2.0, 2.0), randf_range(1.0, 3.0), randf_range(-1.0, 1.0))
	_death_spin_axis = Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)).normalized()

func take_damage(amount: float) -> void:
	if state == State.DYING:
		return
	hp -= amount
	if hp <= 0.0:
		hp = 0.0
		_transition_to(State.DYING)
	else:
		var flash_tween := create_tween()
		flash_tween.tween_property(self, "scale", scale * 1.15, 0.05)
		flash_tween.tween_property(self, "scale", Vector3.ONE, 0.1)
