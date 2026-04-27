extends Control

func _draw() -> void:
	var center: Vector2 = size / 2.0
	var arm := 14.0
	var gap := 5.0
	var col := Color(0.0, 1.0, 0.5, 0.7)
	draw_line(Vector2(center.x - arm, center.y), Vector2(center.x - gap, center.y), col, 2.0)
	draw_line(Vector2(center.x + gap, center.y), Vector2(center.x + arm, center.y), col, 2.0)
	draw_line(Vector2(center.x, center.y - arm), Vector2(center.x, center.y - gap), col, 2.0)
	draw_line(Vector2(center.x, center.y + gap), Vector2(center.x, center.y + arm), col, 2.0)
