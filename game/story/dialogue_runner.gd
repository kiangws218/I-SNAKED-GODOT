class_name DialogueRunner
extends RefCounted

var graph: Dictionary = {}
var nodes: Dictionary = {}
var variables: Dictionary
var condition_resolver: Callable
var node_id := ""
var page_index := 0
var dialogue: Dictionary = {}

func load_graph(path := "res://game/story/story_graph.json") -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"ok": false, "error": "GRAPH_UNREADABLE"}
	var parser := JSON.new()
	if parser.parse(file.get_as_text()) != OK or not parser.data is Dictionary:
		return {"ok": false, "error": "GRAPH_CORRUPT"}
	graph = parser.data
	nodes = graph.get("nodes", {})
	return validate_graph(graph)

func validate_graph(value: Dictionary) -> Dictionary:
	var source: Dictionary = value.get("nodes", {})
	var errors: Array[String] = []
	var actions: Dictionary = {}
	var conditions: Dictionary = {}
	var flags: Dictionary = {}
	if not source.has(value.get("start", "")):
		errors.append("missing start")
	for id in source:
		var node: Dictionary = source[id]
		for target in [node.get("next", ""), node.get("wait", {}).get("target", "")]:
			if not String(target).is_empty() and not source.has(target):
				errors.append("%s -> %s" % [id, target])
		if node.has("enter") and node.enter.has("action"):
			actions[String(node.enter.action)] = true
		if node.has("wait") and node.wait.has("condition"):
			conditions[String(node.wait.condition)] = true
		for choice in node.get("dialogue", {}).get("choices", []):
			if choice.has("next") and not source.has(choice.next):
				errors.append("%s choice -> %s" % [id, choice.next])
			if choice.has("action"):
				actions[String(choice.action)] = true
			if choice.has("when"):
				conditions[String(choice.when)] = true
			for path in choice.get("set", {}):
				if String(path).begins_with("flags."):
					flags[String(path).trim_prefix("flags.")] = true
	return {"ok": errors.is_empty(), "errors": errors, "nodes": source.size(), "actions": actions.keys().size(), "conditions": conditions.keys().size(), "flags_set": flags.keys().size()}

func begin(id: String, node_dialogue: Dictionary, variable_store: Dictionary, resolver: Callable) -> Dictionary:
	node_id = id
	dialogue = node_dialogue
	variables = variable_store
	condition_resolver = resolver
	page_index = 0
	return current_page()

func current_page() -> Dictionary:
	var pages: Array = dialogue.get("pages", [])
	if pages.is_empty():
		return {}
	return {
		"line_id": "%s.page.%d" % [node_id, page_index],
		"speaker": dialogue.get("speaker", "旁白"),
		"sub": dialogue.get("sub", ""),
		"text": _substitute(String(pages[page_index])),
		"page": page_index,
		"page_count": pages.size(),
		"choices": visible_choices() if page_index == pages.size() - 1 else [],
	}

func advance_page() -> Dictionary:
	var pages: Array = dialogue.get("pages", [])
	if page_index + 1 >= pages.size():
		return current_page()
	page_index += 1
	return current_page()

func visible_choices() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for choice in dialogue.get("choices", []):
		if not choice.has("when") or not condition_resolver.is_valid() or bool(condition_resolver.call(String(choice.when))):
			result.append(Dictionary(choice).duplicate(true))
	return result

func choose(choice_id: String) -> Dictionary:
	for choice in visible_choices():
		if String(choice.id) != choice_id:
			continue
		for path in choice.get("set", {}):
			_set_path(String(path), choice.set[path])
		return {"ok": true, "next": String(choice.get("next", "")), "action": String(choice.get("action", "")), "choice": choice}
	return {"ok": false, "error": "INVALID_CHOICE"}

func _set_path(path: String, value: Variant) -> void:
	var parts := path.split(".")
	var target := variables
	for index in range(parts.size() - 1):
		var key := parts[index]
		if not target.has(key) or not target[key] is Dictionary:
			target[key] = {}
		target = target[key]
	target[parts[-1]] = value

func _substitute(text: String) -> String:
	return text.replace("{fire}", "J / 空格").replace("{interact}", "回车").replace("{node}", "F")
