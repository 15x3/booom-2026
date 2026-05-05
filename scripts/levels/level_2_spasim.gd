extends Node3D

signal level_completed
signal level_failed
signal terminal_output(text: String)

var config: Dictionary = {}
var enemy_config: Dictionary = {}
var speed_table: Array[float] = [0.0, 20.0, 50.0, 100.0]
var phaser_damage: float = 8.0
var phaser_hit_width: float = 15.0
var phaser_beam_duration: float = 0.3
var torpedo_damage: float = 30.0
var torpedo_ammo_max: int = 3
var scan_range: float = 5000.0

var hp: float = 100.0
var hp_max: float = 100.0
var heading: float = 0.0
var thrust_tier: int = 0
var torpedo_ammo: int = 3

var phaser_enabled: bool = true
var torpedo_enabled: bool = true

var player: StaticBody3D
var camera: Camera3D
var end_point: Area3D
var enemies: Array[Dictionary] = []
var enemy_projectiles: Array[Dictionary] = []

var phaser_beam: MeshInstance3D
var hologram_mat: ShaderMaterial

enum EnemyState { IDLE, HOVER }

func _ready() -> void:
	_load_config()
	_setup_scene_references()
	_setup_enemies()
	_connect_signals()
	_create_hologram_material()
	_create_starfield()
	_create_phaser_beam()
	_print_welcome.call_deferred()

func _print_welcome() -> void:
	_print_line("=== SPASIM TERMINAL v1.0 ===")
	_print_line("PLATO NETWORK \u2014 1974")
	_print_line("TYPE HELP FOR COMMANDS")
	_print_line("")

func _load_config() -> void:
	var file = FileAccess.open("res://assets/data/game_config.json", FileAccess.READ)
	if file:
		var json = JSON.new()
		json.parse(file.get_as_text())
		var data = json.data
		if data.has("spasim"):
			config = data["spasim"]
			hp_max = float(config.get("hp_max", 100.0))
			hp = hp_max
			phaser_damage = float(config.get("phaser_damage", 8.0))
			phaser_hit_width = float(config.get("phaser_hit_width", 15.0))
			phaser_beam_duration = float(config.get("phaser_beam_duration", 0.3))
			torpedo_damage = float(config.get("torpedo_damage", 30.0))
			torpedo_ammo_max = int(config.get("torpedo_ammo", 3))
			torpedo_ammo = torpedo_ammo_max
			scan_range = float(config.get("scan_range", 5000.0))
			enemy_config = config.get("enemy", {})
			var st = config.get("speed_table", [0.0, 20.0, 50.0, 100.0])
			speed_table.clear()
			for v in st:
				speed_table.append(float(v))
		file.close()

func _setup_scene_references() -> void:
	player = $Player as StaticBody3D
	camera = $Player/Camera3D as Camera3D
	end_point = $EndPoint as Area3D

func _setup_enemies() -> void:
	var idx := 0
	var wander_r: float = float(enemy_config.get("wander_radius", 150.0))
	for child in get_children():
		if child.name.begins_with("Enemy"):
			var detection: Area3D = child.get_node_or_null("Detection")
			var mesh_inst: MeshInstance3D
			for sub in child.get_children():
				if sub is MeshInstance3D:
					mesh_inst = sub
					break
			if not mesh_inst:
				continue
			mesh_inst.material_override = hologram_mat
			var initial_offset := Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0)).normalized() * randf_range(0.0, wander_r)
			enemies.append({
				"node": child,
				"mesh": mesh_inst,
				"detection": detection,
				"hp": 12.0,
				"hp_max": 12.0,
				"state": EnemyState.IDLE,
				"wander_offset": initial_offset,
				"wander_target_offset": Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0)).normalized() * randf_range(0.0, wander_r),
				"fire_cooldown": float(enemy_config.get("fire_interval", 4.0)),
				"alive": true,
				"index": idx,
			})
			idx += 1

func _connect_signals() -> void:
	if end_point:
		end_point.body_entered.connect(_on_end_point_entered)
	for e in enemies:
		var det: Area3D = e["detection"]
		if det:
			var idx: int = e["index"]
			det.body_entered.connect(func(body): _on_enemy_detected(idx, body))

