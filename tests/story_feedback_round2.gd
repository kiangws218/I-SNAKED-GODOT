extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func check(value: bool, message: String) -> void:
	if not value: failures.append(message)

func _new_session() -> GameSession:
	var session := (load("res://game/main.tscn") as PackedScene).instantiate() as GameSession
	root.add_child(session)
	return session

func _run() -> void:
	var session := _new_session()
	await process_frame
	await session.load_map(&"wilderness", &"", true)
	session.story.current_id = "wilderness_keti_wait"
	var keti := session.current_world.get_story_actor(&"keti")
	session.current_world.player.set_physics_process(false)
	keti.set_physics_process(false)
	session.current_world.player.global_position = keti.global_position + Vector2(240, 0)
	for i in range(3): await physics_frame
	session.current_world.player.global_position = keti.global_position
	keti._physics_process(0.1)
	await process_frame
	check(session.story.current_id == "keti_question", "反馈2：真实头触可蒂进入初次对白")
	session.current_world.finish_actor_interaction()
	session.dialogue.close()
	session.set_pause_reason(&"dialogue", false)
	session.story.current_id = "ignored_contact_probe"
	_touch(keti)
	check(not keti.interaction_open and session.current_world.active_npc == null, "忽略的头触释放人物与世界互动锁")
	await create_timer(0.2, true).timeout

	session.story.current_id = "wilderness_slimes"
	session.story.combat_kind = &"slime"
	session.story.enemies_left = 2
	session.story.encounter_expected = 2
	session.current_world.story_enemy_defeated.emit(&"slime")
	session.current_world.story_enemy_defeated.emit(&"slime")
	await process_frame
	check(session.story.current_id == "free_explore" and bool(session.state.flags.get("keti_rescue_pending", false)), "反馈2：史莱姆结束不自动弹可蒂对白")
	session.story.resume()
	await create_timer(6.2, true).timeout
	check(session.story.current_id == "free_explore", "反馈2：pending读档不启动旧六秒计时器")
	check(not session.story.memory_timer_started and session.dialogue.state == &"hidden", "等待回触期间不启动记忆演出或自动对白")
	_touch(keti)
	check(session.story.current_id == "keti_saved", "史莱姆战后真实回触可蒂才继续对白")
	session.queue_free()
	paused = false
	await process_frame

	var forest := _new_session()
	await process_frame
	await forest.load_map(&"forest", &"", true)
	forest.story.current_id = "bandit_combat"
	await forest.story.execute_command("startBanditCombat")
	await forest.story.execute_command("waitBanditCombat")
	var buck := forest.current_world.get_story_actor(&"buck")
	var miro := forest.current_world.get_story_actor(&"miro")
	buck.take_damage(999, &"feedback")
	miro.take_damage(999, &"feedback")
	await process_frame
	check(forest.story.current_id == "chapter1_explore" and bool(forest.state.flags.get("bandit_contact_pending", false)), "反馈6：巴克米罗倒地不自动搜刮对白")
	check(forest.state.gold == 0, "回触劫匪之前不发奖励")
	forest.current_world.player.global_position = buck.global_position
	buck._physics_process(0.1)
	await process_frame
	check(forest.story.current_id == "bandit_search", "反馈6：真实接触倒地劫匪才进入搜刮")
	forest.state.gold = 0
	await forest.story.execute_command("claimBanditCombatReward")
	await forest.story.execute_command("claimBanditCombatReward")
	check(forest.state.gold == 6, "反馈6：搜刮奖励幂等")
	forest.queue_free()
	paused = false
	await process_frame

	var state := SessionState.new()
	state.actors.ajian = {"status": "critical", "location": "cave", "hp": 3.0, "max_hp": 8.0, "met": true}
	var inactive_map := StoryMap.new()
	root.add_child(inactive_map)
	inactive_map.setup(&"forest", {}, &"", {}, state.actors, {})
	inactive_map.capture_actor_states()
	check(String(state.actors.ajian.location) == "cave" and is_equal_approx(float(state.actors.ajian.hp), 3.0), "反馈6：森林inactive阿见不覆盖洞窟持久状态")
	inactive_map.queue_free()

	var rescue := SessionState.new()
	rescue.flags["ajianFound"] = true
	rescue.flags["goblinsDefeated"] = true
	rescue.actors.ajian.status = "riding"
	rescue.actors.ajie = {"status": "alive", "location": "cave", "hp": 5.0, "max_hp": 8.0, "met": true, "hostile": false}
	rescue.actors.lisi = {"status": "alive", "location": "cave", "hp": 6.0, "max_hp": 8.0, "met": true, "hostile": false}
	check(rescue.prepare_released_pair_forest_return(true), "反馈6：洞窟获救返回触发营地迁移")
	check(rescue.actors.ajie.spawn_anchor == "camp_return_ajie" and rescue.actors.lisi.spawn_anchor == "camp_return_lisi" and rescue.actors.ajie.hp == 5.0 and rescue.actors.lisi.hp == 6.0, "反馈6：营地锚点和HP保持")
	rescue.actors.ajie.position = [123, 456]
	check(not rescue.prepare_released_pair_forest_return(true) and rescue.actors.ajie.position == [123, 456], "回营迁移一次性锁定，重入不覆盖新位置")
	var invalid := SessionState.new()
	invalid.actors.ajian.status = "riding"
	invalid.actors.ajie.hostile = true
	invalid.actors.ajie.met = true
	invalid.actors.lisi.status = "dead"
	var original_actors := invalid.actors.duplicate(true)
	check(not invalid.prepare_released_pair_forest_return(true) and invalid.actors == original_actors, "hostile与dead人物都不被回营逻辑改写")
	await _test_actual_camp_return()
	await _test_held_mount()

	if failures.is_empty():
		print("STORY FEEDBACK ROUND 2 TESTS PASSED")
		quit(0)
	else:
		for failure in failures: push_error(failure)
		quit(1)

