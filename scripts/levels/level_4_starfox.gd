extends Node3D

signal level_completed
signal level_failed

var config: Dictionary = {}
var hp: float = 100.0
var hp_max: float = 100.0

func _ready() -> void:
	_load_config()
	_setup_scene()

func _load_config() -> void:
	var file = FileAccess.open("res://assets/data/game_config.json", FileAccess.READ)
	if file:
		var json = JSON.new()
		json.parse(file.get_as_text())
		var data = json.data
		if data.has("starfox"):
			config = data["starfox"]
			if config.has("hp_max"):
				hp_max = config["hp_max"]
				hp = hp_max
		file.close()

func _setup_scene() -> void:
	Engine.max_fps = int(config.get("target_fps", 30))
	push_warning("Level 4 Star Fox: setup complete (FPS: %d)" % Engine.max_fps)

func take_damage(amount: float) -> void:
	hp = maxf(0.0, hp - amount)
	if hp <= 0.0:
		push_warning("Level 4 Star Fox: SHIP DESTROYED")
		level_failed.emit()

func _on_arrived_at_blackhole() -> void:
	push_warning("Level 4 Star Fox: ARRIVED AT BLACKHOLE")
	level_completed.emit()
