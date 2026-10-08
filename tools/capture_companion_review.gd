extends SceneTree

func _initialize() -> void:
	_capture.call_deferred()

func _capture() -> void:
	var session := load("res://game/main.tscn").instantiate() as GameSession
	root.add_child(session)
	session.menus.hide_all()
	session.hud.visible = true
	session.state.player["length"] = 14
	await session.load_map(&"chapter2_slice", &"", false, false)
	session.dialogue.close()
	session.pause_reasons.clear()
	paused = false
	session.state.chapter_two.merge({"intro_seen": true, "outer_lock": true, "inner_latch": true, "settled": true}, true)
	session.story.chapter_two._sync_cart()
	var player := session.current_world.player
	player.reset_at(Vector2(1008, 420), Vector2.RIGHT)
	player.set_physics_process(false)
	var keti := session.current_world.get_story_actor(&"keti")
	keti.global_position = Vector2(1080, 420)
	keti.restore_persistent_state({"hp": 14.0, "active": true, "damageable": true, "is_dead": false, "is_downed": false})
	var result: Dictionary = await session.story.chapter_two.execute("duo", &"keti")
	if not result.ok or not keti.is_riding():
		push_error("Companion capture could not board Keti")
		quit(1)
		return
	session.current_world.camera.restore()
	session.story.chapter_two._refresh_goal()
	session._refresh_hud()
	session._refresh_companion_hud()
	paused = true
	for frame in range(12): await process_frame
	await RenderingServer.frame_post_draw
	var error := root.get_texture().get_image().save_png("res://review/companion_talk_hint.png")
	paused = false
	var key := InputEventKey.new()
	key.physical_keycode = KEY_T
	key.pressed = true
	Input.parse_input_event(key)
	Input.flush_buffered_events()
	key = InputEventKey.new()
	key.physical_keycode = KEY_T
	key.pressed = false
	Input.parse_input_event(key)
	Input.flush_buffered_events()
	await create_timer(0.3, true).timeout
	for pressed in [true, false]:
		key = InputEventKey.new()
		key.physical_keycode = KEY_ENTER
		key.pressed = pressed
		Input.parse_input_event(key)
		Input.flush_buffered_events()
		await process_frame
	for frame in range(8): await process_frame
	await RenderingServer.frame_post_draw
	var menu_error := root.get_texture().get_image().save_png("res://review/companion_talk_menu.png")
	session.dialogue.close()
	session.story._finish_world_interaction()
	session.set_pause_reason(&"dialogue", false)
	session.toggle_pause()
	session.menus._open_settings(&"pause")
	session.menus.settings_panel.show_controls()
	for frame in range(15): await process_frame
	await RenderingServer.frame_post_draw
	var controls_error := root.get_texture().get_image().save_png("res://review/companion_talk_controls.png")
	paused = false
	session.queue_free()
	await process_frame
	await create_timer(0.08, true).timeout
	print("COMPANION CAPTURE: ", [error_string(error), error_string(menu_error), error_string(controls_error)])
	quit(0 if error == OK and menu_error == OK and controls_error == OK else 1)
