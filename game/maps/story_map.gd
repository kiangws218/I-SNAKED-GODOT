class_name StoryMap
extends Node2D

signal exit_reached(target: StringName, entry: StringName)
signal mechanism_changed(mechanism_id: StringName, done: bool)
signal story_actor_interacted(actor_id: StringName)
signal story_actor_defeated(actor_id: StringName)
signal story_enemy_defeated(enemy_kind: StringName)

const TILE_SIZE := 24.0
const PLAYER_SCENE := preload("res://game/player/snake_player.tscn")
const BEAN_SCENE := preload("res://game/projectiles/bean_projectile.tscn")
const GATE_SCRIPT := preload("res://game/maps/fragile_gate.gd")
const PROP_SCRIPT := preload("res://game/maps/map_prop_visual.gd")
const NPC_SCENE := preload("res://game/actors/npc_actor.tscn")
const ENEMY_SCENE := preload("res://game/actors/enemy_actor.tscn")
const PILLAR_SCAN_INTERVAL := 0.1
const PILLAR_ACTIVE_RADIUS := 14.0 * TILE_SIZE

var map_id: StringName
var data: Dictionary
var flags: Dictionary
var item_states: Dictionary
var ground_layer: TileMapLayer
var wall_layer: TileMapLayer
var player: SnakePlayer
var pillar_progress := 0.0
var pillar_done := false
var _exit_armed := false
var _pillar_scan_elapsed := 0.0

func setup(id: StringName, saved_flags: Dictionary, entry := &"", saved_items: Dictionary = {}) -> void:
	map_id = id
	data = StoryMapCatalog.get_map(id)
	flags = saved_flags
	item_states = saved_items
	_build_layers()
	_spawn_player(entry)
	_spawn_beans()
	_build_mechanisms()
	_build_props()
	_build_story_actors()
	_build_camera()

func _physics_process(delta: float) -> void:
	if not is_instance_valid(player): return
	var cell := Vector2i(floori(player.global_position.x / TILE_SIZE), floori(player.global_position.y / TILE_SIZE))
	var exit_data: Dictionary = data.get("exit", data.get("debug_exit", {}))
	if not exit_data.is_empty():
		var allowed := not data.has("gate") or bool(flags.get(String(data.gate.id), false))
		var inside := allowed and Rect2i(exit_data.rect).has_point(cell)
		if inside and not _exit_armed:
			_exit_armed = true
			exit_reached.emit(exit_data.target, exit_data.get("entry", &""))
		elif not inside:
			_exit_armed = false
	if data.has("pillar") and not pillar_done:
		_update_pillar(delta)
	_update_story_item_pickups()

func _build_layers() -> void:
	var layout_scene: PackedScene = load(String(data.scene))
	var layout := layout_scene.instantiate()
	layout.name = "MapLayout"
	add_child(layout)
	ground_layer = layout.get_node("Ground")
	wall_layer = layout.get_node("Collision")
	if data.has("bridge_gate") and bool(flags.get("forest_bridge_open", false)):
		for y in range(data.bridge_gate.position.y, data.bridge_gate.end.y):
			for x in range(data.bridge_gate.position.x, data.bridge_gate.end.x): wall_layer.erase_cell(Vector2i(x, y))
		wall_layer.update_internals()

func _spawn_player(entry: StringName) -> void:
	player = PLAYER_SCENE.instantiate()
	add_child(player)
	var spawn := Vector2(data.spawn)
	var direction := Vector2(data.direction)
	if not entry.is_empty() and data.get("entries", {}).has(entry):
		spawn = data.entries[entry].spawn
		direction = data.entries[entry].direction
	player.global_position = spawn * TILE_SIZE
	player.reset_at(player.global_position, direction)

func _spawn_beans() -> void:
	var cells: Array = data.get("beans", [])
	if cells.is_empty() and int(data.get("beans_random", 0)) > 0:
		var walkable: Rect2i = data.walkable
		for index in range(int(data.beans_random)):
			cells.append(Vector2i(walkable.position.x + 6 + index * 6, walkable.get_center().y + (index % 3) - 1))
	for cell in cells:
		var item_key := "%s:bean:%d:%d" % [map_id, cell.x, cell.y]
		if bool(item_states.get(item_key, false)):
			continue
		var bean: BeanProjectile = BEAN_SCENE.instantiate()
		add_child(bean)
		bean.launch({"id": &"bean", "damage": 4, "length": 1, "weight": 0}, (Vector2(cell) + Vector2(0.5,0.5)) * TILE_SIZE, Vector2.RIGHT, player)
		bean.collected.connect(_on_map_bean_collected.bind(item_key))
		bean.age = 0.25
		bean.land()

func _on_map_bean_collected(_payload: Dictionary, item_key: String) -> void:
	item_states[item_key] = true

func _build_mechanisms() -> void:
	if data.has("gate") and not bool(flags.get(String(data.gate.id), false)):
		var gate: FragileGate = GATE_SCRIPT.new()
		gate.name = "FragileGate"
		add_child(gate)
		gate.setup(data.gate.id, data.gate.get("barrier_rect", data.gate.rect), int(data.gate.need))
		gate.opened.connect(_on_gate_opened)
	if data.has("pillar"):
		pillar_done = bool(flags.get("forest_bridge_open", false))
		var marker := Node2D.new()
		marker.name = "BridgePillar"
		marker.position = (Vector2(data.pillar.cell) + Vector2(0.5,0.5)) * TILE_SIZE
		marker.set_script(preload("res://game/maps/bridge_pillar_visual.gd"))
		marker.set("done", pillar_done)
		add_child(marker)

