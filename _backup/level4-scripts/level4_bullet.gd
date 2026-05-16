extends Node3D

var velocity: Vector3 = Vector3.FORWARD
var lifetime: float = 3.0
var magnet_radius: float = 3.0
var magnet_strength: float = 3.0
var is_player_bullet: bool = false
var _speed: float = 0.0

func _physics_process(delta: float) -> void:
	if is_player_bullet and magnet_radius > 0.0:
		_apply_magnetism(delta)
	global_position += velocity * delta
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()

func _apply_magnetism(_delta: float) -> void:
	var closest_enemy: Node3D = null
	var closest_dist_sq: float = magnet_radius * magnet_radius
	var enemies := get_tree().get_nodes_in_group("enemy")
	for node: Node in enemies:
		var enemy: Node3D = node as Node3D
		if enemy == null or not is_instance_valid(enemy):
			continue
		if not enemy.has_method("take_damage"):
			continue
		var dist_sq := (enemy.global_position - global_position).length_squared()
		if dist_sq < closest_dist_sq:
			closest_dist_sq = dist_sq
			closest_enemy = enemy
	if closest_enemy == null:
		return
	_speed = velocity.length()
	if _speed < 1.0:
		return
	var dir_to_enemy := (closest_enemy.global_position - global_position).normalized()
	velocity = velocity.lerp(dir_to_enemy * _speed, 0.1)
	velocity = velocity.normalized() * _speed
