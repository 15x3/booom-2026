extends Control

@onready var hp_value: Label = $HP/HPValue
@onready var hp_bar: Sprite2D = $HP/Sprite2D

func update_hp(hp: float, hp_max: float) -> void:
	if hp_value:
		hp_value.text = "%.0f/%.0f" % [hp, hp_max]
	if hp_bar and hp_bar.material:
		var ratio: float = hp / hp_max if hp_max > 0.0 else 0.0
		hp_bar.material.set_shader_parameter("progress", ratio)
