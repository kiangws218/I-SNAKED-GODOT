class_name GameSession
extends Node

const MAP_SCRIPT := preload("res://game/maps/story_map.gd")
const DIALOGUE_SCRIPT := preload("res://game/ui/dialogue_panel.gd")
const MENU_SCENE := preload("res://game/ui/menu_controller.tscn")
const STORY_SCRIPT := preload("res://game/story/story_director.gd")
const DEATH_SCENE := preload("res://game/ui/death_screen.tscn")

@onready var world_host: Node2D = $WorldHost
@onready var screen_transition: ScreenTransition = $ScreenTransition
@onready var hud = $HUD
@onready var map_label: Label = $HUD/SafeArea/DebugMap
@onready var status_label: Label = $HUD/SafeArea/Status
@onready var hint_label: Label = $HUD/SafeArea/LegacyGoalText
@onready var inventory_slots: Label = $HUD/SafeArea/LegacyInventoryText
var state := SessionState.new()
var store := SaveStore.new()
var current_world: StoryMap
var active_slot := 1
var dialogue: DialoguePanel
var menus: MenuController
var story: StoryDirector
var pause_reasons: Dictionary = {}
var map_transition_active := false
var death_screen: DeathScreen

func _ready() -> void:
	dialogue = DIALOGUE_SCRIPT.new()
	add_child(dialogue)
	menus = MENU_SCENE.instantiate()
	add_child(menus)
	death_screen = DEATH_SCENE.instantiate()
	add_child(death_screen)
	death_screen.reload_requested.connect(_reload_after_death)
	death_screen.home_requested.connect(return_to_title)
	story = STORY_SCRIPT.new()
	add_child(story)
	var graph_result := story.setup(self, dialogue)
	if not graph_result.ok: status_label.text = "剧情图载入失败"
	story.pause_requested.connect(set_pause_reason)
	story.goal_changed.connect(_on_story_goal_changed)
	story.status_changed.connect(func(text: String): status_label.text = text)
	menus.new_game.connect(start_new_game)
	menus.continue_game.connect(continue_game)
	menus.delete_slot.connect(_delete_and_refresh)
	menus.resume_requested.connect(toggle_pause)
	menus.reload_requested.connect(_reload_from_menu)
	menus.save_requested.connect(_save_from_menu)
	menus.home_requested.connect(return_to_title)
	menus.exit_requested.connect(func(): get_tree().quit())
	hud.visible = false
	menus.show_main(store.list_slots())

func _unhandled_input(event: InputEvent) -> void:
	if death_screen.is_open() or pause_reasons.has(&"cutscene"): return
	if not event is InputEventKey or not event.pressed or event.echo: return
	if event.is_action_pressed("pause") and not menus.main_menu.visible and not pause_reasons.has(&"dialogue"):
		toggle_pause()
		get_viewport().set_input_as_handled()
		return
	if menus.is_blocking() or pause_reasons.has(&"dialogue"): return
	match event.physical_keycode:
		KEY_F1: if OS.is_debug_build(): load_map(&"prologue_tutorial", &"", true)
		KEY_F2: if OS.is_debug_build(): load_map(&"wilderness", &"", true)
		KEY_F3: if OS.is_debug_build(): load_map(&"forest", &"", true)
		KEY_F4: if OS.is_debug_build(): load_map(&"cave", &"", true)
		KEY_F5: save_active_slot()
		KEY_F6: load_active_slot()
		KEY_F9: retry_checkpoint()

func start_new_game(slot: int) -> void:
	death_screen.hide_screen()
	active_slot = clampi(slot, 1, SaveStore.SLOT_COUNT)
	state = SessionState.new()
	state.slot = active_slot
	menus.hide_all()
	hud.visible = true
	pause_reasons.clear()
	get_tree().paused = false
	story.start()

func continue_game(slot: int) -> void:
	active_slot = clampi(slot, 1, SaveStore.SLOT_COUNT)
	var was_paused := pause_reasons.has(&"menu")
	if was_paused:
		set_pause_reason(&"menu", false)
	var loaded := await load_active_slot()
	if not loaded.ok or loaded.get("empty", false):
		if is_instance_valid(current_world):
			set_pause_reason(&"menu", true)
			menus.show_pause()
		else:
			menus.show_main(store.list_slots())
		return
	menus.hide_all()
	hud.visible = true
	pause_reasons.clear()
	get_tree().paused = false
	story.resume()

