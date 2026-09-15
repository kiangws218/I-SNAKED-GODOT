extends SceneTree

## Third-round feedback audit. This file is intentionally standalone: it does
## not alter the production test runner or any existing implementation.

var failures: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)

func _new_session() -> GameSession:
	var session := (load("res://game/main.tscn") as PackedScene).instantiate() as GameSession
	root.add_child(session)
	return session

func _run() -> void:
	await _test_keti_zero_hp()
	await _test_critical_keti_vomit_route()
	await _test_memory_vomit_timer()
	await _test_bandit_contact_and_reward_idempotency()
	await _test_dialogue_layout_contract()
	if failures.is_empty():
		print("FEEDBACK ROUND 3 AUDIT PASSED")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)

func _test_keti_zero_hp() -> void:
	var session := _new_session()
	await process_frame
	await session.load_map(&"wilderness", &"", true)
	session.story.current_id = "wilderness_keti_wait"
	var keti := session.current_world.get_story_actor(&"keti")
	keti.take_damage(999.0, &"round3_audit")
	await process_frame
	check(keti.visible, "可蒂归零后仍可见")
	check(keti.is_downed and not keti.is_dead, "可蒂归零后保持濒死/倒地而非 dead")
	check(String(session.state.actors.keti.status) == "critical", "可蒂归零后持久状态为 critical")
	check(session.story.current_id == "wilderness_keti_wait", "可蒂归零不自动跳过等待回触")
	session.queue_free()
	await process_frame

func _test_memory_vomit_timer() -> void:
	var session := _new_session()
	await process_frame
	await session.load_map(&"wilderness", &"", true)
	# Reproduce the swallowed-character route without entering the dialogue UI.
	session.state.flags.erase("prologue_complete")
	session.state.flags.erase("keti_eaten")
	session.state.flags.erase("memory_blurred")
	session.state.actors["keti"] = {"status": "alive", "location": "wilderness", "hp": 14.0, "max_hp": 14.0, "met": true, "damageable": true}
	session.story.current_id = "free_explore"
	var eaten := await session.story.execute_command("eatKeti")
	check(eaten.ok and session.current_world.player.inventory.count_item(&"keti") == 1, "呕吐路线前可蒂确实进入胃袋")
	var started := await session.story.execute_command("waitForMemoryBlur")
	check(started.ok and session.story.memory_timer_started, "free_explore 启动独立六秒计时")
	await create_timer(6.2, true).timeout
	print("AUDIT memory route current_id=", session.story.current_id, " timer=", session.story.memory_timer_started, " pause=", session.pause_reasons)
	check(session.story.current_id in ["memory_blur", "memory_blur_dialogue", "input_player_name"], "六秒后进入呕吐剧情而非停留 free_explore")
	await create_timer(1.0, true).timeout
	print("AUDIT memory route settled current_id=", session.story.current_id, " timer=", session.story.memory_timer_started, " pause=", session.pause_reasons)
	check(session.story.current_id in ["memory_blur_dialogue", "input_player_name"], "呕吐动作在计时结束后完成并进入对白")
	check(not session.story.memory_timer_started, "六秒计时完成后清除计时状态")
	session.queue_free()
	await process_frame

func _test_critical_keti_vomit_route() -> void:
	var session := _new_session()
	await process_frame
	await session.load_map(&"wilderness", &"", true)
	session.story.current_id = "wilderness_keti_wait"
	var keti := session.current_world.get_story_actor(&"keti")
	keti.take_damage(999.0, &"round3_audit")
	await process_frame
	session.current_world.player.global_position = keti.global_position + Vector2(200, 0)
	for index in range(3):
		await physics_frame
	session.current_world.player.global_position = keti.global_position
	keti._physics_process(0.1)
	await process_frame
	check(session.story.current_id == "keti_dead", "零血可蒂可进入离开/吃掉选择")
	session.dialogue._finish_enter()
	session.story._on_choice("leave")
	await process_frame
	check(session.story.current_id == "wilderness_slimes", "离开零血可蒂后进入史莱姆战")
	session.current_world.story_enemy_defeated.emit(&"slime")
	session.current_world.story_enemy_defeated.emit(&"slime")
	await process_frame
	check(session.story.current_id == "keti_memory_wait", "保护路线结束进入六秒等待")
	await create_timer(7.0, true).timeout
	print("AUDIT critical Keti route current_id=", session.story.current_id, " timer=", session.story.memory_timer_started, " pause=", session.pause_reasons)
	check(session.story.current_id in ["memory_blur_dialogue", "input_player_name"], "零血可蒂离开路线七秒后应完成呕吐并进入对白")
	session.queue_free()
	await process_frame

func _test_bandit_contact_and_reward_idempotency() -> void:
	var session := _new_session()
	await process_frame
	await session.load_map(&"forest", &"", true)
	session.story.current_id = "bandit_combat"
	await session.story.execute_command("startBanditCombat")
	await session.story.execute_command("waitBanditCombat")
	var buck := session.current_world.get_story_actor(&"buck")
	var miro := session.current_world.get_story_actor(&"miro")
	buck.take_damage(999.0, &"round3_audit")
	miro.take_damage(999.0, &"round3_audit")
	await process_frame
	check(bool(session.state.flags.get("bandit_contact_pending", false)), "劫匪全灭后只设置回触 pending")
	check(session.state.gold == 0, "劫匪倒地时不提前发钱")
	session.current_world.player.global_position = buck.global_position
	buck._physics_process(0.1)
	await process_frame
	print("AUDIT bandit contact current_id=", session.story.current_id, " pending=", session.state.flags.get("bandit_contact_pending", false))
	check(session.story.current_id == "bandit_search", "真实回触倒地劫匪进入搜刮")
	session.state.gold = 0
	await session.story.execute_command("claimBanditCombatReward")
	await session.story.execute_command("claimBanditCombatReward")
	check(session.state.gold == 6, "劫匪钱袋奖励重复执行仍只增加六金币")
	session.queue_free()
	await process_frame

func _test_dialogue_layout_contract() -> void:
	var box := (load("res://game/ui/dialogue_box.tscn") as PackedScene).instantiate() as PanelContainer
	root.add_child(box)
	var narrow_position: Vector2 = box.fit_to_viewport(Vector2(768, 480))
	check(is_equal_approx(box.size.x, 261.12), "768×480 对话框宽度固定为设计比例")
	check(narrow_position.x >= 0.0 and narrow_position.x + box.size.x <= 768.0 + 0.01, "编辑器基准视口对话框不越界")
	var wide_position: Vector2 = box.fit_to_viewport(Vector2(1366, 768))
	check(is_equal_approx(box.size.x, 360.0), "导出宽视口对话框宽度受最大值约束")
	check(wide_position.x >= 0.0 and wide_position.x + box.size.x <= 1366.0 + 0.01 and wide_position.y >= 0.0 and wide_position.y + box.size.y <= 768.0 + 0.01, "导出宽视口对话框不越界")
	var font := load("res://assets/fonts/fusion-pixel-10px-monospaced-zh_hans.ttf") as Font
	check(font != null and box.theme.get_default_font() == font, "编辑器与导出共享同一默认中文字体资源")
	box.queue_free()
	await process_frame
