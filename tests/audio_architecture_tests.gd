extends SceneTree

## Audio architecture regression tests.
##
## This file deliberately has no preload/class_name dependency on the audio
## implementation.  The audio package is being developed independently, so a
## checkout without game/audio must still parse and run this test.  Once the
## scenes/resources exist, the tests discover them through ResourceLoader and
## Object.callv; this keeps a missing optional audio package a SKIP rather than
## a parse-time failure.

const MUSIC_SCENE := "res://game/audio/music/music_director.tscn"
const SFX_SCENE := "res://game/audio/sfx/sfx_director.tscn"
const MAP_CATALOG := "res://game/maps/story_map_catalog.gd"
const MUSIC_IDS := [&"music.tutorial", &"music.wilderness", &"music.forest", &"music.cave"]
const EXPECTED_BUSES := {
	&"Master": &"",
	&"Music": &"Master",
	&"SFX": &"Master",
	&"UI": &"SFX",
	&"CG": &"SFX",
	&"Ambience": &"Music",
}

var failures: Array[String] = []
var skips: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_test_bus_routing()
	_test_map_music_ids()
	_test_stable_ids()
	if ResourceLoader.exists(MUSIC_SCENE):
		await _test_music_director()
	else:
		skips.append("MusicDirector scene not present: " + MUSIC_SCENE)
	if ResourceLoader.exists(SFX_SCENE):
		await _test_sfx_director()
	else:
		skips.append("SfxDirector scene not present: " + SFX_SCENE)

	if failures.is_empty():
		print("AUDIO ARCHITECTURE TESTS PASSED (%d skipped)" % skips.size())
		for item in skips:
			print("AUDIO TEST SKIP: " + item)
		quit(0)
	else:
		for failure in failures:
			push_error("AUDIO TEST: " + failure)
		for item in skips:
			print("AUDIO TEST SKIP: " + item)
		quit(1)


func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _test_bus_routing() -> void:
	# The project bus layout is loaded by the engine in a headless process too;
	# no AudioStreamPlayer or physical output device is needed for this check.
	var indexes := {}
	for index in range(AudioServer.get_bus_count()):
		indexes[StringName(AudioServer.get_bus_name(index))] = index
	for bus_name in EXPECTED_BUSES:
		check(indexes.has(bus_name), "audio bus exists: %s" % bus_name)
	for bus_name in EXPECTED_BUSES:
		if not indexes.has(bus_name):
			continue
		var index: int = indexes[bus_name]
		var expected_send: StringName = EXPECTED_BUSES[bus_name]
		var actual_send := StringName(AudioServer.get_bus_send(index))
		check(actual_send == expected_send, "audio bus route %s -> %s (got %s)" % [bus_name, expected_send, actual_send])


func _test_map_music_ids() -> void:
	if not ResourceLoader.exists(MAP_CATALOG):
		skips.append("StoryMapCatalog not present")
		return
	var script = load(MAP_CATALOG)
	if script == null or not script.can_instantiate():
		skips.append("StoryMapCatalog cannot be instantiated")
		return
	var catalog = script.new()
	if not catalog.has_method("get_map"):
		skips.append("StoryMapCatalog.get_map unavailable")
		return
	var seen := {}
	for map_id in [&"prologue_tutorial", &"wilderness", &"forest", &"cave"]:
		var map_data = catalog.call("get_map", map_id)
		check(map_data is Dictionary, "map catalog entry is a Dictionary: %s" % map_id)
		if not map_data is Dictionary:
			continue
		var cue := StringName(map_data.get("music_cue", ""))
		check(not cue.is_empty(), "map has music_cue: %s" % map_id)
		check(cue in MUSIC_IDS, "map music cue is stable: %s -> %s" % [map_id, cue])
		check(not seen.has(cue), "map music cue is not reused accidentally: %s" % cue)
		seen[cue] = map_id
	check(seen.size() == MUSIC_IDS.size(), "four maps cover all stable music IDs")


func _test_stable_ids() -> void:
	var music_ids := _collect_resource_ids("music_cue")
	var sfx_ids := _collect_resource_ids("sfx_definition")
	if music_ids.is_empty():
		skips.append("no MusicCue resources found for stable-ID uniqueness")
	else:
		_check_unique(music_ids, "MusicCue")
	if sfx_ids.is_empty():
		skips.append("no SfxDefinition resources found for stable-ID uniqueness")
	else:
		_check_unique(sfx_ids, "SfxDefinition")
	var music_catalog = load("res://game/audio/music/default_music_catalog.tres")
	if music_catalog != null and music_catalog.has_method("has_cue"):
		for cue_id in MUSIC_IDS:
			check(bool(music_catalog.call("has_cue", cue_id)), "default MusicCatalog contains stable cue: %s" % cue_id)


