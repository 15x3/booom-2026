extends Node

signal breaker_tripped(breaker_index: int)
signal breaker_reset(breaker_index: int)
signal o2_supply_started
signal o2_supply_completed

var _config: Dictionary = {}
var _ship_resources: Node = null
var _ship_physics: Node = null
var _breakers: Array = [false, false, false, false]
var _o2_supplying: bool = false
var _o2_supply_timer: float = 0.0
var _o2_supply_amount: float = 12.0
var _o2_supply_duration: float = 3.0
var _cooling_rate: float = 0.0
var _cooling_rates := [0.0, 2.0, 5.0]
var _breaker_accum: float = 0.0
var _active: bool = false
var _node_index: int = -1

func load_config(cfg: Dictionary) -> void:
	_config = cfg.get("maintenance", {})
	_o2_supply_amount = cfg.get("actions", {}).get("o2_supply_amount", 12.0)
	_o2_supply_duration = cfg.get("actions", {}).get("o2_supply_duration", 3.0)

func setup(resources: Node, physics: Node) -> void:
	_ship_resources = resources
	_ship_physics = physics

func set_active(active: bool) -> void:
	_active = active

func set_node_index(idx: int) -> void:
	_node_index = idx

func set_cooling_stop(stop_index: int) -> void:
	if stop_index < 0 or stop_index >= _cooling_rates.size():
		return
	_cooling_rate = _cooling_rates[stop_index]

func start_o2_supply() -> void:
	if _o2_supplying:
		return
	if _ship_resources == null:
		return
	var threshold: float = _config.get("o2_trigger_threshold", 40.0)
	if _ship_resources.oxygen > threshold + 5.0:
		return
	_o2_supplying = true
	_o2_supply_timer = 0.0
	o2_supply_started.emit()

func stop_o2_supply() -> void:
	_o2_supplying = false
	_o2_supply_timer = 0.0

func reset_breaker(index: int) -> void:
	if index < 0 or index >= _breakers.size():
		return
	if not _breakers[index]:
		return
	_breakers[index] = false
	if _ship_resources and _ship_resources.has_method("reset_breaker"):
		_ship_resources.reset_breaker(index)
	breaker_reset.emit(index)

func get_breaker_state(index: int) -> bool:
	if index < 0 or index >= _breakers.size():
		return false
	return _breakers[index]

func _process(delta: float) -> void:
	if not _active or _ship_resources == null:
		return

	_process_engine_heat(delta)
	_process_breaker_trips(delta)
	_process_o2_supply(delta)

func _process_engine_heat(delta: float) -> void:
	if _ship_physics == null:
		return

	var throttle: int = _ship_physics.throttle_position
	if throttle >= 3:
		var heat_rate: float = _config.get("high_throttle_heat", 15.0)
		_ship_resources.add_heat(heat_rate * delta)

	if throttle <= 1 or _cooling_rate > 0.0:
		var natural_cool: float = _config.get("natural_cooling_rate", 1.0)
		var total_cool: float = natural_cool + _cooling_rate
		_ship_resources.cool_engine(total_cool * delta)

	if _ship_resources.is_overheated():
		var overheat_mult: float = _config.get("overheat_fuel_mult", 1.5)
		var extra_drain: float = (overheat_mult - 1.0) * delta
		_ship_resources.consume_fuel(extra_drain)

func _process_breaker_trips(delta: float) -> void:
	if _ship_physics == null:
		return

	var base_rate: float
	if _node_index < 3:
		base_rate = _config.get("breaker_base_rate_early", 0.02)
	else:
		base_rate = _config.get("breaker_base_rate_late", 0.04)

	var throttle: int = _ship_physics.throttle_position
	if throttle >= 3:
		base_rate *= 1.5

	if _ship_resources.is_overheated():
		base_rate *= _config.get("breaker_heat_factor_hot", 4.0)
	elif _ship_resources.is_warm():
		base_rate *= _config.get("breaker_heat_factor_warm", 2.0)

	_breaker_accum += base_rate * delta

	while _breaker_accum >= 1.0:
		_breaker_accum -= 1.0
		var untripped: Array = []
		for i in range(_breakers.size()):
			if not _breakers[i]:
				untripped.append(i)
		if untripped.is_empty():
			return
		var idx: int = untripped[randi() % untripped.size()]
		_breakers[idx] = true
		if _ship_resources.has_method("trip_breaker"):
			_ship_resources.trip_breaker(idx)
		breaker_tripped.emit(idx)

	if _ship_resources.is_overheated():
		var cascade: float = _config.get("cascade_heat", 5.0)
		_ship_resources.add_heat(cascade * delta)

func _process_o2_supply(delta: float) -> void:
	if not _o2_supplying:
		return
	_o2_supply_timer += delta
	var per_tick: float = _o2_supply_amount / _o2_supply_duration
	_ship_resources.supply_oxygen(per_tick * delta)
	if _o2_supply_timer >= _o2_supply_duration:
		_o2_supplying = false
		_o2_supply_timer = 0.0
		o2_supply_completed.emit()
