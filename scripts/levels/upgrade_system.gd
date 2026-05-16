extends Node

var _pool: Array = []
var _active: Array = []
var _mult_cache: Dictionary = {}
var _add_cache: Dictionary = {}
var _cache_dirty: bool = true
var _exclusions: Dictionary = {}

func load_pool(pool_data: Array, exclusions_data: Dictionary = {}) -> void:
	_pool = pool_data.duplicate(true)
	_exclusions = exclusions_data.duplicate(true)
	_active.clear()
	_cache_dirty = true

func get_random_offers(count: int) -> Array:
	var available: Array = []
	var owned_ids: Dictionary = {}
	for u: Dictionary in _active:
		owned_ids[u.get("id", "")] = true
	var excluded_ids: Dictionary = {}
	for uid: String in owned_ids:
		if _exclusions.has(uid):
			var excl: Array = _exclusions[uid]
			for eid: String in excl:
				excluded_ids[eid] = true
	for entry: Dictionary in _pool:
		var eid: String = entry.get("id", "")
		if not owned_ids.has(eid) and not excluded_ids.has(eid):
			available.append(entry)
	available.shuffle()
	var result: Array = []
	for i: int in range(mini(count, available.size())):
		result.append(available[i])
	return result

func apply_upgrade(upgrade_id: String) -> void:
	for entry: Dictionary in _pool:
		if entry.get("id", "") == upgrade_id:
			_active.append(entry)
			_cache_dirty = true
			return
	push_warning("[UpgradeSystem] Unknown upgrade: %s" % upgrade_id)

func get_mult(stat_name: String) -> float:
	_rebuild_cache()
	return _mult_cache.get(stat_name, 1.0)

func get_add(stat_name: String) -> float:
	_rebuild_cache()
	return _add_cache.get(stat_name, 0.0)

func get_stat(base_val: float, stat_name: String) -> float:
	return (base_val + get_add(stat_name)) * get_mult(stat_name)

func get_active_upgrades() -> Array:
	return _active

func has_upgrade(upgrade_id: String) -> bool:
	for u: Dictionary in _active:
		if u.get("id", "") == upgrade_id:
			return true
	return false

func reset() -> void:
	_active.clear()
	_mult_cache.clear()
	_add_cache.clear()
	_cache_dirty = true

func _rebuild_cache() -> void:
	if not _cache_dirty:
		return
	_mult_cache.clear()
	_add_cache.clear()
	for entry: Dictionary in _active:
		var stat: String = entry.get("stat", "")
		if stat.is_empty():
			continue
		var op: String = entry.get("op", "mult")
		var val: float = entry.get("value", 0.0)
		if op == "mult":
			_mult_cache[stat] = _mult_cache.get(stat, 1.0) * val
		elif op == "add":
			_add_cache[stat] = _add_cache.get(stat, 0.0) + val
	_cache_dirty = false
