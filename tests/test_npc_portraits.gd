extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var panel := DialoguePanel.new()
	root.add_child(panel)
	for speaker in DialoguePanel.PORTRAIT_SPEAKERS:
		var id: String = DialoguePanel.PORTRAIT_SPEAKERS[speaker]
		var portraits: Dictionary = DialoguePanel.NPC_PORTRAITS[id]
		for expression in portraits:
			var texture := portraits[expression] as Texture2D
			assert(texture.get_size() == Vector2(128, 128))
			assert(texture.get_image().get_pixel(0, 0).a == 0.0)
			panel.show_dialogue([{"speaker": speaker, "expression": expression, "text": "头像检查"}])
			assert(panel.portrait.texture.atlas == texture)
			assert(panel.portrait.visible and panel.speaker_label.visible)
		panel.show_dialogue([{"speaker": speaker, "expression": "missing", "text": "默认回退"}])
		assert(panel.portrait.texture.atlas == portraits.neutral)
	panel.show_dialogue([{"speaker": "旁白", "text": "无头像"}])
	assert(not panel.panel.get_node("Layout/PortraitFrame").visible)
	assert(panel.panel.get_node("Layout/DividerFade").visible)
	print("NPC PORTRAIT TESTS PASSED: 5 characters, 45 expressions")
	quit(0)