func _create_hologram_material() -> void:
	hologram_mat = ShaderMaterial.new()
	hologram_mat.shader = load("res://assets/shaders/advance hologram.gdshader")
	var white_tex = load("res://assets/spasim-main/textures/white_4x4.png")
	hologram_mat.set_shader_parameter("albedo_texture", white_tex)
	hologram_mat.set_shader_parameter("scanline_texture", white_tex)
	hologram_mat.set_shader_parameter("albedo_alpha", 0.85)
	hologram_mat.set_shader_parameter("tint_color", Color(1.0, 0.5, 0.0, 0.5))
	hologram_mat.set_shader_parameter("edge_color", Color(1.0, 0.3, 0.0, 1.0))
	hologram_mat.set_shader_parameter("edge_power", 0.5)
	hologram_mat.set_shader_parameter("edge_size", 1.5)
	hologram_mat.set_shader_parameter("edge_intensity", 1.0)
	hologram_mat.set_shader_parameter("scanline_tint", Color(1.0, 0.5, 0.0, 1.0))
	hologram_mat.set_shader_parameter("scanline_intensity", 0.8)
	hologram_mat.set_shader_parameter("scanline_density", 5.0)
	hologram_mat.set_shader_parameter("scanline_thickness", 1.0)
	hologram_mat.set_shader_parameter("scanline_speed", 0.2)
	hologram_mat.set_shader_parameter("enable_glitch", false)

func _create_starfield() -> void:
	var star_mesh := MeshInstance3D.new()
	star_mesh.name = "Starfield"
	var points := PackedVector3Array()
	for i in range(800):
		points.append(Vector3(
			randf_range(-3000.0, 3000.0),
			randf_range(-1000.0, 1000.0),
			randf_range(-500.0, 3000.0)
		))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = points
	var star_array_mesh := ArrayMesh.new()
	star_array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_POINTS, arrays)
	star_mesh.mesh = star_array_mesh
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.6, 0.2, 1.0)
	mat.point_size = 2.0
	star_mesh.material_override = mat
	add_child(star_mesh)

func _create_phaser_beam() -> void:
	phaser_beam = MeshInstance3D.new()
	phaser_beam.name = "PhaserBeam"
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.1
	cyl.bottom_radius = 0.1
	cyl.height = 100.0
	phaser_beam.mesh = cyl
	var beam_mat := StandardMaterial3D.new()
	beam_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	beam_mat.albedo_color = Color(1.0, 0.3, 0.0, 0.8)
	beam_mat.emission_enabled = true
	beam_mat.emission = Color(1.0, 0.5, 0.0)
	beam_mat.emission_energy = 3.0
	beam_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	phaser_beam.material_override = beam_mat
	phaser_beam.visible = false
	player.add_child(phaser_beam)

func _process(delta: float) -> void:
	if thrust_tier != 0:
		_move_ship(delta)
	_process_enemies(delta)
	_process_projectiles(delta)

func _get_speed() -> float:
	var abs_tier := absi(thrust_tier)
	var base: float = speed_table[clampi(abs_tier, 0, speed_table.size() - 1)]
	return base * signf(float(thrust_tier))

func thrust_name() -> String:
	if thrust_tier == 0:
		return "STOP"
	var abs_t := absi(thrust_tier)
	var tier_labels := ["", "SLOW", "CRUISE", "FAST"]
	var label: String = tier_labels[clampi(abs_t, 1, 3)]
	if thrust_tier < 0:
		label = "REV " + label
	return label

func _move_ship(delta: float) -> void:
	var speed: float = _get_speed()
	var heading_rad: float = deg_to_rad(heading)
	var dir := Vector3(sin(heading_rad), 0.0, cos(heading_rad))
	player.position += dir * speed * delta
	player.rotation_degrees.y = 180.0 - heading