func load_map(map_id: StringName, entry := &"", debug_bypass := false, capture_current := true) -> bool:
	if not StoryMapCatalog.is_valid(map_id) or map_transition_active: return false
	var source_map := state.current_map
	map_transition_active = true
	await screen_transition.fade_out()
	if capture_current: _capture_player()
	if map_id == &"forest" and source_map != &"forest":
		state.prepare_released_pair_forest_return(source_map == &"cave")
	if is_instance_valid(current_world):
		var outgoing_world := current_world
		current_world = null
		outgoing_world.queue_free()
		await outgoing_world.tree_exited
	current_world = MAP_SCRIPT.new()
	world_host.add_child(current_world)
	state.current_map = map_id
	current_world.setup(map_id, state.flags, entry, state.items, state.actors, state.encounters)
	_restore_player()
	current_world.exit_reached.connect(_on_exit_reached)
	current_world.exit_blocked.connect(func(message: String): status_label.text = message)
	current_world.mechanism_changed.connect(_on_mechanism_changed)
	current_world.player.died.connect(_on_player_died)
	current_world.player.resources_changed.connect(_refresh_hud)
	current_world.player.health_changed.connect(func(_current: int, _maximum: int): _refresh_hud())
	story.bind_world(current_world)
	remember_checkpoint(map_id, entry)
	hud.set_map_debug("%s  [%s]" % [current_world.data.title, map_id])
	status_label.text = "开发跨图" if debug_bypass else "检查点已记录"
	_refresh_hud()
	await screen_transition.fade_in()
	map_transition_active = false
	return true

func remember_checkpoint(map_id: StringName, entry := &"") -> void:
	state.checkpoint_map = map_id
	state.checkpoint_entry = entry
	_capture_player()
	state.remember_checkpoint()

func retry_checkpoint() -> void:
	if not is_instance_valid(current_world): return
	story.cancel_pending_flow()
	status_label.text = "从检查点重建地图…"
	state.restore_checkpoint()
	await load_map(state.checkpoint_map, state.checkpoint_entry, false, false)
	current_world.player.hearts = current_world.player.max_hearts
	current_world.player.health_changed.emit(current_world.player.hearts, current_world.player.max_hearts)
	story.resume()
	status_label.text = "已回到检查点（满生命）"

func save_active_slot() -> Dictionary:
	_capture_player()
	var metadata := {"current_map": String(state.current_map), "chapter": state.story.get("chapter", "序章"), "player_name": state.story.get("player_name", "未命名")}
	var result := store.save_slot(active_slot, state.to_dictionary(), metadata)
	status_label.text = ("槽位 %d 已保存" % active_slot) if result.ok else ("保存失败：%s" % result.error.code)
	return result

func load_active_slot() -> Dictionary:
	var loaded := store.load_slot(active_slot)
	if not loaded.ok or loaded.get("empty", false):
		status_label.text = "槽位 %d 无法读取" % active_slot
		return loaded
	var applied := state.load_dictionary(loaded.data)
	if not applied.ok: return applied
	story.cancel_pending_flow()
	await load_map(state.current_map, &"", false, false)
	status_label.text = "槽位 %d 已载入" % active_slot
	return loaded

func delete_slot(slot: int) -> Dictionary:
	return store.delete_slot(slot)

func set_pause_reason(reason: StringName, active: bool) -> void:
	if active: pause_reasons[reason] = true
	else: pause_reasons.erase(reason)
	get_tree().paused = not pause_reasons.is_empty()

func toggle_pause() -> void:
	if death_screen.is_open(): return
	var opening := not pause_reasons.has(&"menu")
	set_pause_reason(&"menu", opening)
	if opening: menus.show_pause()
	else: menus.hide_pause()

func return_to_title() -> void:
	story.cancel_pending_flow()
	death_screen.hide_screen()
	dialogue.close()
	if is_instance_valid(current_world): current_world.queue_free()
	current_world = null
	pause_reasons.clear()
	get_tree().paused = false
	hud.visible = false
	menus.show_main(store.list_slots())

func _delete_and_refresh(slot: int) -> void:
	delete_slot(slot)
	menus.update_slots(store.list_slots())

func _save_from_menu() -> void:
	save_active_slot()
	menus.update_slots(store.list_slots())

func _reload_from_menu() -> void:
	set_pause_reason(&"menu", false)
	menus.hide_pause()
	retry_checkpoint()

func _on_exit_reached(target: StringName, entry: StringName) -> void:
	if map_transition_active: return
	if story.map_exit(target, entry): return
	await load_map(target, entry)

func _on_mechanism_changed(id: StringName, done: bool) -> void:
	state.flags[String(id)] = done
	state.mechanisms[String(id)] = {"done": done}
	status_label.text = "机关完成：%s" % id
	if done: story.mechanism_completed(id)

func _on_player_died(_reason: String) -> void:
	if death_screen.is_open(): return
	story.cancel_pending_flow()
	dialogue.close()
	menus.hide_all()
	set_pause_reason(&"death", true)
	var saved := store.load_slot(active_slot)
	death_screen.show_screen(saved.ok and not saved.get("empty", false))

