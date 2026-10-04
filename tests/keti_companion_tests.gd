extends SceneTree

var failures: Array[String] = []
var checks := 0
var session: GameSession
var boarding_finished := false
var boarding_result: Dictionary = {}

func _initialize() -> void:
	_run.call_deferred()

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition: failures.append("CHECK_%d: %s" % [checks, message])

func _tap_enter() -> void:
	var event := InputEventKey.new()
	event.physical_keycode = KEY_ENTER
	event.keycode = KEY_ENTER
	event.pressed = true
	Input.parse_input_event(event)
	await physics_frame
	event = InputEventKey.new()
	event.physical_keycode = KEY_ENTER
	event.keycode = KEY_ENTER
	event.pressed = false
	Input.parse_input_event(event)
	await process_frame

func _tap_interact() -> void:
	var event := InputEventKey.new()
	event.physical_keycode = KEY_ENTER
	event.keycode = KEY_ENTER
	event.pressed = true
	Input.parse_input_event(event)
	await physics_frame
	event = InputEventKey.new()
	event.physical_keycode = KEY_ENTER
	event.keycode = KEY_ENTER
	event.pressed = false
	Input.parse_input_event(event)
	await process_frame

func _advance_to_choices() -> void:
	for step in range(60):
		if session.dialogue.state == &"active" and session.dialogue.page_index == session.dialogue.pages.size() - 1:
			return
		await _tap_enter()

func _start_session() -> void:
	session = (load("res://game/main.tscn") as PackedScene).instantiate() as GameSession
	session.store = SaveStore.new("res://.godot/companion-fixture-saves")
	root.add_child(session)
	session.menus.hide_all()
	session.hud.visible = true
	session.state.actors["buck"]["met"] = true
	session.state.actors["miro"]["met"] = true
	session.state.player["length"] = 14
	await session.load_map(&"chapter2_slice", &"", false, false)
	session.current_world.player.set_physics_process(false)
	session.dialogue.close()
	session.pause_reasons.clear()
	paused = false
	var progress: Dictionary = session.state.chapter_two
	progress.merge({"intro_seen": true, "inner_latch": true, "settled": true, "duo": false, "stretcher": "", "dialogues_seen": {}}, true)
	session.state.current_map = &"chapter2_slice"
	session.story.chapter_two._sync_cart()
	var keti := session.current_world.get_story_actor(&"keti")
	keti.restore_persistent_state({"hp": 14.0, "active": true, "damageable": true, "is_dead": false, "is_downed": false, "hostile": false, "defeat_mode": "downed"})
	keti.global_position = Vector2(1080, 420)

func _end_session() -> void:
	session.story.cancel_pending_flow()
	session.dialogue.close()
	session.pause_reasons.clear()
	paused = false
	session.store.delete_slot(1)
	session.queue_free()
	await process_frame
	session = null

func _run() -> void:
	await _start_session()
	await _test_default_mount_and_input_signal()
	await _test_cross_map_companion()
	await _test_occupied_seat_is_preserved()
	await _test_dismount_save_wake_and_reboard()
	await _test_swallow_and_spit_recovery()
	await _test_cancelled_boarding_keeps_new_cutscene_pause()
	await _end_session()
	# Allow stopped audio decoders to release on the next server mix tick.
	await create_timer(0.08, true).timeout
	if failures.is_empty():
		print("KETI COMPANION TESTS PASSED: %d checks" % checks)
		quit(0)
	else:
		for failure in failures: print("FAIL: ", failure)
		quit(1)

func _begin_boarding(flow: Node) -> void:
	boarding_result = await flow.execute("ride", &"keti")
	boarding_finished = true

func _test_cancelled_boarding_keeps_new_cutscene_pause() -> void:
	var flow := session.story.chapter_two
	var keti := session.current_world.get_story_actor(&"keti")
	if keti.is_riding():
		await flow.execute("dismount", &"keti")
	keti.global_position = Vector2(1080, 420)
	boarding_finished = false
	boarding_result.clear()
	_begin_boarding(flow)
	await create_timer(0.1, true).timeout
	session.story.cancel_pending_flow()
	session.set_pause_reason(&"cutscene", true)
	for frame in range(600):
		if boarding_finished: break
		await process_frame
	check(boarding_finished and not boarding_result.get("ok", false), "取消中的骑乘挂载被 flow_epoch 作废")
	check(is_instance_valid(keti) and not keti.is_riding() and session.state.player.rider == "" and session.state.chapter_two.duo, "取消挂载不会提交临时乘客或改写已结伴状态")
	check(session.pause_reasons.has(&"cutscene"), "旧挂载协程不会清除新 flow 的 cutscene pause")
	session.set_pause_reason(&"cutscene", false)

