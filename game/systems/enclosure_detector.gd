class_name EnclosureDetector
extends RefCounted

const DIRECTIONS: Array[Vector2i] = [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]


static func find_regions(bounds: Rect2i, blocked: Dictionary) -> Array[Dictionary]:
	var outside: Dictionary[Vector2i, bool] = {}
	var frontier: Array[Vector2i] = []
	for x in range(bounds.position.x, bounds.end.x):
		_queue_open(Vector2i(x, bounds.position.y), bounds, blocked, outside, frontier)
		_queue_open(Vector2i(x, bounds.end.y - 1), bounds, blocked, outside, frontier)
	for y in range(bounds.position.y, bounds.end.y):
		_queue_open(Vector2i(bounds.position.x, y), bounds, blocked, outside, frontier)
		_queue_open(Vector2i(bounds.end.x - 1, y), bounds, blocked, outside, frontier)
	_flood(bounds, blocked, outside, frontier)

	var visited := outside.duplicate()
	var regions: Array[Dictionary] = []
	for y in range(bounds.position.y, bounds.end.y):
		for x in range(bounds.position.x, bounds.end.x):
			var cell := Vector2i(x, y)
			if blocked.has(cell) or visited.has(cell):
				continue
			var region_cells: Array[Vector2i] = []
			var touches_body := false
			var touches_node := false
			var touches_connected_node := false
			var queue: Array[Vector2i] = [cell]
			visited[cell] = true
			while not queue.is_empty():
				var current: Vector2i = queue.pop_front()
				region_cells.append(current)
				for direction in DIRECTIONS:
					var neighbor: Vector2i = current + direction
					if blocked.has(neighbor):
						var kind: StringName = blocked[neighbor]
						touches_body = touches_body or kind == &"body"
						var is_node := kind == &"node" or kind == &"node_connected"
						touches_node = touches_node or is_node
						touches_connected_node = touches_connected_node or kind == &"node_connected"
					elif bounds.has_point(neighbor) and not visited.has(neighbor):
						visited[neighbor] = true
						queue.append(neighbor)
			regions.append({
				"cells": region_cells,
				"touches_body": touches_body,
				"touches_node": touches_node,
				"touches_connected_node": touches_connected_node,
			})
	return regions


static func _queue_open(cell: Vector2i, bounds: Rect2i, blocked: Dictionary, visited: Dictionary, queue: Array[Vector2i]) -> void:
	if bounds.has_point(cell) and not blocked.has(cell) and not visited.has(cell):
		visited[cell] = true
		queue.append(cell)


static func _flood(bounds: Rect2i, blocked: Dictionary, visited: Dictionary, queue: Array[Vector2i]) -> void:
	while not queue.is_empty():
		var current: Vector2i = queue.pop_front()
		for direction in DIRECTIONS:
			_queue_open(current + direction, bounds, blocked, visited, queue)
