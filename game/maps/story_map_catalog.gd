class_name StoryMapCatalog
extends RefCounted

const ORDER: Array[StringName] = [&"prologue_tutorial", &"wilderness", &"forest", &"cave"]

const MAPS := {
	&"prologue_tutorial": {
		"title": "序章 · 教学长廊", "size": Vector2i(72, 48), "spawn": Vector2(8.5, 24.5),
		"direction": Vector2.RIGHT, "walkable": Rect2i(4, 16, 51, 16), "ground": 1,
		"obstacles": [], "beans": [Vector2i(16,24), Vector2i(24,24), Vector2i(32,24), Vector2i(42,24), Vector2i(48,24), Vector2i(51,24)],
		"gate": {"id": &"tutorial_fragile_gate", "rect": Rect2i(48,16,3,1), "barrier_rect": Rect2i(48,15,3,1), "need": 3},
		"exit": {"rect": Rect2i(47,14,5,3), "target": &"wilderness"},
		"npcs": [], "enemy_spawns": [], "triggers": [],
	},
	&"wilderness": {
		"title": "荒野", "size": Vector2i(72, 48), "spawn": Vector2(7.5, 24.5),
		"direction": Vector2.RIGHT, "walkable": Rect2i(4, 12, 60, 25), "ground": 0,
		"obstacles": [Rect2i(20,18,2,2), Rect2i(31,29,2,2), Rect2i(48,16,2,2)],
		"beans_random": 8, "debug_exit": {"rect": Rect2i(60,22,3,5), "target": &"forest"},
		"npcs": [{"id": &"keti", "kind": &"keti", "position": Vector2(42.5,24.5)}], "enemy_spawns": [], "triggers": [],
	},
	&"forest": {
		"title": "森林与断桥", "size": Vector2i(100, 60), "spawn": Vector2(7.5, 30.5),
		"direction": Vector2.RIGHT, "walkable": Rect2i(2, 2, 96, 56), "ground": 0,
		"obstacles": [Rect2i(38,2,15,8), Rect2i(60,2,27,8), Rect2i(17,18,3,2), Rect2i(24,38,4,2), Rect2i(37,31,3,3), Rect2i(57,15,4,2), Rect2i(62,39,3,2), Rect2i(45,51,47,7), Rect2i(92,10,4,17), Rect2i(92,33,4,25)],
		"terrain": [{"rect": Rect2i(45,51,47,7), "tile": 2}, {"rect": Rect2i(38,2,54,8), "tile": 4}, {"rect": Rect2i(68,43,10,7), "tile": 1}],
		"beans": [Vector2i(11,29),Vector2i(14,32),Vector2i(17,27),Vector2i(20,34),Vector2i(23,30),Vector2i(26,33),Vector2i(34,25),Vector2i(38,29),Vector2i(42,34),Vector2i(46,27)],
		"bridge_gate": Rect2i(92,27,4,6), "pillar": {"id": &"forest_bridge_pillar", "cell": Vector2i(87,30), "charge": 3.0, "requires_node": true},
		"pillar_scan_bounds": Rect2i(80,20,17,20),
		"exit": {"rect": Rect2i(55,4,5,5), "target": &"cave"},
		"entries": {&"forest_cave_return": {"spawn": Vector2(56.5,11.5), "direction": Vector2.DOWN}},
		"items": [{"id": &"iron_sword", "cell": Vector2(30.5,25.5)}],
		"npcs": [{"id": &"ajie", "position": Vector2(48.5,28.5)}, {"id": &"lisi", "position": Vector2(50.5,32.5)}, {"id": &"buck", "position": Vector2(70.5,27.5)}, {"id": &"miro", "position": Vector2(70.5,30.5)}],
		"enemy_spawns": [{"type": &"slime", "position": Vector2(16.5,29.5)}, {"type": &"slime", "position": Vector2(21.5,34.5)}, {"type": &"slime", "position": Vector2(26.5,27.5)}, {"type": &"mushroom", "position": Vector2(29.5,24.5)}, {"type": &"slime", "position": Vector2(39.5,31.5)}],
		"triggers": [{"id": &"bridge_approach", "rect": Rect2i(84,22,8,17)}, {"id": &"camp_settlement", "rect": Rect2i(68,41,10,10)}],
	},
	&"cave": {
		"title": "横向洞窟", "size": Vector2i(64, 32), "spawn": Vector2(6.5,16.5),
		"direction": Vector2.RIGHT, "walkable": Rect2i(2,8,60,17), "ground": 3,
		"obstacles": [Rect2i(2,8,16,5), Rect2i(2,20,16,5), Rect2i(45,8,17,5), Rect2i(45,20,17,5)],
		"terrain": [{"rect": Rect2i(2,13,60,7), "tile": 3}, {"rect": Rect2i(18,8,27,17), "tile": 3}],
		"beans": [Vector2i(9,16),Vector2i(15,18),Vector2i(22,21),Vector2i(28,10),Vector2i(38,22),Vector2i(48,17)],
		"exit": {"rect": Rect2i(2,14,2,5), "target": &"forest", "entry": &"forest_cave_return"},
		"items": [{"id": &"soup", "cell": Vector2(14.5,16.5)}, {"id": &"healing_potion", "cell": Vector2(32.5,11.5)}, {"id": &"ring", "cell": Vector2(58.5,16.5)}],
		"npcs": [{"id": &"ajian", "position": Vector2(29.5,12.5), "status": &"bound_unconscious"}],
		"enemy_spawns": [], "triggers": [{"id": &"cave_goblin_archers", "origin": [Vector2(52.5,16.5), Vector2(55.5,18.5)], "approach": [Vector2(39.5,16.5), Vector2(42.5,18.5)]}],
	},
}

static func get_map(map_id: StringName) -> Dictionary:
	return MAPS.get(map_id, {}).duplicate(true)

static func is_valid(map_id: StringName) -> bool:
	return MAPS.has(map_id)
