extends SceneTree


func _initialize() -> void:
	_capture.call_deferred()


func _capture() -> void:
	var main: Node = load("res://game/main.tscn").instantiate()
	root.add_child(main)
	for index in range(3):
		await process_frame
	var player: SnakePlayer = main.get_node("TestArena/SnakePlayer")
	player.set_physics_process(false)
	player.place_node()
	player.try_spit()
	for index in range(12):
		for child in main.get_node("TestArena").get_children():
			if child is BeanProjectile:
				child._physics_process(1.0 / 60.0)
		await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var error := image.save_png("res://.godot/n2_test_arena.png")
	if error == OK:
		print("N2 VISUAL CAPTURE SAVED")
	quit(error)