func _check_unique(ids: Array, label: String) -> void:
	var seen := {}
	for value in ids:
		var id := String(value)
		check(not id.is_empty(), label + " stable ID is non-empty")
		check(not seen.has(id), label + " stable IDs are unique: " + id)
		seen[id] = true


func _test_music_director() -> void:
	var director = await _instantiate_scene(MUSIC_SCENE)
	if director == null:
		skips.append("MusicDirector scene did not instantiate")
		return
	if not director.has_method("play_cue"):
		failures.append("MusicDirector.play_cue(StringName) is missing")
	else:
		# A nonexistent ID is required to fail quietly and return the documented
		# Dictionary.  No stream, sound card, or BGM asset is touched here.
		var missing = _call_dict(director, "play_cue", [&"audio.test.missing"])
		if missing != null:
			check(not _result_success(missing), "missing music cue fails quietly")
	if not director.has_method("stop_music"):
		failures.append("MusicDirector.stop_music() is missing")
	if not director.has_method("current_cue_id") and not _has_property(director, "current_cue_id"):
		failures.append("MusicDirector.current_cue_id is missing")
	if _has_property(director, "music_bus"):
		check(StringName(director.get("music_bus")) == &"Music", "MusicDirector routes to Music bus")
	director.queue_free()
	await process_frame
	await _test_music_synthetic_fixture()


func _test_music_synthetic_fixture() -> void:
	var cue_script = load("res://game/audio/music/music_cue.gd")
	var catalog_script = load("res://game/audio/music/music_catalog.gd")
	var director_script = load("res://game/audio/music/music_director.gd")
	if cue_script == null or catalog_script == null or director_script == null:
		skips.append("MusicGenerator fixture scripts unavailable")
		return
	var catalog = catalog_script.new()
	var cue_a = cue_script.new()
	cue_a.id = &"audio.test.music.a"
	cue_a.stream = _silent_stream()
	var cue_b = cue_script.new()
	cue_b.id = &"audio.test.music.b"
	cue_b.stream = _silent_stream()
	var no_stream = cue_script.new()
	no_stream.id = &"audio.test.music.no_stream"
	catalog.cues = [cue_a, cue_b, no_stream]
	var director = director_script.new()
	director.catalog = catalog
	director.default_fade_seconds = 0.03
	root.add_child(director)
	await process_frame
	var missing = _call_dict(director, "play_cue", [&"audio.test.music.missing"])
	var no_stream_result = _call_dict(director, "play_cue", [no_stream.id])
	check(missing != null and not _result_success(missing), "missing music cue fails quietly")
	check(no_stream_result != null and not _result_success(no_stream_result), "music cue with no stream fails quietly")
	var first = _call_dict(director, "play_cue", [cue_a.id])
	check(first != null and _result_success(first), "synthetic MusicCue starts without BGM file")
	if first != null and _result_success(first):
		var second = _call_dict(director, "play_cue", [cue_a.id])
		check(second != null and bool(second.get("reused", false)), "same music cue is reused")
		check(_current_cue(director) == cue_a.id, "same cue preserves current_cue_id")
		_call_dict(director, "play_cue", [cue_b.id])
		_call_dict(director, "play_cue", [cue_a.id])
		for _frame in range(6):
			await process_frame
		check(_current_cue(director) == cue_a.id, "stale crossfade cannot overwrite latest music generation")
	var stopped = _call_dict(director, "stop_music", [0.0])
	check(stopped != null and _current_cue(director) == &"", "stop_music clears current_cue_id")
	director.queue_free()
	await process_frame


func _test_sfx_director() -> void:
	var director = await _instantiate_scene(SFX_SCENE)
	if director == null:
		skips.append("SfxDirector scene did not instantiate")
		return
	if not director.has_method("play_sfx"):
		failures.append("SfxDirector.play_sfx(StringName, Dictionary) is missing")
	else:
		var missing = _call_dict(director, "play_sfx", [&"audio.test.missing", {}])
		if missing != null:
			check(not _result_success(missing), "missing SFX ID fails quietly")
	_test_sfx_bus_properties()
	director.queue_free()
	await process_frame
	await _test_sfx_synthetic_fixture()


