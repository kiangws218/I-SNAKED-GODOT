extends SceneTree

var failures: Array[String] = []
var checks := 0
var session: GameSession

func _initialize() -> void:
	_run.call_deferred()

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition: failures.append("CHECK_%d: %s" % [checks, message])

func _tap_key(key: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.physical_keycode = key
		event.keycode = key
		event.pressed = pressed
		Input.parse_input_event(event)
		Input.flush_buffered_events()
		await physics_frame
		await process_frame

func _clear_combat_threats() -> void:
	for enemy in get_nodes_in_group(&"enemy"):
		if session.current_world.is_ancestor_of(enemy): enemy.set_enemy_active(false)
	session.current_world.player.danger_kind = ""
	session.current_world.player.invulnerability_left = 0.0

func _advance_to_choices() -> void:
	await create_timer(0.5, true).timeout
	if session.dialogue.state == &"entering": await _tap_key(KEY_ENTER)
	for step in range(60):
		if session.dialogue.state != &"active" or session.dialogue.page_index >= session.dialogue.pages.size() - 1: return
		await _tap_key(KEY_ENTER)

func _start() -> void:
	session = (load("res://game/main.tscn") as PackedScene).instantiate() as GameSession
	session.store = SaveStore.new("res://.godot/passenger-talk-fixture-saves")
	root.add_child(session)
	session.menus.hide_all()
	session.hud.visible = true
	session.state.player["length"] = 14
	session.state.chapter_two.merge({"intro_seen": true, "inner_latch": true, "settled": true, "duo": false, "stretcher": "", "dialogues_seen": {}}, true)
	await session.load_map(&"chapter2_slice", &"", false, false)
	session.state.chapter_two["intro_seen"] = true
	session.current_world.player.set_physics_process(false)
	session.dialogue.close()
	session.pause_reasons.clear()
	paused = false
	_clear_combat_threats()
	for npc in get_nodes_in_group(&"npc"):
		if session.current_world.is_ancestor_of(npc): npc.set_physics_process(false)
	session.current_world.player.danger_kind = ""
	session.current_world.player.invulnerability_left = 0.0

func _assign_rider(actor_id: StringName, downed := false) -> NpcActor:
	var previous := session._riding_companion()
	if is_instance_valid(previous):
		previous.detach_from_carrier(session.current_world.player.global_position + Vector2(300, 300))
		previous.set_physics_process(false)
		await physics_frame
	session.state.player["rider"] = ""
	var rider := session.current_world.get_story_actor(actor_id)
	if not is_instance_valid(rider):
		check(false, "测试地图提供乘客 " + String(actor_id))
		return null
	rider.restore_persistent_state({"hp": 0.0 if downed else maxf(1.0, rider.max_hp), "max_hp": rider.max_hp, "active": true, "damageable": true, "is_dead": false, "is_downed": downed, "hostile": false, "defeat_mode": "downed"})
	rider.global_position = session.current_world.player.global_position + Vector2(100, 0)
	rider.set_physics_process(false)
	var attached := rider.attach_to_carrier(session.current_world.player, Vector2.ZERO)
	check(attached, "能装载真实乘客 " + String(actor_id))
	if attached: session.state.player["rider"] = String(actor_id)
	return rider

func _check_generic_talk(actor_id: StringName, downed := false) -> void:
	var rider := await _assign_rider(actor_id, downed)
	if not is_instance_valid(rider): return
	var chapter_before := session.state.chapter_two.duplicate(true)
	var social_before := session.state.social.duplicate(true)
	var story_before := session.state.story.duplicate(true)
	var node_before := session.story.current_id
	await _tap_key(KEY_T)
	check(paused and session.story.current_id == "ch2_passenger_talk", String(actor_id) + " 的 T 入口打开兜底对白")
	check(session.dialogue.pages.size() == 1 and String(session.dialogue.pages[0].get("text", "")) == "...", "乘客对白正文是唯一 ASCII 省略号")
	check(not rider.interaction_open and session.state.player.rider == String(actor_id), "交谈没有触发地面交互或改变乘客")
	check(session.hud.companion_name.text != "可蒂" or actor_id == &"keti", "HUD 不把其他乘客称作可蒂")
	await _advance_to_choices()
	await _tap_key(KEY_ENTER)
	check(not paused and not session.pause_reasons.has(&"dialogue") and rider.is_riding(), "乘客省略号可用 Enter 关闭且不下蛇 state=%s pause=%s id=%s pages=%s choices=%s" % [session.dialogue.state, session.pause_reasons, session.story.current_id, session.dialogue.pages, session.dialogue.choices])
	check(session.story.current_id == node_before and session.state.story == story_before, "乘客交谈关闭后恢复原剧情节点，不改写故事事实")
	session.current_world.finish_actor_interaction()
	await process_frame
	check(session.state.chapter_two == chapter_before and session.state.social == social_before, "乘客兜底对话无章节进度或奖励副作用")

func _run() -> void:
	await _start()
	await _check_generic_talk(&"buck")
	await _check_generic_talk(&"miro")
	await _check_generic_talk(&"caravan_merchant")
	await _check_generic_talk(&"buck", true)
	var buck := await _assign_rider(&"buck")
	var miro := session.current_world.get_story_actor(&"miro")
	check(is_instance_valid(buck) and is_instance_valid(miro) and not miro.attach_to_carrier(session.current_world.player, Vector2.ZERO), "不能同时挂载多个骑乘乘客")
	if is_instance_valid(buck) and is_instance_valid(miro):
		session.state.player["rider"] = "miro"
		session.story.current_id = "chapter2_explore"
		await _tap_key(KEY_T)
		check(not paused and session.story.current_id != "ch2_passenger_talk", "存档 rider 与实际 child 不匹配时 T 不隔空交谈")
		session.state.player["rider"] = "buck"
		check(session.save_active_slot().ok, "任意乘客骑乘状态可保存")
		var loaded: Dictionary = await session.load_active_slot()
		buck = session.current_world.get_story_actor(&"buck")
		_clear_combat_threats()
		check(loaded.ok and session.state.player.rider == "buck" and buck.is_riding(), "读档恢复真实乘客节点关系")
		await _tap_key(KEY_T)
		check(paused and session.story.current_id == "ch2_passenger_talk", "读档后的骑乘乘客仍能 T 交谈: node=%s pause=%s blocked=%s rider=%s" % [session.story.current_id, session.pause_reasons, session._companion_combat_blocked(), session._riding_companion()])
		await _advance_to_choices()
		await _tap_key(KEY_ENTER)
		check(not paused, "读档后的乘客对白可退出")
		buck.detach_from_carrier(session.current_world.player.global_position + Vector2(300, 300))
		buck.set_physics_process(false)
		session.state.player["rider"] = ""
		await _tap_key(KEY_T)
		check(not paused, "乘客下蛇后 T 不隔空交谈")
	await _tap_key(KEY_P)
	await _tap_key(KEY_T)
	check(not session.pause_reasons.has(&"dialogue"), "暂停菜单期间 T 不打开乘客对白")
	await _tap_key(KEY_ESCAPE)
	check(not session.pause_reasons.has(&"menu"), "物理 Escape 可关闭暂停菜单")
	var buck_for_combat := await _assign_rider(&"buck")
	session.story.combat_kind = &"fixture"
	session.story.enemies_left = 1
	await _tap_key(KEY_T)
	check(not session.pause_reasons.has(&"dialogue"), "剧情战斗期间 T 不打开乘客对白")
	session.story.combat_kind = &""
	session.story.enemies_left = 0
	if is_instance_valid(buck_for_combat): buck_for_combat.detach_from_carrier(session.current_world.player.global_position + Vector2(300, 300))
	session.state.player["rider"] = ""
	await _test_ajian_safe_route()
	session.story.cancel_pending_flow()
	session.dialogue.close()
	session.pause_reasons.clear()
	paused = false
	session.store.delete_slot(1)
	session.queue_free()
	await process_frame
	await create_timer(0.08, true).timeout
	if failures.is_empty():
		print("PASSENGER TALK TESTS PASSED: %d checks" % checks)
		quit(0)
	else:
		for failure in failures: print("FAIL: ", failure)
		quit(1)

func _test_ajian_safe_route() -> void:
	check(await session.load_map(&"forest", &"", false, false), "森林地图可用于阿见骑乘对白验证")
	_clear_combat_threats()
	var world := session.current_world
	var player := world.player
	var ajian := world.spawn_npc(&"ajian", player.global_position + Vector2(100, 0))
	ajian.restore_persistent_state({"hp": 8.0, "max_hp": 8.0, "active": true, "damageable": false, "is_dead": false, "is_downed": false, "hostile": false, "defeat_mode": "downed"})
	ajian.set_physics_process(false)
	check(ajian.attach_to_carrier(player, Vector2.ZERO), "测试中阿见以真实 NPC 节点上蛇")
	session.state.player["rider"] = "ajian"
	session.state.flags["campSettlementSeen"] = true
	var reputation_before := int(session.state.social.get("reputation", 0))
	var reward_before := bool(session.state.flags.get("campRewardClaimed", false))
	await _tap_key(KEY_T)
	check(paused and session.story.current_id == "camp_ajian_resting", "阿见在营地结算后使用原有骑乘适用休息对白: node=%s pause=%s blocked=%s rider=%s" % [session.story.current_id, session.pause_reasons, session._companion_combat_blocked(), session._riding_companion()])
	check(session.dialogue.pages[0].get("text", "").contains("我没事"), "阿见对白复用原文，不新造剧情")
	await _advance_to_choices()
	check(session.dialogue.choices.size() == 1 and session.dialogue.choices[0].get("id", "") == "leave", "阿见骑乘对白只有继续赶路出口")
	await _tap_key(KEY_ENTER)
	check(not paused and ajian.is_riding(), "阿见旧对白可以退出并保持骑乘")
	check(int(session.state.social.get("reputation", 0)) == reputation_before and bool(session.state.flags.get("campRewardClaimed", false)) == reward_before and not session.state.flags.has("ajianFirstWakeMethod"), "阿见骑乘对白不重复支付/救援/唤醒奖励")
