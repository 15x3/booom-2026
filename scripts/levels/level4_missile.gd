extends Node3D

var speed: float = 120.0
var lifetime: float = 4.0
var damage: float = 5.0
var _target: Node3D = null
var _turn_rate: float = 4.0

func _physics_process(delta: float) -> void:
	_acquire_target()
	if _target and is_instance_valid(_target):
		var dir_to_target := (_target.global_position - global_position).normalized()
		var forward := -global_basis.z
		forward = forward.lerp(dir_to_target, _turn_rate * delta).normalized()
		look_at(global_position + forward, Vector3.UP)
		global_position += forward * speed * delta
	else:
		global_position += (-global_basis.z) * speed * delta
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()

func _acquire_target() -> void:
	var best_dist_sq: float = 9000000.0
	var best: Node3D = null
	for node: Node in get_tree().get_nodes_in_group("enemy"):
		var enemy: Node3D = node as Node3D
		if enemy == null or not is_instance_valid(enemy):
			continue
		var dist_sq := (enemy.global_position - global_position).length_squared()
		if dist_sq < best_dist_sq:
			best_dist_sq = dist_sq
			best = enemy
	_target = best

func _on_hitbox_area_entered(area: Area3D) -> void:
	var target: Node3D = area.get_parent() as Node3D
	if target == null:
		return
	if target.is_in_group("enemy"):
		if target.has_method("take_damage"):
			target.take_damage(damage)
		queue_free()
	elif target.is_in_group("obstacle"):
		if target.has_method("take_damage"):
			target.take_damage(damage)
		queue_free()