func _test_sfx_synthetic_fixture() -> void:
	var definition_script = load("res://game/audio/sfx/sfx_definition.gd")
	var catalog_script = load("res://game/audio/sfx/sfx_catalog.gd")
	var director_script = load("res://game/audio/sfx/sfx_director.gd")
	if definition_script == null or catalog_script == null or director_script == null:
		skips.append("SFX Generator fixture scripts unavailable")
		return
	var catalog = catalog_script.new()
	var cooldown_def = definition_script.new()
	cooldown_def.id = &"audio.test.sfx.cooldown"
	var cooldown_streams: Array[AudioStream] = [_silent_stream()]
	cooldown_def.streams = cooldown_streams
	cooldown_def.cooldown = 60.0
	cooldown_def.max_instances = 4
	var max_def = definition_script.new()
	max_def.id = &"audio.test.sfx.max"
	var max_streams: Array[AudioStream] = [_silent_stream()]
	max_def.streams = max_streams
	max_def.cooldown = 0.0
	max_def.max_instances = 1
	var no_stream = definition_script.new()
	no_stream.id = &"audio.test.sfx.no_stream"
	var definitions: Array[Resource] = [cooldown_def, max_def, no_stream]
	catalog.definitions = definitions
	var director = director_script.new()
	director.catalog = catalog
	director.default_pool_size = 4
	root.add_child(director)
	await process_frame
	var missing = _call_dict(director, "play_sfx", [&"audio.test.sfx.missing", {}])
	var no_stream_result = _call_dict(director, "play_sfx", [no_stream.id, {}])
	check(missing != null and not _result_success(missing), "missing SFX ID fails quietly")
	check(no_stream_result != null and not _result_success(no_stream_result), "SFX definition with no stream fails quietly")
	var first = _call_dict(director, "play_sfx", [cooldown_def.id, {}])
	var repeated = _call_dict(director, "play_sfx", [cooldown_def.id, {}])
	check(first != null and _result_success(first), "synthetic SFX starts without shipped audio dependency")
	check(repeated != null and String(repeated.get("code", "")) == "cooldown", "SFX cooldown blocks an immediate duplicate")
	var max_first = _call_dict(director, "play_sfx", [max_def.id, {}])
	var max_second = _call_dict(director, "play_sfx", [max_def.id, {}])
	check(max_first != null and _result_success(max_first), "max_instances fixture starts first instance")
	check(max_second != null and String(max_second.get("code", "")) == "pool_full", "SFX max_instances caps concurrent playback")
	director.call("stop_all")
	director.queue_free()
	await process_frame


func _test_sfx_bus_properties() -> void:
	var allowed := [&"SFX", &"UI", &"CG", &"Ambience"]
	for path in _find_files("res://game/audio", [".tres", ".res"]):
		var resource = load(path)
		if resource == null:
			continue
		_check_sfx_bus_value(resource, allowed, {})
		if resource.has_method("validate_catalog"):
			var validation = resource.call("validate_catalog")
			check(validation is Dictionary and bool(validation.get("ok", false)), "SFX catalog validates: %s" % path)


func _check_sfx_bus_value(value, allowed: Array, visited: Dictionary) -> void:
	if value == null or not value is Resource or value is Script:
		return
	var instance_id: int = value.get_instance_id()
	if visited.has(instance_id):
		return
	visited[instance_id] = true
	var script = value.get_script()
	var script_path := String(script.resource_path).to_lower() if script != null else ""
	if script_path.contains("sfx_definition"):
		var bus := StringName(_first_property(value, ["bus", "bus_name"], ""))
		if not bus.is_empty():
			check(bus in allowed, "SFX definition bus is a planned route: %s" % bus)
		return
	if not script_path.contains("catalog"):
		return
	for property in value.get_property_list():
		var property_name := String(property.get("name", ""))
		if property_name == "script":
			continue
		_check_sfx_bus_variant(value.get(property_name), allowed, visited)


func _check_sfx_bus_variant(value, allowed: Array, visited: Dictionary) -> void:
	if value is Resource:
		_check_sfx_bus_value(value, allowed, visited)
	elif value is Array:
		for child in value:
			_check_sfx_bus_variant(child, allowed, visited)


func _instantiate_scene(path: String):
	var packed = load(path) as PackedScene
	if packed == null:
		failures.append("audio scene failed to load: " + path)
		return null
	var node = packed.instantiate()
	if node == null:
		return null
	root.add_child(node)
	await process_frame
	return node


