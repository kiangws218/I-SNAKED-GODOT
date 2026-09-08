extends Node2D

@onready var player: SnakePlayer = $SnakePlayer
@onready var state_label: Label = $UI/State

var enclosure_count := 0
var _enclosure_refresh_left := 0.0


func _ready() -> void:
	player.died.connect(_on_player_died)
	player.add_special_item(&"iron_sword")
	player.add_special_item(&"iron_sword")
	player.add_special_item(&"healing_potion")
	player.set_length(12)
	player.grant_node_charges(3)


func _process(delta: float) -> void:
	_enclosure_refresh_left -= delta
	if _enclosure_refresh_left <= 0.0:
		_refresh_enclosures()
		_enclosure_refresh_left = 0.2
	if player.is_dead:
		return
	if player.danger_kind.is_empty():
		state_label.text = "身长 %d · 豆 %d · 负重 %d/6 · 当前 %s · 节点 %d · 封闭区 %d · 断尾 %.1fs" % [
			player.body_chain.segment_count,
			player.inventory.bean_ammo(player.body_chain.segment_count),
			player.inventory.current_weight(),
			_display_item(player.inventory.selected_id()),
			player.node_charges,
			enclosure_count,
			player.cut_cooldown_left,
		]
	else:
		state_label.text = "危险！%.2f 秒内转向" % player.danger_seconds_left


func _on_player_died(reason: String) -> void:
	state_label.text = ("撞墙" if reason == "wall" else "咬到自己") + " · Enter 重新开始"


func _display_item(item_id: StringName) -> String:
	return {
		&"bean": "豆子",
		&"iron_sword": "铁剑×%d" % player.inventory.count_item(&"iron_sword"),
		&"healing_potion": "药水",
	}.get(item_id, String(item_id))


func _refresh_enclosures() -> void:
	var blocked: Dictionary[Vector2i, StringName] = {}
	for cell in player.body_chain.occupied_cells:
		blocked[cell] = &"body"
	for ring in player.placed_nodes:
		if is_instance_valid(ring) and not ring.finished:
			blocked[ring.cell] = &"node"
	for y in range(5, 15):
		blocked[Vector2i(20, y)] = &"world"
	enclosure_count = EnclosureDetector.find_regions(Rect2i(1, 1, 30, 18), blocked).size()


func _draw() -> void:
	for x in range(0, 769, 24):
		draw_line(Vector2(x, 0), Vector2(x, 480), Color(0.12, 0.14, 0.2), 1.0)
	for y in range(0, 481, 24):
		draw_line(Vector2(0, y), Vector2(768, y), Color(0.12, 0.14, 0.2), 1.0)
