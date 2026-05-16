extends Node3D

signal hit_player

var _path_follow: PathFollow3D = null
var _relative_z: float = -80.0
var _approach_speed: float = 0.0
var _alive: bool = true

func setup(p_path_follow: PathFollow3D, track_speed: float, rel_z: float) -> void:
	_path_follow = p_path_follow
	_relative_z = rel_z
	_approach_speed = track_speed
	var kill_zone := $KillZone as Area3D
	if kill_zone:
		kill_zone.body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	if not _alive or not _path_follow or not is_instance_valid(_path_follow):
		return
	var target := _path_follow.global_position + _path_follow.global_basis.z * _relative_z
	global_position = target
	global_rotation = _path_follow.global_rotation
	_relative_z += _approach_speed * delta
	if _relative_z > 20.0:
		queue_free()

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player_ship") or body.name == "Ship":
		hit_player.emit()
