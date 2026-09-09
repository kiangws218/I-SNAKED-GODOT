@tool
class_name ItemSpawnPoint
extends Marker2D

@export var item_id: StringName = &"bean"
@export var spawn_id: StringName

func stable_id(_map_id: StringName) -> String:
	return String(spawn_id)

func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	draw_circle(Vector2.ZERO, 7.0, Color(1.0, 0.82, 0.25, 0.75))
	draw_arc(Vector2.ZERO, 11.0, 0.0, TAU, 16, Color(1.0, 0.95, 0.65), 2.0)
