class_name RingNode
extends Node2D

signal reclaimed(node: RingNode)
signal destroyed(node: RingNode)

const TILE_SIZE := 24.0

var cell := Vector2i.ZERO
var hp := 2
var armed := false
var finished := false
var visual_offset := Vector2.ZERO


func setup(target_cell: Vector2i, placement_position: Vector2) -> void:
	cell = target_cell
	global_position = (Vector2(cell) + Vector2(0.5, 0.5)) * TILE_SIZE
	visual_offset = placement_position - global_position
	$Sprite2D.position = visual_offset
	queue_redraw()


func update_body_occupancy(occupied_cells: Dictionary) -> void:
	if finished:
		return
	if occupied_cells.has(cell):
		armed = true
	elif armed:
		finished = true
		reclaimed.emit(self)


func damage(amount: int) -> void:
	if finished or amount <= 0:
		return
	hp = maxi(0, hp - amount)
	if hp == 0:
		finished = true
		destroyed.emit(self)
	queue_redraw()


func _draw() -> void:
	if hp == 1:
		draw_arc(visual_offset, 10.0, 0.0, TAU, 16, Color("ef8354"), 2.0)
