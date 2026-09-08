class_name BodyChain
extends Node2D

@export_range(3, 512, 1) var segment_count := 4
@export var spacing := 24.0
@export var tile_size := 24.0

var path: Array[Vector2] = []
var segments: Array[Vector2] = []
var occupied_cells: Dictionary[Vector2i, bool] = {}


func _ready() -> void:
	top_level = true


func reset(head: Vector2, direction: Vector2) -> void:
	path.clear()
	for index in range(1, segment_count + 4):
		path.append(head - direction * spacing * index)
	rebuild(head)


func record_head(head: Vector2) -> void:
	if path.is_empty() or head.distance_to(path[0]) > tile_size * 0.02:
		path.push_front(head)
	rebuild(head)


func rebuild(head: Vector2) -> void:
	segments.assign([head])
	var previous := head
	var target_distance := spacing
	var travelled := 0.0
	for point in path:
		if segments.size() >= segment_count:
			break
		var edge_length := previous.distance_to(point)
		if edge_length > 0.0:
			while travelled + edge_length >= target_distance and segments.size() < segment_count:
				var ratio := (target_distance - travelled) / edge_length
				segments.append(previous.lerp(point, ratio))
				target_distance += spacing
			travelled += edge_length
		previous = point
	while segments.size() < segment_count:
		segments.append(previous)
	_rebuild_occupancy()
	_prune_path((segment_count - 1) * spacing + 3.0 * tile_size)
	queue_redraw()


func collides_with_tail(candidate: Vector2, threshold: float, neck_guard := 4) -> bool:
	for index in range(maxi(2, neck_guard), segments.size()):
		if candidate.distance_to(segments[index]) < threshold:
			return true
	return false


func _rebuild_occupancy() -> void:
	occupied_cells.clear()
	for segment in segments:
		occupied_cells[_to_cell(segment)] = true
	for index in range(segments.size() - 1):
		var a := _to_cell(segments[index])
		var b := _to_cell(segments[index + 1])
		if a.x != b.x and a.y != b.y:
			occupied_cells[Vector2i(a.x, b.y)] = true
			occupied_cells[Vector2i(b.x, a.y)] = true


func _to_cell(point: Vector2) -> Vector2i:
	return Vector2i(floori(point.x / tile_size), floori(point.y / tile_size))


func _prune_path(max_length: float) -> void:
	var travelled := 0.0
	var keep := path.size()
	for index in range(path.size() - 1):
		travelled += path[index].distance_to(path[index + 1])
		if travelled >= max_length:
			keep = index + 2
			break
	path.resize(keep)


func _draw() -> void:
	if segments.size() < 2:
		return
	for index in range(segments.size() - 1, 0, -1):
		var fade := float(index) / float(maxi(1, segments.size() - 1))
		draw_circle(segments[index], 8.5, Color(0.25, 0.62 + fade * 0.15, 0.22))
		draw_circle(segments[index], 5.0, Color(0.42, 0.84, 0.31))
