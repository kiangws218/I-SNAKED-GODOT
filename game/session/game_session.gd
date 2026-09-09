class_name GameSession
extends Node

const MAP_SCRIPT := preload("res://game/maps/story_map.gd")
@onready var world_host: Node2D = $WorldHost
@onready var map_label: Label = $HUD/Panel/VBox/Map
@onready var status_label: Label = $HUD/Panel/VBox/Status
var state := SessionState.new()
var store := SaveStore.new()
var current_world: StoryMap
var active_slot := 1

func _ready() -> void:
	load_map(state.current_map)

func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	match event.physical_keycode:
		KEY_1: _set_active_slot(1)
		KEY_2: _set_active_slot(2)
		KEY_3: _set_active_slot(3)
		KEY_F1: load_map(&"prologue_tutorial", &"", true)
		KEY_F2: load_map(&"wilderness", &"", true)
		KEY_F3: load_map(&"forest", &"", true)
		KEY_F4: load_map(&"cave", &"", true)
		KEY_F5: save_active_slot()
		KEY_F6: load_active_slot()
		KEY_F9: retry_checkpoint()

func load_map(map_id: StringName, entry := &"", debug_bypass := false, capture_current := true) -> bool:
	if not StoryMapCatalog.is_valid(map_id):
		return false
	if capture_current:
		_capture_player()
	if is_instance_valid(current_world):
		current_world.queue_free()
		await current_world.tree_exited
	current_world = MAP_SCRIPT.new()
	world_host.add_child(current_world)
	state.current_map = map_id
	current_world.setup(map_id, state.flags, entry, state.items)
	_restore_player()
	current_world.exit_reached.connect(_on_exit_reached)
	current_world.mechanism_changed.connect(_on_mechanism_changed)
	current_world.player.died.connect(_on_player_died)
	remember_checkpoint(map_id, entry)
	map_label.text = "%s  [%s]" % [current_world.data.title, map_id]
	status_label.text = "调试跨图" if debug_bypass else "检查点已记录"
	return true

func remember_checkpoint(map_id: StringName, entry := &"") -> void:
	state.checkpoint_map = map_id
	state.checkpoint_entry = entry
	_capture_player()
	state.remember_checkpoint()

func retry_checkpoint() -> void:
	status_label.text = "从检查点重建地图…"
	state.restore_checkpoint()
	await load_map(state.checkpoint_map, state.checkpoint_entry, false, false)
	current_world.player.hearts = current_world.player.max_hearts
	current_world.player.health_changed.emit(current_world.player.hearts, current_world.player.max_hearts)
	status_label.text = "已回到检查点（满生命）"

func save_active_slot() -> Dictionary:
	_capture_player()
	var result := store.save_slot(active_slot, state.to_dictionary(), {"current_map": String(state.current_map), "chapter": state.story.chapter})
	status_label.text = ("槽位 %d 已保存" % active_slot) if result.ok else ("保存失败：%s" % result.error.code)
	return result

func load_active_slot() -> Dictionary:
	var loaded := store.load_slot(active_slot)
	if not loaded.ok or loaded.get("empty", false):
		status_label.text = "槽位 %d 无法读取" % active_slot
		return loaded
	var applied := state.load_dictionary(loaded.data)
	if not applied.ok:
		return applied
	await load_map(state.current_map)
	status_label.text = "槽位 %d 已载入" % active_slot
	return loaded

func delete_slot(slot: int) -> Dictionary:
	return store.delete_slot(slot)

func _set_active_slot(slot: int) -> void:
	active_slot = clampi(slot, 1, SaveStore.SLOT_COUNT)
	status_label.text = "当前槽位：%d（F5 保存 / F6 载入）" % active_slot

func _on_exit_reached(target: StringName, entry: StringName) -> void:
	await load_map(target, entry)

func _on_mechanism_changed(id: StringName, done: bool) -> void:
	state.flags[String(id)] = done
	state.mechanisms[String(id)] = {"done": done}
	status_label.text = "机关完成：%s" % id

func _on_player_died(_reason: String) -> void:
	await get_tree().create_timer(0.35).timeout
	await retry_checkpoint()

func _capture_player() -> void:
	if not is_instance_valid(current_world) or not is_instance_valid(current_world.player):
		return
	var v := current_world.player
	state.player = {"length": v.body_chain.segment_count, "hearts": v.hearts, "max_hearts": v.max_hearts, "node_unlocked": v.node_unlocked, "node_charges": v.node_charges, "inventory": v.inventory.entries.duplicate(true), "selected_index": v.inventory.selected_index}

func _restore_player() -> void:
	var v := current_world.player
	v.max_hearts = int(state.player.get("max_hearts", 3))
	v.hearts = int(state.player.get("hearts", v.max_hearts))
	v.node_unlocked = bool(state.player.get("node_unlocked", false))
	v.node_charges = int(state.player.get("node_charges", 0))
	v.inventory.entries.assign(state.player.get("inventory", []))
	v.inventory.selected_index = clampi(int(state.player.get("selected_index", 0)), 0, v.inventory.entries.size())
	v.set_length(int(state.player.get("length", 4)))
	v.resources_changed.emit()
	v.health_changed.emit(v.hearts, v.max_hearts)
