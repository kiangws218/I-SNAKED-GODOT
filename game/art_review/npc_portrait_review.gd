extends Node2D

const IDS := ["ajian", "ajie", "buck", "lisi", "miro"]
const SPEAKERS := ["阿见", "阿杰", "巴克", "丽丝", "米罗"]
const EXPRESSIONS := ["neutral", "happy", "angry", "blushing", "crying", "surprised", "tired", "smug", "terrified"]
var character_index := 0
var expression_index := 0
var dialogue: DialoguePanel

func _ready() -> void:
	var ui := CanvasLayer.new()
	add_child(ui)
	for row in range(5):
		for column in range(9):
			var picture := TextureRect.new()
			picture.texture = DialoguePanel.NPC_PORTRAITS[IDS[row]][EXPRESSIONS[column]]
			picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			picture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			picture.position = Vector2(8 + column * 52, 24 + row * 88)
			ui.add_child(picture)
			picture.size = Vector2(48, 64)
	dialogue = DialoguePanel.new()
	add_child(dialogue)
	dialogue.choice_selected.connect(func(id):
		if id == "character": character_index = (character_index + 1) % 5
		else: expression_index = (expression_index + 1) % 9
		_show())
	_show()
	if OS.get_cmdline_user_args().has("--capture-review"):
		await get_tree().create_timer(0.4).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../npc_portrait_review.png"))
		get_tree().quit()

func _show() -> void:
	dialogue.show_dialogue([{"speaker": SPEAKERS[character_index], "expression": EXPRESSIONS[expression_index], "text": "头像审阅：" + EXPRESSIONS[expression_index], "choices": [{"id": "character", "label": "下一个角色"}, {"id": "expression", "label": "下一种表情"}]}])
