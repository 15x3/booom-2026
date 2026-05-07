extends Node3D

signal destroyed(pos: Vector3, score: int)

var hp: float = 2.0
var max_hp: float = 2.0
var _rot_speed: Vector3 = Vector3.ZERO
var _score: int = 5
var _debris_count: int = 4
var _debris_lifetime: float = 0.6
var _debris_speed: float = 5.0
var _unbreakable: bool = false

func setup(cfg: Dictionary) -> void:
	max_hp = float(cfg.get("hp", 2.0))
	if max_hp < 0.0:
		_unbreakable = true
		max_hp = 999.0
	hp = max_hp
	_score = int(cfg.get("score", 5))
	_debris_count = int(cfg.get("debris_count", 4))
	_debris_lifetime = float(cfg.get("debris_lifetime", 0.6))
	_debris_speed = float(cfg.get("debris_speed", 5.0))
	_rot_speed = Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), randf_range(-1.0, 1.0))

func _physics_process(delta: float) -> void:
	rotation += _rot_speed * delta

func take_damage(amount: float) -> void:
	if _unbreakable:
		return
	hp -= amount
	if hp <= 0.0:
		_die()

func _die() -> void:
	destroyed.emit(global_position, _score)
	_spawn_debris()
	queue_free()

func _spawn_debris() -> void:
	var parent := get_parent()
	if parent == null:
		return
	for i: int in _debris_count:
		var shard := _Debris.new(
			global_position + Vector3(randf_range(-0.5, 0.5), randf_range(-0.5, 0.5), randf_range(-0.5, 0.5)),
			Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)).normalized() * _debris_speed,
			_debris_lifetime,
			randf_range(0.3, 1.0)
		)
		parent.add_child(shard)

class _Debris extends Node3D:
	var _vel: Vector3 = Vector3.ZERO
	var _life: float = 0.6

	func _init(pos: Vector3, vel: Vector3, life: float, _size_factor: float) -> void:
		global_position = pos
		_vel = vel
		_life = life

	func _ready() -> void:
		var mesh_inst := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.3, 0.3, 0.3)
		mesh_inst.mesh = box
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = Color(0.6, 0.5, 0.4)
		mesh_inst.material_override = mat
		add_child(mesh_inst)

	func _physics_process(delta: float) -> void:
		global_position += _vel * delta
		_vel *= 0.95
		_life -= delta
		scale = scale.move_toward(Vector3.ONE * 0.01, delta * 2.0)
		if _life <= 0.0:
			queue_free()
