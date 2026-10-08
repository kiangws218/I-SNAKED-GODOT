extends SceneTree

func _initialize() -> void:
	_capture.call_deferred()

func _capture() -> void:
	var menu := load("res://game/ui/menu_controller.tscn").instantiate() as MenuController
	root.add_child(menu)
	menu._open_settings(&"main")
	var panel := menu.settings_panel
	panel.configure_bindings(InputBindingsStore.new("res://.godot/screenshot-controls.cfg"))
	panel.show_controls()
	for frame in range(15): await process_frame
	await RenderingServer.frame_post_draw
	var first := root.get_texture().get_image().save_png("res://review/input_settings.png")
	panel.get_node("Center/Panel/Margin/VBox/ControlsContent/Scroll").scroll_vertical = 10000
	for frame in range(8): await process_frame
	await RenderingServer.frame_post_draw
	var third := root.get_texture().get_image().save_png("res://review/input_settings_actions.png")
	panel.get_node("Center/Panel/Margin/VBox/ControlsContent/Scroll").scroll_vertical = 0
	panel.begin_capture(&"move_up", 0)
	for frame in range(8): await process_frame
	await RenderingServer.frame_post_draw
	var second := root.get_texture().get_image().save_png("res://review/input_settings_capture.png")
	panel.cancel_capture()
	menu.queue_free()
	await process_frame
	InputBindingsStore.new().apply()
	var session := load("res://game/main.tscn").instantiate() as GameSession
	root.add_child(session)
	session.menus.hide_all()
	session.hud.visible = true
	session.state.actors["buck"]["met"] = true
	session.state.player["length"] = 14
	await session.load_map(&"chapter2_slice", &"", false, false)
	session.story.cancel_pending_flow()
	session.dialogue.close()
	session.pause_reasons.clear()
	paused = false
	for enemy in get_nodes_in_group(&"enemy"): enemy.set_enemy_active(false)
	for npc in get_nodes_in_group(&"npc"): npc.set_physics_process(false)
	var player := session.current_world.player
	player.reset_at(Vector2(840, 650), Vector2.RIGHT)
	player.set_physics_process(false)
	var buck := session.current_world.get_story_actor(&"buck")
	buck.restore_persistent_state({"hp": 8.0, "active": true, "is_dead": false, "is_downed": false, "hostile": false})
	if not buck.attach_to_carrier(player, Vector2.ZERO):
		push_error("Passenger screenshot fixture could not board")
		quit(1)
		return
	session.state.player["rider"] = "buck"
	session.current_world.camera.restore()
	session._refresh_companion_hud()
	for frame in range(15): await process_frame
	await RenderingServer.frame_post_draw
	var fourth := root.get_texture().get_image().save_png("res://review/passenger_talk_hint.png")
	session._talk_to_companion()
	await create_timer(0.5, true).timeout
	await RenderingServer.frame_post_draw
	var fifth := root.get_texture().get_image().save_png("res://review/passenger_talk_silent.png")
	session.story.cancel_pending_flow()
	session.dialogue.close()
	session.pause_reasons.clear()
	paused = false
	session.queue_free()
	await process_frame
	await create_timer(0.08, true).timeout
	print("INPUT SETTINGS CAPTURE: ", [error_string(first), error_string(second), error_string(third), error_string(fourth), error_string(fifth)])
	quit(0 if first == OK and second == OK and third == OK and fourth == OK and fifth == OK else 1)
