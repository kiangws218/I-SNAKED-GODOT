class_name StoryMap
extends Node2D

signal exit_reached(target: StringName, entry: StringName)
signal mechanism_changed(mechanism_id: StringName, done: bool)
signal story_actor_interacted(actor_id: StringName)
signal story_actor_defeated(actor_id: StringName)
signal story_enemy_defeated(enemy_kind: StringName)
signal story_trigger_entered(trigger_id: StringName)
signal story_item_collected(item_id: StringName)
signal story_item_interacted(item_id: StringName)
signal story_actor_released(actor_id: StringName)
signal exit_blocked(message: String)

const TILE_SIZE := 24.0
const PLAYER_SCENE := preload("res://game/player/snake_player.tscn")
const BEAN_SCENE := preload("res://game/projectiles/bean_projectile.tscn")
const NPC_SCENE := preload("res://game/actors/npc_actor.tscn")
const ENEMY_SCENE := preload("res://game/actors/enemy_actor.tscn")
const CAMERA_SCENE := preload("res://game/camera/interaction_camera.tscn")

var map_id: StringName
var data: Dictionary
var flags: Dictionary
var item_states: Dictionary
var actor_states: Dictionary
var encounter_states: Dictionary
var ground_layer: TileMapLayer
var wall_layer: TileMapLayer
var player: SnakePlayer
var layout: Node2D
var camera: InteractionCamera
var active_npc: NpcActor
var active_pickup: StoryPickup
var bridge_pillar: BridgePillar
var pillar_progress := 0.0
var pillar_done := false

func setup(id: StringName, saved_flags: Dictionary, entry := &"", saved_items: Dictionary = {}, saved_actors: Dictionary = {}, saved_encounters: Dictionary = {}) -> void:
	map_id = id
	data = StoryMapCatalog.get_map(id)
	flags = saved_flags
	item_states = saved_items
	actor_states = saved_actors
	encounter_states = saved_encounters
	_build_layers()
	_validate_authored_content()
	_spawn_player(entry)
	_spawn_beans()
	_build_camera()
	_bind_authored_content()
	_spawn_automatic_enemies()

func _build_layers() -> void:
	var layout_scene: PackedScene = load(String(data.scene))
	layout = layout_scene.instantiate()
	layout.name = "MapLayout"
	add_child(layout)
	ground_layer = layout.get_node("Ground")
	wall_layer = layout.get_node("Collision")

func _spawn_player(entry: StringName) -> void:
	player = PLAYER_SCENE.instantiate()
	add_child(player)
	player.actor_released.connect(_on_player_actor_released)
	var wanted := entry if not entry.is_empty() else &"default"
	var marker := _find_entry(wanted)
	if marker == null:
		marker = _find_entry(&"default")
	assert(marker != null, "地图 %s 缺少 default MapEntry" % map_id)
	player.global_position = marker.global_position
	player.reset_at(player.global_position, marker.facing)

func _spawn_beans() -> void:
	for node in _layout_nodes():
		if node is not ItemSpawnPoint or node.item_id != &"bean":
			continue
		var marker := node as ItemSpawnPoint
		var item_key := marker.stable_id(map_id)
		if bool(item_states.get(item_key, false)):
			continue
		var bean: BeanProjectile = BEAN_SCENE.instantiate()
		add_child(bean)
		bean.launch({"id": &"bean", "damage": 4, "length": 1, "weight": 0}, marker.global_position, Vector2.RIGHT, player)
		bean.collected.connect(_on_map_bean_collected.bind(item_key))
		bean.age = 0.25
		bean.land()

func _on_map_bean_collected(_payload: Dictionary, item_key: String) -> void:
	item_states[item_key] = true

func _on_gate_opened(id: StringName) -> void:
	flags[String(id)] = true
	mechanism_changed.emit(id, true)

func step_pillar(delta: float, blocked: Dictionary) -> void:
	if bridge_pillar == null:
		return
	bridge_pillar.step_charge(delta, blocked)
	pillar_progress = bridge_pillar.progress
	pillar_done = bridge_pillar.done

