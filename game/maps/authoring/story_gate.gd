@tool
class_name StoryGate
extends Node2D

signal opened(gate_id: StringName)

@export var gate_id: StringName = &"story_gate"
@export var opened_flag: StringName
@export var open_animation: StringName = &"open"

@onready var gate_body: StaticBody2D = $GateBody
@onready var animation_player: AnimationPlayer = $AnimationPlayer

var is_open := false

func setup(saved_flags: Dictionary) -> void:
	is_open = not opened_flag.is_empty() and bool(saved_flags.get(String(opened_flag), false))
	_apply_open_state(is_open)

func open() -> bool:
	if is_open:
		return true
	is_open = true
	_set_collision_enabled(false)
	animation_player.play(open_animation)
	await animation_player.animation_finished
	opened.emit(gate_id)
	return true

func _apply_open_state(opened_state: bool) -> void:
	_set_collision_enabled(not opened_state)
	if opened_state:
		animation_player.play(open_animation)
		animation_player.seek(animation_player.get_animation(open_animation).length, true)
		animation_player.pause()
	else:
		animation_player.play(&"RESET")
		animation_player.seek(0.0, true)
		animation_player.pause()

func _set_collision_enabled(enabled: bool) -> void:
	if not is_node_ready():
		return
	var collision := gate_body.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision != null:
		collision.set_deferred("disabled", not enabled)
