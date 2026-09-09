extends Node2D

@onready var player: SnakePlayer = $SnakePlayer
@onready var state_label: Label = $UI/State
@onready var combat_label: Label = $UI/Info/Text/Combat
@onready var prison_label: Label = $UI/Info/Text/Prison
@onready var npc_hint_label: Label = $UI/NpcHint
@onready var slime: EnemyActor = $Slime
@onready var mushroom: EnemyActor = $Mushroom
@onready var keti: NpcActor = $Keti
@onready var prison_controller: PrisonController = $PrisonController
@onready var interact_audio: AudioStreamPlayer = $InteractAudio
@onready var prison_audio: AudioStreamPlayer = $PrisonAudio

var enclosure_count := 0
var node_prison_count := 0
const PRISON_BOUNDS := Rect2i(1, 1, 30, 18)
const BEAN_PROJECTILE_SCENE := preload("res://game/projectiles/bean_projectile.tscn")


func _ready() -> void:
	player.died.connect(_on_player_died)
	player.health_changed.connect(_on_player_health_changed)
	slime.setup(player)
	mushroom.setup(player)
	keti.setup(player)
	slime.defeated.connect(_on_enemy_defeated)
	mushroom.defeated.connect(_on_enemy_defeated)
	keti.interaction_requested.connect(_on_npc_interaction)
	prison_controller.prison_burst.connect(_on_prison_burst)
	player.add_special_item(&"iron_sword")
	player.add_special_item(&"iron_sword")
	player.add_special_item(&"healing_potion")
	player.set_length(12)
	player.grant_node_charges(3)
	_update_hud()


func _process(delta: float) -> void:
	_refresh_prisons(delta)
	_update_hud()
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
	var reason_text: String = {
		"wall": "撞墙",
		"self": "咬到自己",
		"enemy_contact": "敌人接触",
		"enemy_projectile": "针刺命中",
	}.get(reason, reason)
	state_label.text = reason_text + " · Enter 重新开始"


func _display_item(item_id: StringName) -> String:
	return {
		&"bean": "豆子",
		&"iron_sword": "铁剑×%d" % player.inventory.count_item(&"iron_sword"),
		&"healing_potion": "药水",
	}.get(item_id, String(item_id))


func _refresh_prisons(delta: float) -> void:
	var blocked: Dictionary[Vector2i, StringName] = {}
	for cell in player.body_chain.occupied_cells:
		blocked[cell] = &"body"
	for ring in player.placed_nodes:
		if is_instance_valid(ring) and not ring.finished:
			blocked[ring.cell] = &"node"
	for y in range(5, 15):
		blocked[Vector2i(20, y)] = &"world"
	var targets: Array = [slime, mushroom, keti]
	var result := prison_controller.step(delta, PRISON_BOUNDS, blocked, targets, player.placed_nodes)
	enclosure_count = int(result.get("active", 0))
	node_prison_count = int(result.get("node", 0))


func _on_enemy_defeated(enemy: EnemyActor, bean_drops: int) -> void:
	if not is_instance_valid(enemy):
		return
	for index in range(bean_drops):
		var bean: BeanProjectile = BEAN_PROJECTILE_SCENE.instantiate()
		add_child(bean)
		var spread := Vector2(float(index) - float(bean_drops - 1) * 0.5, 0.0) * 8.0
		bean.launch({"id": &"bean", "damage": 4, "length": 1, "weight": 0}, enemy.global_position + spread, Vector2.RIGHT, player)
		bean.age = 0.25
		bean.land()


func _on_npc_interaction(npc: NpcActor, _target: SnakePlayer) -> void:
	var display_name := "可提" if npc.npc_id == &"keti" else String(npc.npc_id)
	npc_hint_label.text = "%s：你好！" % display_name
	interact_audio.play()
	npc.call_deferred("finish_interaction")


func _on_prison_burst(_target: Node2D, _damage: float, _node_prison: bool) -> void:
	prison_audio.play()


func _on_player_health_changed(_current: int, _maximum: int) -> void:
	_update_hud()


func _update_hud() -> void:
	var hearts := "♥".repeat(player.hearts) + "♡".repeat(maxi(0, player.max_hearts - player.hearts))
	combat_label.text = "心 %s · 史莱姆 %s · 蘑菇 %s" % [hearts, _enemy_hp(slime), _enemy_hp(mushroom)]
	prison_label.text = "活动监狱 %d · 节点监狱 %d" % [enclosure_count, node_prison_count]


func _enemy_hp(enemy: Variant) -> String:
	if not is_instance_valid(enemy) or not enemy is EnemyActor:
		return "已击败"
	return "%d/%d" % [roundi(enemy.hp), roundi(enemy.max_hp)]


func _draw() -> void:
	for x in range(0, 769, 24):
		draw_line(Vector2(x, 0), Vector2(x, 480), Color(0.12, 0.14, 0.2), 1.0)
	for y in range(0, 481, 24):
		draw_line(Vector2(0, y), Vector2(768, y), Color(0.12, 0.14, 0.2), 1.0)
