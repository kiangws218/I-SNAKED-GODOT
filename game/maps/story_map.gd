class_name StoryMap
extends Node2D

signal exit_reached(target: StringName, entry: StringName)
signal mechanism_changed(mechanism_id: StringName, done: bool)

const TILE_SIZE := 24.0
const TILESET := preload("res://assets/tiles/story_tileset.tres")
const PLAYER_SCENE := preload("res://game/player/snake_player.tscn")
const BEAN_SCENE := preload("res://game/projectiles/bean_projectile.tscn")
const GATE_SCRIPT := preload("res://game/maps/fragile_gate.gd")
const PROP_SCRIPT := preload("res://game/maps/map_prop_visual.gd")

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
	_build_camera()

func _physics_process(delta: float) -> void:
	if not is_instance_valid(player): return
	var cell := Vector2i(floori(player.global_position.x / TILE_SIZE), floori(player.global_position.y / TILE_SIZE))
	var exit_data: Dictionary = data.get("exit", data.get("debug_exit", {}))
	if not exit_data.is_empty():
		var allowed := not data.has("gate") or bool(flags.get(String(data.gate.id), false))
		if allowed and Rect2i(exit_data.rect).has_point(cell):
			if _exit_armed:
				exit_reached.emit(exit_data.target, exit_data.get("entry", &""))
		else:
			_exit_armed = true
	if data.has("pillar") and not pillar_done:
		_update_pillar(delta)

func _build_layers() -> void:
	ground_layer = TileMapLayer.new()
	ground_layer.name = "Ground"
	ground_layer.tile_set = TILESET
	add_child(ground_layer)
	wall_layer = TileMapLayer.new()
	wall_layer.name = "Collision"
	wall_layer.tile_set = TILESET
	wall_layer.z_index = 1
	add_child(wall_layer)
	var walkable: Rect2i = data.walkable
	var base_tile := int(data.get("ground", 0))
	for y in range(walkable.position.y, walkable.end.y):
		for x in range(walkable.position.x, walkable.end.x):
			ground_layer.set_cell(Vector2i(x,y), 0, Vector2i(base_tile,0))
	for terrain in data.get("terrain", []):
		_paint_rect(ground_layer, terrain.rect, int(terrain.tile))
	for x in range(walkable.position.x - 1, walkable.end.x + 1):
		wall_layer.set_cell(Vector2i(x, walkable.position.y - 1), 0, Vector2i(5,0))
		wall_layer.set_cell(Vector2i(x, walkable.end.y), 0, Vector2i(5,0))
	for y in range(walkable.position.y, walkable.end.y):
		wall_layer.set_cell(Vector2i(walkable.position.x - 1,y), 0, Vector2i(5,0))
		wall_layer.set_cell(Vector2i(walkable.end.x,y), 0, Vector2i(5,0))
	for obstacle in data.get("obstacles", []):
		_paint_rect(wall_layer, obstacle, 5)
	if data.has("bridge_gate") and not bool(flags.get("forest_bridge_open", false)):
		_paint_rect(wall_layer, data.bridge_gate, 5)
	ground_layer.update_internals()
	wall_layer.update_internals()

func _paint_rect(layer: TileMapLayer, rect: Rect2i, tile: int) -> void:
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			layer.set_cell(Vector2i(x,y), 0, Vector2i(tile,0))

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
		gate.setup(data.gate.id, data.gate.rect, int(data.gate.need))
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
	var blocked: Dictionary = {}
	for cell in player.body_chain.occupied_cells: blocked[cell] = &"body"
	for ring in player.placed_nodes:
		if is_instance_valid(ring) and not ring.finished: blocked[ring.cell] = &"node"
	step_pillar(delta, blocked)

func step_pillar(delta: float, blocked: Dictionary) -> void:
	var enclosed := false
	for region in EnclosureDetector.find_regions(data.walkable, blocked):
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

func _build_props() -> void:
	var exit_data: Dictionary = data.get("exit", data.get("debug_exit", {}))
	if not exit_data.is_empty():
		var exit_marker := Node2D.new()
		exit_marker.set_script(PROP_SCRIPT)
		exit_marker.name = "ExitMarker"
		add_child(exit_marker)
		exit_marker.setup(&"exit", "exit", (Vector2(exit_data.rect.get_center()) + Vector2(0.5,0.5)) * TILE_SIZE)
	for item in data.get("items", []):
		var marker := Node2D.new()
		marker.set_script(PROP_SCRIPT)
		marker.name = "Item_%s" % item.id
		add_child(marker)
		marker.setup(item.id, String(item.id), Vector2(item.cell) * TILE_SIZE)