func _process_enemies(delta: float) -> void:
	var hover_dist: float = float(enemy_config.get("hover_distance", 200.0))
	var wander_r: float = float(enemy_config.get("wander_radius", 150.0))
	var drift_spd: float = float(enemy_config.get("drift_speed", 2.0))
	var fire_interval: float = float(enemy_config.get("fire_interval", 4.0))

	for e in enemies:
		if not e["alive"]:
			continue
		if e["state"] != EnemyState.HOVER:
			continue
		var wo: Vector3 = e["wander_offset"]
		var wt: Vector3 = e["wander_target_offset"]
		wo = wo.lerp(wt, drift_spd * delta)
		if wo.distance_to(wt) < 10.0:
			wt = Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0)).normalized() * randf_range(0.0, wander_r)
			e["wander_target_offset"] = wt
		e["wander_offset"] = wo
		var heading_rad := deg_to_rad(heading)
		var forward := Vector3(sin(heading_rad), 0.0, cos(heading_rad))
		var base_point := player.position + forward * hover_dist
		var target := base_point + wo
		target.y = 0.0
		var enode: Node3D = e["node"]
		enode.position = enode.position.lerp(target, drift_spd * delta)
		enode.look_at(player.position, Vector3.UP)
		e["fire_cooldown"] = float(e["fire_cooldown"]) - delta
		if float(e["fire_cooldown"]) <= 0.0:
			e["fire_cooldown"] = fire_interval
			_spawn_enemy_projectile(e)

func _spawn_enemy_projectile(e: Dictionary) -> void:
	var proj_speed: float = float(enemy_config.get("projectile_speed", 60.0))
	var proj_life: float = float(enemy_config.get("projectile_life", 6.0))
	var proj_damage: float = float(enemy_config.get("projectile_damage", 5.0))
	var proj := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.5
	sphere.height = 1.0
	proj.mesh = sphere
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.2, 0.0, 0.9)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.3, 0.0)
	mat.emission_energy = 2.0
	proj.material_override = mat
	var enode: Node3D = e["node"]
	proj.position = enode.position
	var dir: Vector3 = (player.position - enode.position).normalized()
	add_child(proj)
	enemy_projectiles.append({"mesh": proj, "direction": dir, "speed": proj_speed, "damage": proj_damage, "life": proj_life})

func _process_projectiles(delta: float) -> void:
	var hit_radius: float = float(enemy_config.get("projectile_hit_radius", 3.0))
	var to_remove: Array[int] = []
	for i in enemy_projectiles.size():
		var p: Dictionary = enemy_projectiles[i]
		p["mesh"].position += p["direction"] * float(p["speed"]) * delta
		p["life"] = float(p["life"]) - delta
		var dist_to_ship: float = p["mesh"].position.distance_to(player.position)
		if dist_to_ship < hit_radius:
			take_damage(float(p["damage"]))
			_print_line("[color=red]HIT! HP: %.0f/%.0f[/color]" % [hp, hp_max])
			p["mesh"].queue_free()
			to_remove.append(i)
			continue
		if float(p["life"]) <= 0.0:
			p["mesh"].queue_free()
			to_remove.append(i)
	for idx in to_remove:
		enemy_projectiles.remove_at(idx)

func _on_enemy_detected(enemy_idx: int, body: Node3D) -> void:
	if body != player:
		return
	if enemy_idx >= enemies.size():
		return
	var e: Dictionary = enemies[enemy_idx]
	if not e["alive"]:
		return
	if e["state"] == EnemyState.IDLE:
		e["state"] = EnemyState.HOVER
		e["fire_cooldown"] = float(enemy_config.get("fire_interval", 4.0))
		_print_line("[color=yellow]ENEMY %d DETECTED YOU![/color]" % [enemy_idx + 1])

func _on_end_point_entered(body: Node3D) -> void:
	if body == player:
		_print_line("[color=yellow]=== ARRIVED AT DESTINATION ===[/color]")
		set_process(false)
		level_completed.emit()

func execute_command(cmd: String) -> void:
	if cmd.is_empty():
		return
	_print_line("> %s" % cmd.to_upper())
	var parts := cmd.split(" ", false)
	var command := parts[0].to_lower()
	match command:
		"head":
			_cmd_head(parts)
		"thrust":
			_cmd_thrust(parts)
		"aim":
			_cmd_aim(parts)
		"scan":
			_do_scan()
		"help":
			_do_help()
		_:
			_print_line("[color=red]ERROR: UNKNOWN COMMAND[/color]")

func _cmd_head(parts: PackedStringArray) -> void:
	if parts.size() < 2:
		_print_line("[color=red]ERROR: HEAD <angle>[/color]")
		return
	var val := float(parts[1])
	if not is_finite(val):
		_print_line("[color=red]ERROR: INVALID NUMBER[/color]")
		return
	heading = fmod(val, 360.0)
	if heading < 0.0:
		heading += 360.0
	_print_line("HEADING SET: %.0f\u00B0" % heading)

