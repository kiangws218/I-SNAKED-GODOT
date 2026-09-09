extends Node2D

var progress := 0.0
var done := false

func _draw() -> void:
	draw_circle(Vector2.ZERO, 18.0, Color("ffd76e") if done else Color("ff8f5e"))
	draw_circle(Vector2.ZERO, 11.0, Color("58465c"))
	draw_arc(Vector2.ZERO, 22.0, -PI * 0.5, -PI * 0.5 + TAU * progress, 24, Color("fff1a8"), 4.0)
