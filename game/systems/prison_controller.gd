class_name PrisonController
extends Node

signal prison_burst(target: Node2D, damage: float, node_prison: bool)

const TILE_SIZE := 24.0
const PLAIN_BURST := 10.0
const PLAIN_DPS := 10.0
const NODE_BURST := 15.0
const NODE_DPS := 30.0
const EXTRA_NODE_PRISON_PENALTY := 1.0
const BURST_COOLDOWN := 1.0

var active_prisons := 0
var active_node_prisons := 0
var _inside: Dictionary[int, bool] = {}
var _burst_cooldowns: Dictionary[int, float] = {}
var _bite_accumulator := 0.0


func step(delta: float, bounds: Rect2i, blocked: Dictionary, targets: Array, nodes: Array) -> Dictionary:
	for id in _burst_cooldowns.keys():
		_burst_cooldowns[id] = maxf(0.0, _burst_cooldowns[id] - delta)
	var regions := EnclosureDetector.find_regions(bounds, blocked)
	var active_regions: Array[Dictionary] = []
	var target_regions: Dictionary[int, Dictionary] = {}
	for region in regions:
		if not bool(region.touches_body):
			continue
		var occupied := false
		for target in targets:
			if not _valid_target(target):
				continue
			if region.cells.has(_to_cell(target.global_position)):
				occupied = true
				target_regions[target.get_instance_id()] = region
		if occupied:
			active_regions.append(region)
	active_prisons = active_regions.size()
	active_node_prisons = active_regions.filter(func(region: Dictionary) -> bool: return bool(region.touches_node)).size()
	var now_inside: Dictionary[int, bool] = {}
	for target in targets:
		if not _valid_target(target):
			continue
		var id: int = target.get_instance_id()
		if not target_regions.has(id):
			continue
		var region: Dictionary = target_regions[id]
		var node_prison := bool(region.touches_node)
		now_inside[id] = true
		if not _inside.has(id) and _burst_cooldowns.get(id, 0.0) <= 0.0:
			var burst := NODE_BURST if node_prison else PLAIN_BURST
			target.take_damage(burst, &"prison")
			_burst_cooldowns[id] = BURST_COOLDOWN
			prison_burst.emit(target, burst, node_prison)
		if is_instance_valid(target):
			var dps := NODE_DPS - EXTRA_NODE_PRISON_PENALTY * maxi(0, active_node_prisons - 1) if node_prison else PLAIN_DPS
			target.take_damage(dps * delta, &"prison")
	_inside = now_inside
	_update_node_biting(delta, targets, nodes, now_inside)
	return {"active": active_prisons, "node": active_node_prisons}


func _update_node_biting(delta: float, targets: Array, nodes: Array, now_inside: Dictionary) -> void:
	_bite_accumulator += delta
	if _bite_accumulator < 1.0:
		return
	_bite_accumulator -= 1.0
	for ring in nodes:
		if not is_instance_valid(ring) or ring.finished:
			continue
		for target in targets:
			if not is_instance_valid(target) or not target.is_in_group(&"enemy") or not now_inside.has(target.get_instance_id()):
				continue
			if target.global_position.distance_to(ring.global_position) < 1.4 * TILE_SIZE:
				ring.damage(1)
				return


func _valid_target(target: Variant) -> bool:
	return is_instance_valid(target) and target is Node2D and target.has_method("is_prison_target") and target.is_prison_target()


func _to_cell(point: Vector2) -> Vector2i:
	return Vector2i(floori(point.x / TILE_SIZE), floori(point.y / TILE_SIZE))
