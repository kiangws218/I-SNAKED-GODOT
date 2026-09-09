class_name StoryMapCatalog
extends RefCounted

const ORDER: Array[StringName] = [&"prologue_tutorial", &"wilderness", &"forest", &"cave"]

# Positions and authored gameplay objects live in each map scene. This registry
# only answers which scene to load and the camera bounds it owns.
const MAPS := {
	&"prologue_tutorial": {"title": "序章 · 教学长廊", "scene": "res://game/maps/levels/prologue_tutorial.tscn", "size": Vector2i(72, 48)},
	&"wilderness": {"title": "荒野", "scene": "res://game/maps/levels/wilderness.tscn", "size": Vector2i(72, 48)},
	&"forest": {"title": "森林与断桥", "scene": "res://game/maps/levels/forest.tscn", "size": Vector2i(100, 60)},
	&"cave": {"title": "横向洞窟", "scene": "res://game/maps/levels/cave.tscn", "size": Vector2i(64, 32)},
}

static func get_map(map_id: StringName) -> Dictionary:
	return MAPS.get(map_id, {}).duplicate(true)

static func is_valid(map_id: StringName) -> bool:
	return MAPS.has(map_id)
