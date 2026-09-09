class_name InteractionCamera
extends Camera2D

@export var focus_seconds := 0.32
@export var restore_seconds := 0.28
@export_range(1.0, 2.0, 0.05) var focus_zoom := 1.25

var _tween: Tween

func focus_on(target: Node2D) -> void:
	if not is_instance_valid(target) or not get_parent() is Node2D:
		return
	_kill_tween()
	var parent_2d := get_parent() as Node2D
	var local_target := parent_2d.to_local(target.global_position)
	_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_parallel(true)
	_tween.tween_property(self, "position", local_target * 0.5, focus_seconds).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "zoom", Vector2.ONE * focus_zoom, focus_seconds).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func restore() -> void:
	_kill_tween()
	_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_parallel(true)
	_tween.tween_property(self, "position", Vector2.ZERO, restore_seconds).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_property(self, "zoom", Vector2.ONE, restore_seconds).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)

func _kill_tween() -> void:
	if is_instance_valid(_tween):
		_tween.kill()

