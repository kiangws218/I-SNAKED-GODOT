class_name AudioSettingsStore
extends RefCounted

const DEFAULT_PERCENT := 100.0
const MUSIC_BUS := &"Music"
const SFX_BUS := &"SFX"

var path := "user://settings.cfg"
var music_percent := DEFAULT_PERCENT
var sfx_percent := DEFAULT_PERCENT


func _init(custom_path := "") -> void:
	if not custom_path.is_empty():
		path = custom_path


func load_settings() -> Dictionary:
	var config := ConfigFile.new()
	var error := config.load(path)
	if error == ERR_FILE_NOT_FOUND:
		apply()
		return {"ok": true, "created": false}
	if error != OK:
		music_percent = DEFAULT_PERCENT
		sfx_percent = DEFAULT_PERCENT
		apply()
		return {"ok": false, "error": error}
	music_percent = clampf(float(config.get_value("audio", "music_percent", DEFAULT_PERCENT)), 0.0, 100.0)
	sfx_percent = clampf(float(config.get_value("audio", "sfx_percent", DEFAULT_PERCENT)), 0.0, 100.0)
	apply()
	return {"ok": true, "created": true}


func set_levels(music: float, sfx: float, persist := true) -> Dictionary:
	music_percent = clampf(music, 0.0, 100.0)
	sfx_percent = clampf(sfx, 0.0, 100.0)
	apply()
	return save() if persist else {"ok": true}


func save() -> Dictionary:
	var absolute_parent := ProjectSettings.globalize_path(path).get_base_dir()
	if not absolute_parent.is_empty() and DirAccess.make_dir_recursive_absolute(absolute_parent) != OK:
		return {"ok": false, "error": ERR_CANT_CREATE}
	var config := ConfigFile.new()
	config.set_value("audio", "music_percent", music_percent)
	config.set_value("audio", "sfx_percent", sfx_percent)
	var error := config.save(path)
	return {"ok": error == OK, "error": error}


func apply() -> void:
	_apply_bus(MUSIC_BUS, music_percent)
	_apply_bus(SFX_BUS, sfx_percent)


func _apply_bus(bus_name: StringName, percent: float) -> void:
	var index := AudioServer.get_bus_index(bus_name)
	if index < 0:
		return
	var normalized := clampf(percent / 100.0, 0.0, 1.0)
	AudioServer.set_bus_mute(index, is_zero_approx(normalized))
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(normalized, 0.0001)))

