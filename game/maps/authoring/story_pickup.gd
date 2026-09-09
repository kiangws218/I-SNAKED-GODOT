class_name StoryPickup
extends Area2D

signal collected(pickup: StoryPickup)

const PLACEHOLDER_TEXTURES := {
	&"iron_sword": preload("res://assets/placeholders/kenney/tiny_dungeon/items/iron_sword.png"),
	&"healing_potion": preload("res://assets/placeholders/kenney/tiny_dungeon/items/healing_potion.png"),
	&"ring": preload("res://assets/nodes/ring.png"),
}

@export var item_id: StringName
@export var pickup_id: StringName
@export var display_name := "剧情物品"
@export var auto_collect := false

var consumed := false

func persistent_id() -> StringName:
	return pickup_id if not pickup_id.is_empty() else item_id

func _ready() -> void:
	collision_layer = 128
	collision_mask = 4
	body_entered.connect(_on_body_entered)
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
	if auto_collect and not consumed and body is SnakePlayer:
		collected.emit(self)

func _draw() -> void:
	var texture := PLACEHOLDER_TEXTURES.get(item_id) as Texture2D
	if texture:
		draw_texture_rect(texture, Rect2(-12, -12, 24, 24), false)
	else:
		draw_circle(Vector2.ZERO, 9.0, Color("f6bd60"))
	draw_arc(Vector2.ZERO, 13.0, 0.0, TAU, 20, Color("fff1b8"), 2.0)
