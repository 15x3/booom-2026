extends Node3D

signal level_completed
signal level_failed
signal comm_output(text: String)
signal sfx_requested(sfx_name: String)

@onready var player: CharacterBody3D = $Player
@onready var camera: Camera3D = $Player/Camera3D
@onready var _ship_mesh: MeshInstance3D = $Player/ShipMesh
@onready var laser_beam: MeshInstance3D = $Player/LaserBeam
@onready var _starfield_node: MeshInstance3D = $Starfield
@onready var _exit_station: Node3D = $ExitStation
@onready var _coriolis_mesh: MeshInstance3D = $ExitStation/CoriolisMesh

var config: Dictionary = {}

var velocity: Vector3 = Vector3.ZERO

var roll_input: float = 0.0
var pitch_input: float = 0.0
var thrust_level: int = 0
var max_roll_speed: float = 90.0
var max_pitch_speed: float = 60.0
var thrust_speeds: Array[float] = [0.0, 30.0, 60.0, 120.0]
var drag: float = 0.3
var hp: float = 100.0
var hp_max: float = 100.0
var shield: float = 50.0
var shield_max: float = 50.0
var shield_regen: float = 5.0
var energy: float = 100.0
var energy_max: float = 100.0
var energy_regen: float = 10.0

var credits: int = 100
var cargo: Dictionary = {}
var max_cargo: int = 20
var toll_fee: int = 1000
var toll_paid: bool = false

var wireframe_mat: ShaderMaterial

var laser_active: bool = false
var laser_cooldown: float = 0.0
var laser_cooldown_max: float = 0.5
var laser_damage: float = 10.0
var laser_range: float = 500.0
var fire_energy_cost: float = 10.0

var enemies: Array[Dictionary] = []
var enemy_projectiles: Array[Dictionary] = []

var stations: Array[Dictionary] = []
var is_docked: bool = false
var in_trade: bool = false
var _current_station: Dictionary = {}

var exit_rotation_speed: float = 36.0

var commodities: Array[String] = ["food", "textiles", "machinery", "luxuries"]
var commodity_names: Dictionary = {
	"food": "Food",
	"textiles": "Textiles",
	"machinery": "Machinery",
	"luxuries": "Luxuries",
}

var _roll_cur: float = 0.0
var _pitch_cur: float = 0.0
var _station_counter: int = 0
var _hit_flash_timer: float = 0.0

func _ready() -> void:
	_load_config()
	_setup_scene()
	_emit_comm.call_deferred("=== ELITE TERMINAL v1.0 ===")
	_emit_comm.call_deferred("1984 — WIREFRAME SPACE")
	_emit_comm.call_deferred("WASD:Roll/Pitch I/K:Thrust SPACE:Fire")
	_emit_comm.call_deferred("T:Dock(near station)")
	_emit_comm.call_deferred("")

func _load_config() -> void:
	var file = FileAccess.open("res://assets/data/game_config.json", FileAccess.READ)
	if file:
		var json = JSON.new()
		json.parse(file.get_as_text())
		var data = json.data
		if data.has("elite"):
			config = data["elite"]
		file.close()
	hp_max = float(config.get("hp_max", 100.0))
	hp = hp_max
	shield_max = float(config.get("shield_max", 50.0))
	shield = shield_max
	energy_max = float(config.get("energy_max", 100.0))
	energy = energy_max
	max_roll_speed = float(config.get("max_roll_speed", 90.0))
	max_pitch_speed = float(config.get("max_pitch_speed", 60.0))
	drag = float(config.get("drag", 0.3))
	max_cargo = int(config.get("max_cargo", 20))
	credits = int(config.get("starting_credits", 100))
	toll_fee = int(config.get("toll_fee", 1000))
	laser_damage = float(config.get("laser_damage", 10.0))
	laser_range = float(config.get("laser_range", 500.0))
	laser_cooldown_max = float(config.get("laser_cooldown", 0.5))
	fire_energy_cost = float(config.get("fire_energy_cost", 10.0))
	shield_regen = float(config.get("shield_regen", 5.0))
	energy_regen = float(config.get("energy_regen", 10.0))
	exit_rotation_speed = float(config.get("station_rotation_speed", 36.0))
	var st = config.get("thrust_speeds", [0.0, 30.0, 60.0, 120.0])
	thrust_speeds.clear()
	for v in st:
		thrust_speeds.append(float(v))

