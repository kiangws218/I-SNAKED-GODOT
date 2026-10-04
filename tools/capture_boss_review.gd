extends SceneTree
## Opens the editable Boss arena under the native renderer and saves an overview.

const ARENA_PATH := "res://game/boss/boss_arena.tscn"
const OUTPUT_PATH := "res://review/boss_arena_overview.png"
const PHASE_TWO_OUTPUT_PATH := "res://review/boss_arena_phase_two.png"

func _initialize() -> void:
	_capture.call_deferred()

func _capture() -> void:
	root.size = Vector2i(1280, 800)
	root.content_scale_size = Vector2i(1280, 800)
	var packed := load(ARENA_PATH) as PackedScene
	if packed == null:
		push_error("Boss arena scene could not be loaded: %s" % ARENA_PATH)
		quit(1)
		return
	var arena := packed.instantiate()
	root.add_child(arena)
	for _frame in range(12):
		await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var first_result := image.save_png(OUTPUT_PATH)
	var boss := arena.get_node("Battle/Boss") as RockCocoonBoss
	boss.take_damage(110.0, &"review_capture")
	for _frame in range(4):
		await process_frame
	paused = true
	await process_frame
	await RenderingServer.frame_post_draw
	var phase_two_image := root.get_texture().get_image()
	var second_result := phase_two_image.save_png(PHASE_TWO_OUTPUT_PATH)
	paused = false
	arena.queue_free()
	await process_frame
	await create_timer(0.08, true).timeout
	print("BOSS ARENA CAPTURE: %s (%s), %s (%s)" % [OUTPUT_PATH, error_string(first_result), PHASE_TWO_OUTPUT_PATH, error_string(second_result)])
	quit(0 if first_result == OK and second_result == OK else 1)
