class_name StoryDirector
extends Node

signal pause_requested(reason: StringName, active: bool)
signal goal_changed(text: String)
signal status_changed(text: String)

const N6_ACTIONS := {
	"loadMap": true, "waitForWall": true, "waitForExit": true, "spawnSlimes": true,
	"eatKeti": true, "eatCorpse": true, "waitForMemoryBlur": true,
	"memoryBlur": true, "nameInput": true, "banner": true,
}

var session: GameSession
var panel: DialoguePanel
var runner := DialogueRunner.new()
var nodes: Dictionary = {}
var current_id := ""
var counters := {"tutorialBeansEaten": 0, "tutorialBeansSpit": 0}
var enemies_left := 0
var memory_timer_started := false

func setup(owner_session: GameSession, dialogue_panel: DialoguePanel) -> Dictionary:
	session = owner_session
	panel = dialogue_panel
	panel.choice_selected.connect(_on_choice)
	panel.name_submitted.connect(_on_name_submitted)
	var result := runner.load_graph()
	nodes = runner.nodes
	return result

func start(id := "prologue_start") -> void:
	counters = {"tutorialBeansEaten": 0, "tutorialBeansSpit": 0}
	session.state.story["counters"] = counters.duplicate(true)
	enemies_left = 0
	memory_timer_started = false
	enter_node(id)

func resume() -> void:
	counters = Dictionary(session.state.story.get("counters", counters)).duplicate(true)
	var saved := String(session.state.story.get("current_node", "prologue_start"))
	enter_node(saved if nodes.has(saved) else "prologue_start")

func bind_world(world: StoryMap) -> void:
	world.player.bean_collected.connect(func(): notify(&"PLAYER_BEAN_EATEN"))
	world.player.bean_spit.connect(func(): notify(&"PLAYER_BEAN_SPIT"))
	world.story_actor_interacted.connect(func(id: StringName): _on_actor_event(id, &"interacted"))
	world.story_actor_defeated.connect(func(id: StringName): _on_actor_event(id, &"died"))
	world.story_enemy_defeated.connect(func(_kind: StringName):
		enemies_left = maxi(0, enemies_left - 1)
		notify(&"ENEMIES_DEFEATED"))

func notify(event: StringName) -> void:
	match event:
		&"PLAYER_BEAN_EATEN": counters.tutorialBeansEaten += 1
		&"PLAYER_BEAN_SPIT": counters.tutorialBeansSpit += 1
	session.state.story["counters"] = counters.duplicate(true)
	if current_id == "tutorial_1" and _condition("tutorialBeans3"):
		enter_node("dialogue_1")
	elif current_id == "tutorial_2" and _condition("tutorialSpit3"):
		enter_node("dialogue_2")
	elif current_id == "dialogue_2" and _tutorial_wall_ready():
		enter_node("dialogue_3")
	elif current_id in ["wilderness_slimes", "eaten_slimes"] and _condition("enemiesCleared"):
		enter_node("keti_saved" if current_id == "wilderness_slimes" and not bool(session.state.flags.get("keti_dead", false)) else "keti_memory_wait")

func mechanism_completed(id: StringName) -> void:
	if id == &"tutorial_fragile_gate" and current_id == "dialogue_2" and _tutorial_wall_ready():
		enter_node("dialogue_3")

func map_exit(target: StringName, entry: StringName) -> bool:
	if session.state.current_map == &"prologue_tutorial":
		if current_id in ["dialogue_3", "tutorial_free_play"]:
			enter_node("wilderness_start")
		else:
			status_changed.emit("出口尚未开放：先完成教学")
		return true
	if session.state.current_map == &"wilderness" and not bool(session.state.flags.get("prologue_complete", false)):
		status_changed.emit("出口尚未开放：先完成可蒂事件")
		return true
	return false

func enter_node(id: String) -> Dictionary:
	if not nodes.has(id):
		status_changed.emit("剧情错误：未知节点 %s" % id)
		return {"ok": false, "error": "UNKNOWN_NODE"}
	current_id = id
	session.state.story.current_node = id
	var node: Dictionary = nodes[id]
	var progress: Dictionary = node.get("progress", {})
	if not progress.is_empty(): session.state.story.chapter = String(progress.get("chapter", session.state.story.chapter))
	goal_changed.emit(_goal_text(node.get("goal", {})))
	if node.has("enter"):
		var action_result := await _run_action(String(node.enter.get("action", "")), node.enter, id)
		if not action_result.ok: return action_result
		if bool(action_result.get("waiting", false)): return action_result
	if node.has("dialogue"):
		_show_dialogue(id, node.dialogue)
		return {"ok": true, "waiting": true}
	if node.has("wait"):
		return {"ok": true, "waiting": true}
	var next := String(node.get("next", ""))
	if not next.is_empty():
			return await enter_node(next)
	return {"ok": true}

func execute_command(action: String, parameters := {}) -> Dictionary:
	return await _run_action(action, parameters, current_id)