func _call_dict(object: Object, method: StringName, args: Array):
	if object == null or not object.has_method(method):
		return null
	var value = object.callv(method, args)
	check(value is Dictionary, "%s returns Dictionary" % method)
	return value if value is Dictionary else null


func _result_success(result: Dictionary) -> bool:
	for key in ["ok", "success", "played", "started", "accepted"]:
		if result.has(key):
			return bool(result[key])
	if result.has("error") or result.has("failure") or result.has("blocked"):
		return false
	var reason := String(result.get("reason", ""))
	if reason.to_lower().contains("missing") or reason.to_lower().contains("not_found"):
		return false
	# A successful result is allowed to carry only cue/id/status metadata.  The
	# API intentionally does not mandate one particular success-key spelling.
	return true


func _result_blocked(result: Dictionary) -> bool:
	if result.has("blocked"):
		return bool(result.blocked)
	for key in ["ok", "success", "played", "started", "accepted"]:
		if result.has(key):
			return not bool(result[key])
	var reason := String(result.get("reason", ""))
	return reason.to_lower().contains("cooldown") or reason.to_lower().contains("instance") or reason.to_lower().contains("limit")


func _usable_ids_for_director(_director: Object, marker: String, fallback: Array) -> Array:
	var ids := _collect_resource_ids(marker)
	if ids.is_empty():
		return fallback.duplicate()
	return ids


func _collect_resource_ids(marker: String) -> Array:
	var ids: Array = []
	for path in _find_files("res://game/audio", [".tres", ".res"]):
		var resource = load(path)
		if resource == null:
			continue
		_collect_ids_from_value(resource, marker, ids, {})
	return ids


func _collect_ids_from_value(value, marker: String, ids: Array, visited: Dictionary) -> void:
	if value == null or not value is Resource:
		return
	if value is Script:
		return
	var instance_id: int = value.get_instance_id()
	if visited.has(instance_id):
		return
	visited[instance_id] = true
	var script = value.get_script()
	var script_path := String(script.resource_path).to_lower() if script != null else ""
	if script_path.contains(marker):
		var id_value = _first_property(value, ["id", "cue_id", "sfx_id", "stable_id", "key"], "")
		if id_value is StringName or id_value is String:
			if not String(id_value).is_empty():
				ids.append(StringName(id_value))
		return
	if not script_path.contains("catalog"):
		return
	for property in value.get_property_list():
		var property_name := String(property.get("name", ""))
		if property_name == "script":
			continue
		_collect_ids_from_variant(value.get(property_name), marker, ids, visited)


func _collect_ids_from_variant(value, marker: String, ids: Array, visited: Dictionary) -> void:
	if value is Resource:
		_collect_ids_from_value(value, marker, ids, visited)
	elif value is Array:
		for child in value:
			_collect_ids_from_variant(child, marker, ids, visited)
	elif value is Dictionary:
		for child in value.values():
			_collect_ids_from_variant(child, marker, ids, visited)


func _find_definition(id: StringName):
	for path in _find_files("res://game/audio", [".tres", ".res"]):
		if not path.to_lower().contains("sfx_definition"):
			continue
		var resource = load(path)
		if resource != null and StringName(_first_property(resource, ["id", "sfx_id", "stable_id"], "")) == id:
			return resource
	return null


func _numeric_property(object, names: Array) -> float:
	return float(_first_property(object, names, 0.0))


func _first_property(object, names: Array, default_value):
	if object == null:
		return default_value
	for name in names:
		if _has_property(object, name):
			return object.get(name)
	return default_value


func _has_property(object: Object, wanted: String) -> bool:
	for property in object.get_property_list():
		if String(property.get("name", "")) == wanted:
			return true
	return false


func _silent_stream() -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 8000
	stream.data = PackedByteArray([0, 0, 0, 0])
	return stream


func _current_cue(director: Object) -> StringName:
	if director.has_method("current_cue_id"):
		return StringName(director.call("current_cue_id"))
	if _has_property(director, "current_cue_id"):
		return StringName(director.get("current_cue_id"))
	return &""


func _find_files(directory_path: String, suffixes: Array) -> Array:
	var output: Array = []
	var directory := DirAccess.open(directory_path)
	if directory == null:
		return output
	for file_name in directory.get_files():
		for suffix in suffixes:
			if file_name.to_lower().ends_with(String(suffix).to_lower()):
				output.append(directory_path.path_join(file_name))
				break
	for child in directory.get_directories():
		output.append_array(_find_files(directory_path.path_join(child), suffixes))
	return output