func _setup_scene() -> void:
	_create_wireframe_material()
	_assign_meshes()
	_apply_materials()
	_setup_laser_beam_material()
	_setup_starfield()
	_collect_stations()
	_collect_enemies()

func _assign_meshes() -> void:
	if _coriolis_mesh:
		_coriolis_mesh.mesh = _create_coriolis_mesh()
	if laser_beam and laser_beam.mesh == null:
		var beam := CylinderMesh.new()
		beam.top_radius = 0.3
		beam.bottom_radius = 0.3
		beam.height = 1.0
		laser_beam.mesh = beam
	for child in get_children():
		if child.name.begins_with("Station") and child is MeshInstance3D:
			child.mesh = _create_station_mesh(_station_counter)
			_station_counter += 1
		if child.name.begins_with("Enemy") and child is MeshInstance3D:
			child.mesh = _create_enemy_ship_mesh()

func _create_wireframe_material() -> void:
	wireframe_mat = ShaderMaterial.new()
	wireframe_mat.shader = load("res://assets/shaders/wireframe.gdshader")
	wireframe_mat.set_shader_parameter("line_color", Color(1.0, 0.5, 0.0, 1.0))
	wireframe_mat.set_shader_parameter("line_opacity", 0.9)
	wireframe_mat.set_shader_parameter("fresnel_power", 3.0)
	wireframe_mat.set_shader_parameter("scan_speed", 1.0)
	wireframe_mat.set_shader_parameter("scan_intensity", 0.15)

func _apply_materials() -> void:
	if _ship_mesh:
		_ship_mesh.material_override = wireframe_mat
	if _coriolis_mesh:
		_coriolis_mesh.material_override = wireframe_mat
	for s in stations:
		var n: MeshInstance3D = s.get("node")
		if n:
			n.material_override = wireframe_mat
	for e in enemies:
		var n: MeshInstance3D = e.get("node")
		if n:
			n.material_override = wireframe_mat

func _setup_laser_beam_material() -> void:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.3, 0.0, 0.8)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.5, 0.0)
	mat.emission_energy = 3.0
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	laser_beam.material_override = mat

func _setup_starfield() -> void:
	var points := PackedVector3Array()
	for i in range(1200):
		points.append(Vector3(
			randf_range(-5000.0, 5000.0),
			randf_range(-3000.0, 3000.0),
			randf_range(-5000.0, 5000.0)
		))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = points
	var star_array := ArrayMesh.new()
	star_array.add_surface_from_arrays(Mesh.PRIMITIVE_POINTS, arrays)
	_starfield_node.mesh = star_array
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.6, 0.2, 1.0)
	mat.point_size = 2.5
	_starfield_node.material_override = mat

func _create_enemy_ship_mesh() -> ArrayMesh:
	var verts := PackedVector3Array([
		Vector3(0, 0, -10),
		Vector3(-6, 0, 6),
		Vector3(6, 0, 6),
		Vector3(0, 3, 0),
		Vector3(0, -2, 2),
	])
	var indices := PackedInt32Array([
		0, 1, 2,
		0, 2, 3,
		0, 3, 1,
		1, 2, 4,
		1, 4, 3,
		2, 3, 4,
	])
	var mesh := ArrayMesh.new()
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_INDEX] = indices
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

