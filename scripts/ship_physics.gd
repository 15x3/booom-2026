extends Node

signal position_changed(pos: Vector2, heading: float, speed: float)

var ship_position: Vector2 = Vector2(0.5, 0.75)
var ship_velocity: Vector2 = Vector2.ZERO
var ship_heading: float = -PI / 2.0

var turn_input: float = 0.0
var throttle_position: int = 0
var heading_locked: bool = false

var _physics_cfg: Dictionary = {}
var _gravity_cfg: Dictionary = {}
var _gravity_base: float = 0.0
var _gravity_curve_exp: float = 1.5
var _map_scale: float = 480.0
var _active: bool = false
var driving_enabled: bool = true
var _max_speeds := [0.0, 60.0, 120.0, 200.0]
var _fuel_drains := [0.0, 0.05, 0.12, 0.25]

func load_config(cfg: Dictionary) -> void:
	_physics_cfg = cfg.get("ship_physics", {})
	_gravity_cfg = cfg.get("gravity", {})
	_max_speeds = [
		_physics_cfg.get("max_speed_off", 0.0),
		_physics_cfg.get("max_speed_low", 60.0),
		_physics_cfg.get("max_speed_mid", 120.0),
		_physics_cfg.get("max_speed_high", 200.0)
	]
	_fuel_drains = [
		_physics_cfg.get("fuel_drain_off", 0.0),
		_physics_cfg.get("fuel_drain_low", 0.05),
		_physics_cfg.get("fuel_drain_mid", 0.12),
		_physics_cfg.get("fuel_drain_high", 0.25)
	]

func setup_for_node(map_data: Dictionary) -> void:
	var start: Array = map_data.get("start_position", [0.5, 0.75])
	ship_position = Vector2(start[0], start[1])
	ship_velocity = Vector2.ZERO
	ship_heading = -PI / 2.0
	turn_input = 0.0
	throttle_position = 0
	heading_locked = false
	_gravity_base = map_data.get("gravity_base_strength", 0.0)
	_gravity_curve_exp = map_data.get("gravity_curve_exponent", 1.5)
	_active = true

func set_active(active: bool) -> void:
	_active = active
	if not active:
		ship_velocity = Vector2.ZERO
		turn_input = 0.0
		driving_enabled = true

func get_fuel_drain() -> float:
	if throttle_position < 0 or throttle_position >= _fuel_drains.size():
		return 0.0
	return _fuel_drains[throttle_position]

func _process(delta: float) -> void:
	if not _active:
		return

	var max_turn_rate: float = deg_to_rad(_physics_cfg.get("max_turn_rate", 45.0))
	var acceleration: float = _physics_cfg.get("acceleration", 80.0)
	var drag: float = _physics_cfg.get("drag", 0.02)
	var speed_penalty_max: float = _gravity_cfg.get("speed_penalty_max", 0.5)

	var max_speed: float = _max_speeds[clampi(throttle_position, 0, 3)]

	if not heading_locked and driving_enabled:
		ship_heading += turn_input * max_turn_rate * delta
	while ship_heading > PI:
		ship_heading -= 2.0 * PI
	while ship_heading < -PI:
		ship_heading += 2.0 * PI

	if throttle_position > 0 and driving_enabled:
		var heading_vec := Vector2(cos(ship_heading), sin(ship_heading))
		var accel_norm: float = acceleration / _map_scale
		ship_velocity += heading_vec * accel_norm * delta

	ship_velocity *= (1.0 - drag)

	var gravity_ratio: float = clampf(ship_position.y, 0.0, 1.0)
	var gravity_strength: float = _gravity_base * pow(gravity_ratio, _gravity_curve_exp)
	ship_velocity.y += gravity_strength * delta

	var speed_mult: float = 1.0 - gravity_ratio * speed_penalty_max
	var effective_max: float = (max_speed / _map_scale) * maxf(speed_mult, 0.1)
	if effective_max > 0.0 and ship_velocity.length() > effective_max:
		ship_velocity = ship_velocity.normalized() * effective_max

	ship_position += ship_velocity * delta

	if ship_position.x <= 0.02:
		ship_position.x = 0.02
		ship_velocity.x *= -0.3
	elif ship_position.x >= 0.98:
		ship_position.x = 0.98
		ship_velocity.x *= -0.3
	if ship_position.y <= 0.02:
		ship_position.y = 0.02
		ship_velocity.y *= -0.3
	elif ship_position.y >= 0.98:
		ship_position.y = 0.98
		ship_velocity.y *= -0.3

	var speed_px: float = ship_velocity.length() * _map_scale
	position_changed.emit(ship_position, ship_heading, speed_px)
