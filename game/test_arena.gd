extends Node2D

@onready var player: SnakePlayer = $SnakePlayer
@onready var state_label: Label = $UI/State


func _ready() -> void:
	player.died.connect(_on_player_died)


func _process(_delta: float) -> void:
	if player.is_dead:
		return
	if player.danger_kind.is_empty():
		state_label.text = "速度 %.1f 格/秒 · 身长 %d" % [player.current_speed / 24.0, player.body_chain.segment_count]
	else:
		state_label.text = "危险！%.2f 秒内转向" % player.danger_seconds_left


func _on_player_died(reason: String) -> void:
	state_label.text = ("撞墙" if reason == "wall" else "咬到自己") + " · Enter 重新开始"


func _draw() -> void:
	for x in range(0, 769, 24):
		draw_line(Vector2(x, 0), Vector2(x, 480), Color(0.12, 0.14, 0.2), 1.0)
	for y in range(0, 481, 24):
		draw_line(Vector2(0, y), Vector2(768, y), Color(0.12, 0.14, 0.2), 1.0)
