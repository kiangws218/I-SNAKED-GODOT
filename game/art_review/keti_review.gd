extends Node2D

# Isolated art review: square motion is not production NPC patrol behavior.
func _ready() -> void:
	var world := StoryMap.new()
	add_child(world)
	world.setup(&"wilderness", {})
	var npc := world.get_story_actor(&"keti")
	var origin := npc.global_position
	world.player.reset_at(origin - Vector2(112, 0), Vector2.RIGHT)
	world.player.set_physics_process(false)
	world.camera.position_smoothing_enabled = false
	world.camera.reset_smoothing()
	var motion := create_tween().set_loops()
	for corner in [Vector2(72, 0), Vector2(72, 72), Vector2(0, 72), Vector2.ZERO]:
		motion.tween_property(npc, "global_position", origin + corner, 1.0)
		motion.tween_interval(0.35)
	var overlay := CanvasLayer.new()
	add_child(overlay)
	var label := Label.new()
	label.text = "KETI ART REVIEW  |  4 directions + idle  |  32x40 frames"
	label.position = Vector2(16, 16)
	overlay.add_child(label)
	if OS.get_cmdline_user_args().has("--capture-review"):
		await get_tree().create_timer(0.5).timeout
		await RenderingServer.frame_post_draw
		var image := get_viewport().get_texture().get_image()
		var capture_path := ProjectSettings.globalize_path("res://").path_join("../keti_ingame_review.png").simplify_path()
		var error := image.save_png(capture_path)
		print("KETI REVIEW CAPTURE: ", error)
		get_tree().quit(error)
