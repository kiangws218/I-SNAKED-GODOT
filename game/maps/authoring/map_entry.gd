@tool
class_name MapEntry
extends Marker2D

@export var entry_id: StringName = &"default"
@export var facing := Vector2.RIGHT:
	set(value):
		facing = value.normalized() if not value.is_zero_approx() else Vector2.RIGHT
		queue_redraw()

func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	draw_circle(Vector2.ZERO, 8.0, Color(0.25, 0.8, 1.0, 0.65))
	draw_line(Vector2.ZERO, facing * 22.0, Color(0.85, 0.97, 1.0), 3.0)

