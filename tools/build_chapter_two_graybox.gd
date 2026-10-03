extends SceneTree
## Offline authoring helper. Runtime loads the saved native .tscn, not this tool.

var scene_root := Node2D.new()

func _initialize() -> void:
	_build.call_deferred()

func _add(parent: Node, node: Node, node_name: String) -> Node:
	node.name = node_name
	parent.add_child(node)
	node.owner = scene_root
	return node

func _label(parent: Node, title: String, at: Vector2, color := Color.WHITE) -> void:
	var label := Label.new()
	label.text = title
	label.position = at
	label.add_theme_font_override("font", load("res://assets/fonts/fusion-pixel-10px-monospaced-zh_hans.ttf"))
	label.add_theme_font_size_override("font_size", 16)
	label.modulate = color
	_add(parent, label, "Label%d" % parent.get_child_count())

func _build() -> void:
	scene_root.name = "ChapterTwoSlice"
	var tiles := load("res://assets/tiles/story_tileset.tres") as TileSet
	var ground := _add(scene_root, TileMapLayer.new(), "Ground") as TileMapLayer
	ground.tile_set = tiles
	var walls := _add(scene_root, TileMapLayer.new(), "Collision") as TileMapLayer
	walls.tile_set = tiles
	for y in range(30):
		for x in range(56):
			ground.set_cell(Vector2i(x, y), 0, Vector2i(2 if x >= 49 else 0, 0))
			if x in [0, 55] or y in [0, 29]: walls.set_cell(Vector2i(x, y), 0, Vector2i(5, 0))
	for y in range(10, 19):
		for x in range(20, 29):
			ground.set_cell(Vector2i(x, y), 0, Vector2i(4, 0))
			if y in [10, 18] or x == 28 or (x == 20 and y not in range(11, 16)):
				walls.set_cell(Vector2i(x, y), 0, Vector2i(5, 0))
	for x in range(43, 55):
		for y in range(16, 20): ground.set_cell(Vector2i(x, y), 0, Vector2i(4, 0))
	for group_name in ["Actors", "Interactables", "Pickups", "Triggers", "SpawnPoints", "Decor"]:
		_add(scene_root, Node2D.new(), group_name)
	var actors := scene_root.get_node("Actors")
	for actor_id in ["caravan_merchant", "keti", "ferryman", "buck", "miro"]:
		var npc := load("res://game/actors/npc_actor.tscn").instantiate() as NpcActor
		npc.npc_id = StringName(actor_id)
		npc.persistent_state_id = StringName(actor_id)
		npc.max_hp = 14.0 if actor_id == "keti" else 8.0
		npc.defeat_mode = "downed"
		npc.initially_active = false
		npc.position = {"caravan_merchant": Vector2(348, 324), "keti": Vector2(552, 324), "ferryman": Vector2(1176, 516), "buck": Vector2(252, 504), "miro": Vector2(348, 504)}[actor_id]
		_add(actors, npc, actor_id.to_pascal_case())
	var gate := load("res://game/maps/authoring/story_gate.tscn").instantiate() as StoryGate
	gate.gate_id = &"ch2_cart_open"
	gate.opened_flag = &"ch2_cart_open"
	gate.position = Vector2(492, 324)
	_add(scene_root.get_node("Interactables"), gate, "CartGate")
	for item_id in ["ch2_key", "ch2_lever", "ch2_cart", "ch2_cot"]:
		var pickup := load("res://game/maps/authoring/story_pickup.tscn").instantiate() as StoryPickup
		pickup.item_id = StringName(item_id)
		pickup.pickup_id = StringName(item_id)
		pickup.position = {"ch2_key": Vector2(300, 228), "ch2_lever": Vector2(396, 420), "ch2_cart": Vector2(444, 324), "ch2_cot": Vector2(1008, 420)}[item_id]
		_add(scene_root.get_node("Pickups"), pickup, item_id.to_pascal_case())
	var entry := Marker2D.new()
	entry.set_script(load("res://game/maps/authoring/map_entry.gd"))
	entry.position = Vector2(132, 324)
	_add(scene_root.get_node("SpawnPoints"), entry, "Default")
	var decor := scene_root.get_node("Decor")
	_label(decor, "车队停靠地", Vector2(72, 108))
	_label(decor, "工具箱 / 备用钥匙", Vector2(216, 192))
	_label(decor, "商人", Vector2(320, 280))
	_label(decor, "开门杆", Vector2(360, 452))
	_label(decor, "马车：可蒂在里面", Vector2(504, 208))
	_label(decor, "渡口休息台", Vector2(948, 364))
	_label(decor, "船夫", Vector2(1140, 552))
	_label(decor, "灰盒：方向键移动 / J 吐出 / Q E 切换胃袋\n靠近角色与黄圈互动 / 回车推进对白", Vector2(72, 624), Color("ffe2a8"))
	var packed := PackedScene.new()
	var result := packed.pack(scene_root)
	if result == OK: result = ResourceSaver.save(packed, "res://game/maps/levels/chapter2_slice.tscn")
	scene_root.free()
	print("CH2 AUTHORING RESULT: ", result)
	quit(0 if result == OK else 1)
