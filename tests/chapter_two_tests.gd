extends SceneTree

var failures: Array[String] = []
var session: GameSession
var checks := 0

func _initialize() -> void:
	_run.call_deferred()

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition: failures.append(message)

func _new_session() -> void:
	session = load("res://game/main.tscn").instantiate() as GameSession
	session.store = SaveStore.new("res://.godot/ch2-fixture-saves")
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
	session.story.cancel_pending_flow()
	session.pause_reasons.clear()
	paused = false
	session.queue_free()
	await process_frame
	session = null

func _tap(key: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = key
	event.keycode = key
	event.pressed = true
	Input.parse_input_event(event)
	await physics_frame
	await process_frame
	event = InputEventKey.new()
	event.physical_keycode = key
	event.keycode = key
	event.pressed = false
	Input.parse_input_event(event)
	await process_frame

func _choose(choice_id: String) -> void:
	var panel := session.dialogue
	for step in range(24):
		if panel.state == &"active" and panel.page_index == panel.pages.size() - 1: break
		await _tap(KEY_ENTER)
	var index := -1
	for i in range(panel.choices.size()):
		if String(panel.choices[i].id) == choice_id: index = i
	check(index >= 0, "真实对白选项存在：%s @ %s" % [choice_id, session.story.current_id])
	if index < 0: return
	for step in range(panel.choices.size() + 1):
		if panel.selected_choice_index == index: break
		await _tap(KEY_DOWN)
	await _tap(KEY_ENTER)
	for frame in range(8): await process_frame

func _run() -> void:
	_test_state_and_history()
	await _test_normal_entry()
	await _new_session()
	await _test_commands_and_saves()
	await _cleanup()
	for transfer in ["stretcher", "protect"]:
		await _new_session()
		await _test_transport_save(transfer)
		await _cleanup()
	await _new_session()
	await _test_real_mainline("deal", "stretcher", "face")
	await _cleanup()
	await _new_session()
	await _test_real_mainline("eat", "protect", "foot")
	await _cleanup()
	await _new_session()
	await _test_real_mainline("threat", "stretcher", "face")
	await _cleanup()
	await _new_session()
	await _test_real_mainline("attack", "stretcher", "foot")
	await _cleanup()
	# AudioServer tears down stopped decoder playbacks on its next mix tick.
	await create_timer(0.08, true).timeout
	if failures.is_empty():
		print("CHAPTER TWO TESTS PASSED: %d checks; keyboard mainline deal/stretcher/face, eat/key/protect/foot, threat/stretcher/face, attack/key/stretcher/foot" % checks)
		quit(0)
	else:
		for failure in failures: push_error(failure)
		quit(1)

func _test_state_and_history() -> void:
	var state := SessionState.new()
	check(not state.apply_social_event("old", 3, 3), "第一章不计声望和恐惧")
	state.actors["buck"]["met"] = true
	state.actors["miro"]["met"] = true
	state.actors["miro"]["hostile"] = true
	var ajie_before := Dictionary(state.actors["ajie"]).duplicate(true)
	check(state.prepare_chapter_two(), "活着的可蒂可迁移")
	check(state.actors["keti"].status == "unconscious" and state.actors["keti"].hp == 0, "车中可蒂确实昏迷")
	check(state.actors["buck"].location == "chapter2_slice" and state.actors["miro"].location == "forest", "两位旧人独立检查相识与敌意")
	check(state.actors["ajie"] == ajie_before, "不自动迁入三人组")
	state.current_map = &"chapter2_slice"
	check(state.apply_social_event("ch2:one", 3, 3), "第二章独立计分")
	check(not state.apply_social_event("ch2:one", 3, 3), "稳定事件 ID 防重复")
	state.remember_checkpoint()
	state.apply_social_event("ch2:two", 0, 2)
	state.restore_checkpoint()
	check(state.social.fear == 3 and not state.social.applied_events.has("ch2:two"), "检查点一并恢复计分与去重键")
	state.apply_social_event("ch2:clamp", 500, 500)
	check(state.social.reputation == 100 and state.social.fear == 100, "两个计分独立封顶")
	var old_state := SessionState.new()
	check(old_state.load_dictionary({"current_map": "forest"}).ok and not old_state.social.enabled, "旧存档补默认字段")
	var dead_state := SessionState.new()
	dead_state.actors["keti"]["status"] = "dead"
	check(not dead_state.prepare_chapter_two(), "不复活旧分支真正死亡角色")
	var carried := SessionState.new()
	carried.actors["keti"]["status"] = "swallowed"
	carried.actors["keti"]["location"] = "stomach"
	var carried_inventory := StomachInventory.new()
	carried_inventory.add_item(&"keti", {"actor_id": &"keti", "hp": 14.0})
	carried.player["inventory"] = carried_inventory.entries.duplicate(true)
	check(carried.prepare_chapter_two() and carried.actors["keti"].location == "stomach", "不复制历史胃袋可蒂")
	var legacy := SessionState.new()
	legacy.flags["banditResolved"] = true
	legacy.prepare_chapter_two()
	check(legacy.actors["buck"].location == "chapter2_slice", "旧章已解决劫匪事件可作为巴克相识证据")
	check(legacy.actors["miro"].location == "chapter2_slice", "旧章已解决劫匪事件可作为米罗相识证据")

func _test_normal_entry() -> void:
	# Start in a real previous world: capture_current must not undo relocation.
	session = load("res://game/main.tscn").instantiate() as GameSession
	root.add_child(session)
	session.menus.hide_all()
	session.state.flags["prologue_complete"] = true
	session.state.flags["forest_bridge_open"] = true
	session.state.actors["buck"]["met"] = true
	session.state.actors["miro"]["met"] = true
	await session.load_map(&"wilderness", &"", false, false)
	session.current_world.player.set_physics_process(false)
	check(await session.load_map(&"chapter2_slice"), "真实源地图捕获后可进入第二章")
	session.current_world.player.set_physics_process(false)
	check(session.state.actors["keti"].location == "chapter2_slice" and session.current_world.get_story_actor(&"keti").visible and session.current_world.get_story_actor(&"keti").is_downed, "荒野实体捕获不覆盖昏迷可蒂迁移")
	await _cleanup()
	session = load("res://game/main.tscn").instantiate() as GameSession
	root.add_child(session)
	session.menus.hide_all()
	session.state.flags["prologue_complete"] = true
	session.state.flags["forest_bridge_open"] = true
	session.state.actors["buck"]["met"] = true
	session.state.actors["miro"]["met"] = true
	session.state.player["length"] = 6
	session.state.player["rider"] = "ajian"
	session.state.actors["ajian"].merge({"status": "riding", "location": "rider", "hp": 2.0}, true)
	await session.load_map(&"forest", &"", false, false)
	var player := session.current_world.player
	player.reset_at(Vector2(2208, 732), Vector2.RIGHT)
	var event := InputEventKey.new()
	event.physical_keycode = KEY_RIGHT
	event.keycode = KEY_RIGHT
	event.pressed = true
	Input.parse_input_event(event)
	for frame in range(180):
		await physics_frame
		if session.state.current_map == &"chapter2_slice" and not session.map_transition_active: break
	event = InputEventKey.new()
	event.physical_keycode = KEY_RIGHT
	event.keycode = KEY_RIGHT
	event.pressed = false
	Input.parse_input_event(event)
	check(session.state.current_map == &"chapter2_slice", "实际方向键穿过森林新出口")
	if session.state.current_map == &"chapter2_slice":
		session.current_world.player.set_physics_process(false)
		for actor_id in [&"buck", &"miro"]:
			check(session.current_world.get_story_actor(actor_id).visible and session.state.actors[String(actor_id)].location == "chapter2_slice", "森林换图保留旧人迁移：%s" % actor_id)
		var passenger := session.current_world.get_story_actor(&"ajian")
		check(passenger != null and passenger.is_riding() and passenger.hp == 2.0, "真实换图保留玩家已有乘客")
		session.current_world.player.global_position = Vector2(1008, 420)
		check((await session.story.chapter_two.execute("dismount", &"")).ok and not passenger.is_riding() and session.state.player.rider == "", "渡口可放下旧乘客继续交互")
	await _cleanup()

func _test_commands_and_saves() -> void:
	var flow: Node = session.story.chapter_two
	var world := session.current_world
	var player := world.player
	check(world.get_story_actor(&"keti").is_downed, "实体可蒂昏迷")
	check(not (await flow.execute("lever", &"")).ok, "外锁未开不许打开内扣")
	check(not (await flow.execute("face", &"keti")).ok, "车门前不能隔墙叫醒可蒂")
	check((await flow.execute("threat", &"caravan_merchant")).ok, "商人威胁开锁")
	await flow.execute("threat", &"caravan_merchant")
	check(session.state.social.fear == 2, "重复威胁只加一次")
	await flow.execute("lever", &"")
	player.add_special_item(&"buck")
	player.add_special_item(&"miro")
	var before := session.state.to_dictionary()
	check(not (await flow.execute("protect", &"keti")).ok, "满胃保护失败")
	check(session.state.actors == before.actors and session.state.social == before.social, "满胃不提交角色/计分副作用")
	player.consume_inventory_item(&"buck")
	player.consume_inventory_item(&"miro")
	for actor_id in [&"caravan_merchant", &"ferryman", &"buck", &"miro"]:
		var npc := world.get_story_actor(actor_id)
		npc.set_physics_process(false)
		npc.hp = 3.0
		npc.hostile = true
		npc.take_damage(50, &"test_projectile")
		check(npc.is_downed and not npc.is_dead, "攻击仅击晕：%s" % actor_id)
		await flow.execute("face", actor_id)
		check(npc.hp == 1.0 and npc.hostile and not npc.is_downed, "舔脸保留敌意：%s" % actor_id)
		npc.take_damage(50, &"test_projectile")
		await flow.execute("foot", actor_id)
		check(npc.hp == 1.0 and npc.hostile and not npc.is_downed, "舔脚保留敌意：%s" % actor_id)
		await flow.execute("eat", actor_id)
		check(player.inventory.count_item(actor_id) == 1, "每位 NPC 可吞下：%s" % actor_id)
		player.inventory.selected_index = player.inventory.entries.size()
		player.direction = Vector2.RIGHT
		player.shot_cooldown_left = 0
		player._special_spit_latched = false
		var saved_speed := player.base_speed
		player.base_speed = 0
		player.set_physics_process(true)
		await _tap(KEY_J)
		player.set_physics_process(false)
		player.base_speed = saved_speed
		for frame in range(420):
			if world.get_story_actor(actor_id).visible: break
			await physics_frame
		var released := world.get_story_actor(actor_id)
		released.set_physics_process(false)
		check(player.inventory.count_item(actor_id) == 0 and released.is_downed and not released.is_dead, "真实吐出保持昏迷实体：%s" % actor_id)
		check(session.state.actors[String(actor_id)].get("wake_hostile", false), "吐出不丢旧敌意历史：%s" % actor_id)
		await flow.execute("face", actor_id)
		check(released.hostile, "吐后再次唤醒仍记得敌意：%s" % actor_id)
		await flow.execute("eat", actor_id)
		player.consume_inventory_item(actor_id)
		# End this independent fixture; reinitialize the next actor in its authored spot.
		released.set_actor_active(false)
	player.global_position = Vector2(1008, 420)
	check((await flow.execute("protect", &"keti")).ok, "昏迷可蒂保护可成功")
	var fear_before := int(session.state.social.fear)
	await flow.execute("settle", &"")
	check(session.state.social.fear == fear_before, "保护转移不增加恐惧")
	check(not (await flow.execute("duo", &"keti")).ok, "昏迷会合不能结算")
	await flow.execute("face", &"keti")
	await flow.execute("duo", &"keti")
	await flow.execute("duo", &"keti")
	check(session.state.social.reputation == 3, "任务只在清醒结伴后发一次声望")
	session.state.actors["keti"]["resentful"] = true
	check(session.save_active_slot().ok, "第二章正式存档写入")
	var expected := session.state.to_dictionary()
	check((await session.load_active_slot()).ok, "第二章正式读档")
	session.current_world.player.set_physics_process(false)
	if session.state.social != expected.social or session.state.chapter_two != expected.chapter_two:
		print("SAVE EXPECTED: ", expected.social, " / ", expected.chapter_two)
		print("SAVE LOADED: ", session.state.social, " / ", session.state.chapter_two)
	check(session.state.social == expected.social and session.state.chapter_two == expected.chapter_two, "读档保留计分与里程碑")
	check(session.current_world.get_story_actor(&"keti").hp == 1.0 and session.state.actors["keti"].resentful, "读档保留低 HP 与互动历史")
	check(session.story.current_id.begins_with("ch2_"), "读档不回落序章")
	session.store.delete_slot(1)

func _move_to(target: Vector2, key: Key, max_seconds := 6.0) -> void:
	var player := session.current_world.player
	player.set_physics_process(true)
	var event := InputEventKey.new()
	event.physical_keycode = key
	event.keycode = key
	event.pressed = true
	Input.parse_input_event(event)
	var began := Time.get_ticks_msec()
	var horizontal := key in [KEY_LEFT, KEY_RIGHT]
	while Time.get_ticks_msec() - began < max_seconds * 1000:
		await physics_frame
		if player.is_dead: break
		if session.dialogue.state != &"hidden" and session.dialogue.state != &"exiting": break
		var distance := absf(player.global_position.x - target.x) if horizontal else absf(player.global_position.y - target.y)
		if distance < 5: break
	event = InputEventKey.new()
	event.physical_keycode = key
	event.keycode = key
	event.pressed = false
	Input.parse_input_event(event)
	player.set_physics_process(false)
	await process_frame
	print("CH2 INPUT MOVE: ", player.global_position, " node=", session.story.current_id)

func _test_transport_save(transfer: String) -> void:
	var flow: Node = session.story.chapter_two
	await flow.execute("key", &"")
	await flow.execute("lever", &"")
	await flow.execute(transfer, &"keti")
	check(session.save_active_slot().ok, "转移途中存档：%s" % transfer)
	check((await session.load_active_slot()).ok, "转移途中读档：%s" % transfer)
	var world := session.current_world
	world.player.set_physics_process(false)
	if transfer == "stretcher":
		var keti := world.get_story_actor(&"keti")
		check(keti.is_riding() and keti.is_downed and keti.hp == 0.0, "担架读档不能提前唤醒可蒂")
	else:
		check(world.player.inventory.count_item(&"keti") == 1 and not world.get_story_actor(&"keti").visible, "胃袋读档不生成第二个可蒂")
	world.player.global_position = Vector2(1008, 420)
	check((await flow.execute("settle", &"")).ok and world.get_story_actor(&"keti").is_downed, "途中读档后仍可正确安置：%s" % transfer)
	check(session.state.social.fear == 0, "保护/担架途中读档不增恐惧")
	session.store.delete_slot(1)

func _test_real_mainline(approach: String, transfer: String, wake: String) -> void:
	var world := session.current_world
	await _move_to(Vector2(348, 324), KEY_RIGHT)
	check(session.story.current_id == "ch2_merchant", "方向键碰触商人触发真实对白")
	await _choose(approach)
	if approach in ["eat", "attack"]:
		if approach == "eat":
			check(world.player.inventory.count_item(&"caravan_merchant") == 1 and session.state.social.fear == 3, "实际选项吞掉商人计分")
		else:
			check(world.get_story_actor(&"caravan_merchant").is_downed and session.state.social.fear == 1, "实际选项击晕商人计分")
			await _choose("leave")
		await _move_to(Vector2(324, 228), KEY_UP)
		await _move_to(Vector2(300, 228), KEY_LEFT)
		check(session.story.current_id == "ch2_key", "商人消失仍可真实碰触备用钥匙")
		await _choose("key")
		await _move_to(Vector2(228, 228), KEY_LEFT)
		await _move_to(Vector2(228, 420), KEY_DOWN)
	else:
		await _choose("leave")
		await _move_to(Vector2(324, 420), KEY_DOWN)
	await _move_to(Vector2(396, 420), KEY_RIGHT)
	check(session.story.current_id == "ch2_lever", "方向键碰触开门杆")
	await _choose("lever")
	await _move_to(Vector2(396, 324), KEY_UP)
	await _move_to(Vector2(444, 324), KEY_RIGHT)
	if session.story.current_id == "ch2_cart_open": await _choose("leave")
	await _move_to(Vector2(552, 324), KEY_RIGHT)
	check(session.story.current_id == "ch2_keti_down", "开门后真实靠近昏迷可蒂")
	await _choose(transfer)
	await _move_to(Vector2(552, 360), KEY_DOWN)
	await _move_to(Vector2(444, 360), KEY_LEFT)
	await _move_to(Vector2(444, 492), KEY_DOWN)
	await _move_to(Vector2(900, 492), KEY_RIGHT)
	await _move_to(Vector2(900, 420), KEY_UP)
	await _move_to(Vector2(1008, 420), KEY_RIGHT)
	check(session.story.current_id == "ch2_cot", "方向键到达真实渡口休息台")
	await _choose("settle")
	await _choose(wake)
	if wake == "foot":
		for frame in range(480):
			if not session.dialogue.input_locked: break
			await create_timer(0.016, true).timeout
		check(not session.dialogue.input_locked, "可蒂舔脚 CG 正常完成并释放输入")
	await _choose("leave")
	await _move_to(Vector2(1080, 420), KEY_RIGHT)
	check(session.story.current_id == "ch2_keti_cot", "必须面对面再确认结伴")
	await _choose("duo")
	await _choose("leave")
	check(session.state.chapter_two.duo and session.state.social.reputation == 3, "真实输入完成救援与结伴闭环")
	check(int(session.state.social.fear) == {"eat": 3, "threat": 2, "attack": 1, "deal": 0}[approach], "实操路线计分正确")