func _create_coriolis_mesh() -> ArrayMesh:
	var h := 40.0
	var verts := PackedVector3Array([
		Vector3(-h, -h, -h), Vector3(h, -h, -h), Vector3(h, h, -h), Vector3(-h, h, -h),
		Vector3(-h, -h, h), Vector3(h, -h, h), Vector3(h, h, h), Vector3(-h, h, h),
	])
	var indices := PackedInt32Array([
		0, 1, 2, 0, 2, 3,
		4, 6, 5, 4, 7, 6,
		0, 4, 5, 0, 5, 1,
		2, 6, 7, 2, 7, 3,
		0, 3, 7, 0, 7, 4,
	])
	var mesh := ArrayMesh.new()
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_INDEX] = indices
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

func _create_station_mesh(variant: int) -> ArrayMesh:
	var s := 20.0
	var verts: PackedVector3Array
	match variant % 3:
		0:
			verts = PackedVector3Array([
				Vector3(-s, -s, -s), Vector3(s, -s, -s), Vector3(s, s, -s), Vector3(-s, s, -s),
				Vector3(-s, -s, s), Vector3(s, -s, s), Vector3(s, s, s), Vector3(-s, s, s),
			])
		1:
			verts = PackedVector3Array([
				Vector3(0, s * 1.2, 0),
				Vector3(-s, -s * 0.5, -s),
				Vector3(s, -s * 0.5, -s),
				Vector3(s, -s * 0.5, s),
				Vector3(-s, -s * 0.5, s),
			])
		_:
			verts = PackedVector3Array([
				Vector3(0, s, -s), Vector3(-s, -s, -s), Vector3(s, -s, -s),
				Vector3(0, s, s), Vector3(-s, -s, s), Vector3(s, -s, s),
			])
	var indices := PackedInt32Array()
	if verts.size() == 8:
		indices = PackedInt32Array([
			0, 1, 2, 0, 2, 3, 4, 6, 5, 4, 7, 6,
			0, 4, 5, 0, 5, 1, 2, 6, 7, 2, 7, 3, 0, 3, 7, 0, 7, 4,
		])
	elif verts.size() == 5:
		indices = PackedInt32Array([0,1,2, 0,2,3, 0,3,4, 0,4,1, 1,3,2, 1,4,3])
	else:
		indices = PackedInt32Array([0,1,2, 3,5,4, 0,2,5, 0,5,3, 1,4,2, 2,4,5])
	var mesh := ArrayMesh.new()
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_INDEX] = indices
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

func _collect_stations() -> void:
	var station_names := ["Alpha Station", "Beta Station", "Gamma Station"]
	var price_sets := [
		{"food": [6, 12], "textiles": [15, 25], "machinery": [35, 55], "luxuries": [65, 100]},
		{"food": [8, 14], "textiles": [12, 22], "machinery": [40, 65], "luxuries": [70, 110]},
		{"food": [5, 10], "textiles": [18, 30], "machinery": [30, 50], "luxuries": [60, 95]},
	]
	var idx := 0
	for child in get_children():
		if not child.name.begins_with("Station"):
			continue
		if idx >= station_names.size():
			break
		var prices: Dictionary = {}
		for comm in commodities:
			var range_arr = price_sets[idx][comm]
			prices[comm] = {"buy": range_arr[0], "sell": range_arr[1]}
		stations.append({
			"node": child,
			"name": station_names[idx],
			"prices": prices,
			"index": idx,
		})
		idx += 1

func _collect_enemies() -> void:
	var ecfg: Dictionary = config.get("enemy", {})
	var fire_interval: float = float(ecfg.get("fire_interval", 2.0))
	var e_damage: float = float(ecfg.get("damage", 8.0))
	var bounty: int = int(ecfg.get("bounty_base", 100))
	var e_hp: float = float(ecfg.get("hp", 30.0))
	var idx := 0
	for child in get_children():
		if not child.name.begins_with("Enemy"):
			continue
		var detection: Area3D = child.get_node_or_null("Detection")
		enemies.append({
			"node": child,
			"detection": detection,
			"hp": e_hp,
			"hp_max": e_hp,
			"alive": true,
			"state": "patrol",
			"patrol_center": child.position,
			"patrol_radius": 200.0,
			"patrol_angle": randf() * TAU,
			"fire_cooldown": fire_interval,
			"fire_interval": fire_interval,
			"damage": e_damage,
			"bounty": bounty,
			"index": idx,
		})
		idx += 1

