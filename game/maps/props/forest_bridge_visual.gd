@tool
extends Node2D

@export var bridge_size := Vector2(96.0, 72.0)
@export var plank_count := 4

func _ready() -> void:
	queue_redraw()

func _draw() -> void:
	var half_width := bridge_size.x * 0.5
	var half_height := bridge_size.y * 0.5
	draw_rect(Rect2(-half_width, -half_height, bridge_size.x, bridge_size.y), Color("6b493e"), true)
	draw_rect(Rect2(-half_width, -half_height, bridge_size.x, bridge_size.y), Color("d49a5f"), false, 4.0)
	for index in range(maxi(1, plank_count)):
		var y := lerpf(-half_height + 10.0, half_height - 10.0, float(index) / float(maxi(1, plank_count - 1)))
		draw_line(Vector2(-half_width + 6.0, y), Vector2(half_width - 6.0, y), Color("b9784c"), 3.0)
	draw_line(Vector2(-half_width + 8.0, -half_height + 5.0), Vector2(-half_width + 8.0, half_height - 5.0), Color("473542"), 4.0)
	draw_line(Vector2(half_width - 8.0, -half_height + 5.0), Vector2(half_width - 8.0, half_height - 5.0), Color("473542"), 4.0)
