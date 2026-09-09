class_name StoryMap
extends Node2D

signal exit_reached(target: StringName, entry: StringName)
signal mechanism_changed(mechanism_id: StringName, done: bool)
signal story_actor_interacted(actor_id: StringName)
signal story_actor_defeated(actor_id: StringName)
signal story_enemy_defeated(enemy_kind: StringName)
signal story_trigger_entered(trigger_id: StringName)
signal story_item_collected(item_id: StringName)
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
var ground_layer: TileMapLayer
var wall_layer: TileMapLayer
var player: SnakePlayer
var layout: Node2D
var camera: InteractionCamera
var active_npc: NpcActor
var bridge_pillar: BridgePillar
var pillar_progress := 0.0
var pillar_done := false

func setup(id: StringName, saved_flags: Dictionary, entry := &"", saved_items: Dictionary = {}) -> void:
	map_id = id
	data = StoryMapCatalog.get_map(id)
	flags = saved_flags
	item_states = saved_items
	_build_layers()
	_validate_authored_content()
	_spawn_player(entry)
	_spawn_beans()
	_build_camera()
	_bind_authored_content()

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
	var npc: NpcActor = NPC_SCENE.instantiate()
	npc.name = "NPC_%s" % actor_id
	npc.npc_id = actor_id
	add_child(npc)
	npc.global_position = at_position
	_bind_npc(npc)
	return npc

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
			return spawn_enemy(StringName(node.enemy_kind), node.global_position)
	return null

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
			return node
	return null

func finish_actor_interaction() -> void:
	if is_instance_valid(active_npc):
		active_npc.finish_interaction()
	active_npc = null
	if is_instance_valid(camera):
		camera.restore()

func _bind_authored_content() -> void:
	for node in _layout_nodes():
		if node is MapExit:
			node.requested.connect(_on_map_exit_requested)
		elif node is FragileGate:
			if bool(flags.get(String(node.gate_id), false)):
				node.queue_free()
			else:
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
		elif node is NpcActor:
			if not node.initially_active or (node.npc_id == &"keti" and (bool(flags.get("keti_eaten", false)) or bool(flags.get("keti_dead", false)))):
				node.set_actor_active(false)
			else:
				_bind_npc(node)
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
	npc.interaction_requested.connect(_on_npc_interaction_requested)
	npc.defeated.connect(func(actor: NpcActor): story_actor_defeated.emit(actor.npc_id))

func _bind_enemy(enemy: EnemyActor) -> void:
	enemy.setup(player)
	enemy.defeated.connect(_on_story_enemy_defeated.bind(enemy.enemy_kind))

func _on_npc_interaction_requested(npc: NpcActor, _player: SnakePlayer) -> void:
	active_npc = npc
	camera.focus_on(npc)
	story_actor_interacted.emit(npc.npc_id)

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
	story_enemy_defeated.emit(kind)
	_spawn_story_loot.call_deferred(death_position, burst)

func _spawn_story_loot(death_position: Vector2, burst: Array[Dictionary]) -> void:
	for launch_data in burst:
		var bean: BeanProjectile = BEAN_SCENE.instantiate()
		add_child(bean)
		bean.launch({"id": &"bean", "damage": 4, "length": 1, "weight": 0}, death_position, launch_data.direction, player)
		bean.speed = float(launch_data.speed)