func _process(delta: float) -> void:
	if is_docked:
		return
	_process_flight(delta)
	_process_combat(delta)
	_process_enemies(delta)
	_process_projectiles(delta)
	_rotate_exit_station(delta)
	_check_docking()
	_update_starfield_position()
	if _hit_flash_timer > 0.0:
		_hit_flash_timer -= delta

func _process_flight(delta: float) -> void:
	if roll_input != 0.0:
		_roll_cur += roll_input * max_roll_speed * delta
	if pitch_input != 0.0:
		_pitch_cur += pitch_input * max_pitch_speed * delta
	_pitch_cur = clampf(_pitch_cur, -85.0, 85.0)
	var basis := Basis()
	basis = basis.rotated(Vector3.UP, deg_to_rad(-_roll_cur))
	basis = basis.rotated(basis.x, deg_to_rad(_pitch_cur))
	player.transform.basis = basis
	var forward := -basis.z
	var speed: float = thrust_speeds[clampi(thrust_level, 0, thrust_speeds.size() - 1)]
	velocity = velocity.lerp(forward * speed, 1.0 - exp(-drag * delta * 10.0))
	if speed == 0.0:
		velocity = velocity.lerp(Vector3.ZERO, 1.0 - exp(-drag * delta * 3.0))
	player.position += velocity * delta

func _process_combat(delta: float) -> void:
	shield = minf(shield + shield_regen * delta, shield_max)
	energy = minf(energy + energy_regen * delta, energy_max)
	if laser_cooldown > 0.0:
		laser_cooldown -= delta
	if laser_active and laser_cooldown <= 0.0 and energy >= fire_energy_cost:
		energy -= fire_energy_cost
		laser_cooldown = laser_cooldown_max
		laser_beam.visible = true
		laser_beam.position = Vector3(0, 0, -laser_range * 0.5)
		laser_beam.rotation_degrees = Vector3(90, 0, 0)
		_check_laser_hit()
		sfx_requested.emit("laser_fire")
		get_tree().create_timer(0.15).timeout.connect(func(): if is_instance_valid(laser_beam): laser_beam.visible = false)

func _check_laser_hit() -> void:
	var forward := -player.transform.basis.z
	for e in enemies:
		if not e["alive"]:
			continue
		var enode: Node3D = e["node"]
		var to_enemy: Vector3 = enode.global_position - player.global_position
		var dist := to_enemy.length()
		if dist > laser_range:
			continue
		var proj := to_enemy.dot(forward)
		if proj <= 0.0:
			continue
		var closest := player.global_position + forward * proj
		var perp := closest.distance_to(enode.global_position)
		if perp < 25.0:
			e["hp"] = float(e["hp"]) - laser_damage
			if float(e["hp"]) <= 0.0:
				e["alive"] = false
				enode.visible = false
				var bounty: int = int(e["bounty"])
				credits += bounty
				_emit_comm("[color=green]ENEMY DESTROYED! Bounty: %d cr[/color]" % bounty)
				sfx_requested.emit("enemy_explode")
			else:
				_emit_comm("HIT! Enemy HP: %.0f/%.0f" % [float(e["hp"]), float(e["hp_max"])])
				sfx_requested.emit("laser_hit")
			return

