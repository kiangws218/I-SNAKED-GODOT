extends SceneTree


func _initialize() -> void:
	_capture.call_deferred()


func _capture() -> void:
	var main: Node = load("res://game/main.tscn").instantiate()
	root.add_child(main)
	for index in range(8):
		await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var error := image.save_png("res://.godot/n1_test_arena.png")
	if error == OK:
		print("N1 VISUAL CAPTURE SAVED")
	quit(error)
