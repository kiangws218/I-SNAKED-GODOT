class_name MapExit
extends Area2D

signal requested(exit: MapExit)

@export var target_map: StringName
@export var target_entry: StringName
@export var required_flag: StringName
@export var locked_message := "道路尚未开放"

var armed := true

func _ready() -> void:
	collision_layer = 0
	collision_mask = 4
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node2D) -> void:
	if armed and body is SnakePlayer:
		armed = false
		requested.emit(self)

func _on_body_exited(body: Node2D) -> void:
	if body is SnakePlayer:
		armed = true

func is_unlocked(flags: Dictionary) -> bool:
	return required_flag.is_empty() or bool(flags.get(String(required_flag), false))
