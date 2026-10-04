extends SceneTree
## Adversarial sequences through the real world, inventory and slot store.

var failures: Array[String] = []
var session: GameSession
var checks := 0

func _initialize() -> void:
	_run.call_deferred()

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition: failures.append(message)

func _tap(key: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.physical_keycode = key
		event.keycode = key
		event.pressed = pressed
		Input.parse_input_event(event)
		await physics_frame
		await process_frame

func _choose(choice_id: String) -> void:
	var panel := session.dialogue
	for step in range(24):
		if panel.state == &"active" and panel.page_index == panel.pages.size() - 1: break
		await _tap(KEY_ENTER)
	var index := -1
	for i in range(panel.choices.size()):
		if String(panel.choices[i].id) == choice_id: index = i
	check(index >= 0, "实际选项存在：%s @ %s" % [choice_id, session.story.current_id])
	if index < 0: return
	for step in range(panel.choices.size() + 1):
		if panel.selected_choice_index == index: break
		await _tap(KEY_DOWN)
	await _tap(KEY_ENTER)
	for frame in range(8): await process_frame

func _new_session() -> void:
	session = load("res://game/main.tscn").instantiate() as GameSession
	session.store = SaveStore.new("res://.godot/ch2-audit-saves")
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

func _run() -> void:
	await _new_session()
	await _test_airborne_save(&"keti")
	await _cleanup()
	await _new_session()
	await _test_airborne_save(&"ajie")
	await _cleanup()
	await _new_session()
	await _test_repeated_settle()
	await _cleanup()
	await _new_session()
	await _test_stretcher_dismount()
	await _cleanup()
	_test_legacy_states()
	await _new_session()
	await _test_dynamic_visitor_save()
	await _test_transition_guard()
	await _cleanup()
	await _new_session()
	await _test_old_passenger()
	await _cleanup()
	await _new_session()
	await _test_checkpoint_and_death()
	await _cleanup()
	await _new_session()
	await _test_failure_choices_and_cg_cancel()
	await _cleanup()
	await _new_session()
	await _test_projectile_attack()
	await _cleanup()
	await _new_session()
	await _test_npc_threats_and_invalid_save()
	await _cleanup()
	for transfer in ["stretcher", "protect"]:
		await _new_session()
		await _test_contact_after_transport_load(transfer)
		await _cleanup()
	for approach in ["negotiate", "threat", "key", "attack", "eat"]:
		for transfer in ["stretcher", "protect", "eat", "spit"]:
			for timing in ["late", "early", "again"]:
				for wake in ["face", "foot"]:
					await _new_session()
					await _test_route_matrix(approach, transfer, timing, wake)
					await _cleanup()
		print("BRANCH MATRIX: completed approach ", approach)
	if failures.is_empty():
		print("CHAPTER TWO BRANCH AUDIT PASSED: %d checks" % checks)
		quit(0)
	else:
		for failure in failures: push_error(failure)
		quit(1)

func _open_cart() -> void:
	await session.story.chapter_two.execute("key", &"")
	await session.story.chapter_two.execute("lever", &"")

func _test_airborne_save(actor_id: StringName) -> void:
	await _open_cart()
	var world := session.current_world
	if actor_id == &"keti":
		check((await session.story.chapter_two.execute("protect", actor_id)).ok, "吞入可蒂以测试空中存档")
	else:
		# A real previous-chapter payload has no authored NPC in this map.
		session.state.actors[String(actor_id)].merge({"status": "swallowed", "location": "stomach", "hp": 2.0, "resentful": true}, true)
		check(world.player.add_special_item(actor_id, {"actor_id": actor_id, "hp": 2.0}), "旧角色胃袋载荷")
	world.player.global_position = Vector2(840, 588)
	world.player.direction = Vector2.RIGHT
	check(world.player.spit_item(actor_id, false, true), "真实吐出角色：%s" % actor_id)
	var airborne := 0
	for node in world.get_children():
		if node is BeanProjectile and node.payload.get("id", &"") == actor_id and not node.is_landed:
			airborne += 1
	check(airborne == 1, "存档发生在角色还未落地时")
	check(session.save_active_slot().ok, "空中保存")
	check((await session.load_active_slot()).ok, "空中读档")
	world = session.current_world
	world.player.set_physics_process(false)
	var restored := world.get_story_actor(actor_id)
	check(is_instance_valid(restored) and restored.visible and restored.is_downed, "空中读档后角色不能丢失：%s" % actor_id)
	check(world.player.inventory.count_item(actor_id) == 0, "读档没有胃袋复制：%s" % actor_id)
	if is_instance_valid(restored) and restored.visible:
		check((await session.story.chapter_two.execute("face", actor_id)).ok, "读档落地角色仍可唤醒")
		if actor_id == &"keti":
			check((await session.story.chapter_two.execute("stretcher", actor_id)).ok, "空中读档后仍可搬运可蒂")
			world.player.global_position = Vector2(1008, 420)
			check((await session.story.chapter_two.execute("settle", &"")).ok, "空中读档后安置")
			check((await session.story.chapter_two.execute("duo", actor_id)).ok, "空中读档后完成结伴")
		else:
			check(session.state.actors[String(actor_id)].get("resentful", false), "动态旧角色保留历史")
	session.store.delete_slot(1)

func _test_repeated_settle() -> void:
	await _open_cart()
	var flow: Node = session.story.chapter_two
	await flow.execute("stretcher", &"keti")
	session.current_world.player.global_position = Vector2(1008, 420)
	await flow.execute("settle", &"")
	await flow.execute("face", &"keti")
	check((await flow.execute("settle", &"")).ok, "已唤醒后再点安置")
	check(not session.current_world.get_story_actor(&"keti").is_downed, "重复安置不能让清醒可蒂重新昏迷")
	check((await flow.execute("duo", &"keti")).ok, "重复安置后仍能结伴")

func _test_stretcher_dismount() -> void:
	await _open_cart()
	var flow: Node = session.story.chapter_two
	await flow.execute("stretcher", &"keti")
	session.current_world.player.global_position = Vector2(1008, 420)
	check((await flow.execute("dismount", &"")).ok, "担架可蒂也是蛇背上的乘客，可以放下")
	check(not session.current_world.get_story_actor(&"keti").is_riding(), "担架乘客真实下蛇")
	check(session.state.chapter_two.get("stretcher", "") == "", "下蛇不残留担架标记")

func _test_legacy_states() -> void:
	for terminal in ["dead", "eaten", "bones", "left"]:
		var state := SessionState.new()
		state.actors["keti"]["status"] = terminal
		check(not state.prepare_chapter_two(), "不复活不可营救的旧终态：%s" % terminal)
	for dangling in ["swallowed", "riding"]:
		for initialized in [false, true]:
			var state := SessionState.new()
			state.actors["keti"].merge({"status": dangling, "location": "stomach" if dangling == "swallowed" else "rider"}, true)
			state.chapter_two = {"initialized": initialized, "settled": initialized, "stretcher": ""}
			check(state.prepare_chapter_two(), "恢复旧版遗漏的活人承载关系")
			check(state.actors["keti"].status == "unconscious" and state.actors["keti"].location == "chapter2_slice", "旧空中存档不能永久隐藏可蒂")
	var state := SessionState.new()
	state.actors["keti"].merge({"status": "riding", "location": "rider", "hp": 0.0, "transport_down": true}, true)
	state.chapter_two = {"initialized": true, "stretcher": "keti"}
	check(state.prepare_chapter_two() and state.player.rider == "keti", "兼容旧版仅有担架字段的存档")

func _test_dynamic_visitor_save() -> void:
	var world := session.current_world
	session.state.actors["ajie"].merge({"status": "swallowed", "location": "stomach", "hp": 2.0, "hostile": true, "wake_hostile": true}, true)
	world.player.add_special_item(&"ajie", {"actor_id": &"ajie", "hp": 2.0})
	world.player.global_position = Vector2(840, 588)
	world.player.spit_item(&"ajie", false, true)
	for child in world.get_children():
		if child is BeanProjectile and child.payload.get("id", &"") == &"ajie": child.land()
	check(world.get_story_actor(&"ajie").visible, "真实落地生成无预置节点的旧角色")
	check(world.get_story_actor(&"ajie").max_hp == 8.0, "跨章吐出旧角色不改变生命上限")
	session.save_active_slot()
	await session.load_active_slot()
	world = session.current_world
	world.player.set_physics_process(false)
	var visitor := world.get_story_actor(&"ajie")
	check(is_instance_valid(visitor) and visitor.visible and visitor.is_downed and visitor.hp == 2.0, "落地后的动态角色也能存读档")
	check(is_instance_valid(visitor) and visitor.max_hp == 8.0, "动态角色生命上限在读档后保持")
	if is_instance_valid(visitor):
		check((await session.story.chapter_two.execute("foot", &"ajie")).ok and visitor.hostile, "动态角色唤醒保留敌意")
	session.store.delete_slot(1)

func _test_transition_guard() -> void:
	var old := session.state.to_dictionary()
	var old_world := session.current_world
	session.map_transition_active = true
	check(not session.save_active_slot().ok, "切图中不得保存混合状态")
	check(not (await session.load_active_slot()).ok, "切图中不得读档覆盖当前状态")
	await session.retry_checkpoint()
	session.return_to_title()
	session.start_new_game(2)
	await session.continue_game(2)
	for key in [KEY_F5, KEY_F6, KEY_F9, KEY_F1]: await _tap(key)
	check(session.current_world == old_world and session.active_slot == 1 and session.state.to_dictionary() == old, "连续快捷键及菜单动作在切图期间不提交副作用")
	session.map_transition_active = false

func _test_old_passenger() -> void:
	session.state.player["rider"] = "ajian"
	session.state.actors["ajian"].merge({"status": "riding", "location": "rider", "hp": 2.0}, true)
	await session.load_map(&"chapter2_slice", &"", false, false)
	session.current_world.player.set_physics_process(false)
	await _open_cart()
	var flow: Node = session.story.chapter_two
	check(not (await flow.execute("stretcher", &"keti")).ok, "担架不覆盖旧乘客")
	session.current_world.player.global_position = Vector2(1008, 420)
	check((await flow.execute("dismount", &"")).ok, "旧乘客可实际放下")
	check((await flow.execute("stretcher", &"keti")).ok, "放下旧乘客后可上担架")
	check(session.state.player.rider == "keti", "担架与乘客字段统一")
	session.save_active_slot()
	await session.load_active_slot()
	session.current_world.player.set_physics_process(false)
	var old_passenger := session.current_world.get_story_actor(&"ajian")
	check(is_instance_valid(old_passenger) and old_passenger.visible and not old_passenger.is_riding() and old_passenger.hp == 2.0, "下蛇旧乘客读档不消失")
	check(session.current_world.get_story_actor(&"keti").is_downed and session.current_world.get_story_actor(&"keti").is_riding(), "新担架乘客读档保留昏迷")
	session.store.delete_slot(1)

func _test_checkpoint_and_death() -> void:
	await _open_cart()
	var flow: Node = session.story.chapter_two
	await flow.execute("stretcher", &"keti")
	session.remember_checkpoint(&"chapter2_slice")
	await flow.execute("threat", &"ferryman")
	session.current_world.player.global_position = Vector2(1008, 420)
	await flow.execute("settle", &"")
	await flow.execute("face", &"keti")
	await flow.execute("duo", &"keti")
	await session.retry_checkpoint()
	session.current_world.player.set_physics_process(false)
	check(not session.state.chapter_two.duo and session.state.social.reputation == 0 and session.state.social.fear == 0, "检查点回滚完成事件与恐惧去重键")
	check(session.current_world.get_story_actor(&"keti").is_riding() and session.current_world.get_story_actor(&"keti").is_downed, "检查点恢复昏迷担架")
	session.save_active_slot()
	session._on_player_died("audit")
	check(session.death_screen.is_open(), "真实死亡界面可进入")
	await session._reload_after_death()
	session.current_world.player.set_physics_process(false)
	check(not session.death_screen.is_open() and not session.pause_reasons.has(&"death"), "死亡读档释放死亡暂停")
	session.current_world.player.global_position = Vector2(1008, 420)
	await flow.execute("settle", &"")
	await flow.execute("face", &"keti")
	check((await flow.execute("duo", &"keti")).ok and session.state.social.reputation == 3, "死亡重载后仍可完成唯一奖励")
	session.store.delete_slot(1)

func _test_failure_choices_and_cg_cancel() -> void:
	var flow: Node = session.story.chapter_two
	flow.interact_item(&"ch2_lever")
	await _choose("lever")
	check(not session.dialogue.input_locked and session.pause_reasons.has(&"dialogue"), "失败选项仍可操作同一对白")
	await _choose("leave")
	check(not session.pause_reasons.has(&"dialogue"), "失败后离开能释放对话暂停")
	await _open_cart()
	flow.interact_actor(&"keti")
	await _choose("foot")
	check(session.dialogue.input_locked and session.cg_player.visible, "真实舔脚选项进入CG并锁输入")
	session.return_to_title()
	for frame in range(12): await process_frame
	check(session.current_world == null and not session.dialogue.input_locked and not session.cg_player.visible and session.pause_reasons.is_empty(), "返回标题取消CG，不残留输入和暂停锁")
	check(session.story.current_id != "ch2_keti_foot_reply", "已取消流程不能迟到显示旧对白")
	await session.load_map(&"chapter2_slice", &"", false, false)
	session.current_world.player.set_physics_process(false)
	check(session.story.current_id == "ch2_explore", "返回游戏不复用旧CG回调")

func _test_contact_after_transport_load(transfer: String) -> void:
	await _open_cart()
	var flow: Node = session.story.chapter_two
	await flow.execute(transfer, &"keti")
	session.save_active_slot()
	await session.load_active_slot()
	var world := session.current_world
	world.player.set_physics_process(false)
	world.player.global_position = Vector2(1008, 420)
	await flow.execute("settle", &"")
	var keti := world.get_story_actor(&"keti")
	check(keti.player == world.player and keti.interaction_requested.is_connected(world._on_npc_interaction_requested) and keti.harmed.is_connected(world._on_npc_harmed), "载运读档后恢复真实互动和受伤信号：" + transfer)
	world.player.reset_at(Vector2(1032, 420), Vector2.RIGHT)
	# Establish the fixture without swept contact across a teleport through
	# other NPCs. The following approach itself uses ordinary physics/input.
	for node in world.get_tree().get_nodes_in_group(&"npc"):
		if world.is_ancestor_of(node):
			node._previous_head_position = world.player.global_position
			if node != keti: node.set_physics_process(false)
	world.player.set_physics_process(true)
	await _tap(KEY_RIGHT)
	for frame in range(90):
		await physics_frame
		if session.story.current_id == "ch2_keti_down": break
	world.player.set_physics_process(false)
	print("TRANSPORT CONTACT: ", transfer, " node=", session.story.current_id, " position=", world.player.global_position)
	check(session.story.current_id == "ch2_keti_down", "载运读档后方向键接触触发可蒂对白：" + transfer)
	if session.story.current_id == "ch2_keti_down":
		await _choose("face")
		await _choose("leave")
	check((await flow.execute("duo", &"keti")).ok, "实际接触唤醒后能够结伴：" + transfer)
	session.store.delete_slot(1)

func _test_projectile_attack() -> void:
	var world := session.current_world
	var merchant := world.get_story_actor(&"caravan_merchant")
	world.player.reset_at(Vector2(276, 324), Vector2.RIGHT)
	world.player.base_speed = 0
	world.player.set_physics_process(true)
	await _tap(KEY_J)
	for frame in range(90):
		await physics_frame
		if merchant.hp <= 4.0: break
	check(merchant.hp <= 4.0 and session.state.social.fear == 1, "真实豆子命中NPC计恐惧")
	for frame in range(32): await physics_frame
	await _tap(KEY_J)
	for frame in range(90):
		await physics_frame
		if merchant.is_downed: break
	check(merchant.is_downed and not merchant.is_dead and merchant.visible, "连续真实射击只能击晕NPC")
	check(session.state.social.fear == 1, "连续豆子攻击同一遭遇不重复加分")
	world.player.base_speed = 96
	await _tap(KEY_RIGHT)
	for frame in range(90):
		await physics_frame
		if session.story.current_id == "ch2_npc_down": break
	world.player.set_physics_process(false)
	check(session.story.current_id == "ch2_npc_down", "击晕后真实靠近仍可对话")
	if session.story.current_id == "ch2_npc_down":
		await _choose("foot")
		await _choose("leave")
	check(not merchant.is_downed and merchant.hp == 1.0, "普通NPC的舔脚选项可唤醒")
	await session.story.chapter_two.execute("key", &"")
	check((await session.story.chapter_two.execute("lever", &"")).ok, "物理攻击NPC后备用钥匙主线仍可继续")

func _test_npc_threats_and_invalid_save() -> void:
	var flow: Node = session.story.chapter_two
	for actor_id in [&"ferryman", &"buck", &"miro"]:
		var before := int(session.state.social.fear)
		check((await flow.execute("threat", actor_id)).ok, "普通NPC可威胁：%s" % actor_id)
		await flow.execute("threat", actor_id)
		check(session.state.social.fear == before + 2, "普通NPC威胁去重：%s" % actor_id)
		await flow.execute("attack", actor_id)
		var after_attack := int(session.state.social.fear)
		check(not (await flow.execute("threat", actor_id)).ok and session.state.social.fear == after_attack, "昏迷NPC不可应答也不加威胁分")
		await flow.execute("face", actor_id)
		await flow.execute("threat", actor_id)
		check(session.state.social.fear == after_attack, "唤醒不重置已提交威胁事件")
	var before := session.state.to_dictionary()
	check(not (await flow.execute("eat", &"missing_actor")).ok and not (await flow.execute("missing_action", &"")).ok, "失效人物及未知行动安全失败")
	check(session.state.to_dictionary() == before, "无效行动没有副作用")
	var invalid := session.state.to_dictionary()
	invalid.actors["keti"]["status"] = "bones"
	session.store.save_slot(1, invalid)
	var old_world := session.current_world
	check(not (await session.load_active_slot()).ok, "拒绝不可营救旧档")
	check(session.current_world == old_world and session.state.to_dictionary() == before, "拒绝存档不能破坏当前可玩的世界和状态")
	session.store.delete_slot(1)

func _test_route_matrix(approach: String, transfer: String, timing: String, wake: String) -> void:
	var label := "%s/%s/%s/%s" % [approach, transfer, timing, wake]
	var flow: Node = session.story.chapter_two
	var world := session.current_world
	if approach == "key":
		await flow.execute("key", &"")
	else:
		check((await flow.execute(approach, &"caravan_merchant")).ok, "开门方式：" + label)
		if approach in ["attack", "eat"]: await flow.execute("key", &"")
	check((await flow.execute("lever", &"")).ok, "开门杆：" + label)
	if timing == "early":
		await flow.execute(wake, &"keti")
		if transfer == "protect":
			check(not (await flow.execute("protect", &"keti")).ok, "清醒可蒂不能冒充昏迷保护：" + label)
			await flow.execute("attack", &"keti")
	if transfer == "spit":
		await flow.execute("eat" if timing == "early" else "protect", &"keti")
		world.player.global_position = Vector2(1008, 420)
		check(world.player.spit_item(&"keti", false, true), "吐出可蒂：" + label)
		for child in world.get_children():
			if child is BeanProjectile and child.payload.get("id", &"") == &"keti":
				child.global_position = Vector2(1080, 420)
				child.land()
	else:
		check((await flow.execute(transfer, &"keti")).ok, "转移：" + label)
	check(session.save_active_slot().ok, "转移存档：" + label)
	check((await session.load_active_slot()).ok, "转移读档：" + label)
	world = session.current_world
	world.player.set_physics_process(false)
	world.player.global_position = Vector2(1008, 420)
	check((await flow.execute("settle", &"")).ok, "安置：" + label)
	if world.get_story_actor(&"keti").is_downed: await flow.execute(wake, &"keti")
	if timing == "again":
		await flow.execute("attack", &"keti")
		check(not (await flow.execute("duo", &"keti")).ok, "击晕后不能直接结伴：" + label)
		await flow.execute(wake, &"keti")
	await flow.execute("settle", &"")
	check(not world.get_story_actor(&"keti").is_downed, "重新安置保留清醒：" + label)
	check((await flow.execute("duo", &"keti")).ok, "完成同一终点：" + label)
	await flow.execute("duo", &"keti")
	check(session.state.social.reputation == 3, "奖励只发一次：" + label)
	var expected_fear: int = {"negotiate": 0, "threat": 2, "key": 0, "attack": 1, "eat": 3}[approach]
	if transfer == "eat": expected_fear += 3
	if transfer == "spit" and timing == "early": expected_fear += 3
	if timing == "again" or (timing == "early" and transfer == "protect"): expected_fear += 1
	check(session.state.social.fear == expected_fear, "成功行为才结算恐惧：" + label)
	check(session.state.player.rider == "" and session.state.chapter_two.stretcher == "" and world.player.inventory.count_item(&"keti") == 0, "结束不残留承载关系：" + label)
	session.store.delete_slot(1)
