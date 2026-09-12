extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var panel := DialoguePanel.new()
	root.add_child(panel)
	for expression in DialoguePanel.KETI_PORTRAITS:
		var texture := DialoguePanel.KETI_PORTRAITS[expression] as Texture2D
		assert(texture.get_size() == Vector2(128, 128))
		assert(texture.get_image().get_pixel(0, 0).a == 0.0)
		panel.show_dialogue([{"speaker": "可蒂", "expression": expression, "text": "预览"}])
		assert(panel.portrait.texture.atlas == texture and panel.portrait.visible and not panel.portrait_placeholder.visible)
		assert(panel.speaker_label.text == "可蒂")
	await process_frame
	await process_frame
	assert(panel.portrait.size.x == panel.portrait.size.y)
	assert(panel.portrait.get_parent().clip_contents)
	assert(not panel.panel.get_node("Layout/DividerFade").get_parent() is Container)
	panel.show_dialogue([{"speaker": "可蒂", "crying": true, "text": "害怕"}])
	assert(panel.portrait.texture.atlas == DialoguePanel.KETI_PORTRAITS.crying)
	panel.show_dialogue([{"speaker": "可蒂", "expression": "unknown", "text": "回退"}])
	assert(panel.portrait.texture.atlas == DialoguePanel.KETI_PORTRAITS.neutral)
	panel.show_dialogue([{"speaker": "我", "text": "玩家"}])
	assert(panel.portrait.texture.atlas == DialoguePanel.PLAYER_PORTRAIT)
	panel.show_dialogue([{"speaker": "旁白", "text": "不残留头像"}])
	assert(not panel.portrait.visible and panel.portrait_placeholder.visible)
	assert(not panel.panel.get_node("Layout/PortraitFrame").visible)
	assert(not panel.speaker_label.visible)
	assert(panel.panel.get_node("Layout/DividerFade").visible)
	panel.show_dialogue([{"speaker": "可蒂", "text": "恢复"}])
	assert(panel.panel.get_node("Layout/PortraitFrame").visible and panel.speaker_label.visible)
	panel.show_name_input()
	await process_frame
	await process_frame
	await process_frame
	assert(panel.name_edit.global_position.y > panel.body_label.global_position.y + panel.body_label.size.y + 24)
	assert(panel.name_edit.global_position.y + panel.name_edit.size.y <= panel.panel.global_position.y + panel.panel.size.y)
	var runner := DialogueRunner.new()
	var page := runner.begin("portrait_test", {"speaker": "可蒂", "portrait": "keti", "crying": true, "pages": ["你要吃掉我吗？"]}, {}, Callable())
	assert(page.expression == "crying" and page.portrait == "keti")
	panel.queue_free()
	await process_frame
	print("KETI PORTRAIT TESTS PASSED")
	quit(0)