func _test_default_mount_and_input_signal() -> void:
	var flow := session.story.chapter_two
	var keti := session.current_world.get_story_actor(&"keti")
	var result: Dictionary = await flow.execute("duo", &"keti")
	check(result.ok and session.state.chapter_two.duo, "结伴行动完成")
	check(session.state.player.rider == "keti" and keti.is_riding(), "空座结伴后可蒂默认上蛇并提交唯一 rider")
	check(not keti.is_downed and keti.hp == 14.0, "默认骑乘保留可蒂清醒状态与生命")
	check(session.state.social.reputation == 3, "默认上蛇不重复或漏发结伴声望")
	await _tap_interact()
	check(keti.interaction_open, "Enter 真实输入选中蛇背上的可蒂")
	check(session.story.current_id == "ch2_keti_duo", "骑乘交互进入结伴后重复对白")
	await _advance_to_choices()
	var has_dismount := false
	for choice in session.dialogue.choices:
		if String(choice.get("action", "")) == "dismount": has_dismount = true
	check(has_dismount, "RIDER_DIALOGUE_HAS_DISMOUNT")
	check(keti.is_riding() and session.state.player.rider == "keti", "查看骑乘对白不会自行下蛇")
	session.dialogue.close()
	session.pause_reasons.clear()
	paused = false

func _test_cross_map_companion() -> void:
	var player := session.current_world.player
	var keti := session.current_world.get_story_actor(&"keti")
	check(session.save_active_slot().ok, "跨图前骑乘可保存")
	var loaded: Dictionary = await session.load_active_slot()
	keti = session.current_world.get_story_actor(&"keti")
	check(loaded.ok and session.state.player.rider == "keti" and keti.is_riding(), "同图读档恢复骑乘可蒂")
	session.story.cancel_pending_flow()
	check(await session.load_map(&"forest", &"", false, true), "结伴骑乘跨入森林地图")
	player = session.current_world.player
	keti = session.current_world.get_story_actor(&"keti")
	check(session.state.current_map == &"forest" and is_instance_valid(keti) and keti.is_riding() and session.state.player.rider == "keti", "森林中恢复同一个 rider 关系")
	if not is_instance_valid(keti):
		check(false, "CROSS_MAP_INITIAL_MUST_SPAWN_RIDER")
		session.story.cancel_pending_flow()
		await session.load_map(&"chapter2_slice", &"", false, false)
		return
	check(session.save_active_slot().ok, "森林地图中的骑乘状态能保存")
	loaded = await session.load_active_slot()
	player = session.current_world.player
	keti = session.current_world.get_story_actor(&"keti")
	if not is_instance_valid(keti):
		check(false, "CROSS_MAP_RELOAD_MUST_SPAWN_RIDER")
		session.story.cancel_pending_flow()
		await session.load_map(&"chapter2_slice", &"", false, false)
		return
	check(loaded.ok and session.state.current_map == &"forest" and keti.is_riding(), "跨图读档仍恢复 rider")
	await _tap_interact()
	check(keti.interaction_open and session.story.current_id == "ch2_keti_duo", "森林中的 Enter 仍打开可蒂结伴对白")
	await _advance_to_choices()
	var can_dismount := false
	for choice in session.dialogue.choices:
		if String(choice.get("action", "")) == "dismount": can_dismount = true
	check(can_dismount and keti.is_riding(), "森林骑乘对白有下蛇选项且浏览不下蛇")
	session.dialogue.close()
	session.pause_reasons.clear()
	paused = false
	var flow := session.story.chapter_two
	var dismounted: Dictionary = await flow.execute("dismount", &"keti")
	check(dismounted.ok and not keti.is_riding() and session.state.player.rider == "" and session.state.actors["keti"].location == "forest", "非第二章地图可蒂可下蛇并记当前位置")
	var down: Dictionary = await flow.execute("attack", &"keti")
	check(down.ok and keti.is_downed, "非第二章地图结伴可蒂可被击晕")
	var woke: Dictionary = await flow.execute("face", &"keti")
	check(woke.ok and not keti.is_downed and session.state.actors["keti"].location == "forest", "非第二章地图可以唤醒并保留位置")
	keti.global_position = player.body_chain.segments[1] + Vector2(24, 0)
	var boarded: Dictionary = await flow.execute("ride", &"keti")
	check(boarded.ok and keti.is_riding() and session.state.player.rider == "keti", "森林里唤醒的可蒂可以重新上蛇")
	check(session.save_active_slot().ok, "森林里重新上蛇可保存")
	loaded = await session.load_active_slot()
	keti = session.current_world.get_story_actor(&"keti")
	check(loaded.ok and keti.is_riding() and session.state.player.rider == "keti", "森林存档恢复骑乘关系")
	player = session.current_world.player
	var off_snake: Dictionary = await flow.execute("dismount", &"keti")
	var swallowed: Dictionary = await flow.execute("eat", &"keti")
	check(off_snake.ok and swallowed.ok and player.inventory.count_item(&"keti") == 1, "森林中的结伴可蒂沿用既有吞入路径")
	check(player.spit_item(&"keti", false, true), "森林里可以吐出胃袋中的可蒂")
	var flying_actor: BeanProjectile
	for child in session.current_world.get_children():
		if child is BeanProjectile and not child.is_landed and child.payload.get("id", &"") == &"keti":
			flying_actor = child
			break
	check(is_instance_valid(flying_actor), "森林吐出可蒂后生成唯一飞行投射物")
	check(session.save_active_slot().ok, "可蒂仍在森林飞行时可保存投射物位置")
	loaded = await session.load_active_slot()
	keti = session.current_world.get_story_actor(&"keti")
	check(loaded.ok and is_instance_valid(keti) and keti.visible and keti.is_downed and session.state.actors["keti"].location == "forest", "森林飞行中的可蒂读档投影为唯一可互动昏迷 NPC")
	if is_instance_valid(keti):
		var wake_after_flight: Dictionary = await flow.execute("face", &"keti")
		check(wake_after_flight.ok and not keti.is_downed, "森林飞行存档恢复的可蒂可以唤醒")
		keti.global_position = session.current_world.player.body_chain.segments[1] + Vector2(24, 0)
		var remount_after_flight: Dictionary = await flow.execute("ride", &"keti")
		check(remount_after_flight.ok and keti.is_riding() and session.state.player.rider == "keti", "森林吐出并读档后仍可主动恢复骑乘")
	session.story.cancel_pending_flow()
	check(await session.load_map(&"chapter2_slice", &"", false, true), "结伴骑乘返回第二章地图")
	keti = session.current_world.get_story_actor(&"keti")
	check(session.state.current_map == "chapter2_slice" and keti.is_riding() and session.state.player.rider == "keti", "返回第二章后维持唯一骑乘可蒂")