func _process_enemies(delta: float) -> void:
	for e in enemies:
		if not e["alive"]:
			continue
		var enode: Node3D = e["node"]
		var dist := enode.global_position.distance_to(player.global_position)
		if e["state"] == "patrol":
			e["patrol_angle"] += 0.3 * delta
			var center: Vector3 = e["patrol_center"]
			var r: float = e["patrol_radius"]
			var target := center + Vector3(cos(e["patrol_angle"]), 0, sin(e["patrol_angle"])) * r
			enode.position = enode.position.lerp(target, 2.0 * delta)
			if dist < 500.0:
				e["state"] = "attack"
				e["fire_cooldown"] = e["fire_interval"]
				_emit_comm("[color=yellow]PIRATE DETECTED![/color]")
		elif e["state"] == "attack":
			var to_player := (player.global_position - enode.global_position).normalized()
			var attack_pos := player.global_position - to_player * 150.0
			enode.position = enode.position.lerp(attack_pos, 1.5 * delta)
			enode.look_at(player.global_position, Vector3.UP)
			e["fire_cooldown"] = float(e["fire_cooldown"]) - delta
			if float(e["fire_cooldown"]) <= 0.0:
				e["fire_cooldown"] = e["fire_interval"]
				_spawn_enemy_projectile(e)
				sfx_requested.emit("enemy_fire")
			if dist > 800.0:
				e["state"] = "patrol"

func _spawn_enemy_projectile(e: Dictionary) -> void:
	var proj := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 1.5
	sphere.height = 3.0
	proj.mesh = sphere
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.2, 0.0, 0.9)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.3, 0.0)
	mat.emission_energy = 2.0
	proj.material_override = mat
	var enode: Node3D = e["node"]
	proj.position = enode.global_position
	var to_player: Vector3 = player.global_position - enode.global_position
	var dist := to_player.length()
	var proj_speed: float = float(config.get("enemy", {}).get("projectile_speed", 80.0))
	var lead_time := dist / proj_speed
	var predicted_pos := player.global_position + velocity * lead_time
	var dir: Vector3 = (predicted_pos - enode.global_position).normalized()
	add_child(proj)
	enemy_projectiles.append({
		"mesh": proj,
		"direction": dir,
		"speed": 80.0,
		"damage": float(e["damage"]),
		"life": 5.0,
	})

func _process_projectiles(delta: float) -> void:
	var to_remove: Array[int] = []
	for i in enemy_projectiles.size():
		var p: Dictionary = enemy_projectiles[i]
		p["mesh"].position += p["direction"] * float(p["speed"]) * delta
		p["life"] = float(p["life"]) - delta
		var dist: float = p["mesh"].position.distance_to(player.global_position)
		if dist < 8.0:
			_take_damage(float(p["damage"]))
			p["mesh"].queue_free()
			to_remove.append(i)
			continue
		if float(p["life"]) <= 0.0:
			p["mesh"].queue_free()
			to_remove.append(i)
	for idx in range(to_remove.size() - 1, -1, -1):
		enemy_projectiles.remove_at(to_remove[idx])

func _rotate_exit_station(delta: float) -> void:
	if _exit_station:
		_exit_station.rotation_degrees.y += exit_rotation_speed * delta

func _check_docking() -> void:
	if not _exit_station:
		return
	var dist := player.global_position.distance_to(_exit_station.global_position)
	if dist > 100.0:
		return
	var speed := velocity.length()
	if speed > 15.0:
		return
	if not toll_paid:
		_emit_comm("[color=yellow]Toll fee required: %d cr[/color]" % toll_fee)
		return
	var station_fwd := -_exit_station.transform.basis.z
	var to_player := (player.global_position - _exit_station.global_position).normalized()
	var angle := rad_to_deg(station_fwd.angle_to(to_player))
	if angle > 30.0:
		_take_damage(15.0)
		_emit_comm("[color=red]DOCKING COLLISION! Wrong angle.[/color]")
		var push_dir := (player.global_position - _exit_station.global_position).normalized()
		player.global_position += push_dir * 30.0
		return
	_emit_comm("[color=green]=== DOCKING SUCCESSFUL ===[/color]")
	_emit_comm("[color=green]=== LEVEL COMPLETE ===[/color]")
	sfx_requested.emit("dock_success")
	set_process(false)
	level_completed.emit()

