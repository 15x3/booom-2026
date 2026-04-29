extends Node

signal resources_changed(fuel: float, hull: float, oxygen: float, engine_temp: float)
signal resource_depleted(resource_type: String)
signal engine_overheated
signal breaker_tripped(breaker_index: int)
signal breaker_reset(breaker_index: int)

var fuel: float = 100.0
var hull: float = 100.0
var oxygen: float = 100.0
var engine_temp: float = 20.0

var _oxygen_drain_rate: float = 0.05
var _depleted: Dictionary = {"fuel": false, "hull": false, "oxygen": false}
var _breakers: Array = [false, false, false, false]

func load_config(cfg: Dictionary) -> void:
	var res: Dictionary = cfg.get("resources", {})
	fuel = res.get("initial_fuel", 100.0)
	hull = res.get("initial_hull", 100.0)
	oxygen = res.get("initial_oxygen", 100.0)
	engine_temp = res.get("initial_engine_temp", 20.0)
	_oxygen_drain_rate = res.get("oxygen_drain_rate", 0.05)
	_depleted = {"fuel": false, "hull": false, "oxygen": false}
	_breakers = [false, false, false, false]
	_emit_changed()

func _process(delta: float) -> void:
	if oxygen > 0.0:
		oxygen = maxf(oxygen - _oxygen_drain_rate * delta, 0.0)
		if oxygen <= 0.0 and not _depleted["oxygen"]:
			_depleted["oxygen"] = true
			resource_depleted.emit("oxygen")
	_emit_changed()

func can_consume_fuel(amount: float) -> bool:
	return fuel >= amount

func can_consume(amounts: Dictionary) -> bool:
	if amounts.has("fuel") and fuel < amounts["fuel"]:
		return false
	if amounts.has("oxygen") and oxygen < amounts["oxygen"]:
		return false
	return true

func consume_fuel(amount: float) -> void:
	fuel = maxf(fuel - amount, 0.0)
	if fuel <= 0.0 and not _depleted["fuel"]:
		_depleted["fuel"] = true
		resource_depleted.emit("fuel")
	_emit_changed()

func consume_oxygen(amount: float) -> void:
	oxygen = maxf(oxygen - amount, 0.0)
	if oxygen <= 0.0 and not _depleted["oxygen"]:
		_depleted["oxygen"] = true
		resource_depleted.emit("oxygen")
	_emit_changed()

func damage_hull(amount: float) -> void:
	hull = maxf(hull - amount, 0.0)
	if hull <= 0.0 and not _depleted["hull"]:
		_depleted["hull"] = true
		resource_depleted.emit("hull")
	_emit_changed()

func supply_oxygen(amount: float) -> void:
	oxygen = minf(oxygen + amount, 100.0)
	_emit_changed()

func add_heat(amount: float) -> void:
	engine_temp = minf(engine_temp + amount, 120.0)
	if engine_temp >= 90.0:
		engine_overheated.emit()
	_emit_changed()

func cool_engine(amount: float) -> void:
	engine_temp = maxf(engine_temp - amount, 20.0)
	_emit_changed()

func is_overheated() -> bool:
	return engine_temp >= 90.0

func is_warm() -> bool:
	return engine_temp >= 70.0

func trip_breaker(index: int) -> void:
	if index < 0 or index >= _breakers.size():
		return
	if _breakers[index]:
		return
	_breakers[index] = true
	breaker_tripped.emit(index)

func reset_breaker(index: int) -> void:
	if index < 0 or index >= _breakers.size():
		return
	if not _breakers[index]:
		return
	_breakers[index] = false
	breaker_reset.emit(index)

func is_breaker_tripped(index: int) -> bool:
	if index < 0 or index >= _breakers.size():
		return false
	return _breakers[index]

func get_tripped_breakers() -> Array:
	var result: Array = []
	for i in range(_breakers.size()):
		if _breakers[i]:
			result.append(i)
	return result

func is_alive() -> bool:
	return hull > 0.0 and oxygen > 0.0

func _emit_changed() -> void:
	resources_changed.emit(fuel, hull, oxygen, engine_temp)