func _test_occupied_seat_is_preserved() -> void:
	var flow := session.story.chapter_two
	var world := session.current_world
	var player := world.player
	var keti := world.get_story_actor(&"keti")
	var buck := world.spawn_npc(&"buck", player.global_position + Vector2(24, 0))
	var left_seat: Dictionary = await flow.execute("dismount", &"keti")
	check(left_seat.ok and not keti.is_riding(), "OCCUPANCY_KETI_LEFT_SEAT")
	buck.global_position = player.body_chain.segments[1] + Vector2(24, 0)
	check(buck.attach_to_carrier(player, Vector2.ZERO), "OCCUPANCY_OLD_PASSENGER_BOARDS")
	session.state.player["rider"] = "buck"
	session.state.actors["buck"].merge({"status": "riding", "location": "rider"}, true)
	var refused: Dictionary = await flow.execute("ride", &"keti")
	check(not refused.ok and world.get_story_actor(&"buck") == buck and buck.is_riding(), "OCCUPANCY_FLOW_REFUSES_REPLACEMENT")
	check(not keti.attach_to_carrier(player, Vector2.ZERO) and buck.is_riding(), "OCCUPANCY_ACTOR_API_REFUSES_REPLACEMENT")
	keti.global_position = Vector2(1080, 420)
	session.state.chapter_two["duo"] = false
	var applied_events: Dictionary = session.state.social.get("applied_events", {})
	applied_events.erase("ch2:quest:reunite_keti")
	session.state.social["applied_events"] = applied_events
	session.state.social["reputation"] = 0
	var completed_full: Dictionary = await flow.execute("duo", &"keti")
	check(completed_full.ok and completed_full.get("next", "") == "ending_occupied" and session.state.chapter_two.duo and session.state.player.rider == "buck" and buck.is_riding() and not keti.is_riding(), "满座仍完成结伴且保留原乘客，可蒂留在地面")
	check(session.state.social.reputation == 3, "满座结伴仍只发放一次声望")
	var repeated_full: Dictionary = await flow.execute("duo", &"keti")
	check(repeated_full.ok and repeated_full.get("next", "") == "keti_duo" and session.state.social.reputation == 3 and session.state.player.rider == "buck", "满座结伴后的重复交互不重播结尾、不重复奖励或替换乘客")
	flow.show("ending_occupied")
	var ending_text := ""
	for page in session.dialogue.pages: ending_text += String(page.get("text", ""))
	check(ending_text.contains("你背上已经有人了！先让他下来，再来接我") and session.dialogue.choices.any(func(choice: Dictionary) -> bool: return choice.get("action", "") == "leave"), "满座结伴结尾明确提示先让乘客下来并保留出发选项")
	session.dialogue.close()
	session.pause_reasons.clear()
	paused = false
	player.reset_at(Vector2(1008, 420))
	var buck_down: Dictionary = await flow.execute("dismount", &"")
	check(buck_down.ok and not buck.is_riding() and session.state.player.rider == "", "OCCUPANCY_OLD_PASSENGER_DISMOUNTS")
	keti.global_position = player.body_chain.segments[1] + Vector2(24, 0)
	var boarded: Dictionary = await flow.execute("ride", &"keti")
	check(boarded.ok and keti.is_riding() and buck.visible and not buck.is_riding(), "OCCUPANCY_KETI_BOARDS_AFTER_EMPTY_SEAT")