func _update_starfield_position() -> void:
	if _starfield_node:
		_starfield_node.global_position = player.global_position

func _take_damage(amount: float) -> void:
	if shield > 0.0:
		var shield_absorb := minf(shield, amount)
		shield -= shield_absorb
		amount -= shield_absorb
	hp -= amount
	_emit_comm("[color=red]HIT! Shield: %.0f HP: %.0f[/color]" % [shield, hp])
	_hit_flash_timer = 0.3
	sfx_requested.emit("player_hit")
	if hp <= 0.0:
		_emit_comm("[color=red]=== SHIP DESTROYED ===[/color]")
		sfx_requested.emit("player_destroyed")
		set_process(false)
		level_failed.emit()

func try_dock() -> void:
	if is_docked:
		return
	for s in stations:
		var snode: Node3D = s["node"]
		var dist := player.global_position.distance_to(snode.global_position)
		if dist < 80.0:
			is_docked = true
			velocity = Vector3.ZERO
			_enter_station(s)
			return
	if _exit_station:
		var dist := player.global_position.distance_to(_exit_station.global_position)
		if dist < 100.0:
			if credits >= toll_fee and not toll_paid:
				toll_paid = true
				credits -= toll_fee
				_emit_comm("Toll fee paid: %d cr" % toll_fee)
				_emit_comm("Proceed to docking approach...")
			elif not toll_paid:
				_emit_comm("[color=red]Need %d cr toll fee![/color]" % toll_fee)

func _enter_station(station: Dictionary) -> void:
	_emit_comm("[color=cyan]--- %s ---[/color]" % station["name"])
	_emit_comm("Credits: %d cr | Cargo: %d/%d" % [credits, _cargo_used(), max_cargo])
	_emit_comm("Commands: BUY <item> <qty> | SELL <item> <qty> | LEAVE")
	for comm in commodities:
		var prices: Dictionary = station["prices"][comm]
		_emit_comm("  %s: Buy %d cr | Sell %d cr" % [commodity_names[comm], prices["buy"], prices["sell"]])
	in_trade = true
	_current_station = station

func execute_trade_command(cmd: String) -> void:
	if not in_trade:
		return
	var parts := cmd.split(" ", false)
	if parts.is_empty():
		return
	var command := parts[0].to_lower()
	match command:
		"buy":
			_cmd_buy(parts)
		"sell":
			_cmd_sell(parts)
		"leave":
			_leave_station()
		_:
			_emit_comm("[color=red]Unknown: BUY/SELL/LEAVE[/color]")

func _cmd_buy(parts: PackedStringArray) -> void:
	if parts.size() < 3:
		_emit_comm("BUY <food|textiles|machinery|luxuries> <qty>")
		return
	var item := parts[1].to_lower()
	var qty := int(parts[2])
	if not commodities.has(item):
		_emit_comm("[color=red]Unknown commodity[/color]")
		return
	if qty <= 0:
		_emit_comm("[color=red]Invalid quantity[/color]")
		return
	var prices: Dictionary = _current_station["prices"][item]
	var cost: int = int(prices["buy"]) * qty
	if credits < cost:
		_emit_comm("[color=red]Not enough credits (need %d)[/color]" % cost)
		return
	if _cargo_used() + qty > max_cargo:
		_emit_comm("[color=red]Cargo full (space: %d)[/color]" % (max_cargo - _cargo_used()))
		return
	credits -= cost
	cargo[item] = int(cargo.get(item, 0)) + qty
	_emit_comm("[color=green]Bought %d %s for %d cr[/color]" % [qty, commodity_names[item], cost])

