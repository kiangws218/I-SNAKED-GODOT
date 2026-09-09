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
	player.play_sfx = false
	var arena: Node2D = main.get_node("TestArena")
	var slime: EnemyActor = arena.get_node("Slime")
	var mushroom: EnemyActor = arena.get_node("Mushroom")
	var keti: NpcActor = arena.get_node("Keti")
	slime.set_physics_process(false)
	mushroom.set_physics_process(false)
	slime.global_position = Vector2(216, 240)
	mushroom.global_position = Vector2(624, 240)
	mushroom.warning_active = true
	mushroom.queue_redraw()
	keti.global_position = Vector2(384, 216)
	player.reset_at(Vector2(372, 336), Vector2.RIGHT)
	for index in range(12):
		await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var error := image.save_png("res://.godot/n3_test_arena.png")
	if error == OK:
		print("N3 VISUAL CAPTURE SAVED")
	quit(error)
