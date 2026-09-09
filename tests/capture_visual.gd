extends SceneTree


func _initialize() -> void:
	_capture.call_deferred()


func _capture() -> void:
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
		print("N4 VISUAL CAPTURE SAVED")
	quit(error)
