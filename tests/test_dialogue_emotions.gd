extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var runner := DialogueRunner.new()
	assert(runner.load_graph().ok)
	var allowed := ["neutral", "happy", "angry", "blushing", "crying", "surprised", "tired", "smug", "terrified"]
	var count := 0
	for id in runner.nodes:
		var node: Dictionary = runner.nodes[id]
		if not node.has("dialogue"): continue
		var source_pages: Array = node.dialogue.get("pages", [])
		assert(runner.emotion_tags.has(id), "Missing emotion labels: " + id)
		assert(runner.emotion_tags[id].size() == source_pages.size(), "Stale label count: " + id)
		var page := runner.begin(id, node.dialogue, {}, Callable())
		while not page.is_empty():
			assert(page.emotion in allowed and page.expression in allowed)
			assert(page.emotion == runner.emotion_tags[id][page.source_page])
			assert(page.text.length() <= DialogueRunner.MAX_PAGE_TEXT_LENGTH)
			if page.page + 1 >= page.page_count: break
			page = runner.advance_page()
		count += source_pages.size()
	var split := runner.begin("explicit_test", {"speaker": "阿见", "pages": [{"text": "很长的测试台词。".repeat(12), "emotion": "blushing", "portrait": "ajian"}]}, {}, Callable())
	assert(split.page_count > 1)
	assert(split.expression == "blushing" and split.portrait == "ajian")
	assert(runner.advance_page().emotion == "blushing")
	var panel := DialoguePanel.new()
	root.add_child(panel)
	panel.show_dialogue([{"speaker": "旁白", "text": "事件描述"}])
	panel.set_presentation_expression("surprised", "ajian")
	assert(panel.portrait.texture.atlas == DialoguePanel.NPC_PORTRAITS.ajian.surprised)
	assert(panel.panel.get_node("Layout/PortraitFrame").visible)
	panel.show_dialogue([{"speaker": "少女", "expression": "blushing", "text": "后续对白"}])
	assert(panel.portrait.texture.atlas == DialoguePanel.NPC_PORTRAITS.ajian.blushing)
	panel.set_presentation_expression("surprised")
	assert(panel.portrait.texture.atlas == DialoguePanel.NPC_PORTRAITS.ajian.surprised)
	panel.show_dialogue([{"speaker": "旁白", "text": "结束"}])
	assert(not panel.panel.get_node("Layout/PortraitFrame").visible)
	print("DIALOGUE EMOTION TESTS PASSED: ", count, " original pages + CG override")
	quit(0)
