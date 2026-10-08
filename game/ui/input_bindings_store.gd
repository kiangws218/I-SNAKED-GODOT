class_name InputBindingsStore
extends RefCounted

const ACTION_LABELS := {
	&"move_up": "上移",
	&"move_down": "下移",
	&"move_left": "左移",
	&"move_right": "右移",
	&"spit": "吐出",
	&"place_node": "放置节点",
	&"cut_tail": "断尾",
	&"inventory_previous": "上一件物品",
	&"inventory_next": "下一件物品",
	&"interact": "互动",
	&"companion_talk": "乘客交谈",
	&"pause": "暂停",
}
const ACTIONS: Array[StringName] = [
	&"move_up", &"move_down", &"move_left", &"move_right", &"spit", &"place_node",
	&"cut_tail", &"inventory_previous", &"inventory_next", &"interact", &"companion_talk", &"pause",
]
const FIXED_ESCAPE := KEY_ESCAPE
const RESERVED_FUNCTION_KEYS := [KEY_F1, KEY_F2, KEY_F3, KEY_F4, KEY_F5, KEY_F6, KEY_F7, KEY_F8, KEY_F9, KEY_F10, KEY_F11, KEY_F12]
const ALLOWED_SPECIAL_KEYS := [
	KEY_TAB, KEY_BACKSPACE, KEY_ENTER, KEY_KP_ENTER, KEY_INSERT, KEY_DELETE,
	KEY_HOME, KEY_END, KEY_LEFT, KEY_UP, KEY_RIGHT, KEY_DOWN, KEY_PAGEUP, KEY_PAGEDOWN,
	KEY_KP_MULTIPLY, KEY_KP_DIVIDE, KEY_KP_SUBTRACT, KEY_KP_PERIOD, KEY_KP_ADD,
	KEY_KP_0, KEY_KP_1, KEY_KP_2, KEY_KP_3, KEY_KP_4, KEY_KP_5, KEY_KP_6, KEY_KP_7, KEY_KP_8, KEY_KP_9,
]
const MODIFIER_KEYS := [KEY_SHIFT, KEY_CTRL, KEY_META, KEY_ALT, KEY_CAPSLOCK, KEY_NUMLOCK, KEY_SCROLLLOCK]

var path := "user://controls.cfg"
var defaults: Dictionary = {}
var bindings: Dictionary = {}


func _init(custom_path := "") -> void:
	if not custom_path.is_empty():
		path = custom_path
	_capture_defaults()
	bindings = _copy_bindings(defaults)


func load_settings() -> Dictionary:
	_capture_defaults()
	var config := ConfigFile.new()
	var error := config.load(path)
	if error == ERR_FILE_NOT_FOUND:
		bindings = _copy_bindings(defaults)
		apply()
		return {"ok": true, "created": false}
	if error != OK:
		bindings = _copy_bindings(defaults)
		apply()
		return {"ok": false, "error": error, "bindings": _copy_bindings(bindings)}

	var loaded := _copy_bindings(defaults)
	for action in ACTIONS:
		if not config.has_section_key("bindings", String(action)):
			continue
		var value: Variant = config.get_value("bindings", String(action))
		if not value is Array or value.size() < 1 or value.size() > 2:
			continue
		var parsed: Array[int] = []
		var valid := true
		for raw_code in value:
			if not raw_code is int or not _is_usable_code(int(raw_code), action):
				valid = false
				break
			parsed.append(int(raw_code))
		if not valid or (parsed.size() == 2 and parsed[0] == parsed[1]):
			continue
		if action == &"pause" and (parsed.size() != 2 or parsed[1] != FIXED_ESCAPE):
			continue
		if action == &"pause" and parsed[0] == FIXED_ESCAPE:
			continue
		loaded[action] = parsed

	# Resolve corrupt files conservatively: any conflicting customized action returns to its defaults.
	var changed := true
	while changed:
		changed = false
		for index in range(ACTIONS.size()):
			var first: StringName = ACTIONS[index]
			for other_index in range(index + 1, ACTIONS.size()):
				var second: StringName = ACTIONS[other_index]
				if not _arrays_overlap(loaded[first], loaded[second]):
					continue
				var first_custom: bool = loaded[first] != defaults[first]
				var second_custom: bool = loaded[second] != defaults[second]
				if first_custom:
					loaded[first] = defaults[first].duplicate()
					changed = true
				if second_custom:
					loaded[second] = defaults[second].duplicate()
					changed = true
	bindings = loaded
	apply()
	return {"ok": true, "created": true, "bindings": _copy_bindings(bindings)}


