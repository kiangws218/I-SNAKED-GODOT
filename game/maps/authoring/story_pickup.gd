class_name StoryPickup
extends Area2D

signal collected(pickup: StoryPickup)
signal interaction_requested(pickup: StoryPickup)

@export var item_id: StringName
@export var pickup_id: StringName
@export var display_name := "剧情物品"
@export var auto_collect := false

var consumed := false
var _interaction_armed := true

func persistent_id() -> StringName:
	return pickup_id if not pickup_id.is_empty() else item_id

func _ready() -> void:
	collision_layer = 128
	collision_mask = 4
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	queue_redraw()

func consume() -> void:
	if consumed:
		return
	consumed = true
	set_deferred("monitoring", false)
	visible = false

func play_event(animation_name: StringName) -> void:
	var animation_player := get_node_or_null("AnimationPlayer") as AnimationPlayer
	if animation_player and animation_player.has_animation(animation_name):
		animation_player.play(animation_name)

func _on_body_entered(body: Node2D) -> void:
	if consumed or body is not SnakePlayer:
		return
	if auto_collect:
		collected.emit(self)
	elif _interaction_armed:
		_interaction_armed = false
		interaction_requested.emit(self)

func _on_body_exited(body: Node2D) -> void:
	if body is SnakePlayer:
		_interaction_armed = true

func _draw() -> void:
	draw_circle(Vector2.ZERO, 9.0, Color("f6bd60"))
	draw_arc(Vector2.ZERO, 13.0, 0.0, TAU, 20, Color("fff1b8"), 2.0)