func _cmd_thrust(parts: PackedStringArray) -> void:
	if parts.size() < 2:
		_print_line("[color=red]ERROR: THRUST <-3 to 3>[/color]")
		return
	var val := int(float(parts[1]))
	val = clampi(val, -3, 3)
	thrust_tier = val
	_print_line("THRUST: %s" % thrust_name())

func _cmd_aim(parts: PackedStringArray) -> void:
	if parts.size() < 3:
		_print_line("[color=red]ERROR: AIM <PHASER|TORPEDO> <enemy#>[/color]")
		return
	var weapon := parts[1].to_lower()
	var target_str := parts[2]
	var target_idx := int(float(target_str)) - 1
	if target_idx < 0 or target_idx >= enemies.size():
		_print_line("[color=red]ERROR: INVALID TARGET[/color]")
		return
	var e: Dictionary = enemies[target_idx]
	if not e["alive"]:
		_print_line("[color=red]TARGET ALREADY DESTROYED[/color]")
		return
	match weapon:
		"phaser":
			if not phaser_enabled:
				_print_line("[color=red]PHASER OFFLINE[/color]")
				return
			_fire_phaser_at(e)
		"torpedo":
			if not torpedo_enabled:
				_print_line("[color=red]TORPEDO OFFLINE[/color]")
				return
			_fire_torpedo_at(e)
		_:
			_print_line("[color=red]ERROR: UNKNOWN WEAPON (PHASER|TORPEDO)[/color]")

func _fire_phaser_at(e: Dictionary) -> void:
	phaser_beam.visible = true
	phaser_beam.position = Vector3(0.0, 0.0, -50.0)
	phaser_beam.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	get_tree().create_timer(phaser_beam_duration).timeout.connect(func(): if is_instance_valid(phaser_beam): phaser_beam.visible = false)
	var heading_rad := deg_to_rad(heading)
	var fire_dir := Vector3(sin(heading_rad), 0.0, cos(heading_rad))
	var enode: Node3D = e["node"]
	var to_enemy: Vector3 = enode.position - player.position
	var proj: float = to_enemy.dot(fire_dir)
	if proj <= 0.0:
		_print_line("TARGET NOT IN SIGHT")
		return
	var closest_point: Vector3 = player.position + fire_dir * proj
	var perp_dist: float = closest_point.distance_to(enode.position)
	if perp_dist > phaser_hit_width:
		_print_line("TARGET NOT IN SIGHT")
		return
	e["hp"] = float(e["hp"]) - phaser_damage
	if float(e["hp"]) <= 0.0:
		e["alive"] = false
		e["node"].visible = false
		_print_line("[color=green]ENEMY DESTROYED[/color]")
	else:
		_print_line("HIT! ENEMY HP: %.0f/%.0f" % [float(e["hp"]), float(e["hp_max"])])

func _fire_torpedo_at(e: Dictionary) -> void:
	if torpedo_ammo <= 0:
		_print_line("[color=red]NO TORPEDOES LEFT[/color]")
		return
	torpedo_ammo -= 1
	var enode: Node3D = e["node"]
	var dir: Vector3 = (enode.position - player.position).normalized()
	var torp := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	torp.mesh = sphere
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.0, 0.8, 1.0, 0.9)
	mat.emission_enabled = true
	mat.emission = Color(0.3, 0.6, 1.0)
	mat.emission_energy = 3.0
	torp.material_override = mat
	torp.position = player.position + dir * 5.0
	add_child(torp)
	var target_pos: Vector3 = enode.position
	var speed := 120.0
	var travel := (target_pos - torp.position).length()
	var duration := travel / speed
	var tween := create_tween()
	tween.tween_property(torp, "position", target_pos, duration)
	tween.tween_callback(func():
		if is_instance_valid(torp):
			torp.queue_free()
		_apply_torpedo_hit(e)
	)

func _apply_torpedo_hit(e: Dictionary) -> void:
	if not e["alive"]:
		return
	e["hp"] = float(e["hp"]) - torpedo_damage
	if float(e["hp"]) <= 0.0:
		e["alive"] = false
		e["node"].visible = false
		_print_line("[color=green]TORPEDO HIT \u2014 ENEMY DESTROYED[/color]")
	else:
		_print_line("TORPEDO HIT! ENEMY HP: %.0f/%.0f" % [float(e["hp"]), float(e["hp_max"])])

