extends Node2D

var kind: StringName = &"item"
var label := ""

func setup(prop_kind: StringName, prop_label: String, at_position: Vector2) -> void:
	kind = prop_kind
	label = prop_label
	position = at_position
	queue_redraw()

func _draw() -> void:
	if kind == &"exit":
		draw_rect(Rect2(-12, -12, 24, 24), Color(0.45, 0.85, 1.0, 0.28))
		draw_arc(Vector2.ZERO, 9.0, 0.0, TAU, 16, Color("7fd1e8"), 2.0)
	elif kind == &"soup":
		draw_circle(Vector2.ZERO, 9.0, Color("7a4d35"))
		draw_arc(Vector2.ZERO, 7.0, PI, TAU, 12, Color("ffcf70"), 3.0)
	elif kind == &"healing_potion":
		draw_rect(Rect2(-6, -8, 12, 16), Color("f06c9b"))
	elif kind == &"ring":
		draw_arc(Vector2.ZERO, 9.0, 0.0, TAU, 18, Color("ffd76e"), 3.0)
	else:
		draw_rect(Rect2(-9, -3, 18, 6), Color("d9e2e8"))
