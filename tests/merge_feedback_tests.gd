extends SceneTree

var failures: Array[String] = []
var exit_count := 0
var status_message := ""

func _initialize() -> void:
	_run.call_deferred()

func check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)

func _run() -> void:
	# Exercise real Area2D overlap and the gate's opened signal.
	var map := StoryMap.new()
	root.add_child(map)
	map.setup(&"prologue_tutorial", {})
	map.player.set_physics_process(false)
	var exit_area := map.get_node("MapLayout/Triggers/ExitToWilderness") as MapExit
	exit_area.required_flag = &"tutorial_fragile_gate"
	map.exit_reached.connect(func(_target: StringName, _entry: StringName): exit_count += 1)
	map.player.global_position = exit_area.global_position
	for i in range(4):
		await physics_frame
	check(exit_area.overlaps_body(map.player) and exit_count == 0, "玩家在锁定出口内不换图")
	var gate := map.get_node("MapLayout/Interactables/TutorialFragileGate") as FragileGate
	var bean := (load("res://game/projectiles/bean_projectile.tscn") as PackedScene).instantiate() as BeanProjectile
	root.add_child(bean)
	for i in range(3):
		gate.hit_by_bean(bean)
	check(exit_count == 1, "门打开时出口内玩家立即触发一次换图请求")
	bean.queue_free()
	map.queue_free()
	await process_frame

	# Drive a full-stomach choice through the production dialogue button signal.
	var session := (load("res://game/main.tscn") as PackedScene).instantiate() as GameSession
	root.add_child(session)
	await process_frame
	session.menus.hide_all()
	await session.load_map(&"forest", &"", true, false)
	session.current_world.player.set_physics_process(false)
	for i in range(3):
		check(session.current_world.player.add_special_item(&"iron_sword"), "填满胃袋的测试准备成功")
	session.story.status_changed.connect(func(message: String): status_message = message)
	await session.story.enter_node("chapter1_meeting_hunger")
	await create_timer(0.25, true).timeout
	while session.dialogue.page_index + 1 < session.dialogue.pages.size():
		session.dialogue.continue_button.pressed.emit()
	var eat_button: Button
	for i in range(session.dialogue.choices.size()):
		if String(session.dialogue.choices[i].id) == "eat_ajie":
			eat_button = session.dialogue.choices_box.get_child(i) as Button
	check(eat_button != null, "生产对话显示吞入阿杰选项")
	if eat_button != null:
		eat_button.pressed.emit()
	await process_frame
	check(session.dialogue.state == &"active" and paused, "吞入失败后对话保持可操作且世界继续暂停")
	check(status_message == "胃袋已满，请先吐出物品或角色", "吞入失败明确提示胃袋容量")
	check(session.story.current_id == "chapter1_meeting_hunger", "吞入失败不跳转剧情")
	check(session.current_world.get_story_actor(&"ajie") != null and session.current_world.player.inventory.count_item(&"ajie") == 0, "吞入失败保持角色唯一身份")
	session.return_to_title()
	await create_timer(0.3, true).timeout
	session.queue_free()
	await process_frame
	if failures.is_empty():
		print("MERGE FEEDBACK TESTS PASSED")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)
