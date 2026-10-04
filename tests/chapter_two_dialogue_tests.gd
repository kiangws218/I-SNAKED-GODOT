extends SceneTree
## Verify what the player hears after an outcome, including physical re-contact.

var session: GameSession
var failures: Array[String] = []
var checks := 0

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)

func _tap(key: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.physical_keycode = key
		event.keycode = key
		event.pressed = pressed
		Input.parse_input_event(event)
		await physics_frame
		await process_frame

func _choose(id: String) -> void:
	var panel := session.dialogue
	for step in range(24):
		if panel.state == &"active" and panel.page_index == panel.pages.size() - 1: break
		await _tap(KEY_ENTER)
	var index := -1
	for i in range(panel.choices.size()):
		if String(panel.choices[i].id) == id: index = i
	check(index >= 0, "选项存在：%s @ %s" % [id, session.story.current_id])
	if index < 0: return
	for step in range(panel.choices.size() + 1):
		if panel.selected_choice_index == index: break
		await _tap(KEY_DOWN)
	await _tap(KEY_ENTER)
	for frame in range(8): await process_frame
	for frame in range(400):
		if not panel.input_locked: break
		await create_timer(0.016, true).timeout
	check(not panel.input_locked, "结果动画完成：" + id)

func _new_session() -> void:
	session = load("res://game/main.tscn").instantiate() as GameSession
	session.store = SaveStore.new("res://.godot/ch2-dialogue-fixtures")
	root.add_child(session)
	session.menus.hide_all()
	session.hud.visible = true
	session.state.actors["buck"]["met"] = true
	session.state.actors["miro"]["met"] = true
	session.state.player["length"] = 14
	await session.load_map(&"chapter2_slice", &"", false, false)
	session.current_world.player.set_physics_process(false)
	await _choose("continue")

func _cleanup() -> void:
	session.store.delete_slot(1)
	session.story.cancel_pending_flow()
	session.pause_reasons.clear()
	paused = false
	session.queue_free()
	await process_frame
	session = null

func _contact(actor_id: StringName) -> void:
	var world := session.current_world
	var npc := world.get_story_actor(actor_id)
	if npc.is_riding():
		npc.finish_interaction()
		await _tap(KEY_ENTER)
		check(session.pause_reasons.has(&"dialogue"), "确认键与骑乘角色交互：%s" % actor_id)
		return
	world.player.reset_at(npc.global_position - Vector2(48, 0), Vector2.RIGHT)
	# Set up a local approach, rather than a swept contact across a fixture teleport.
	for node in get_nodes_in_group(&"npc"):
		if world.is_ancestor_of(node):
			node._previous_head_position = world.player.global_position
			node.set_physics_process(node == npc)
	npc.rearm_interaction()
	world.player.set_physics_process(true)
	await _tap(KEY_RIGHT)
	for frame in range(90):
		await physics_frame
		if session.pause_reasons.has(&"dialogue"): break
	world.player.set_physics_process(false)
	check(session.pause_reasons.has(&"dialogue"), "方向键再次接触触发对白：%s" % actor_id)

func _has_choice(id: String) -> bool:
	for choice in session.story.runner.visible_choices():
		if String(choice.id) == id: return true
	return false

func _expect(id: String, forbidden: Array[String] = []) -> void:
	check(session.story.current_id == "ch2_" + id, "结果对白：%s，实际 %s" % [id, session.story.current_id])
	for choice in forbidden:
		check(not _has_choice(choice), "完成后不再显示旧选项：" + choice)
	for choice in ["eat", "attack"]:
		if id.begins_with("merchant") or id.begins_with("keti_duo"):
			check(_has_choice(choice), "保留统一人物操作：" + choice)

func _run() -> void:
	for approach in ["deal", "threat", "key"]:
		await _new_session()
		await _test_merchant(approach)
		await _cleanup()
	await _new_session()
	await _test_keti()
	await _cleanup()
	for actor_id in [&"ferryman", &"buck", &"miro"]:
		await _new_session()
		await _test_npc(actor_id)
		await _cleanup()
	await _new_session()
	await _test_item_followups()
	await _cleanup()
	await create_timer(0.08, true).timeout
	if failures.is_empty():
		print("CHAPTER TWO DIALOGUE TESTS PASSED: %d checks" % checks)
		quit(0)
	else:
		for failure in failures: push_error(failure)
		quit(1)

func _test_merchant(approach: String) -> void:
	var flow: Node = session.story.chapter_two
	if approach == "key":
		await flow.execute("key", &"")
	else:
		await _contact(&"caravan_merchant")
		await _choose("leave")
		await _contact(&"caravan_merchant")
		_expect("merchant_repeat")
		await _choose(approach)
		await _choose("leave")
	await _contact(&"caravan_merchant")
	_expect("merchant_threatened" if approach == "threat" else "merchant_open", ["deal"])
	await _choose("leave")
	await flow.execute("lever", &"")
	await _contact(&"caravan_merchant")
	_expect("merchant_threatened" if approach == "threat" else "merchant_cart_open", ["deal"])
	await _choose("leave")
	check(session.save_active_slot().ok and (await session.load_active_slot()).ok, "商人结果存读档")
	session.current_world.player.set_physics_process(false)
	await _contact(&"caravan_merchant")
	_expect("merchant_threatened" if approach == "threat" else "merchant_cart_open", ["deal"])
	await _choose("leave")
	await flow.execute("attack", &"caravan_merchant")
	await flow.execute("face", &"caravan_merchant")
	await _contact(&"caravan_merchant")
	_expect("merchant_hurt", ["deal"])
	await _choose("leave")
	check(session.state.social.fear == (3 if approach == "threat" else 1), "重接触不增加分数")

func _test_keti() -> void:
	var flow: Node = session.story.chapter_two
	await flow.execute("key", &"")
	await flow.execute("lever", &"")
	await flow.execute("stretcher", &"keti")
	session.current_world.player.global_position = Vector2(1008, 420)
	await flow.execute("settle", &"")
	await flow.execute("face", &"keti")
	await _contact(&"keti")
	_expect("keti_cot")
	await _choose("leave")
	await _contact(&"keti")
	_expect("keti_cot_repeat")
	await _choose("duo")
	await _choose("leave")
	await _contact(&"keti")
	_expect("keti_duo", ["duo", "stretcher"])
	await _choose("leave")
	check(session.save_active_slot().ok and (await session.load_active_slot()).ok, "结伴结果存读档")
	session.current_world.player.set_physics_process(false)
	await _contact(&"keti")
	_expect("keti_duo", ["duo"])
	await _choose("leave")
	check((await flow.execute("dismount", &"keti")).ok, "结伴后先下蛇再测试击晕")
	await flow.execute("attack", &"keti")
	var wake: Dictionary = await flow.execute("face", &"keti")
	check(wake.get("next", "") == "keti_rewake_reply", "再次叫醒不重演首次重逢")
	await _contact(&"keti")
	_expect("keti_duo_hurt", ["duo"])
	await _choose("leave")
	check(session.state.chapter_two.duo and session.state.social.reputation == 3, "重复互动保留结伴且不重复奖励")
	var repeat_duo: Dictionary = await flow.execute("duo", &"keti")
	check(repeat_duo.get("next", "") != "ending", "旧结伴请求不能重播结局")
	await _contact(&"caravan_merchant")
	_expect("merchant_rescued", ["deal"])
	await _choose("leave")

func _test_npc(actor_id: StringName) -> void:
	var flow: Node = session.story.chapter_two
	await _contact(actor_id)
	_expect(String(actor_id))
	await _choose("leave")
	await _contact(actor_id)
	_expect(String(actor_id) + "_repeat")
	await _choose("leave")
	check(session.save_active_slot().ok and (await session.load_active_slot()).ok, "首次对白完成记录存读档")
	session.current_world.player.set_physics_process(false)
	await _contact(actor_id)
	_expect(String(actor_id) + "_repeat")
	await _choose("threat")
	await _choose("leave")
	await _contact(actor_id)
	_expect("npc_threatened")
	await _choose("leave")
	var repeat_threat: Dictionary = await flow.execute("threat", actor_id)
	check(repeat_threat.get("next", "") == "npc_threat_again", "重复威胁承接已有威胁")
	await flow.execute("attack", actor_id)
	await flow.execute("face", actor_id)
	await _contact(actor_id)
	_expect("npc_hurt")
	await _choose("leave")
	check(session.save_active_slot().ok and (await session.load_active_slot()).ok, "普通人物结果存读档")
	session.current_world.player.set_physics_process(false)
	await _contact(actor_id)
	_expect("npc_hurt")
	await _choose("leave")
	check(session.state.social.fear == 3, "受伤/威胁对白不重复计分")

func _test_item_followups() -> void:
	var flow: Node = session.story.chapter_two
	await flow.execute("key", &"")
	flow.interact_item(&"ch2_cart")
	_expect("cart_unlocked")
	await _choose("leave")
	await flow.execute("lever", &"")
	flow.interact_item(&"ch2_lever")
	_expect("lever_open", ["lever"])
	await _choose("leave")
	await flow.execute("stretcher", &"keti")
	flow.interact_item(&"ch2_cart")
	_expect("cart_empty")
	await _choose("leave")
	await _contact(&"caravan_merchant")
	_expect("merchant_rescued", ["deal"])
	await _choose("leave")