func _build_camera() -> void:
	camera = CAMERA_SCENE.instantiate()
	player.add_child(camera)
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = int(data.size.x * TILE_SIZE)
	camera.limit_bottom = int(data.size.y * TILE_SIZE)
	camera.reset_smoothing.call_deferred()

func _story_item_key(item_id: StringName) -> String:
	return "%s:item:%s" % [map_id, item_id]

func spawn_npc(actor_id: StringName, at_position: Vector2) -> NpcActor:
	var existing := _find_npc(actor_id)
	if is_instance_valid(existing):
		existing.global_position = at_position
		if existing.player == null:
			_bind_npc(existing)
		else:
			existing.set_actor_active(true)
		return existing
	var npc: NpcActor = NPC_SCENE.instantiate()
	npc.name = "NPC_%s" % actor_id
	npc.npc_id = actor_id
	add_child(npc)
	npc.global_position = at_position
	_bind_npc(npc)
	return npc

func _find_npc(actor_id: StringName) -> NpcActor:
	for node in get_tree().get_nodes_in_group(&"npc"):
		if not is_ancestor_of(node):
			continue
		if node is NpcActor and node.npc_id == actor_id and not node.is_queued_for_deletion():
			return node
	return null

func _on_player_actor_released(payload: Dictionary, at_position: Vector2) -> void:
	var metadata: Dictionary = payload.get("metadata", {})
	var actor_id := StringName(metadata.get("actor_id", payload.get("id", "")))
	if actor_id.is_empty() or actor_id == &"bean":
		return
	var npc := spawn_npc(actor_id, at_position)
	npc.restore_from_payload(payload)
	actor_states[String(actor_id)] = {
		"status": "critical" if bool(metadata.get("critical", false)) else "unconscious",
		"location": String(map_id), "hp": npc.hp, "max_hp": npc.max_hp,
		"position": [at_position.x, at_position.y], "met": true,
	}
	_discard_actor_projectile(actor_id, at_position)
	story_actor_released.emit(actor_id)

func _discard_actor_projectile(actor_id: StringName, at_position: Vector2) -> void:
	for child in get_children():
		if not child is BeanProjectile or not child.actor_released:
			continue
		var payload: Dictionary = child.payload
		var metadata: Dictionary = payload.get("metadata", {})
		var child_actor_id := StringName(metadata.get("actor_id", payload.get("id", "")))
		if child_actor_id == actor_id and child.global_position.distance_to(at_position) < 1.0:
			child.queue_free()

func spawn_enemy(kind: StringName, at_position: Vector2) -> EnemyActor:
	var enemy: EnemyActor = ENEMY_SCENE.instantiate()
	enemy.name = "StoryEnemy_%s" % get_child_count()
	enemy.enemy_kind = kind
	add_child(enemy)
	enemy.global_position = at_position
	_bind_enemy(enemy)
	return enemy

func spawn_enemy_at(spawn_id: StringName) -> EnemyActor:
	for node in _layout_nodes():
		if node is EnemySpawnPoint and node.spawn_id == spawn_id:
			var saved: Dictionary = encounter_states.get(_enemy_state_key(spawn_id), {})
			if bool(saved.get("is_dead", false)):
				return null
			var enemy := spawn_enemy(StringName(node.enemy_kind), node.global_position)
			enemy.spawn_id = spawn_id
			if not saved.is_empty():
				enemy.restore_persistent_state(saved)
			return enemy
	return null

func _spawn_automatic_enemies() -> void:
	for node in _layout_nodes():
		if node is not EnemySpawnPoint or not node.auto_spawn:
			continue
		var state_key := _enemy_state_key(node.spawn_id)
		var saved: Dictionary = encounter_states.get(state_key, {})
		if bool(saved.get("is_dead", false)):
			continue
		spawn_enemy_at(node.spawn_id)

func _enemy_state_key(spawn_id: StringName) -> String:
	return "%s:enemy:%s" % [map_id, spawn_id]

func has_enemy_spawn(spawn_id: StringName) -> bool:
	for node in _layout_nodes():
		if node is EnemySpawnPoint and node.spawn_id == spawn_id:
			return true
	return false

