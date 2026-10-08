extends SceneTree

const Store = preload("res://game/ui/input_bindings_store.gd")
const AudioStore = preload("res://game/ui/audio_settings_store.gd")
const TEST_DIR := "res://.godotfixture/input_bindings_store"
const CONFIG_PATH := TEST_DIR + "/controls.cfg"

var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TEST_DIR))
	var store = Store.new(CONFIG_PATH)
	store.load_settings()
	_test_defaults_are_raw_project_settings(store)
	_test_persistence(store)
	_test_validation_and_recovery(store)
	_test_corrupt_file(store)
	_test_write_failure_is_transactional(store)
	_test_audio_settings_are_separate(store)
	store.reset_all()
	if FileAccess.file_exists(CONFIG_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(CONFIG_PATH))
	if FileAccess.file_exists(TEST_DIR + "/audio.cfg"):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_DIR + "/audio.cfg"))
	if DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(TEST_DIR + "/blocked")):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_DIR + "/blocked"))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_DIR))
	if DirAccess.get_files_at("res://.godotfixture").is_empty() and DirAccess.get_directories_at("res://.godotfixture").is_empty():
		DirAccess.remove_absolute(ProjectSettings.globalize_path("res://.godotfixture"))
	if failures.is_empty():
		print("INPUT BINDINGS STORE TESTS PASSED")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _test_defaults_are_raw_project_settings(store) -> void:
	var original := InputMap.action_get_events(&"move_up")
	InputMap.action_erase_events(&"move_up")
	var changed := InputEventKey.new()
	changed.physical_keycode = KEY_X
	InputMap.action_add_event(&"move_up", changed)
	var fresh = Store.new(CONFIG_PATH + ".raw")
	check(fresh.keys_for(&"move_up").has(KEY_W), "新实例从 ProjectSettings 读取原始 W 默认键")
	check(not fresh.keys_for(&"move_up").has(KEY_X), "运行时 InputMap 改键不会污染原始默认")
	InputMap.action_erase_events(&"move_up")
	for event in original:
		InputMap.action_add_event(&"move_up", event)
	store.apply()


func _test_persistence(store) -> void:
	var changed: Dictionary = store.set_binding(&"spit", 0, KEY_B)
	check(changed.ok and InputMap.action_get_events(&"spit").size() == 2, "提交改键先保存并重建 InputMap")
	var reopened = Store.new(CONFIG_PATH)
	var loaded: Dictionary = reopened.load_settings()
	check(loaded.ok and reopened.keys_for(&"spit")[0] == KEY_B, "新实例读取持久化的主键")
	check(reopened.keys_for(&"pause") == [KEY_P, KEY_ESCAPE], "pause 主键可变且 Esc 备用固定")
	check(reopened.set_binding(&"pause", 0, KEY_O).ok, "允许更改暂停主键")
	var pause_reopened = Store.new(CONFIG_PATH)
	check(pause_reopened.load_settings().ok and pause_reopened.keys_for(&"pause") == [KEY_O, KEY_ESCAPE], "重启读取自定义暂停键并固定保留 Esc")
	store.reset_all()


