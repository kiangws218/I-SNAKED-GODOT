class_name BossBeanPickup
extends Area2D

@export_range(1, 20, 1) var length_amount := 1
@export_range(0, 60, 0.5) var respawn_seconds := 3.0
var _respawn_left := 0.0
var _available := true

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	if _available or respawn_seconds <= 0.0: return
	_respawn_left = maxf(0.0, _respawn_left - delta)
	if _respawn_left <= 0.0:
		_available = true
		visible = true
		# A stopped snake may still overlap a respawned supply.
		for body in get_overlapping_bodies():
			if body is SnakePlayer:
				_on_body_entered(body)
				break

func _on_body_entered(body: Node2D) -> void:
	if not _available or not body is SnakePlayer or body.is_dead: return
	_available = false
	visible = false
	_respawn_left = respawn_seconds
	body.set_length(body.body_chain.segment_count + length_amount)
	body.bean_collected.emit()