func remove_story_actor(actor_id: StringName) -> void:
	for node in _layout_nodes() + get_children():
		if node is NpcActor and node.npc_id == actor_id:
			if layout.is_ancestor_of(node):
				node.set_actor_active(false)
			else:
				node.queue_free()
			return

func activate_npc(actor_id: StringName) -> NpcActor:
	for node in _layout_nodes():
		if node is NpcActor and node.npc_id == actor_id:
			if node.player == null:
				_bind_npc(node)
			node.set_actor_active(true)
			_restore_actor_state(node)
			return node
	return null

func finish_actor_interaction() -> void:
	if is_instance_valid(active_npc):
		active_npc.finish_interaction()
	active_npc = null
	active_pickup = null
	if is_instance_valid(camera):
		camera.restore()


func focus_dialogue() -> void:
	if not is_instance_valid(camera):
		return
	if is_instance_valid(active_npc):
		camera.focus_on(active_npc)
	elif is_instance_valid(active_pickup):
		camera.focus_on(active_pickup)
	else:
		camera.focus_on_player()

func open_story_gate(gate_id: StringName) -> bool:
	var gate := get_story_gate(gate_id)
	if gate == null:
		return false
	camera.focus_on_position(gate.global_position, false)
	await get_tree().create_timer(camera.focus_seconds, true, false, true).timeout
	await gate.open()
	camera.restore()
	await get_tree().create_timer(camera.restore_seconds, true, false, true).timeout
	return true

func get_story_gate(gate_id: StringName) -> StoryGate:
	for node in _layout_nodes():
		if node is StoryGate and node.gate_id == gate_id:
			return node
	return null

func _bind_authored_content() -> void:
	for node in _layout_nodes():
		if node is MapExit:
			node.requested.connect(_on_map_exit_requested)
		elif node is FragileGate:
			if bool(flags.get(String(node.gate_id), false)):
				node.queue_free()
			else:
				node.opened.connect(_on_gate_opened)
		elif node is StoryGate:
			node.setup(flags)
			if not node.opened.is_connected(_on_gate_opened):
				node.opened.connect(_on_gate_opened)
		elif node is BridgePillar:
			bridge_pillar = node
			pillar_done = bool(flags.get("forest_bridge_open", false))
			bridge_pillar.setup(player, pillar_done)
			bridge_pillar.completed.connect(_on_bridge_pillar_completed)
			if pillar_done:
				_open_bridge_collision(bridge_pillar.barrier_cells)
		elif node is StoryPickup:
			var pickup_key := _story_item_key(node.persistent_id())
			if bool(item_states.get(pickup_key, false)):
				node.consume()
			else:
				node.collected.connect(_on_story_pickup_collected)
				node.interaction_requested.connect(_on_story_pickup_interaction_requested)
		elif node is NpcActor:
			var actor_state: Dictionary = actor_states.get(String(node.npc_id), {})
			var actor_here := StringName(actor_state.get("location", "")) == map_id
			var actor_status := String(actor_state.get("status", "alive"))
			var state_active := actor_here and actor_status not in ["dead", "swallowed", "riding", "left"]
			var keti_consumed: bool = node.npc_id == &"keti" and actor_status in ["swallowed", "dead"]
			if (not node.initially_active and not state_active) or keti_consumed:
				node.set_actor_active(false)
			else:
				_bind_npc(node)
				_restore_actor_state(node)
		elif node is EnemyActor:
			if not node.initially_active:
				node.queue_free()
			else:
				_bind_enemy(node)
		elif node is StoryTrigger:
			node.entered.connect(func(trigger_id: StringName): story_trigger_entered.emit(trigger_id))

func _bind_npc(npc: NpcActor) -> void:
	npc.setup(player)
	npc.set_actor_active(true)
	if not npc.interaction_requested.is_connected(_on_npc_interaction_requested):
		npc.interaction_requested.connect(_on_npc_interaction_requested)
	if not npc.defeated.is_connected(_on_npc_defeated):
		npc.defeated.connect(_on_npc_defeated)
	if not npc.downed.is_connected(_on_npc_defeated):
		npc.downed.connect(_on_npc_defeated)

