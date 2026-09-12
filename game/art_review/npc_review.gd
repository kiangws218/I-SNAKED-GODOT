extends Node2D

# Isolated review motion. Production patrol and story behavior are not changed.
func _ready() -> void:
	var world := StoryMap.new()
	add_child(world)
	world.setup(&"forest", {})
	world.player.reset_at(Vector2(864, 576), Vector2.RIGHT)
	world.player.set_physics_process(false)
	world.camera.position_smoothing_enabled = false
	world.camera.reset_smoothing()
	for enemy in get_tree().get_nodes_in_group(&"enemy"):
		enemy.set_physics_process(false)
	var ids := [&"keti", &"ajie", &"lisi", &"ajian", &"buck", &"miro"]
	for index in range(ids.size()):
		var origin := world.player.global_position + Vector2(-240 + index * 80, -64)
		var npc := world.spawn_npc(ids[index], origin)
		npc.set_actor_active(true)
		npc.set_physics_process(false)
		npc._last_visual_position = origin
		var label := Label.new()
		label.text = String(ids[index])
		label.position = Vector2(-20, 12)
		label.add_theme_font_size_override("font_size", 12)
		npc.add_child(label)
		var motion := create_tween().set_loops()
		for corner in [Vector2(32, 0), Vector2(32, 32), Vector2(0, 32), Vector2.ZERO]:
			motion.tween_property(npc, "global_position", origin + corner, 1.0)
			motion.tween_interval(0.35)
	var overlay := CanvasLayer.new()
	add_child(overlay)
	var heading := Label.new()
	heading.text = "NPC ART REVIEW | all six | 4 directions + idle"
	heading.position = Vector2(16, 16)
	overlay.add_child(heading)
	if OS.get_cmdline_user_args().has("--capture-review"):
		await get_tree().create_timer(0.5).timeout
		await RenderingServer.frame_post_draw
		var capture_path := ProjectSettings.globalize_path("res://").path_join("../npc_ingame_review.png").simplify_path()
		var error := get_viewport().get_texture().get_image().save_png(capture_path)
		get_tree().quit(error)
