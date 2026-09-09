class_name ScreenTransition
extends CanvasLayer

@export var fade_out_seconds := 0.22
@export var fade_in_seconds := 0.26

@onready var shade: ColorRect = $Shade
var _tween: Tween

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	shade.modulate.a = 0.0
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE

func fade_out() -> void:
	await _fade_to(1.0, fade_out_seconds)

func fade_in() -> void:
	await _fade_to(0.0, fade_in_seconds)

func _fade_to(alpha: float, seconds: float) -> void:
	if DisplayServer.get_name() == "headless":
		shade.modulate.a = alpha
		return
	if is_instance_valid(_tween):
		_tween.kill()
	_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_tween.tween_property(shade, "modulate:a", alpha, seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await _tween.finished