func _run_action(action: String, parameters: Dictionary, source_id: String) -> Dictionary:
	if action.is_empty(): return {"ok": true}
	if not N6_ACTIONS.has(action):
		var known := false
		for node in nodes.values():
			if String(node.get("enter", {}).get("action", "")) == action: known = true
			for choice in node.get("dialogue", {}).get("choices", []):
				if String(choice.get("action", "")) == action: known = true
		if known: return {"ok": false, "error": "DEFERRED_OUT_OF_STAGE", "action": action}
		return {"ok": false, "error": "UNKNOWN_COMMAND", "action": action}
	match action:
		"loadMap":
			var wanted := StringName(parameters.get("mapId", ""))
			if session.state.current_map != wanted or not is_instance_valid(session.current_world):
				await session.load_map(wanted, StringName(parameters.get("entry", "")))
		"waitForWall":
			return {"ok": true, "waiting": true}
		"waitForExit":
			session.state.flags["tutorial_exit_open"] = true
			_start_exit_timer(source_id)
			return {"ok": true, "waiting": true}
		"spawnSlimes":
			if enemies_left == 0 and is_instance_valid(session.current_world):
				if not session.current_world.has_enemy_spawn(&"keti_slime_1") or not session.current_world.has_enemy_spawn(&"keti_slime_2"):
					return {"ok": false, "error": "MISSING_SPAWN_POINT", "action": action}
				enemies_left = 2
				session.current_world.spawn_enemy_at(&"keti_slime_1")
				session.current_world.spawn_enemy_at(&"keti_slime_2")
			return {"ok": true, "waiting": true}
		"eatKeti", "eatCorpse":
			if not bool(session.state.flags.get("keti_eaten", false)):
				var item_id := &"keti" if action == "eatKeti" else &"keti_corpse"
				if not session.current_world.player.add_special_item(item_id, {"actor_id": &"keti", "hp": 14.0}):
					return {"ok": false, "error": "STOMACH_FULL", "action": action}
				session.state.flags["keti_eaten"] = true
				if action == "eatCorpse": session.state.flags["keti_dead"] = true
				if is_instance_valid(session.current_world): session.current_world.remove_story_actor(&"keti")
		"waitForMemoryBlur":
			_start_memory_timer(source_id)
			return {"ok": true, "waiting": true}
		"memoryBlur":
			if not bool(session.state.flags.get("memory_blurred", false)):
				await _perform_memory_vomit()
				session.state.flags["memory_blurred"] = true
		"nameInput":
			panel.show_name_input()
			pause_requested.emit(&"dialogue", true)
			return {"ok": true, "waiting": true}
		"banner": status_changed.emit(String(parameters.get("text", "")))
	return {"ok": true}

func _show_dialogue(id: String, dialogue: Dictionary) -> void:
	var pages: Array[Dictionary] = []
	var variables := {"flags": session.state.flags, "story": session.state.story, "items": session.state.items}
	var page := runner.begin(id, dialogue, variables, _condition)
	while not page.is_empty():
		pages.append(page)
		if int(page.page) + 1 >= int(page.page_count): break
		page = runner.advance_page()
	panel.show_dialogue(pages)
	pause_requested.emit(&"dialogue", true)

func _on_choice(choice_id: String) -> void:
	var result := runner.choose(choice_id)
	if not result.ok: return
	panel.close()
	pause_requested.emit(&"dialogue", false)
	_finish_world_interaction()
	var action := String(result.get("action", ""))
	if not action.is_empty():
		var command := await _run_action(action, result.choice, current_id)
		if action == "waitForWall" or action == "waitForExit": return
		if not command.ok: return
	var next := String(result.get("next", ""))
	if not next.is_empty(): enter_node(next)

func _on_name_submitted(player_name: String) -> void:
	session.state.story.player_name = player_name
	session.state.flags["prologue_complete"] = true
	panel.close()
	pause_requested.emit(&"dialogue", false)
	_finish_world_interaction()
	enter_node("chapter1_start")

func _finish_world_interaction() -> void:
	if is_instance_valid(session.current_world):
		session.current_world.finish_actor_interaction()

func _on_actor_event(actor_id: StringName, event: StringName) -> void:
	if actor_id != &"keti" or current_id != "wilderness_keti_wait": return
	if event == &"died":
		session.state.flags["keti_dead"] = true
		enter_node("keti_dead")
	else:
		enter_node("keti_question")

func _start_memory_timer(source_id: String) -> void:
	if memory_timer_started: return
	memory_timer_started = true
	get_tree().create_timer(6.0).timeout.connect(func():
		memory_timer_started = false
		if current_id == source_id: enter_node("memory_blur"))

func _start_exit_timer(source_id: String) -> void:
	get_tree().create_timer(30.0).timeout.connect(func():
		if current_id == source_id: enter_node("dialogue_4"))

func _perform_memory_vomit() -> void:
	var player := session.current_world.player
	pause_requested.emit(&"cutscene", true)
	var bean_count := player.inventory.bean_ammo(player.body_chain.segment_count, SnakePlayer.MIN_LENGTH)
	player.inventory.selected_index = 0
	for index in range(bean_count):
		player.shot_cooldown_left = 0.0
		player.try_spit()
		await get_tree().create_timer(0.13, true, false, true).timeout
	for item_id in [&"keti", &"keti_corpse"]:
		for index in range(player.inventory.entries.size()):
			if player.inventory.entries[index].id == item_id:
				player.inventory.selected_index = index + 1
				player.shot_cooldown_left = 0.0
				player.try_spit()
				break
	player.inventory.selected_index = 0
	pause_requested.emit(&"cutscene", false)

func _tutorial_wall_ready() -> bool:
	return int(counters.tutorialBeansEaten) >= 5 and bool(session.state.flags.get("tutorial_fragile_gate", false))

func _condition(name: String) -> bool:
	match name:
		"tutorialBeans3": return int(counters.tutorialBeansEaten) >= 3
		"tutorialSpit3": return int(counters.tutorialBeansSpit) >= 3
		"enemiesCleared": return enemies_left <= 0
		"ketiEvent": return bool(session.state.flags.get("keti_dead", false)) or bool(session.state.flags.get("keti_contact", false))
		"freeExploreTimer": return not memory_timer_started
	return bool(session.state.flags.get(name, false))

func _goal_text(goal: Dictionary) -> String:
	if goal.get("kind", "") == "counter":
		return "%s：%d / %d" % [goal.get("label", "目标"), counters.get(goal.get("counter", ""), 0), goal.get("target", 0)]
	return String(goal.get("text", "继续探索"))
