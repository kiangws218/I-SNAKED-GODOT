class_name StoryMapCatalog
extends RefCounted

const ORDER: Array[StringName] = [&"prologue_tutorial", &"wilderness", &"forest", &"cave", &"chapter2_slice"]

# Positions and authored gameplay objects live in each map scene. This registry
# only answers which scene to load and the camera bounds it owns.
const MAPS := {
	&"chapter2_slice": {"title": "第二章 · 把她带走（灰盒）", "scene": "res://game/maps/levels/chapter2_slice.tscn", "size": Vector2i(56, 30), "music_cue": &"music.forest"},
	&"prologue_tutorial": {"title": "序章 · 教学长廊", "scene": "res://game/maps/levels/prologue_tutorial.tscn", "size": Vector2i(72, 48), "music_cue": &"music.tutorial"},
	&"wilderness": {"title": "荒野", "scene": "res://game/maps/levels/wilderness.tscn", "size": Vector2i(72, 48), "music_cue": &"music.wilderness"},
	&"forest": {"title": "森林与断桥", "scene": "res://game/maps/levels/forest.tscn", "size": Vector2i(100, 60), "music_cue": &"music.forest"},
	&"cave": {"title": "横向洞窟", "scene": "res://game/maps/levels/cave.tscn", "size": Vector2i(64, 32), "music_cue": &"music.cave"},
}

static func get_map(map_id: StringName) -> Dictionary:
	return MAPS.get(map_id, {}).duplicate(true)

static func is_valid(map_id: StringName) -> bool:
	return MAPS.has(map_id)
