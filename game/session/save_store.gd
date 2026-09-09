class_name SaveStore
extends RefCounted

const SLOT_COUNT := 3
const CURRENT_SCHEMA := 1

var base_dir := "user://saves"

func _init(custom_base_dir := "") -> void:
	if not custom_base_dir.is_empty():
		base_dir = custom_base_dir

func save_slot(slot: int, state: Dictionary, metadata := {}) -> Dictionary:
	if not _valid_slot(slot): return _error(&"INVALID_SLOT", "存档位必须是 1、2 或 3")
	if state.is_empty(): return _error(&"INVALID_STATE", "无法保存空的剧情状态")
	if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(base_dir)) != OK:
		return _error(&"STORAGE_WRITE_FAILED", "无法创建存档目录")
	var envelope := {"schema_version": CURRENT_SCHEMA, "meta": metadata.duplicate(true), "state": state.duplicate(true)}
	envelope.meta["slot"] = slot
	envelope.meta["updated_at"] = Time.get_datetime_string_from_system(true)
	var temp_path := _path(slot) + ".tmp"
	var file := FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null: return _error(&"STORAGE_WRITE_FAILED", "无法写入存档")
	file.store_string(JSON.stringify(envelope))
	file.close()
	var absolute_temp := ProjectSettings.globalize_path(temp_path)
	var absolute_final := ProjectSettings.globalize_path(_path(slot))
	var absolute_backup := absolute_final + ".bak"
	if FileAccess.file_exists(_path(slot) + ".bak"):
		DirAccess.remove_absolute(absolute_backup)
	if FileAccess.file_exists(_path(slot)):
		if DirAccess.rename_absolute(absolute_final, absolute_backup) != OK:
			DirAccess.remove_absolute(absolute_temp)
			return _error(&"STORAGE_WRITE_FAILED", "无法备份旧存档")
	if DirAccess.rename_absolute(absolute_temp, absolute_final) != OK:
		if FileAccess.file_exists(_path(slot) + ".bak"):
			DirAccess.rename_absolute(absolute_backup, absolute_final)
		return _error(&"STORAGE_WRITE_FAILED", "无法提交存档")
	if FileAccess.file_exists(_path(slot) + ".bak"):
		DirAccess.remove_absolute(absolute_backup)
	return {"ok": true, "slot": slot, "data": state.duplicate(true), "meta": envelope.meta}

func load_slot(slot: int) -> Dictionary:
	if not _valid_slot(slot): return _error(&"INVALID_SLOT", "存档位必须是 1、2 或 3")
	var path := _path(slot)
	if not FileAccess.file_exists(path): return {"ok": true, "empty": true, "slot": slot}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null: return _error(&"STORAGE_READ_FAILED", "无法读取存档")
	var parser := JSON.new()
	if parser.parse(file.get_as_text()) != OK:
		return _error(&"CORRUPT_JSON", "存档数据损坏，无法解析")
	var parsed = parser.data
	if not parsed is Dictionary: return _error(&"CORRUPT_JSON", "存档数据损坏，无法解析")
	var version := int(parsed.get("schema_version", 0))
	if version > CURRENT_SCHEMA: return _error(&"SCHEMA_TOO_NEW", "存档版本高于当前游戏版本")
	if version < CURRENT_SCHEMA: return _error(&"SCHEMA_UNSUPPORTED", "没有可用的存档版本迁移")
	if not parsed.get("state") is Dictionary: return _error(&"INVALID_SAVE", "存档格式无效")
	return {"ok": true, "slot": slot, "meta": parsed.get("meta", {}), "data": parsed.state.duplicate(true)}

func list_slots() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for slot in range(1, SLOT_COUNT + 1):
		var loaded := load_slot(slot)
		if not loaded.ok: result.append({"slot": slot, "exists": true, "corrupted": true, "error": loaded.error})
		elif loaded.get("empty", false): result.append({"slot": slot, "exists": false})
		else:
			var meta: Dictionary = loaded.meta.duplicate(true)
			meta["slot"] = slot; meta["exists"] = true; result.append(meta)
	return result

func delete_slot(slot: int) -> Dictionary:
	if not _valid_slot(slot): return _error(&"INVALID_SLOT", "存档位必须是 1、2 或 3")
	if FileAccess.file_exists(_path(slot)):
		var code := DirAccess.remove_absolute(ProjectSettings.globalize_path(_path(slot)))
		if code != OK: return _error(&"STORAGE_DELETE_FAILED", "删除存档失败")
	return {"ok": true, "slot": slot}

func _path(slot: int) -> String:
	return "%s/slot_%d.json" % [base_dir, slot]

func _valid_slot(slot: int) -> bool:
	return slot >= 1 and slot <= SLOT_COUNT

func _error(code: StringName, message: String) -> Dictionary:
	return {"ok": false, "error": {"code": code, "message": message}}