func set_binding(action: StringName, slot: int, code: Key) -> Dictionary:
	if not ACTIONS.has(action):
		return _failure("未知动作")
	if slot < 0 or slot > 1:
		return _failure("键位槽无效")
	if action == &"pause" and slot == 1:
		return _failure("Esc 是固定返回键，不能修改或移除")
	var next := _copy_bindings(bindings)
	var action_keys: Array = next[action]
	if code == KEY_NONE:
		if slot == 0:
			return _failure("主键不能为空")
		if action_keys.size() <= 1:
			return _failure("该动作没有备用键")
		action_keys.remove_at(1)
	else:
		if not _is_usable_code(int(code), action):
			return _failure(_unusable_reason(int(code), action))
		if slot == 1 and action_keys.size() < 2:
			action_keys.append(int(code))
		else:
			action_keys[slot] = int(code)
		if action_keys.size() == 2 and action_keys[0] == action_keys[1]:
			return _failure("同一动作不能重复绑定同一键")
	for other in ACTIONS:
		if other == action:
			continue
		if _arrays_overlap(action_keys, next[other]):
			return _failure("按键与“%s”冲突" % ACTION_LABELS[other])
	next[action] = action_keys
	return _commit(next)


func reset_action(action: StringName) -> Dictionary:
	if not ACTIONS.has(action):
		return _failure("未知动作")
	for other in ACTIONS:
		if other == action:
			continue
		if _arrays_overlap(defaults[action], bindings[other]):
			return _failure("默认键与“%s”冲突" % ACTION_LABELS[other])
	var next := _copy_bindings(bindings)
	next[action] = defaults[action].duplicate()
	return _commit(next)


func reset_all() -> Dictionary:
	return _commit(_copy_bindings(defaults))


func save() -> Dictionary:
	var parent := ProjectSettings.globalize_path(path).get_base_dir()
	if not parent.is_empty() and DirAccess.make_dir_recursive_absolute(parent) != OK:
		return {"ok": false, "error": ERR_CANT_CREATE}
	var config := ConfigFile.new()
	for action in ACTIONS:
		config.set_value("bindings", String(action), bindings[action].duplicate())
	var error := config.save(path)
	return {"ok": error == OK, "error": error}


func apply() -> void:
	for action in ACTIONS:
		Input.action_release(action)
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		InputMap.action_erase_events(action)
		for code in bindings.get(action, []):
			var event := InputEventKey.new()
			event.physical_keycode = int(code)
			InputMap.action_add_event(action, event)


func keys_for(action: StringName) -> Array:
	return bindings.get(action, []).duplicate()


func key_text(action: StringName) -> String:
	var labels: PackedStringArray = []
	for code in keys_for(action):
		labels.append(key_label(int(code)))
	return " / ".join(labels)


static func current_key_text(action: StringName) -> String:
	var labels: PackedStringArray = []
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			labels.append(key_label(event.physical_keycode if event.physical_keycode != KEY_NONE else event.keycode))
	return " / ".join(labels)


