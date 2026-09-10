class_name GameSession
extends Node

const MAP_SCRIPT := preload("res://game/maps/story_map.gd")
const DIALOGUE_SCRIPT := preload("res://game/ui/dialogue_panel.gd")
const MENU_SCRIPT := preload("res://game/ui/menu_controller.gd")
const STORY_SCRIPT := preload("res://game/story/story_director.gd")

@onready var world_host: Node2D = $WorldHost
@onready var screen_transition: ScreenTransition = $ScreenTransition
@onready var hud: CanvasLayer = $HUD
@onready var map_label: Label = $HUD/Panel/VBox/Map
@onready var status_label: Label = $HUD/Panel/VBox/Status
@onready var hint_label: Label = $HUD/Panel/VBox/Hint
@onready var inventory_title: Label = $HUD/InventoryPanel/VBox/Title
@onready var inventory_slots: Label = $HUD/InventoryPanel/VBox/Slots
var state := SessionState.new()
var store := SaveStore.new()
var current_world: StoryMap
var active_slot := 1
var dialogue: DialoguePanel
var menus: MenuController
var story: StoryDirector
var pause_reasons: Dictionary = {}
var map_transition_active := false

func _ready() -> void:
	dialogue = DIALOGUE_SCRIPT.new()
	add_child(dialogue)
	menus = MENU_SCRIPT.new()
	add_child(menus)
	story = STORY_SCRIPT.new()
	add_child(story)
	var graph_result := story.setup(self, dialogue)
	if not graph_result.ok: status_label.text = "剧情图载入失败"
	story.pause_requested.connect(set_pause_reason)
	story.goal_changed.connect(func(text: String): hint_label.text = "目标：" + text)
	story.status_changed.connect(func(text: String): status_label.text = text)
	menus.new_game.connect(start_new_game)
	menus.continue_game.connect(continue_game)
	menus.delete_slot.connect(_delete_and_refresh)
	menus.resume_requested.connect(toggle_pause)
	menus.reload_requested.connect(_reload_from_menu)
	menus.home_requested.connect(return_to_title)
	hud.visible = false
	menus.show_main(store.list_slots())

func _unhandled_input(event: InputEvent) -> void:
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
	var loaded := await load_active_slot()
	if not loaded.ok or loaded.get("empty", false):
		menus.show_main(store.list_slots())
		return
	menus.hide_all()
	hud.visible = true
	story.resume()

func load_map(map_id: StringName, entry := &"", debug_bypass := false, capture_current := true) -> bool:
	if not StoryMapCatalog.is_valid(map_id) or map_transition_active: return false
	map_transition_active = true
	await screen_transition.fade_out()
	if capture_current: _capture_player()
	if is_instance_valid(current_world):
		current_world.queue_free()
		await current_world.tree_exited
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
	map_label.text = "%s  [%s]" % [current_world.data.title, map_id]
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
	await load_map(state.current_map)
	status_label.text = "槽位 %d 已载入" % active_slot
	return loaded

func delete_slot(slot: int) -> Dictionary:
	return store.delete_slot(slot)

func set_pause_reason(reason: StringName, active: bool) -> void:
	if active: pause_reasons[reason] = true
	else: pause_reasons.erase(reason)
	get_tree().paused = not pause_reasons.is_empty()

func toggle_pause() -> void:
	var opening := not pause_reasons.has(&"menu")
	set_pause_reason(&"menu", opening)
	if opening: menus.show_pause()
	else: menus.hide_pause()

func return_to_title() -> void:
	if is_instance_valid(current_world): current_world.queue_free()
	current_world = null
	pause_reasons.clear()
	get_tree().paused = false
	hud.visible = false
	menus.show_main(store.list_slots())

func _delete_and_refresh(slot: int) -> void:
	delete_slot(slot)
	menus.show_main(store.list_slots())

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
	await get_tree().create_timer(0.35).timeout
	await retry_checkpoint()

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
			rider.attach_to_carrier(v, Vector2.ZERO)
	v.resources_changed.emit()
	v.health_changed.emit(v.hearts, v.max_hearts)

func _refresh_hud() -> void:
	if not is_instance_valid(current_world) or not is_instance_valid(current_world.player): return
	var v := current_world.player
	var bean_ammo := v.inventory.bean_ammo(v.body_chain.segment_count, SnakePlayer.MIN_LENGTH)
	status_label.text = "生命 %d/%d · 长度 %d · 豆 %d · 节点 %d" % [v.hearts, v.max_hearts, v.body_chain.segment_count, bean_ammo, v.node_charges]
	inventory_title.text = "胃袋  %d/%d  [Q/E 切换]" % [v.inventory.current_weight(), StomachInventory.MAX_WEIGHT]
	var lines: Array[String] = []
	lines.append(("▶ " if v.inventory.selected_index == 0 else "　") + "豆子 ×%d" % bean_ammo)
	for index in range(v.inventory.entries.size()):
		var entry: Dictionary = v.inventory.entries[index]
		var marker := "▶ " if v.inventory.selected_index == index + 1 else "　"
		lines.append("%s%s ×%d（重%d）" % [marker, _item_name(entry.id), entry.count, int(entry.weight) * int(entry.count)])
	inventory_slots.text = "\n".join(lines)

func _item_name(item_id: StringName) -> String:
	return {
		&"keti": "可蒂", &"keti_corpse": "可蒂的尸体", &"iron_sword": "铁剑",
		&"healing_potion": "治疗药水", &"ajie": "阿杰", &"lisi": "丽丝",
		&"ajian": "阿见", &"buck": "巴克", &"miro": "米洛", &"character_bones": "角色遗骨",
	}.get(item_id, String(item_id))
