class_name FragileGate
extends StaticBody2D

signal opened(gate_id: StringName)

const TILE_SIZE := 24.0
@export var gate_id: StringName = &"tutorial_fragile_gate"
@export_range(1, 99, 1) var need := 3
var progress := 0

func _ready() -> void:
	queue_redraw()

func setup(id: StringName, rect: Rect2i, required_hits: int, restored := false) -> void:
	gate_id = id
	need = required_hits
	position = (Vector2(rect.position) + Vector2(rect.size) * 0.5) * TILE_SIZE
	var collision := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision == null:
		collision = CollisionShape2D.new()
		collision.name = "CollisionShape2D"
		add_child(collision)
	var shape := RectangleShape2D.new()
	shape.size = Vector2(rect.size) * TILE_SIZE
	collision.shape = shape
	if restored:
		progress = need
		queue_free()
	queue_redraw()

func hit_by_bean(_projectile: BeanProjectile) -> void:
	progress = mini(need, progress + 1)
	queue_redraw()
	if progress >= need:
		opened.emit(gate_id)
		queue_free()

func _draw() -> void:
	var collision := get_node_or_null("CollisionShape2D") as CollisionShape2D
	var shape := collision.shape as RectangleShape2D if collision else null
	var size := shape.size if shape else Vector2(72, 24)
	var rect := Rect2(-size * 0.5, size)
	draw_rect(rect, Color("6d4c41"))
	for index in range(need):
		var x := rect.position.x + (index + 0.5) * size.x / need
		draw_circle(Vector2(x, 0), 4.0, Color("f3d55b") if index < progress else Color("332b2b"))