func _test_dismount_save_wake_and_reboard() -> void:
	var flow := session.story.chapter_two
	var world := session.current_world
	var player := world.player
	var keti := world.get_story_actor(&"keti")
	var landed: Dictionary = await flow.execute("dismount", &"keti")
	check(landed.ok and not keti.is_riding() and session.state.player.rider == "", "蛇背对白可蒂能在任意地点下蛇")
	check(keti.visible and keti.global_position.distance_to(player.global_position) < 100.0, "下蛇将可蒂放在身边并恢复地图互动")
	check(session.save_active_slot().ok, "临时下蛇状态能写入存档")
	var loaded: Dictionary = await session.load_active_slot()
	keti = session.current_world.get_story_actor(&"keti")
	check(loaded.ok and session.state.player.rider == "" and not keti.is_riding() and keti.visible, "读档保留主动下蛇状态")
	player = session.current_world.player
	keti.global_position = player.body_chain.segments[1] + Vector2(24, 0)
	var down: Dictionary = await flow.execute("attack", &"keti")
	check(down.ok and keti.is_downed and not keti.is_riding(), "结伴后可蒂下蛇仍可被击晕")
	var woke: Dictionary = await flow.execute("face", &"keti")
	check(woke.ok and not keti.is_downed and not keti.hostile, "舔醒恢复可蒂但保留既有非敌对状态")
	keti.global_position = player.body_chain.segments[1] + Vector2(24, 0)
	var reboarded: Dictionary = await flow.execute("ride", &"keti")
	check(reboarded.ok and keti.is_riding() and session.state.player.rider == "keti", "醒来的可蒂可通过主动上蛇恢复常态骑乘")
	check(session.state.social.reputation == 3, "上下蛇与恢复流程不重复奖励")
	check(session.save_active_slot().ok, "常态骑乘状态能写入存档")
	loaded = await session.load_active_slot()
	keti = session.current_world.get_story_actor(&"keti")
	check(loaded.ok and keti.is_riding() and session.state.player.rider == "keti" and not keti.is_downed, "读档恢复同一清醒可蒂及骑乘关系")

func _test_swallow_and_spit_recovery() -> void:
	var flow := session.story.chapter_two
	var world := session.current_world
	var player := world.player
	var keti := world.get_story_actor(&"keti")
	var unmounted: Dictionary = await flow.execute("dismount", &"keti")
	check(unmounted.ok and not keti.is_riding(), "吞吐前先让可蒂下蛇")
	var swallowed: Dictionary = await flow.execute("eat", &"keti")
	check(swallowed.ok and player.inventory.count_item(&"keti") == 1 and session.state.player.rider == "", "结伴后的可蒂仍沿用吞人路径并清除骑乘位")
	check(player.spit_item(&"keti", false, true), "胃中可蒂可走现有吐出流程")
	var projectile: BeanProjectile
	for child in world.get_children():
		if child is BeanProjectile and not child.is_landed and child.payload.get("id", &"") == &"keti":
			projectile = child
			break
	check(is_instance_valid(projectile), "吐出操作创建唯一 NPC 投射物")
	if is_instance_valid(projectile): projectile.land()
	await process_frame
	keti = world.get_story_actor(&"keti")
	check(is_instance_valid(keti) and keti.visible and not keti.is_riding(), "吐出后恢复唯一的地面可蒂")
	if is_instance_valid(keti):
		var woke: Dictionary = await flow.execute("face", &"keti")
		check(woke.ok and not keti.is_downed, "吐出后的昏迷可蒂可被舔醒")
		keti.global_position = player.body_chain.segments[1] + Vector2(24, 0)
		var boarded: Dictionary = await flow.execute("ride", &"keti")
		check(boarded.ok and keti.is_riding() and session.state.player.rider == "keti", "吐出恢复后的可蒂可主动重新上蛇")
