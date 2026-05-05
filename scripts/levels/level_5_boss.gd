extends Node3D

signal level_completed
signal level_failed

enum InterferenceType { WIREFRAME, COMMAND_HIJACK, SPACEWAR_FLASHBACK }
enum BossPhase { PHASE_1, PHASE_2 }

var config: Dictionary = {}
var hp: float = 100.0
var hp_max: float = 100.0
var boss_hp: float = 500.0
var boss_hp_max: float = 500.0
var boss_phase: BossPhase = BossPhase.PHASE_1
var active_interference: InterferenceType = -1
var interference_timer: float = 0.0
var interference_cooldown: float = 10.0
var spacewar_triggered: bool = false

func _ready() -> void:
	_load_config()
	_setup_scene()

func _load_config() -> void:
	var file = FileAccess.open("res://assets/data/game_config.json", FileAccess.READ)
	if file:
		var json = JSON.new()
		json.parse(file.get_as_text())
		var data = json.data
		if data.has("boss"):
			config = data["boss"]
			if config.has("hp_max"):
				hp_max = config["hp_max"]
				hp = hp_max
			if config.has("boss_hp"):
				boss_hp = config["boss_hp"]
				boss_hp_max = boss_hp
		file.close()

func _setup_scene() -> void:
	push_warning("Level 5 Boss: setup complete")

func _process(delta: float) -> void:
	interference_timer += delta
	if interference_timer >= interference_cooldown:
		interference_timer = 0.0
		_trigger_interference()
	if boss_hp <= boss_hp_max * 0.5 and boss_phase == BossPhase.PHASE_1:
		boss_phase = BossPhase.PHASE_2
		interference_cooldown *= 0.5

func _trigger_interference() -> void:
	if hp < hp_max * float(config.get("spacewar_trigger_hp", 0.3)) and not spacewar_triggered:
		active_interference = InterferenceType.SPACEWAR_FLASHBACK
		spacewar_triggered = true
		push_warning("Level 5 Boss: SPACEWAR FLASHBACK!")
		return
	var options: Array[InterferenceType] = [InterferenceType.WIREFRAME, InterferenceType.COMMAND_HIJACK]
	active_interference = options.pick_random()
	match active_interference:
		InterferenceType.WIREFRAME:
			push_warning("Level 5 Boss: WIREFRAME INTERFERENCE")
		InterferenceType.COMMAND_HIJACK:
			push_warning("Level 5 Boss: COMMAND HIJACK")

func take_damage(amount: float) -> void:
	hp = maxf(0.0, hp - amount)
	if hp <= 0.0:
		push_warning("Level 5 Boss: SHIP DESTROYED")
		level_failed.emit()

func boss_take_damage(amount: float) -> void:
	boss_hp = maxf(0.0, boss_hp - amount)
	if boss_hp <= 0.0:
		push_warning("Level 5 Boss: Y2K BUG DEFEATED!")
		_start_ending()

func _start_ending() -> void:
	push_warning("Level 5 Boss: ACCELERATING... WHITE SCREEN... CREDITS")
	level_completed.emit()