func _touch(npc: NpcActor) -> void:
	var player := npc.player
	player.global_position = npc.global_position + Vector2(80, 0)
	npc.setup(player)
	npc._physics_process(0.016)
	player.global_position = npc.global_position + Vector2(0, 12)
	npc._physics_process(0.016)

func _test_actual_camp_return() -> void:
	var session := _new_session()
	session.state.flags["chapter1MeetingSeen"] = true
	session.state.flags["findAjianAccepted"] = true
	session.state.actors.ajie.hp = 5.0
	session.state.actors.lisi.hp = 6.0
	# Old saves may have the quest flag without actor.met: accept that evidence.
	session.state.actors.ajian.status = "alive"
	await session.load_map(&"cave", &"", true, false)
	session.current_world.player.set_physics_process(false)
	var mounted := await session.story.execute_command("mountAjian")
	check(mounted.ok and session.state.player.rider == "ajian", "实际演出后才提交阿见骑乘")
	session.story.map_exit(&"forest", &"forest_cave_return")
	await session.load_map(&"forest", &"forest_cave_return")
	session.current_world.player.set_physics_process(false)
	var ajie := session.current_world.get_story_actor(&"ajie")
	var lisi := session.current_world.get_story_actor(&"lisi")
	check(ajie.global_position.distance_to(Vector2(1692, 1068)) < 5 and lisi.global_position.distance_to(Vector2(1740, 1068)) < 5, "实际洞窟返回将两名同伴移至营地近距离队形")
	check(ajie.hp == 5 and lisi.hp == 6 and bool(session.state.actors.ajie.met), "实际换图保留生命并兼容旧任务认识标记")
	var rider := session.current_world.get_story_actor(&"ajian")
	check(rider.is_riding() and rider.hp == float(session.state.actors.ajian.hp), "骑乘跨图恢复同一生命状态")
	_touch(ajie)
	check(session.story.current_id.begins_with("camp_") and session.story.current_id != "chapter1_meeting", "回营头触触发营地状态而非初见")
	session.state.flags["campRewardClaimed"] = true
	session.state.flags["campRewardKind"] = "lick"
	session.current_world.finish_actor_interaction()
	session.story.current_id = "chapter1_explore"
	_touch(ajie)
	check(session.story.current_id == "camp_followup" and not "十枚金币" in session.dialogue.body_label.text, "非金币结算也不会谎报拿钱或重播初见")
	ajie.global_position += Vector2(36, 0)
	var moved_position := ajie.global_position
	session.dialogue.close()
	session.pause_reasons.clear()
	paused = false
	await session.load_map(&"forest", &"", true)
	check(session.current_world.get_story_actor(&"ajie").global_position.distance_to(moved_position) < 5, "营地锚点只用一次，重建地图保存人物新的游走位置")
	session.queue_free()
	paused = false
	await process_frame

func _test_held_mount() -> void:
	var session := _new_session()
	session.state.actors.ajian.status = "alive"
	session.state.actors.ajian.hp = 5.0
	await session.load_map(&"cave", &"", true, false)
	var player := session.current_world.player
	player.set_physics_process(false)
	player.set_length(8)
	var swallowed := await session.story.execute_command("swallowAjian")
	check(swallowed.ok and player.inventory.count_item(&"ajian") == 1, "胃袋登蛇分支准备持有唯一阿见")
	var mounted := await session.story.execute_command("mountAjian")
	var rider := session.current_world.get_story_actor(&"ajian")
	check(mounted.ok and rider.is_riding() and rider.hp == 5 and player.inventory.count_item(&"ajian") == 0, "胃袋阿见先释放再走近登蛇，不复制人物或重置生命")
	session.queue_free()
	paused = false
	await process_frame
