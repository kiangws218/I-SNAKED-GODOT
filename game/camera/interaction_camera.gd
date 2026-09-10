class_name InteractionCamera
extends Camera2D

@export var focus_seconds := 0.32
@export var restore_seconds := 0.28
@export_range(1.0, 2.0, 0.05) var focus_zoom := 1.4
@export var focus_screen_anchor := Vector2(0.26, 0.5)

var _tween: Tween
var _focus_active := false
var _smoothing_before_focus := true

func focus_on(target: Node2D) -> void:
	if not is_instance_valid(target) or not get_parent() is Node2D:
		return
	focus_on_position(target.global_position, true)


func focus_on_player() -> void:
	if not get_parent() is Node2D:
		return
	var parent_2d := get_parent() as Node2D
	focus_on_position(parent_2d.global_position, false)


func focus_on_position(focus_point: Vector2, include_parent := true) -> void:
	if not get_parent() is Node2D:
		return
	_kill_tween()
	var parent_2d := get_parent() as Node2D
	if not _focus_active:
		_focus_active = true
		_smoothing_before_focus = position_smoothing_enabled
	position_smoothing_enabled = false
	# Frame the snake head and the contacted subject as one small left-side shot.
	if include_parent:
		focus_point = parent_2d.global_position.lerp(focus_point, 0.5)
	var desired_global := _camera_position_for(focus_point)
	var local_target := parent_2d.to_local(desired_global)
	_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_parallel(true)
	_tween.tween_property(self, "position", local_target, focus_seconds).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "zoom", Vector2.ONE * focus_zoom, focus_seconds).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func restore() -> void:
	_kill_tween()
	position_smoothing_enabled = false if _focus_active else _smoothing_before_focus
	_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_parallel(true)
	_tween.tween_property(self, "position", Vector2.ZERO, restore_seconds).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_property(self, "zoom", Vector2.ONE, restore_seconds).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_tween.chain().tween_callback(_finish_restore)

func _camera_position_for(focus_point: Vector2) -> Vector2:
	var viewport_size := get_viewport_rect().size
	if viewport_size.is_zero_approx():
		viewport_size = Vector2(768.0, 480.0)
	var anchor := Vector2(clampf(focus_screen_anchor.x, 0.0, 1.0), clampf(focus_screen_anchor.y, 0.0, 1.0))
	var zoom_amount := maxf(focus_zoom, 1.0)
	return focus_point - (viewport_size * (anchor - Vector2(0.5, 0.5))) / zoom_amount

func _finish_restore() -> void:
	_focus_active = false
	position_smoothing_enabled = _smoothing_before_focus

func _kill_tween() -> void:
	if is_instance_valid(_tween):
		_tween.kill()