func _reload_after_death() -> void:
	if not death_screen.is_open() or map_transition_active: return
	death_screen.reload_button.disabled = true
	death_screen.home_button.disabled = true
	var saved := store.load_slot(active_slot)
	if saved.ok and not saved.get("empty", false):
		var applied := state.load_dictionary(saved.data)
		if not applied.ok:
			death_screen.message.text = "存档无效，请返回主菜单选择其他槽位"
			death_screen.reload_button.disabled = false
			death_screen.home_button.disabled = false
			return
		pause_reasons.clear()
		get_tree().paused = false
		await load_map(state.current_map, &"", false, false)
		story.resume()
	else:
		pause_reasons.clear()
		get_tree().paused = false
		await retry_checkpoint()
	death_screen.hide_screen()
	hud.visible = true

func _capture_player() -> void:
	if not is_instance_valid(current_world) or not is_instance_valid(current_world.player): return
	current_world.capture_actor_states()
	current_world.capture_enemy_states()
	var v := current_world.player
	state.player = {"length": v.body_chain.segment_count, "hearts": v.hearts, "max_hearts": v.max_hearts, "node_unlocked": v.node_unlocked, "node_charges": v.node_charges, "inventory": v.inventory.entries.duplicate(true), "selected_index": v.inventory.selected_index, "rider": state.player.get("rider", "")}

func _restore_player() -> void:
	var v := current_world.player
	v.max_hearts = int(state.player.get("max_hearts", 3))
	v.hearts = int(state.player.get("hearts", v.max_hearts))
	v.node_unlocked = bool(state.player.get("node_unlocked", false))
	v.node_charges = int(state.player.get("node_charges", 0))
	v.inventory.entries.assign(state.player.get("inventory", []))
	v.inventory.selected_index = clampi(int(state.player.get("selected_index", 0)), 0, v.inventory.entries.size())
	v.set_length(int(state.player.get("length", 4)))
	var rider_id := StringName(state.player.get("rider", ""))
	if not rider_id.is_empty():
		var rider := current_world.get_story_actor(rider_id)
		if is_instance_valid(rider):
			var rider_state: Dictionary = state.actors.get(String(rider_id), {})
			rider.restore_persistent_state({"hp": float(rider_state.get("hp", rider.hp)), "max_hp": float(rider_state.get("max_hp", rider.max_hp)), "damageable": false, "active": false, "is_dead": false, "is_downed": false})
			rider.attach_to_carrier(v, Vector2.ZERO)
	v.resources_changed.emit()
	v.health_changed.emit(v.hearts, v.max_hearts)

func _refresh_hud() -> void:
	if not is_instance_valid(current_world) or not is_instance_valid(current_world.player): return
	var v := current_world.player
	var bean_ammo := v.inventory.bean_ammo(v.body_chain.segment_count, SnakePlayer.MIN_LENGTH)
	hud.set_health(v.hearts, v.max_hearts)
	hud.set_inventory(v.inventory.entries, v.inventory.selected_index, bean_ammo, v.inventory.current_weight(), StomachInventory.MAX_WEIGHT)
	var lines: Array[String] = []
	lines.append(("▶ " if v.inventory.selected_index == 0 else "　") + "豆子 ×%d" % bean_ammo)
	for index in range(v.inventory.entries.size()):
		var entry: Dictionary = v.inventory.entries[index]
		var marker := "▶ " if v.inventory.selected_index == index + 1 else "　"
		lines.append("%s%s ×%d（重%d）" % [marker, _item_name(entry.id), entry.count, int(entry.weight) * int(entry.count)])
	inventory_slots.text = "\n".join(lines)
	_refresh_quest_hud()

func _on_story_goal_changed(text: String) -> void:
	hint_label.text = text
	call_deferred("_refresh_quest_hud")

func _refresh_quest_hud() -> void:
	var quests: Dictionary = state.story.get("quests", {})
	var quest: Dictionary = quests.get("findAjian", {})
	var accepted := bool(state.flags.get("findAjianAccepted", false)) or not quest.is_empty()
	var active := accepted and String(quest.get("status", "active")) == "active"
	active = active and not bool(state.flags.get("ajianFound", false)) and not bool(state.flags.get("storyCompleted", false))
	hud.set_find_ajian_quest(active)

func _item_name(item_id: StringName) -> String:
	return {
		&"keti": "可蒂", &"keti_corpse": "可蒂的尸体", &"iron_sword": "铁剑",
		&"healing_potion": "治疗药水", &"ajie": "阿杰", &"lisi": "丽丝",
		&"ajian": "阿见", &"buck": "巴克", &"miro": "米洛", &"character_bones": "角色遗骨",
	}.get(item_id, String(item_id))
