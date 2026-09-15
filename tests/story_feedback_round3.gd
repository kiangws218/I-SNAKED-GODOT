extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func check(value: bool, message: String) -> void:
	if not value: failures.append(message)

func _session() -> GameSession:
	var value := (load("res://game/main.tscn") as PackedScene).instantiate() as GameSession
	root.add_child(value)
	return value

func _run() -> void:
	var session := _session()
	await process_frame
	await session.load_map(&"wilderness", &"", true)
	session.story.current_id = "wilderness_keti_wait"
	var keti := session.current_world.get_story_actor(&"keti")
	keti.take_damage(999.0, &"round3")
	await process_frame
	check(session.story.current_id == "wilderness_keti_wait" and String(session.state.actors.keti.status) == "critical" and keti.visible and keti.is_downed, "可蒂归零后保持濒死可见")
	keti.take_damage(999.0, &"round3_again")
	check(is_zero_approx(keti.hp), "可蒂濒死后不可继续扣血")
	var restored := SessionState.new()
	check(restored.load_dictionary(session.state.to_dictionary()).ok and String(restored.actors.keti.status) == "critical", "可蒂濒死状态可读档保持")
	session.current_world.player.global_position = keti.global_position + Vector2(200, 0)
	for i in range(3): await physics_frame
	session.current_world.player.global_position = keti.global_position
	keti._physics_process(0.1)
	await process_frame
	check(session.story.current_id == "keti_dead", "濒死可蒂头触进入吃掉/离开选择")
	session.dialogue._finish_enter()
	await session.story._on_choice("leave")
	await process_frame
	session.pause_reasons.clear()
	paused = false
	check(session.story.current_id == "wilderness_slimes" and session.story.enemies_left == 2, "离开濒死可蒂后正常生成史莱姆")
	session.current_world.story_enemy_defeated.emit(&"slime")
	session.current_world.story_enemy_defeated.emit(&"slime")
	await process_frame
	check(session.story.current_id == "keti_memory_wait", "史莱姆结束后进入六秒呕吐等待")
	check(session.story.memory_timer_started, "史莱姆清场后已启动六秒计时")
	session.story.memory_timer_started = false
	session.story.notify(&"TIMER_EXPIRED")
	await process_frame
	check(session.story.current_id in ["memory_blur", "memory_blur_dialogue"], "计时结束后开始呕吐剧情")
	session.queue_free()
	await process_frame

	var forest := _session()
	await process_frame
	await forest.load_map(&"forest", &"", true)
	forest.story.current_id = "bandit_combat"
	await forest.story.execute_command("startBanditCombat")
	await forest.story.execute_command("waitBanditCombat")
	forest.current_world.get_story_actor(&"buck").take_damage(999, &"round3")
	forest.current_world.get_story_actor(&"miro").take_damage(999, &"round3")
	await process_frame
	check(forest.story.current_id == "chapter1_explore" and bool(forest.state.flags.get("bandit_contact_pending", false)), "巴克米罗战后不自动搜刮")
	var buck := forest.current_world.get_story_actor(&"buck")
	forest.current_world.player.global_position = buck.global_position
	buck._physics_process(0.1)
	await process_frame
	check(forest.story.current_id == "bandit_search", "战后首次接触进入搜刮奖励")
	forest.state.gold = 0
	await forest.story.execute_command("claimBanditCombatReward")
	await forest.story.execute_command("claimBanditCombatReward")
	check(forest.state.gold == 6, "巴克米罗战后奖励幂等")
	forest.story.current_id = "chapter1_explore"
	forest.story._on_actor_event(&"buck", &"interacted")
	await process_frame
	check(forest.story.current_id == "bandit_buck_unconscious", "领取后再次接触只显示昏迷")
	forest.queue_free()

	if failures.is_empty():
		print("STORY FEEDBACK ROUND 3 TESTS PASSED")
		quit(0)
	for failure in failures: push_error(failure)
	quit(1)