func _bind_enemy(enemy: EnemyActor) -> void:
	enemy.setup(player)
	enemy.defeated.connect(_on_story_enemy_defeated.bind(enemy.enemy_kind))

func _on_npc_interaction_requested(npc: NpcActor, _player: SnakePlayer) -> void:
	active_npc = npc
	story_actor_interacted.emit(npc.npc_id)

func _on_story_pickup_interaction_requested(pickup: StoryPickup) -> void:
	active_pickup = pickup
	story_item_interacted.emit(pickup.item_id if not pickup.item_id.is_empty() else pickup.persistent_id())

func _on_npc_defeated(npc: NpcActor) -> void:
	var actor_id := String(npc.npc_id)
	var state: Dictionary = actor_states.get(actor_id, {})
	state["status"] = "critical" if npc.npc_id == &"ajian" else ("downed" if npc.is_downed else "dead")
	if npc.npc_id == &"ajian":
		flags["ajianCritical"] = true
	state["location"] = String(map_id)
	state["hp"] = npc.hp
	state["max_hp"] = npc.max_hp
	state["position"] = [npc.global_position.x, npc.global_position.y]
	actor_states[actor_id] = state
	story_actor_defeated.emit(npc.npc_id)

func _on_map_exit_requested(map_exit: MapExit) -> void:
	if not map_exit.is_unlocked(flags):
		exit_blocked.emit(map_exit.locked_message)
		return
	exit_reached.emit(map_exit.target_map, map_exit.target_entry)

func _on_story_pickup_collected(pickup: StoryPickup) -> void:
	var item_key := _story_item_key(pickup.persistent_id())
	if bool(item_states.get(item_key, false)):
		return
	item_states[item_key] = true
	if pickup.item_id == &"ring":
		player.grant_node_charges(1, true)
		if player.play_sfx:
			player.pickup_audio.play()
	pickup.consume()
	story_item_collected.emit(pickup.item_id)

func consume_story_pickup(item_id: StringName) -> bool:
	for node in _layout_nodes():
		if node is StoryPickup and node.item_id == item_id and not node.consumed:
			var item_key := _story_item_key(node.persistent_id())
			item_states[item_key] = true
			node.consume()
			return true
	return false

func get_story_actor(actor_id: StringName) -> NpcActor:
	return _find_npc(actor_id)

func capture_actor_states() -> void:
	for node in get_tree().get_nodes_in_group(&"npc"):
		if not is_ancestor_of(node):
			continue
		if node is not NpcActor:
			continue
		var key := String(node.npc_id)
		var state: Dictionary = actor_states.get(key, {})
		var current_status := String(state.get("status", "alive"))
		if current_status not in ["swallowed", "riding", "dead", "left"]:
			state["status"] = "downed" if node.is_downed else ("dead" if node.is_dead else current_status)
			state["location"] = String(map_id)
			state["hp"] = node.hp
			state["max_hp"] = node.max_hp
			state["damageable"] = node.damageable
			state["hostile"] = node.hostile
			state["position"] = [node.global_position.x, node.global_position.y]
		actor_states[key] = state

func capture_enemy_states() -> void:
	for node in get_tree().get_nodes_in_group(&"enemy"):
		if not is_ancestor_of(node) or node is not EnemyActor or node.spawn_id.is_empty():
			continue
		var state: Dictionary = node.get_persistent_state()
		state["position"] = [node.global_position.x, node.global_position.y]
		encounter_states[_enemy_state_key(node.spawn_id)] = state

func _restore_actor_state(npc: NpcActor) -> void:
	var state: Dictionary = actor_states.get(String(npc.npc_id), {})
	if state.is_empty():
		return
	var actor_here := StringName(state.get("location", "")) == map_id
	var spawn_anchor := StringName(state.get("spawn_anchor", ""))
	var anchor := _find_entry(spawn_anchor) if actor_here and not spawn_anchor.is_empty() else null
	if anchor != null:
		npc.global_position = anchor.global_position
		state["position"] = [anchor.global_position.x, anchor.global_position.y]
		actor_states[String(npc.npc_id)] = state
	var saved_position: Array = state.get("position", [])
	if anchor == null and saved_position.size() == 2 and actor_here:
		npc.global_position = Vector2(float(saved_position[0]), float(saved_position[1]))
	var status := String(state.get("status", "alive"))
	npc.restore_persistent_state({
		"npc_id": String(npc.npc_id), "persistent_state_id": String(npc.persistent_state_id),
		"max_hp": float(state.get("max_hp", npc.max_hp)), "hp": float(state.get("hp", npc.max_hp)),
		"damageable": bool(state.get("damageable", false)),
		"hostile": bool(state.get("hostile", false)),
		"active": status not in ["dead", "swallowed", "riding", "left"],
		"is_dead": status == "dead", "is_downed": status == "downed",
	})