func _test_validation_and_recovery(store) -> void:
	check(not store.set_binding(&"spit", 0, KEY_NONE).ok, "主键不能删除")
	check(not store.set_binding(&"spit", 0, KEY_F5).ok, "拒绝 F1–F12 存读档键")
	check(not store.set_binding(&"spit", 0, KEY_SHIFT).ok, "拒绝修饰键")
	check(not store.set_binding(&"spit", 0, KEY_ESCAPE).ok, "Esc 保留全局返回用途")
	check(not store.set_binding(&"pause", 1, KEY_NONE).ok, "固定 Esc 备用不能删除")
	check(not store.set_binding(&"pause", 0, KEY_ESCAPE).ok, "暂停主键不能与固定 Esc 重复")
	check(not store.set_binding(&"pause", 0, KEY_NONE).ok, "暂停主键不能为空")
	check(not store.set_binding(&"missing", 0, KEY_X).ok, "拒绝未知动作")
	check(not store.set_binding(&"spit", 0, KEY_W).ok, "拒绝与其他动作主键冲突")
	check(not store.set_binding(&"move_up", 1, KEY_J).ok, "也拒绝和其他动作备用键冲突")
	check(store.set_binding(&"spit", 1, KEY_B).ok, "允许设置备用键")
	check(not store.set_binding(&"spit", 0, KEY_B).ok, "同一动作不能重复主备用键")
	check(store.set_binding(&"spit", 1, KEY_NONE).ok and store.keys_for(&"spit").size() == 1, "KEY_NONE 删除备用键")
	check(not store.set_binding(&"spit", 1, KEY_NONE).ok, "主鍵存在時不能删除不存在的备用键")
	check(store.set_binding(&"move_up", 0, KEY_Z).ok, "可将动作改到新的有效键")
	check(store.set_binding(&"companion_talk", 0, KEY_W).ok, "释放默认键后其他动作可占用该键")
	var reset_collision: Dictionary = store.reset_action(&"move_up")
	check(not reset_collision.ok and "乘客交谈" in String(reset_collision.error), "恢复默认键冲突时说明占用动作")
	check(store.reset_all().ok and store.keys_for(&"move_up").has(KEY_W), "恢复全部默认键")
	check(store.reset_action(&"spit").ok, "恢复单项默认键")


func _test_corrupt_file(store) -> void:
	var config := ConfigFile.new()
	config.set_value("bindings", "move_up", [99999999])
	config.set_value("bindings", "move_down", [KEY_W])
	config.set_value("bindings", "move_left", [97])
	config.set_value("bindings", "move_right", [KEY_U, KEY_U])
	config.set_value("bindings", "pause", [KEY_O, KEY_ESCAPE])
	config.set_value("bindings", "unknown_action", [KEY_Z])
	check(config.save(CONFIG_PATH) == OK, "写入损坏键位样本")
	var recovered = Store.new(CONFIG_PATH)
	var result: Dictionary = recovered.load_settings()
	check(result.ok, "损坏键位配置可安全加载")
	check(recovered.keys_for(&"move_up").has(KEY_W), "未知键值回退原始默认")
	check(recovered.keys_for(&"move_down").has(KEY_S), "与其他动作冲突时回退该动作默认")
	check(recovered.keys_for(&"move_left").has(KEY_A), "不可触发的小写物理字母键回退默认")
	check(recovered.keys_for(&"move_right").has(KEY_D), "损坏配置中的同动作重复键回退默认")
	check(recovered.keys_for(&"pause") == [KEY_O, KEY_ESCAPE], "损坏配置恢复流程保留自定义暂停键与 Esc")
	check(recovered.keys_for(&"companion_talk").has(KEY_T), "新动作或未知配置保持版本默认")
	store.reset_all()


func _test_write_failure_is_transactional(store) -> void:
	var blocked_path := TEST_DIR + "/blocked"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(blocked_path))
	var blocked = Store.new(blocked_path)
	blocked.load_settings()
	var before := blocked.keys_for(&"spit")
	var input_before := InputMap.action_get_events(&"spit").duplicate()
	var result: Dictionary = blocked.set_binding(&"spit", 0, KEY_B)
	check(not result.ok and not String(result.get("message", "")).is_empty(), "写入失败向调用方返回可读错误")
	check(blocked.keys_for(&"spit") == before, "写入失败保留原 bindings")
	check(InputMap.action_get_events(&"spit") == input_before, "写入失败不修改原 InputMap")
	store.apply()


func _test_audio_settings_are_separate(store) -> void:
	var audio_path := TEST_DIR + "/audio.cfg"
	var audio = AudioStore.new(audio_path)
	check(audio.set_levels(37.0, 62.0).ok, "音量配置可单独保存")
	var persisted := ConfigFile.new()
	check(persisted.load(CONFIG_PATH) == OK, "音量保存后控制配置仍存在")
	check(persisted.has_section_key("bindings", "spit"), "音量保存没有覆盖键位配置")
	var restored_audio = AudioStore.new(audio_path)
	check(restored_audio.load_settings().ok and is_equal_approx(restored_audio.music_percent, 37.0), "音量配置独立读取")
	store.reset_all()


func check(condition: bool, label: String) -> void:
	if not condition:
		failures.append("FAILED: " + label)
