extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var dialogue := DialoguePanel.new()
	root.add_child(dialogue)
	var options: Array[Dictionary] = []
	for index in range(8):
		options.append({"id": str(index), "label": "这是一段很长的中文选项，需要完整换行显示，不能让按钮撑出屏幕，也不能隐藏末尾文字。"})
	dialogue.show_dialogue([{"speaker": "旁白", "text": "长段落正文。".repeat(20), "choices": options}])
	dialogue._finish_enter()
	await _settle()
	_check_layout(dialogue)
	dialogue._set_choice_index(7)
	await _settle()
	check(dialogue.content_scroll.scroll_vertical > 0, "键盘焦点可以滚动到末尾选项")
	dialogue.show_dialogue([{"speaker": "我", "text": "下一页", "choices": [{"id": "next", "label": "继续"}]}])
	await _settle()
	check(dialogue.choices_box.get_child_count() == 1, "旧页按钮立即移除，不混入新页焦点")
	dialogue.show_name_input()
	await _settle()
	check(dialogue.panel.get_global_rect().end.x <= root.get_visible_rect().size.x + 1, "命名输入不会撑宽对话框")
	dialogue.queue_free()
	await process_frame
	if failures.is_empty():
		print("DIALOGUE FEEDBACK TESTS PASSED")
		quit(0)
	else:
		for failure in failures: push_error(failure)
		quit(1)

func _settle() -> void:
	for index in range(8): await process_frame

func _check_layout(dialogue: DialoguePanel) -> void:
	var bounds := dialogue.panel.get_global_rect()
	var viewport := root.get_visible_rect().size
	check(bounds.position.x >= 0 and bounds.end.x <= viewport.x + 1 and bounds.end.y <= viewport.y + 1, "对话框完整位于视口内")
	for button in dialogue.choices_box.get_children():
		var label := button.get_child(0) as Label
		check(label.size.y + 20 <= button.size.y + 1, "选项按钮容纳换行文本与上下边距")
		check(label.size.x <= button.size.x - 19, "选项文字宽度受按钮约束")

func check(condition: bool, message: String) -> void:
	if not condition: failures.append(message)
