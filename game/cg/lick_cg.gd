class_name LickCg
extends Control

const HUMAN_FOOT_FRAMES := preload("res://assets/cg/lick/human_foot_frames.png")
const SNAKE_HEAD := preload("res://assets/cg/lick/snake_head.png")
const TONGUE_FRAMES := preload("res://assets/cg/lick/tongue_frames.png")
const FOOT_FRAME_SIZE := Vector2(512, 512)
const TONGUE_FRAME_SIZE := Vector2(543, 724)
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

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)
	queue_redraw()

func set_variant(value: LickCgVariant) -> void:
	variant = value
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
	_tween = create_tween()
	_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "_visible_amount", 1.0, 0.35)
	_tween.tween_property(self, "_snake_position", Vector2(132, 362), 0.35)
	_tween.tween_interval(0.18)
	_tween.tween_callback(func(): cue.emit("contact"))
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
	finished.emit()
	completed.emit({"ok": true, "cancelled": false})

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	var a := _visible_amount
	if a <= 0.001:
		return
	var dialogue_width := clampf(size.x * 0.34, 240.0, 360.0)
	var safe_width := maxf(240.0, size.x - dialogue_width - 28.0)
	var stage_scale := minf(safe_width / 480.0, size.y / 480.0)
	var stage_x := (safe_width - 480.0 * stage_scale) * 0.5 + 14.0
	var stage_y := (size.y - 480.0 * stage_scale) * 0.5
	draw_set_transform(Vector2(stage_x, stage_y), 0.0, Vector2(stage_scale, stage_scale))
	# Dedicated left-side stage: x=0..480 leaves the production dialogue zone clear.
	draw_rect(Rect2(0, 0, 480, 480), Color(0.035, 0.045, 0.09, 0.94 * a))
	draw_circle(Vector2(246, 210), 150.0, Color(0.10, 0.13, 0.22, 0.8 * a))
	_draw_foot(a)
	_draw_snake(a)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_foot(a: float) -> void:
	var p := variant.subject_offset
	var s := variant.subject_scale
	if variant.foot_asset_id == &"human_female":
		var frame := clampi(roundi(_toe_spread), 0, 2)
		var source := Rect2(Vector2(frame * FOOT_FRAME_SIZE.x, 0), FOOT_FRAME_SIZE)
		var destination := Rect2(p + Vector2(-155, -220) * s, Vector2(325, 325) * s)
		draw_texture_rect_region(HUMAN_FOOT_FRAMES, destination, source, Color(1, 1, 1, a))
		return
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

func _draw_snake(a: float) -> void:
	var movement := _snake_position - Vector2(88, 398)
	draw_texture_rect(SNAKE_HEAD, Rect2(Vector2(20, 230) + movement, Vector2(250, 250)), false, Color(1, 1, 1, a))
	if _tongue_progress > 0.01:
		var order_index := clampi(floori(_tongue_progress * TONGUE_FRAME_ORDER.size()), 0, TONGUE_FRAME_ORDER.size() - 1)
		var frame: int = TONGUE_FRAME_ORDER[order_index]
		var source := Rect2(Vector2(frame * TONGUE_FRAME_SIZE.x, 0), TONGUE_FRAME_SIZE)
		var destination := Rect2(Vector2(174, 205) + movement, Vector2(180, 240))
		draw_texture_rect_region(TONGUE_FRAMES, destination, source, Color(1, 1, 1, a))
