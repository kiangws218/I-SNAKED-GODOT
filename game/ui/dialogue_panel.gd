class_name DialoguePanel
extends CanvasLayer

signal choice_selected(choice_id: String)
signal name_submitted(player_name: String)

const ENTER_SECONDS := 0.18
const EXIT_SECONDS := 0.12
const UI_FONT := preload("res://assets/fonts/fusion-pixel-10px-monospaced-zh_hans.ttf")
const PLAYER_PORTRAIT := preload("res://assets/portraits/player_snake.png")
const INTERACT_AUDIO := preload("res://assets/audio/interact.wav")
const DIALOGUE_THEME := preload("res://game/ui/dialogue_theme.tres")
const DIVIDER_TEXTURE := preload("res://assets/ui/fantasy/dialogue/divider_fade.png")

var state: StringName = &"hidden"
var pages: Array[Dictionary] = []
var page_index := 0
var choices: Array[Dictionary] = []
var panel: PanelContainer
var speaker_label: Label
var sub_label: Label
var body_label: Label
var choices_box: VBoxContainer
var name_edit: LineEdit
var portrait: TextureRect
var portrait_placeholder: Label
var interact_audio: AudioStreamPlayer
var _tween: Tween
var _shown_position := Vector2.ZERO

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 20
	_build_ui()
	interact_audio = AudioStreamPlayer.new()
	interact_audio.stream = INTERACT_AUDIO
	interact_audio.bus = &"SFX"
	add_child(interact_audio)
	panel.visible = false

func show_dialogue(dialogue_pages: Array[Dictionary]) -> void:
	pages = dialogue_pages
	page_index = 0
	name_edit.visible = false
	_render_page()
	_enter()

func show_name_input() -> void:
	pages = [{"speaker": "旁白", "sub": "回忆名字", "text": "脑海中最后留下的名字是……", "choices": []}]
	page_index = 0
	_render_page()
	name_edit.text = ""
	name_edit.visible = true
	_enter()
	name_edit.call_deferred("grab_focus")

func close() -> void:
	if state == &"hidden" or state == &"exiting":
		return
	_kill_tween()
	state = &"exiting"
	_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_tween.set_parallel(true)
	_tween.tween_property(panel, "position", _shown_position + Vector2(64, 0), EXIT_SECONDS).set_trans(Tween.TRANS_CUBIC)
	_tween.tween_property(panel, "modulate:a", 0.0, EXIT_SECONDS)
	_tween.chain().tween_callback(_finish_exit)

func _unhandled_input(event: InputEvent) -> void:
	if state == &"hidden" or state == &"exiting" or not event.is_pressed() or (event is InputEventKey and event.echo):
		return
	if event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		if state == &"entering":
			_finish_enter()
			return
		if name_edit.visible:
			_submit_name()
			return
		if page_index + 1 < pages.size():
			page_index += 1
			_render_page()
		elif choices.size() == 1:
			choice_selected.emit(String(choices[0].id))
	elif event is InputEventKey and event.physical_keycode >= KEY_1 and event.physical_keycode <= KEY_9:
		var index := int(event.physical_keycode - KEY_1)
		if state == &"active" and index < choices.size():
			get_viewport().set_input_as_handled()
			choice_selected.emit(String(choices[index].id))

func _build_ui() -> void:
	panel = PanelContainer.new()
	panel.name = "DialogueBox"
	panel.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	panel.position = Vector2(-270, -185)
	panel.size = Vector2(250, 370)
	panel.theme = DIALOGUE_THEME
	panel.add_theme_font_override("font", UI_FONT)
	add_child(panel)
	_shown_position = panel.position
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	margin.add_child(box)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	box.add_child(header)
	var avatar_slot := Control.new()
	avatar_slot.custom_minimum_size = Vector2(46, 46)
	avatar_slot.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	header.add_child(avatar_slot)
	portrait = TextureRect.new()
	portrait.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	portrait.texture = PLAYER_PORTRAIT
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	avatar_slot.add_child(portrait)
	portrait_placeholder = Label.new()
	portrait_placeholder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	portrait_placeholder.text = "头像"
	portrait_placeholder.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	portrait_placeholder.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	portrait_placeholder.modulate = Color("9cc7d6")
	portrait_placeholder.add_theme_font_size_override("font_size", 12)
	avatar_slot.add_child(portrait_placeholder)
	var names := VBoxContainer.new()
	header.add_child(names)
	speaker_label = Label.new()
	speaker_label.add_theme_font_size_override("font_size", 24)
	names.add_child(speaker_label)
	sub_label = Label.new()
	sub_label.visible = false
	sub_label.modulate = Color("9cc7d6")
	names.add_child(sub_label)
	var divider := TextureRect.new()
	divider.name = "DividerFade"
	divider.custom_minimum_size = Vector2(0, 10)
	divider.texture = DIVIDER_TEXTURE
	divider.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	divider.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	divider.stretch_mode = TextureRect.STRETCH_SCALE
	divider.modulate = Color(0.68, 0.94, 0.66, 0.82)
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(divider)
	body_label = Label.new()
	body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body_label.custom_minimum_size = Vector2(210, 150)
	body_label.add_theme_font_size_override("font_size", 18)
	box.add_child(body_label)
	choices_box = VBoxContainer.new()
	box.add_child(choices_box)
	name_edit = LineEdit.new()
	name_edit.placeholder_text = "输入名字（空白则为“未命名”）"
	name_edit.text_submitted.connect(func(_value): _submit_name())
	box.add_child(name_edit)

func _render_page() -> void:
	if pages.is_empty():
		return
	var page := pages[page_index]
	speaker_label.text = String(page.get("speaker", "旁白"))
	portrait.visible = speaker_label.text == "我"
	portrait_placeholder.visible = not portrait.visible
	sub_label.text = String(page.get("sub", ""))
	sub_label.visible = false
	body_label.text = String(page.get("text", ""))
	if DisplayServer.get_name() != "headless" and is_instance_valid(interact_audio): interact_audio.play()
	choices.assign(page.get("choices", []))
	for child in choices_box.get_children():
		child.queue_free()
	for index in range(choices.size()):
		var choice := choices[index]
		var button := Button.new()
		button.text = "%d. %s" % [index + 1, choice.get("label", "继续")]
		button.pressed.connect(func(id = String(choice.id)): choice_selected.emit(id))
		choices_box.add_child(button)

func _enter() -> void:
	_kill_tween()
	panel.visible = true
	panel.position = _shown_position + Vector2(72, 0)
	panel.modulate.a = 0.0
	panel.scale = Vector2(0.97, 0.97)
	state = &"entering"
	_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_tween.set_parallel(true)
	_tween.tween_property(panel, "position", _shown_position, ENTER_SECONDS).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_property(panel, "modulate:a", 1.0, ENTER_SECONDS)
	_tween.tween_property(panel, "scale", Vector2.ONE, ENTER_SECONDS)
	_tween.chain().tween_callback(_finish_enter)

func _finish_enter() -> void:
	if state != &"entering":
		return
	_kill_tween()
	panel.position = _shown_position
	panel.modulate.a = 1.0
	panel.scale = Vector2.ONE
	state = &"active"

func _finish_exit() -> void:
	panel.visible = false
	state = &"hidden"

func _submit_name() -> void:
	if state != &"active":
		return
	var value := name_edit.text.strip_edges()
	name_submitted.emit(value if not value.is_empty() else "未命名")

func _kill_tween() -> void:
	if is_instance_valid(_tween):
		_tween.kill()
