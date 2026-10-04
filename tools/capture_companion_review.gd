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
	paused = true
	for frame in range(12): await process_frame
	await RenderingServer.frame_post_draw
	var error := root.get_texture().get_image().save_png("res://review/keti_companion_riding.png")
	paused = false
	session.queue_free()
	await process_frame
	await create_timer(0.08, true).timeout
	print("COMPANION CAPTURE: ", error_string(error))
	quit(0 if error == OK else 1)
