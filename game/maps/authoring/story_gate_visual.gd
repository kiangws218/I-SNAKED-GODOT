@tool
extends Node2D

func _draw() -> void:
	var stone := Color("665c67")
	var mortar := Color("39333d")
	draw_rect(Rect2(-18, -66, 36, 132), mortar)
	for row in range(6):
		var offset := 0.0 if row % 2 == 0 else 9.0
		for column in range(-2, 2):
			var center := Vector2(column * 18.0 + offset, -55.0 + row * 22.0)
			draw_rect(Rect2(center - Vector2(8, 9), Vector2(16, 18)), stone)