func _on_bridge_pillar_completed(pillar: BridgePillar) -> void:
	pillar_done = true
	pillar_progress = pillar.progress
	flags["forest_bridge_open"] = true
	_open_bridge_collision(pillar.barrier_cells)
	mechanism_changed.emit(pillar.pillar_id, true)

func _open_bridge_collision(cells: Rect2i) -> void:
	for y in range(cells.position.y, cells.end.y):
		for x in range(cells.position.x, cells.end.x):
			wall_layer.erase_cell(Vector2i(x, y))
	wall_layer.update_internals()

func _find_entry(entry_id: StringName) -> MapEntry:
	for node in _layout_nodes():
		if node is MapEntry and node.entry_id == entry_id:
			return node
	return null

func _validate_authored_content() -> void:
	var seen: Dictionary = {}
	for node in _layout_nodes():
		var kind := ""
		var stable_id := ""
		if node is MapEntry:
			kind = "entry"
			stable_id = String(node.entry_id)
		elif node is EnemySpawnPoint:
			kind = "enemy_spawn"
			stable_id = String(node.spawn_id)
		elif node is ItemSpawnPoint:
			kind = "item_spawn"
			stable_id = String(node.spawn_id)
		elif node is StoryTrigger:
			kind = "trigger"
			stable_id = String(node.trigger_id)
		elif node is StoryPickup:
			kind = "pickup"
			stable_id = String(node.persistent_id())
		elif node is NpcActor:
			kind = "npc"
			stable_id = String(node.npc_id)
		elif node is BridgePillar:
			kind = "pillar"
			stable_id = String(node.pillar_id)
		elif node is FragileGate:
			kind = "gate"
			stable_id = String(node.gate_id)
		elif node is StoryGate:
			kind = "story_gate"
			stable_id = String(node.gate_id)
		if kind.is_empty():
			continue
		assert(not stable_id.is_empty(), "地图 %s 的 %s 缺少稳定 ID：%s" % [map_id, kind, node.get_path()])
		var key := "%s:%s" % [kind, stable_id]
		assert(not seen.has(key), "地图 %s 的稳定 ID 重复：%s" % [map_id, key])
		seen[key] = true
	assert(seen.has("entry:default"), "地图 %s 缺少 default MapEntry" % map_id)

func _layout_nodes() -> Array[Node]:
	var result: Array[Node] = []
	_append_descendants(layout, result)
	return result

func _append_descendants(parent: Node, result: Array[Node]) -> void:
	for child in parent.get_children():
		result.append(child)
		_append_descendants(child, result)

func _on_story_enemy_defeated(enemy: EnemyActor, drops: int, kind: StringName) -> void:
	var death_position := enemy.global_position
	var burst := enemy.make_loot_burst(drops)
	if not enemy.spawn_id.is_empty():
		var state := enemy.get_persistent_state()
		state["position"] = [death_position.x, death_position.y]
		encounter_states[_enemy_state_key(enemy.spawn_id)] = state
	story_enemy_defeated.emit(kind)
	_spawn_story_loot.call_deferred(death_position, burst)

func _spawn_story_loot(death_position: Vector2, burst: Array[Dictionary]) -> void:
	for launch_data in burst:
		var bean: BeanProjectile = BEAN_SCENE.instantiate()
		add_child(bean)
		bean.launch({"id": &"bean", "damage": 4, "length": 1, "weight": 0}, death_position, launch_data.direction, player)
		bean.speed = float(launch_data.speed)
