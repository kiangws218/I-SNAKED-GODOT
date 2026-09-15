class_name LickCg
extends Control

const TONGUE_FRAME_ORDER := [3, 0, 1, 2]

## A single, cancellable lick performance that composes replaceable imported art layers.
signal cue(name: String)
signal finished
signal cancelled
signal completed(result: Dictionary)

var variant: LickCgVariant = LickCgVariant.human_female()
var _snake_position := Vector2(88, 398)
var _tongue_progress := 0.0
var _toe_spread := 0.0
var _visible_amount := 0.0
var _running := false
var _generation := 0
var _tween: Tween

@onready var _stage: Node2D = $Stage
@onready var _foot: AnimatedSprite2D = $Stage/Foot
@onready var _snake_rig: Node2D = $Stage/SnakeRig
@onready var _tongue: Sprite2D = $Stage/SnakeRig/Tongue

var _foot_base_position: Vector2
var _foot_base_scale: Vector2
var _foot_base_rotation: float

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_foot_base_position = _foot.position
	_foot_base_scale = _foot.scale
	_foot_base_rotation = _foot.rotation
	resized.connect(_update_stage_layout)
	_update_stage_layout()
	_apply_variant()
	_sync_visuals()
	set_process(false)
	queue_redraw()

func set_variant(value: LickCgVariant) -> void:
	variant = value
	if is_node_ready():
		_apply_variant()
	queue_redraw()

func play_once() -> void:
	cancel()
	_generation += 1
	var run_id := _generation
	_running = true
	set_process(true)
	_snake_position = Vector2(88, 398)
	_tongue_progress = 0.0
	_toe_spread = 0.0
	_visible_amount = 0.0
	_foot.stop()
	_foot.frame = 0
	_tween = create_tween()
	_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "_visible_amount", 1.0, 0.35)
	_tween.tween_property(self, "_snake_position", Vector2(132, 362), 0.35)
	_tween.tween_interval(0.18)
	_tween.tween_callback(func():
		cue.emit("contact")
		_foot.play(&"foot_action")
	)
	_tween.parallel().tween_property(self, "_tongue_progress", 1.0, 0.32)
	_tween.parallel().tween_property(self, "_toe_spread", 1.0, 0.18)
	_tween.tween_callback(func(): cue.emit("reaction_peak"))
	_tween.tween_property(self, "_toe_spread", 2.0, 0.16)
	_tween.tween_interval(0.1)
	_tween.tween_property(self, "_tongue_progress", 0.0, 0.28)
	_tween.parallel().tween_property(self, "_toe_spread", 0.0, 0.28)
	_tween.tween_interval(0.25)
	_tween.tween_property(self, "_snake_position", Vector2(88, 398), 0.3)
	_tween.tween_property(self, "_visible_amount", 0.0, 0.3)
	_tween.tween_callback(func(): _finish(run_id))

func cancel() -> void:
	var was_running := _running
	_generation += 1
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = null
	_running = false
	set_process(false)
	_foot.stop()
	_foot.frame = 0
	if was_running:
		cancelled.emit()
		completed.emit({"ok": true, "cancelled": true})

func _finish(run_id: int) -> void:
	if run_id != _generation:
		return
	if not _running:
		return
	_running = false
	set_process(false)
	_foot.stop()
	_foot.frame = 0
	finished.emit()
	completed.emit({"ok": true, "cancelled": false})

func _process(_delta: float) -> void:
	_sync_visuals()
	queue_redraw()

func _draw() -> void:
	var a := _visible_amount
	if a <= 0.001:
		return
	draw_set_transform(_stage.position, 0.0, _stage.scale)
	# Dedicated left-side stage: x=0..480 leaves the production dialogue zone clear.
	draw_rect(Rect2(0, 0, 480, 480), Color(0.035, 0.045, 0.09, 0.94 * a))
	draw_circle(Vector2(246, 210), 150.0, Color(0.10, 0.13, 0.22, 0.8 * a))
	if variant.foot_asset_id != &"human_female":
		_draw_placeholder_foot(a)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_placeholder_foot(a: float) -> void:
	var p := variant.subject_offset
	var s := variant.subject_scale
	var skin := variant.skin_color
	var accent := variant.accent_color
	# Sole points down-left; polygon is intentionally graphic placeholder art.
	var sole := PackedVector2Array([p + Vector2(-18, -112) * s, p + Vector2(68, -98) * s, p + Vector2(105, -18) * s, p + Vector2(86, 58) * s, p + Vector2(35, 104) * s, p + Vector2(-38, 76) * s, p + Vector2(-74, 12) * s])
	draw_colored_polygon(sole, Color(skin, a))
	draw_polyline(sole, Color(accent, a), 4.0)
	var spread := _toe_spread
	var toe_base := p + Vector2(-59, 38) * s
	for i in range(5):
		var t := float(i) - 2.0
		var pos := toe_base + Vector2(t * 17.0, t * 7.0 - spread * abs(t) * 5.0) * s
		draw_circle(pos, (11.0 - abs(t) * 1.2) * s.x, Color(accent, a))
		draw_circle(pos - Vector2(2, 2), (7.0 - abs(t) * 0.8) * s.x, Color(skin.lightened(0.08), a))

func _update_stage_layout() -> void:
	var dialogue_width := clampf(size.x * 0.34, 240.0, 360.0)
	var safe_width := maxf(240.0, size.x - dialogue_width - 28.0)
	var stage_scale := minf(safe_width / 480.0, size.y / 480.0)
	_stage.position = Vector2((safe_width - 480.0 * stage_scale) * 0.5 + 14.0, (size.y - 480.0 * stage_scale) * 0.5)
	_stage.scale = Vector2.ONE * stage_scale
	queue_redraw()

func _apply_variant() -> void:
	var is_human := variant.foot_asset_id == &"human_female"
	_foot.visible = is_human
	_foot.position = _foot_base_position + variant.foot_offset
	_foot.scale = _foot_base_scale * variant.foot_scale
	_foot.rotation = _foot_base_rotation + deg_to_rad(variant.foot_rotation_degrees)
	_foot.modulate = variant.foot_tint

func _sync_visuals() -> void:
	_stage.modulate.a = _visible_amount
	_snake_rig.position = _snake_position - Vector2(88, 398)
	_tongue.visible = _tongue_progress > 0.01
	if _tongue.visible:
		var order_index := clampi(floori(_tongue_progress * TONGUE_FRAME_ORDER.size()), 0, TONGUE_FRAME_ORDER.size() - 1)
		_tongue.frame = TONGUE_FRAME_ORDER[order_index]
