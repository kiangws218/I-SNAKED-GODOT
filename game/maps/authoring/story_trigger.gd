class_name StoryTrigger
extends Area2D

signal entered(trigger_id: StringName)

@export var trigger_id: StringName
@export var one_shot := true

var consumed := false

func _ready() -> void:
	collision_layer = 0
	collision_mask = 4
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if body is not SnakePlayer or (one_shot and consumed):
		return
	consumed = true
	entered.emit(trigger_id)

