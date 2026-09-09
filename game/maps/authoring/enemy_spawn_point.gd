@tool
class_name EnemySpawnPoint
extends Marker2D

@export var spawn_id: StringName
@export_enum("slime", "mushroom", "goblin") var enemy_kind := "slime"

func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	var color := Color(1.0, 0.35, 0.3, 0.8)
	draw_circle(Vector2.ZERO, 10.0, Color(color, 0.2))
	draw_line(Vector2(-12, 0), Vector2(12, 0), color, 3.0)
	draw_line(Vector2(0, -12), Vector2(0, 12), color, 3.0)
