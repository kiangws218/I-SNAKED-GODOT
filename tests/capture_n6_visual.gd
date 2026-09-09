extends SceneTree

func _initialize() -> void:
	_capture.call_deferred()

func _capture() -> void:
	var session: GameSession = load("res://game/main.tscn").instantiate()
	root.add_child(session)
	for index in range(8): await process_frame
	var error := root.get_texture().get_image().save_png("res://.godot/n6_main_menu.png")
	if error != OK: quit(error); return
	session.start_new_game(1)
	await process_frame
	for index in range(3): session.current_world.player.try_collect_payload({"id": &"bean"})
	for index in range(12): await process_frame
	error = root.get_texture().get_image().save_png("res://.godot/n6_dialogue.png")
	session.dialogue.close()
	session.set_pause_reason(&"dialogue", false)
	await session.load_map(&"wilderness")
	session.current_world.player.play_sfx = false
	await session.story.execute_command("eatKeti")
	session.current_world.player.global_position = Vector2(58.0, 24.5) * StoryMap.TILE_SIZE
	for index in range(12): await process_frame
	if error == OK: error = root.get_texture().get_image().save_png("res://.godot/n6_inventory_exit.png")
	if error == OK: print("N6 MENU + DIALOGUE VISUAL CAPTURES SAVED")
	session.dialogue.interact_audio.stop()
	session.queue_free()
	await process_frame
	quit(error)
