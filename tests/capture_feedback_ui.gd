extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("UI capture requires a rendering display, not --headless")
		quit(1)
		return
	var dialogue := DialoguePanel.new()
	root.add_child(dialogue)
	dialogue.show_dialogue([{
		"speaker": "旁白", "text": "饥饿压过了思考，你的视线不由自主地落到了眼前的人身上。该如何选择？",
		"choices": [
			{"id": "a", "label": "吃掉可蒂，然后继续探索这个陌生的世界"},
			{"id": "b", "label": "吃掉所有豆子，但是不要伤害眼前的人"},
			{"id": "c", "label": "吐出身上的物品，留下来想想其他办法"},
		]
	}])
	await create_timer(0.5).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot/feedback_dialogue.png")
	print("DIALOGUE RECT: ", dialogue.panel.get_global_rect())
	for button in dialogue.choices_box.get_children():
		var label := button.get_child(0) as Label
		print("CHOICE: ", button.size, " LABEL: ", label.size, " MIN: ", label.get_combined_minimum_size())
	dialogue._set_choice_index(2)
	await create_timer(0.2).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot/feedback_dialogue_scrolled.png")
	dialogue.queue_free()
	var death := preload("res://game/ui/death_screen.tscn").instantiate()
	root.add_child(death)
	death.show_screen(true)
	await create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot/feedback_death.png")
	quit()