func enable_weapon(weapon_name: String) -> void:
	match weapon_name.to_lower():
		"phaser":
			phaser_enabled = true
			_print_line("PHASER ONLINE")
		"torpedo":
			torpedo_enabled = true
			_print_line("TORPEDO ONLINE")

func disable_weapon(weapon_name: String) -> void:
	match weapon_name.to_lower():
		"phaser":
			phaser_enabled = false
			_print_line("PHASER OFFLINE")
		"torpedo":
			torpedo_enabled = false
			_print_line("TORPEDO OFFLINE")

func _do_scan() -> void:
	var end_pos: Vector3 = end_point.position
	var dist_ep := player.position.distance_to(end_pos)
	var dir_to_ep := player.position.direction_to(end_pos)
	var bearing := rad_to_deg(atan2(dir_to_ep.x, dir_to_ep.z))
	if bearing < 0.0:
		bearing += 360.0
	_print_line("--- SCAN ---")
	_print_line("HDG: %.0f\u00B0 | THRUST: %s | HP: %.0f/%.0f" % [heading, thrust_name(), hp, hp_max])
	_print_line("TORPEDOES: %d/%d" % [torpedo_ammo, torpedo_ammo_max])
	_print_line("PHASER: %s | TORPEDO: %s" % ["ONLINE" if phaser_enabled else "OFFLINE", "ONLINE" if torpedo_enabled else "OFFLINE"])
	_print_line("DESTINATION: BEARING %.0f\u00B0 | DIST %.0f" % [bearing, dist_ep])
	var enemy_idx := 0
	for e in enemies:
		enemy_idx += 1
		if not e["alive"]:
			_print_line("ENEMY %d: DESTROYED" % enemy_idx)
			continue
		var enode: Node3D = e["node"]
		var dist := player.position.distance_to(enode.position)
		if dist < scan_range:
			var edir := player.position.direction_to(enode.position)
			var ebearing := rad_to_deg(atan2(edir.x, edir.z))
			if ebearing < 0.0:
				ebearing += 360.0
			var state_str := "HOVER" if e["state"] == EnemyState.HOVER else "IDLE"
			_print_line("ENEMY %d: BEARING %.0f\u00B0 | DIST %.0f | HP %.0f | %s" % [enemy_idx, ebearing, dist, float(e["hp"]), state_str])
	_print_line("--- END ---")

func _do_help() -> void:
	_print_line("--- COMMANDS ---")
	_print_line("HEAD <0-360>           Set heading")
	_print_line("THRUST <-3 to 3>       Speed (+fwd/-rev)")
	_print_line("AIM PHASER <n>         Fire phaser at enemy #n")
	_print_line("AIM TORPEDO <n>        Fire torpedo at enemy #n")
	_print_line("SCAN                   Scan area")
	_print_line("HELP                   This list")
	_print_line("--- END ---")

func _print_line(text: String) -> void:
	terminal_output.emit(text)

func take_damage(amount: float) -> void:
	hp = maxf(0.0, hp - amount)
	if hp <= 0.0:
		_print_line("[color=red]=== SYSTEM FAILURE ===[/color]")
		level_failed.emit()

func get_player_position() -> Vector3:
	return player.position if is_instance_valid(player) else Vector3.ZERO

func get_end_point_position() -> Vector3:
	return end_point.position if is_instance_valid(end_point) else Vector3.ZERO

func get_enemies_for_map() -> Array:
	var result: Array = []
	for e in enemies:
		result.append({
			"alive": e["alive"],
			"position": e["node"].position if is_instance_valid(e["node"]) else Vector3.ZERO,
			"index": e["index"],
		})
	return result

func get_status_data() -> Dictionary:
	return {
		"hp": hp,
		"hp_max": hp_max,
		"heading": heading,
		"thrust_name": thrust_name(),
		"torpedo_ammo": torpedo_ammo,
		"torpedo_ammo_max": torpedo_ammo_max,
		"phaser_enabled": phaser_enabled,
		"torpedo_enabled": torpedo_enabled,
	}