static func key_label(code: int) -> String:
	var labels := {
		KEY_SPACE: "空格", KEY_ESCAPE: "Esc", KEY_ENTER: "Enter", KEY_KP_ENTER: "数字键盘 Enter",
		KEY_UP: "↑", KEY_DOWN: "↓", KEY_LEFT: "←", KEY_RIGHT: "→", KEY_TAB: "Tab",
		KEY_BACKSPACE: "Backspace", KEY_DELETE: "Delete", KEY_INSERT: "Insert",
		KEY_HOME: "Home", KEY_END: "End", KEY_PAGEUP: "Page Up", KEY_PAGEDOWN: "Page Down",
		KEY_KP_MULTIPLY: "数字键盘 *", KEY_KP_DIVIDE: "数字键盘 /",
		KEY_KP_SUBTRACT: "数字键盘 -", KEY_KP_PERIOD: "数字键盘 .", KEY_KP_ADD: "数字键盘 +",
		KEY_KP_0: "数字键盘 0", KEY_KP_1: "数字键盘 1", KEY_KP_2: "数字键盘 2",
		KEY_KP_3: "数字键盘 3", KEY_KP_4: "数字键盘 4", KEY_KP_5: "数字键盘 5",
		KEY_KP_6: "数字键盘 6", KEY_KP_7: "数字键盘 7", KEY_KP_8: "数字键盘 8", KEY_KP_9: "数字键盘 9",
	}
	if labels.has(code):
		return labels[code]
	if code >= KEY_A and code <= KEY_Z:
		return String.chr(code)
	return OS.get_keycode_string(code)


func _commit(next: Dictionary) -> Dictionary:
	var prior := bindings
	bindings = next
	var result := save()
	if not result.ok:
		bindings = prior
		result["message"] = "键位配置保存失败"
		return result
	apply()
	result["bindings"] = _copy_bindings(bindings)
	return result


func _capture_defaults() -> void:
	defaults.clear()
	for action in ACTIONS:
		var setting: Dictionary = ProjectSettings.get_setting("input/" + String(action), {})
		var codes: Array[int] = []
		for event in setting.get("events", []):
			if not event is InputEventKey:
				continue
			var key_event := event as InputEventKey
			var code := int(key_event.physical_keycode)
			if code == KEY_NONE:
				code = int(key_event.keycode)
			if code != KEY_NONE and not codes.has(code) and codes.size() < 2:
				codes.append(code)
		if action == &"pause":
			var primary := KEY_P
			for code in codes:
				if code != FIXED_ESCAPE:
					primary = code
					break
			codes = [primary, FIXED_ESCAPE]
		defaults[action] = codes


func _is_usable_code(code: int, action: StringName) -> bool:
	if code == FIXED_ESCAPE:
		return action == &"pause"
	if code == KEY_NONE or RESERVED_FUNCTION_KEYS.has(code) or MODIFIER_KEYS.has(code):
		return false
	# Physical letter codes are uppercase ASCII; lowercase values do not map to physical keyboard keys.
	if code >= 97 and code <= 122:
		return false
	if code < KEY_SPACE or (code > KEY_ASCIITILDE and not ALLOWED_SPECIAL_KEYS.has(code)):
		return false
	return true


func _unusable_reason(code: int, action: StringName) -> String:
	if code == FIXED_ESCAPE and action != &"pause":
		return "Esc 保留为全局返回键"
	if RESERVED_FUNCTION_KEYS.has(code):
		return "F1–F12 保留给开发和存读档操作"
	if MODIFIER_KEYS.has(code):
		return "仅支持普通键盘按键，不支持修饰键或组合键"
	return "未知或不支持的键值"


func _copy_bindings(source: Dictionary) -> Dictionary:
	var result := {}
	for action in ACTIONS:
		result[action] = Array(source.get(action, [])).duplicate()
	return result


func _arrays_overlap(first: Array, second: Array) -> bool:
	for code in first:
		if second.has(code):
			return true
	return false


func _failure(message: String) -> Dictionary:
	return {"ok": false, "error": message, "message": message}