func _on_gate_opened(id: StringName) -> void:
	flags[String(id)] = true
	mechanism_changed.emit(id, true)

func _update_pillar(delta: float) -> void:
	_pillar_scan_elapsed += delta
	if _pillar_scan_elapsed < PILLAR_SCAN_INTERVAL:
		return
	var elapsed := _pillar_scan_elapsed
	_pillar_scan_elapsed = 0.0
	var pillar_position := (Vector2(data.pillar.cell) + Vector2(0.5,0.5)) * TILE_SIZE
	if player.global_position.distance_to(pillar_position) > PILLAR_ACTIVE_RADIUS or player.placed_nodes.is_empty():
		step_pillar(elapsed, {})
		return
	var scan_bounds: Rect2i = data.get("pillar_scan_bounds", data.walkable)
	var blocked: Dictionary = {}
	for cell in player.body_chain.occupied_cells:
		if scan_bounds.has_point(cell):
			blocked[cell] = &"body"
	for ring in player.placed_nodes:
		if is_instance_valid(ring) and not ring.finished and scan_bounds.has_point(ring.cell):
			blocked[ring.cell] = &"node"
	step_pillar(elapsed, blocked)

func step_pillar(delta: float, blocked: Dictionary) -> void:
	var enclosed := false
	var scan_bounds: Rect2i = data.get("pillar_scan_bounds", data.walkable)
	for region in EnclosureDetector.find_regions(scan_bounds, blocked):
		if region.cells.has(data.pillar.cell) and region.touches_body and region.touches_node:
			enclosed = true
			break
	pillar_progress = minf(float(data.pillar.charge), pillar_progress + delta) if enclosed else maxf(0.0, pillar_progress - delta * 0.2)
	var marker := get_node_or_null("BridgePillar")
	if marker:
		marker.set("progress", pillar_progress / float(data.pillar.charge))
		marker.queue_redraw()
	if pillar_progress >= float(data.pillar.charge):
		pillar_done = true
		flags["forest_bridge_open"] = true
		for y in range(data.bridge_gate.position.y, data.bridge_gate.end.y):
			for x in range(data.bridge_gate.position.x, data.bridge_gate.end.x): wall_layer.erase_cell(Vector2i(x,y))
		wall_layer.update_internals()
		if marker: marker.set("done", true)
		mechanism_changed.emit(data.pillar.id, true)

func _build_camera() -> void:
	var camera := Camera2D.new()
	camera.name = "Camera2D"
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 8.0
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = int(data.size.x * TILE_SIZE)
	camera.limit_bottom = int(data.size.y * TILE_SIZE)
	player.add_child(camera)
	camera.reset_smoothing.call_deferred()

func _build_props() -> void:
	for item in data.get("items", []):
		if bool(item_states.get(_story_item_key(item.id), false)):
			continue
		var marker := Node2D.new()
		marker.set_script(PROP_SCRIPT)
		marker.name = "Item_%s" % item.id
		add_child(marker)
		marker.setup(item.id, String(item.id), Vector2(item.cell) * TILE_SIZE)

func _update_story_item_pickups() -> void:
	if map_id != &"cave":
		return
	for item in data.get("items", []):
		if item.id != &"ring":
			continue
		var item_key := _story_item_key(item.id)
		if bool(item_states.get(item_key, false)):
			return
		if player.global_position.distance_to(Vector2(item.cell) * TILE_SIZE) > 0.7 * TILE_SIZE:
			return
		item_states[item_key] = true
		player.grant_node_charges(1, true)
		if player.play_sfx:
			player.pickup_audio.play()
		var marker := get_node_or_null("Item_%s" % item.id)
		if marker:
			marker.queue_free()
		return

func _story_item_key(item_id: StringName) -> String:
	return "%s:item:%s" % [map_id, item_id]

func _build_story_actors() -> void:
	if map_id != &"wilderness":
		return
	for definition in data.get("npcs", []):
		if definition.id == &"keti" and (bool(flags.get("keti_eaten", false)) or bool(flags.get("keti_dead", false))):
			continue
		spawn_npc(definition.id, Vector2(definition.position) * TILE_SIZE)

func spawn_npc(actor_id: StringName, at_position: Vector2) -> NpcActor:
	var npc: NpcActor = NPC_SCENE.instantiate()
	npc.name = "NPC_%s" % actor_id
	npc.npc_id = actor_id
	add_child(npc)
	npc.global_position = at_position
	npc.setup(player)
	npc.interaction_requested.connect(func(actor: NpcActor, _player: SnakePlayer): story_actor_interacted.emit(actor.npc_id))
	npc.defeated.connect(func(actor: NpcActor): story_actor_defeated.emit(actor.npc_id))
	return npc

func spawn_enemy(kind: StringName, at_position: Vector2) -> EnemyActor:
	var enemy: EnemyActor = ENEMY_SCENE.instantiate()
	enemy.name = "StoryEnemy_%s" % get_child_count()
	enemy.enemy_kind = kind
	add_child(enemy)
	enemy.global_position = at_position
	enemy.setup(player)
	enemy.defeated.connect(_on_story_enemy_defeated.bind(kind))
	return enemy

func remove_story_actor(actor_id: StringName) -> void:
	var actor := get_node_or_null("NPC_%s" % actor_id)
	if actor:
		actor.queue_free()

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
