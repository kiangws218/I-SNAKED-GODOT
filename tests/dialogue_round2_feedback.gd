extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var runner := DialogueRunner.new()
	var long_line := "第一句说完了。第二句继续说明这段对白会在句子边界分页，并且每页都有明确的继续节奏，同时保留玩家点击继续的输入语义。"
	var page := runner.begin("round2", {
		"speaker": "旁白",
		"pages": [{"text": long_line}],
		"choices": [{"id": "continue", "label": "继续"}],
	}, {"flags": {}}, Callable())
	var ok := true
	ok = _check(page.page_count > 1, "长对白按句界分页") and ok
	ok = _check(page.text == "第一句说完了。", "即使第一句较短也优先完整句界，不硬切下一句") and ok
	ok = _check(page.choices.is_empty(), "选项只出现在最后页") and ok
	while page.page + 1 < page.page_count:
		page = runner.advance_page()
	ok = _check(page.choices.size() == 1, "最后页保留选项") and ok
	for split_page in runner.dialogue.pages:
		ok = _check(String(split_page.text).length() <= DialogueRunner.MAX_PAGE_TEXT_LENGTH, "分页不超过长度上限") and ok
	var panel := DialoguePanel.new()
	root.add_child(panel)
	panel.show_dialogue([
		{"speaker": "旁白", "text": "点击继续的第一句。", "choices": []},
		{"speaker": "旁白", "text": "最后一句。", "choices": [{"id": "done", "label": "完成"}]},
	])
	for index in range(8): await process_frame
	panel._finish_enter()
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.position = panel.continue_button.get_global_rect().get_center()
	click.pressed = true
	root.push_input(click, true)
	var release := click.duplicate() as InputEventMouseButton
	release.pressed = false
	root.push_input(release, true)
	await process_frame
	ok = _check(panel.page_index == 1, "鼠标继续按钮推进下一页") and ok
	ok = _check(not panel.continue_button.visible and panel.choices.size() == 1, "继续按钮不伪装成最终选项") and ok
	panel.queue_free()
	if ok:
		print("DIALOGUE ROUND2 FEEDBACK PASSED")
		quit()
	else:
		quit(1)

func _check(condition: bool, message: String) -> bool:
	if not condition:
		push_error(message)
	return condition
