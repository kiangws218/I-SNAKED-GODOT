class_name LickCg
extends Control

## A single, cancellable lick performance. Replace the drawing with imported art later.
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
	_tween.parallel().tween_property(self, "_toe_spread", 0.72, 0.22)
	_tween.tween_interval(0.12)
	_tween.tween_callback(func(): cue.emit("reaction_peak"))
	_tween.tween_property(self, "_tongue_progress", 0.0, 0.28)
	_tween.parallel().tween_property(self, "_toe_spread", 0.12, 0.28)
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
	var head := _snake_position
	draw_circle(head, 25.0, Color("#5cc6a1", a))
	draw_circle(head + Vector2(9, -7), 4.0, Color("#101b2b", a))
	draw_circle(head + Vector2(9, 7), 4.0, Color("#101b2b", a))
	draw_arc(head, 18.0, -0.7, 0.7, 12, Color("#193b46", a), 3.0)
	var tip := variant.subject_offset + variant.contact_offset
	var tongue_end := head.lerp(tip, _tongue_progress)
	if _tongue_progress > 0.01:
		draw_line(head + Vector2(20, 0), tongue_end, Color("#f07f91", a), 4.0)
		draw_line(tongue_end, tongue_end + Vector2(-8, -6), Color("#f07f91", a), 2.0)
		draw_line(tongue_end, tongue_end + Vector2(-8, 6), Color("#f07f91", a), 2.0)
