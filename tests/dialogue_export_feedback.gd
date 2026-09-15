extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var dialogue := DialoguePanel.new()
	root.add_child(dialogue)
	var choices: Array[Dictionary] = []
	for index in range(4):
		choices.append({"id": str(index), "label": "这是导出环境下也必须完整显示的窄宽四行长行动选项，不能向下错位，不能裁切末尾文字，且按钮高度必须跟随实际行数。"})
	dialogue.show_dialogue([{"speaker": "旁白", "text": "导出布局检查。", "choices": choices}])
	dialogue._finish_enter()
	for index in range(8):
		await process_frame
	var viewport := root.get_visible_rect()
	var panel_rect := dialogue.panel.get_global_rect()
	var ok := panel_rect.position.x >= -1.0 and panel_rect.position.y >= -1.0 and panel_rect.end.x <= viewport.end.x + 1.0 and panel_rect.end.y <= viewport.end.y + 1.0
	for button_node in dialogue.choices_box.get_children():
		var button := button_node as Button
		var label := button.get_child(0) as Label
		var button_rect := button.get_global_rect()
		var label_rect := label.get_global_rect()
		ok = label.get_line_count() >= 4 and label_rect.position.y >= button_rect.position.y and label_rect.end.y <= button_rect.end.y + 1.0 and label_rect.size.x <= button_rect.size.x - 19.0 and ok
	if ok:
		print("DIALOGUE EXPORT FEEDBACK PASSED")
		quit(0)
	else:
		push_error("导出布局中的选项标签超出按钮矩形")
		quit(1)
