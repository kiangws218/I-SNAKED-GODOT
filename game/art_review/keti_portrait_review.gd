extends Node2D

var dialogue: DialoguePanel
var expression_index := 0
const EXPRESSIONS := ["neutral", "happy", "angry", "blushing", "crying", "surprised", "tired", "smug", "terrified"]

func _ready() -> void:
	var ui := CanvasLayer.new()
	add_child(ui)
	for index in range(9):
		var portrait := TextureRect.new()
		portrait.texture = DialoguePanel.KETI_PORTRAITS[EXPRESSIONS[index]]
		portrait.position = Vector2(16 + (index % 3) * 92, 56 + (index / 3) * 136)
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.size = Vector2(80, 80)
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		ui.add_child(portrait)
		portrait.size = Vector2(80, 80)
		var label := Label.new()
		label.text = EXPRESSIONS[index]
		label.position = portrait.position + Vector2(0, 82)
		label.add_theme_font_size_override("font_size", 12)
		ui.add_child(label)
	dialogue = DialoguePanel.new()
	add_child(dialogue)
	dialogue.choice_selected.connect(func(_id):
		expression_index = (expression_index + 1) % 9
		_show_expression())
	_show_expression()
	if OS.get_cmdline_user_args().has("--capture-review"):
		await get_tree().create_timer(0.4).timeout
		await RenderingServer.frame_post_draw
		var path := ProjectSettings.globalize_path("res://").path_join("../keti_portrait_review.png").simplify_path()
		get_tree().quit(get_viewport().get_texture().get_image().save_png(path))

func _show_expression() -> void:
	dialogue.show_dialogue([{"speaker": "可蒂", "portrait": "keti", "expression": EXPRESSIONS[expression_index], "text": "这是可蒂的头像预览。\n当前表情：" + EXPRESSIONS[expression_index], "choices": [{"id": "next", "label": "下一种表情"}]}])
