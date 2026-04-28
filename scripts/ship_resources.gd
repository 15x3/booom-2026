extends Node

signal resources_changed(fuel: float, hull: float, oxygen: float)
signal resource_depleted(resource_type: String)

var fuel: float = 100.0
var hull: float = 100.0
var oxygen: float = 100.0

var _oxygen_drain_rate: float = 0.05
var _depleted: Dictionary = {"fuel": false, "hull": false, "oxygen": false}

func load_config(cfg: Dictionary) -> void:
	var res: Dictionary = cfg.get("resources", {})
	fuel = res.get("initial_fuel", 100.0)
	hull = res.get("initial_hull", 100.0)
	oxygen = res.get("initial_oxygen", 100.0)
	_oxygen_drain_rate = res.get("oxygen_drain_rate", 0.05)
	_depleted = {"fuel": false, "hull": false, "oxygen": false}
	_emit_changed()

func _process(delta: float) -> void:
	if oxygen <= 0.0:
		return
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

func is_alive() -> bool:
	return hull > 0.0 and oxygen > 0.0

func _emit_changed() -> void:
	resources_changed.emit(fuel, hull, oxygen)
