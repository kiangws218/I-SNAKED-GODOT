extends SceneTree

var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures.append(label)

func tap(code: Key, shift := false) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.physical_keycode = code
		event.keycode = code
		event.pressed = pressed
		event.shift_pressed = shift
		Input.parse_input_event(event)
		Input.flush_buffered_events()
		await physics_frame
		await process_frame

func press_button(button: Button) -> void:
	button.grab_focus()
	await tap(KEY_ENTER)

func bind_key(panel: SettingsPanel, row_name: String, slot: int, code: Key) -> void:
	var row := panel.binding_rows.get_node(row_name) as KeyBindingRow
	await press_button(row.primary if slot == 0 else row.secondary)
	check(panel.capture_action == row.action, row_name + " button starts capture")
	await tap(code)

func _run() -> void:
	var menu := load("res://game/ui/menu_controller.tscn").instantiate() as MenuController
	root.add_child(menu)
	var store := menu.bindings_store
	check(store.reset_all().ok, "fixture resets to project defaults")
	await process_frame
	await press_button(menu.get_node("MainMenu/Center/Panel/Margin/VBox/Settings"))
	var panel := menu.settings_panel
	check(panel.visible, "actual Enter opens Settings")
	await press_button(panel.view_controls_button)
	check(panel.controls_content.visible, "actual Enter opens bindings page")
	await bind_key(panel, "MoveUp", 0, KEY_U)
	check(panel.capture_action.is_empty() and store.keys_for(&"move_up")[0] == KEY_U, "capture saves physical key")
	check(panel.binding_rows.get_node("MoveUp/Primary").text == "U", "saved primary label refreshes")
	await bind_key(panel, "MoveUp", 1, KEY_O)
	check(store.keys_for(&"move_up") == [KEY_U, KEY_O], "secondary captured separately")
	await bind_key(panel, "MoveDown", 0, KEY_U)
	check(not panel.capture_action.is_empty() and panel.binding_hint.text.contains("冲突"), "collision keeps capture open with reason")
	await tap(KEY_ESCAPE)
	check(panel.capture_action.is_empty() and panel.controls_content.visible, "Esc cancels capture without leaving bindings")
	await bind_key(panel, "Spit", 0, KEY_F5)
	check(not panel.capture_action.is_empty() and panel.binding_hint.text.contains("F1"), "save function key rejected during capture")
	await tap(KEY_ESCAPE)
	await press_button(panel.binding_rows.get_node("Spit/Primary"))
	await tap(KEY_I, true)
	check(not panel.capture_action.is_empty() and panel.binding_hint.text.contains("组合键"), "modified key rejected")
	await tap(KEY_ESCAPE)
	await bind_key(panel, "MoveUp", 0, KEY_BACKSPACE)
	check(not panel.capture_action.is_empty() and store.keys_for(&"move_up")[0] == KEY_U, "cannot clear primary")
	await tap(KEY_ESCAPE)
	await bind_key(panel, "MoveUp", 1, KEY_BACKSPACE)
	check(store.keys_for(&"move_up") == [KEY_U], "Backspace clears spare")
	await press_button(panel.binding_rows.get_node("MoveUp/Reset"))
	check(store.keys_for(&"move_up") == store.defaults[&"move_up"], "row reset restores original project defaults")
	await bind_key(panel, "Passenger", 0, KEY_Y)
	await bind_key(panel, "Spit", 0, KEY_I)
	await bind_key(panel, "Pause", 0, KEY_O)
	await bind_key(panel, "Interact", 0, KEY_L)
	await bind_key(panel, "MoveUp", 0, KEY_U)
	check(panel.binding_rows.get_node("Pause/Secondary").disabled, "Esc spare fixed")
	var reloaded := InputBindingsStore.new()
	check(reloaded.load_settings().ok and reloaded.keys_for(&"pause") == [KEY_O, KEY_ESCAPE], "saved pause and fixed Esc reload")
	check(reloaded.keys_for(&"companion_talk") == [KEY_Y], "saved passenger key reloads")
	var tutorial := DialogueRunner.new().begin("fixture", {"pages": ["{fire} / {interact} / {node}"]}, {}, Callable())
	check(tutorial.text == "I / 空格 / Enter / F", "tutorial tokens use live gameplay keys and fixed dialogue confirm")
	await tap(KEY_ESCAPE)
	check(panel.visible and panel.audio_content.visible, "Esc leaves bindings for audio")
	await tap(KEY_ESCAPE)
	check(not panel.visible and menu.main_menu.visible, "second Esc returns to main menu")
	menu.queue_free()
	await process_frame

	# F6's independent arena must load controls without a MenuController instance.
	var arena := load("res://game/boss/boss_arena.tscn").instantiate() as BossArena
	root.add_child(arena)
	current_scene = arena
	arena.boss.set_physics_process(false)
	await process_frame
	check(arena.get_node("UI/Hud/Controls").text.contains("I / 空格"), "independent Boss HUD reads saved spit key")
	await tap(KEY_O)
	check(arena.battle_paused and paused, "new pause key pauses Boss")
	await tap(KEY_ESCAPE)
	check(not arena.battle_paused and not paused, "fixed Esc resumes Boss")
	await tap(KEY_P)
	check(not arena.battle_paused, "old pause key no longer active")
	arena.player.reset_at(Vector2(660, 588), Vector2.RIGHT)
	await tap(KEY_U)
	check(arena.player.direction == Vector2.UP or arena.player.direction_queue.has(Vector2.UP), "remapped movement controls snake")
	var shots := [0]
	arena.player.bean_spit.connect(func(): shots[0] += 1)
	await tap(KEY_I)
	check(shots[0] == 1, "remapped spit produces real projectile")
	await tap(KEY_J)
	check(shots[0] == 1, "old primary spit no longer fires")
	arena.queue_free()
	await process_frame
	current_scene = null

	var session := load("res://game/main.tscn").instantiate() as GameSession
	root.add_child(session)
	session.menus.hide_all()
	session.state.actors["buck"]["met"] = true
	await session.load_map(&"chapter2_slice", &"", false, false)
	session.dialogue.close()
	session.story.cancel_pending_flow()
	session.pause_reasons.clear()
	paused = false
	for enemy in get_nodes_in_group(&"enemy"): enemy.set_enemy_active(false)
	var player := session.current_world.player
	player.set_physics_process(false)
	var buck := session.current_world.get_story_actor(&"buck")
	buck.set_physics_process(false)
	buck.restore_persistent_state({"hp": 10.0, "active": true, "is_dead": false, "is_downed": false, "hostile": false})
	check(buck.attach_to_carrier(player, Vector2.ZERO), "fixture boards non-Keti rider")
	session.state.player["rider"] = "buck"
	player.set_physics_process(true)
	session._refresh_companion_hud()
	check(session.hud.companion_key.text.contains("Y"), "passenger HUD updates to remapped key")
	await tap(KEY_T)
	check(not session.pause_reasons.has(&"dialogue"), "old T no longer opens rider talk")
	await tap(KEY_Y)
	check(session.story.current_id == "ch2_passenger_talk" and paused, "saved new key opens actual rider fallback")
	for frame in range(90):
		if session.dialogue.state != &"entering": break
		await process_frame
	await tap(KEY_L)
	check(paused and session.dialogue.state == &"active", "remapped world interaction does not confirm dialogue")
	await tap(KEY_ENTER)
	check(not paused and buck.is_riding(), "fixed Enter closes fallback despite remapped interaction")
	await tap(KEY_O)
	check(session.pause_reasons.has(&"menu"), "saved pause key opens story pause menu")
	await press_button(session.menus.get_node("PauseMenu/Center/Panel/Margin/VBox/Settings"))
	var game_panel := session.menus.settings_panel
	await press_button(game_panel.view_controls_button)
	await press_button(game_panel.binding_rows.get_node("Passenger/Primary"))
	await tap(KEY_F5)
	check(session.store.load_slot(1).get("empty", false) and not game_panel.capture_action.is_empty(), "capture consumes F5 without saving a game slot")
	await tap(KEY_ESCAPE)
	check(game_panel.controls_content.visible and session.pause_reasons.has(&"menu"), "capture cancel does not resume paused game")
	await tap(KEY_ESCAPE)
	await tap(KEY_ESCAPE)
	check(not game_panel.visible and session.pause_reasons.has(&"menu"), "leaving settings returns to paused game menu")
	await tap(KEY_ESCAPE)
	check(not session.pause_reasons.has(&"menu"), "fixed Esc resumes story")
	check(session.menus.bindings_store.reset_all().ok, "all defaults restoration succeeds")
	session.story.cancel_pending_flow()
	session.dialogue.close()
	session.pause_reasons.clear()
	paused = false
	session.queue_free()
	await process_frame
	await create_timer(0.08, true).timeout
	if failures.is_empty():
		print("INPUT REBINDING TESTS PASSED: %d checks" % checks)
		quit(0)
	else:
		for failure in failures: print("FAIL: ", failure)
		quit(1)
