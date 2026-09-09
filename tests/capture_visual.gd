extends SceneTree


func _initialize() -> void:
	_capture.call_deferred()


func _capture() -> void:
	var tutorial := StoryMap.new()
	root.add_child(tutorial)
	tutorial.setup(&"prologue_tutorial", {})
	tutorial.player.set_physics_process(false)
	tutorial.player.play_sfx = false
	tutorial.player.reset_at(Vector2(46.5, 18.5) * StoryMap.TILE_SIZE, Vector2.RIGHT)
	for index in range(12):
		await process_frame
	var tutorial_image := root.get_texture().get_image()
	var tutorial_error := tutorial_image.save_png("res://.godot/n4_tutorial_gate.png")
	tutorial.queue_free()
	await process_frame
	if tutorial_error != OK:
		quit(tutorial_error)
		return

	var arena := StoryMap.new()
	root.add_child(arena)
	arena.setup(&"forest", {})
	var player: SnakePlayer = arena.player
	player.set_physics_process(false)
	player.play_sfx = false
	player.reset_at(Vector2(86.5, 30.5) * StoryMap.TILE_SIZE, Vector2.RIGHT)
	player.grant_node_charges(1)
	for index in range(12):
		await process_frame
	var image := root.get_texture().get_image()
	var error := image.save_png("res://.godot/n4_forest_bridge.png")
	if error == OK:
		print("N4 TUTORIAL + FOREST VISUAL CAPTURES SAVED")
	quit(error)