func _cmd_sell(parts: PackedStringArray) -> void:
	if parts.size() < 3:
		_emit_comm("SELL <food|textiles|machinery|luxuries> <qty>")
		return
	var item := parts[1].to_lower()
	var qty := int(parts[2])
	if not commodities.has(item):
		_emit_comm("[color=red]Unknown commodity[/color]")
		return
	if qty <= 0:
		_emit_comm("[color=red]Invalid quantity[/color]")
		return
	var held := int(cargo.get(item, 0))
	if held < qty:
		_emit_comm("[color=red]Only have %d %s[/color]" % [held, commodity_names[item]])
		return
	var prices: Dictionary = _current_station["prices"][item]
	var revenue: int = int(prices["sell"]) * qty
	credits += revenue
	cargo[item] = held - qty
	if int(cargo[item]) <= 0:
		cargo.erase(item)
	_emit_comm("[color=green]Sold %d %s for %d cr[/color]" % [qty, commodity_names[item], revenue])

func _leave_station() -> void:
	is_docked = false
	in_trade = false
	_current_station = {}
	_emit_comm("Undocking...")
	_emit_comm("Credits: %d cr | Toll need: %d cr" % [credits, toll_fee])

func _cargo_used() -> int:
	var total := 0
	for key in cargo:
		total += int(cargo[key])
	return total

func _emit_comm(text: String) -> void:
	comm_output.emit(text)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		handle_input(event)

func handle_input(event: InputEventKey) -> void:
	if not event.pressed:
		var kc: int = event.keycode if event.keycode != 0 else event.physical_keycode
		match kc:
			KEY_A, KEY_Q:
				roll_input = 0.0
			KEY_D, KEY_E:
				roll_input = 0.0
			KEY_W:
				pitch_input = 0.0
			KEY_S:
				pitch_input = 0.0
			KEY_SPACE:
				laser_active = false
		return
	var kc: int = event.keycode if event.keycode != 0 else event.physical_keycode
	if in_trade:
		return
	match kc:
		KEY_A, KEY_Q:
			roll_input = -1.0
		KEY_D, KEY_E:
			roll_input = 1.0
		KEY_W:
			pitch_input = 1.0
		KEY_S:
			pitch_input = -1.0
		KEY_I:
			thrust_level = mini(thrust_level + 1, thrust_speeds.size() - 1)
			_emit_comm("Thrust: %d/%d" % [thrust_level, thrust_speeds.size() - 1])
		KEY_K:
			thrust_level = maxi(thrust_level - 1, 0)
			_emit_comm("Thrust: %d/%d" % [thrust_level, thrust_speeds.size() - 1])
		KEY_SPACE:
			laser_active = true
		KEY_T:
			try_dock()

func get_player_position() -> Vector3:
	return player.global_position if is_instance_valid(player) else Vector3.ZERO

func get_player_velocity() -> Vector3:
	return velocity

func get_player_heading() -> float:
	return _roll_cur

func get_enemies_for_radar() -> Array:
	var result: Array = []
	for e in enemies:
		result.append({
			"alive": e["alive"],
			"position": e["node"].global_position if is_instance_valid(e["node"]) else Vector3.ZERO,
			"index": e["index"],
		})
	return result

func get_stations_for_radar() -> Array:
	var result: Array = []
	for s in stations:
		result.append({
			"position": s["node"].global_position if is_instance_valid(s["node"]) else Vector3.ZERO,
			"name": s["name"],
			"index": s["index"],
		})
	return result

func get_exit_position() -> Vector3:
	return _exit_station.global_position if is_instance_valid(_exit_station) else Vector3.ZERO

func get_status_data() -> Dictionary:
	return {
		"hp": hp,
		"hp_max": hp_max,
		"shield": shield,
		"shield_max": shield_max,
		"energy": energy,
		"energy_max": energy_max,
		"credits": credits,
		"toll_fee": toll_fee,
		"toll_paid": toll_paid,
		"speed": velocity.length(),
		"thrust_level": thrust_level,
		"cargo_used": _cargo_used(),
		"cargo_max": max_cargo,
		"hit_flash": _hit_flash_timer > 0.0,
	}
