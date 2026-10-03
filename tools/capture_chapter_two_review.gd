extends SceneTree
## Run with a renderer (not --headless) to capture native map and dialogue.

func _initialize() -> void:
	_capture.call_deferred()

func _capture() -> void:
	root.size = Vector2i(768, 480)
	root.content_scale_size = Vector2i(768, 480)
	var state := SessionState.new()
	state.actors["buck"]["met"] = true
	state.actors["miro"]["met"] = true
	state.prepare_chapter_two()
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1344, 720)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var map := StoryMap.new()
	viewport.add_child(map)
	map.setup(&"chapter2_slice", state.flags, &"", state.items, state.actors)
	map.camera.enabled = false
	map.player.set_physics_process(false)
	for node in get_nodes_in_group(&"npc"): node.set_physics_process(false)
	for frame in range(8): await process_frame
	await RenderingServer.frame_post_draw
	var first := viewport.get_texture().get_image().save_png("res://.godot/ch2-review-overview.png")
	viewport.queue_free()
	await process_frame
	var session := load("res://game/chapter2_preview.tscn").instantiate() as GameSession
	root.add_child(session)
	await create_timer(1.2, true).timeout
	await RenderingServer.frame_post_draw
	var second := root.get_texture().get_image().save_png("res://.godot/ch2-review-intro.png")
	paused = false
	session.queue_free()
	await process_frame
	print("CH2 CAPTURE: ", first, " / ", second)
	quit(0 if first == OK and second == OK else 1)
