class_name DialoguePanel
extends CanvasLayer

signal choice_selected(choice_id: String)
signal name_submitted(player_name: String)

const ENTER_SECONDS := 0.18
const EXIT_SECONDS := 0.12
const UI_FONT := preload("res://assets/fonts/fusion-pixel-10px-monospaced-zh_hans.ttf")
const PLAYER_PORTRAIT := preload("res://assets/portraits/player_snake.png")
const KETI_PORTRAITS := {
	"neutral": preload("res://assets/portraits/keti/neutral.png"),
	"happy": preload("res://assets/portraits/keti/happy.png"),
	"angry": preload("res://assets/portraits/keti/angry.png"),
	"blushing": preload("res://assets/portraits/keti/blushing.png"),
	"crying": preload("res://assets/portraits/keti/crying.png"),
	"surprised": preload("res://assets/portraits/keti/surprised.png"),
	"tired": preload("res://assets/portraits/keti/tired.png"),
	"smug": preload("res://assets/portraits/keti/smug.png"),
	"terrified": preload("res://assets/portraits/keti/terrified.png"),
}
const INTERACT_AUDIO := preload("res://assets/audio/interact.wav")
const DIALOGUE_THEME := preload("res://game/ui/dialogue_theme.tres")
const DIVIDER_TEXTURE := preload("res://assets/ui/fantasy/dialogue/divider_fade.png")

var state: StringName = &"hidden"
var pages: Array[Dictionary] = []
var page_index := 0
var choices: Array[Dictionary] = []
var selected_choice_index := 0
var panel: PanelContainer
var speaker_label: Label
var sub_label: Label
var body_label: Label
var choices_box: VBoxContainer
var name_edit: LineEdit
var continue_button: Button
var content_scroll: ScrollContainer
var content_box: VBoxContainer
var portrait: TextureRect
var portrait_placeholder: Label
var _portrait_regions: Dictionary = {}
var interact_audio: AudioStreamPlayer
var _tween: Tween
var _shown_position := Vector2.ZERO

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 20
	_build_ui()
	get_viewport().size_changed.connect(_layout_panel)
	_layout_panel()
	interact_audio = AudioStreamPlayer.new()
	interact_audio.stream = INTERACT_AUDIO
	interact_audio.bus = &"SFX"
	add_child(interact_audio)
	panel.visible = false

func show_dialogue(dialogue_pages: Array[Dictionary]) -> void:
	pages = dialogue_pages
	page_index = 0
	selected_choice_index = 0
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
		_advance_page_or_choice()
	elif state == &"active" and not name_edit.visible and not choices.is_empty() and event.is_action_pressed("move_up"):
		get_viewport().set_input_as_handled()
		_set_choice_index(selected_choice_index - 1)
	elif state == &"active" and not name_edit.visible and not choices.is_empty() and event.is_action_pressed("move_down"):
		get_viewport().set_input_as_handled()
		_set_choice_index(selected_choice_index + 1)
	elif event is InputEventKey and event.physical_keycode >= KEY_1 and event.physical_keycode <= KEY_9:
		var index := int(event.physical_keycode - KEY_1)
		if state == &"active" and index < choices.size():
			get_viewport().set_input_as_handled()
			_set_choice_index(index)

func _build_ui() -> void:
	panel = (load("res://game/ui/dialogue_box.tscn") as PackedScene).instantiate() as PanelContainer
	add_child(panel)
	speaker_label = panel.get_node("Layout/SpeakerName")
	sub_label = panel.get_node("Layout/SubLabel")
	portrait = panel.get_node("Layout/PortraitFrame/PortraitClip/Portrait")
	portrait_placeholder = panel.get_node("Layout/PortraitFrame/PortraitClip/PortraitPlaceholder")
	content_scroll = panel.get_node("Layout/ContentScroll")
	content_box = panel.get_node("Layout/ContentScroll/Content")
	body_label = content_box.get_node("BodyText")
	choices_box = content_box.get_node("Choices")
	name_edit = content_box.get_node("NameInput")
	name_edit.text_submitted.connect(func(_value): _submit_name())
	continue_button = Button.new()
	continue_button.name = "ContinuePage"
	continue_button.text = "继续"
	continue_button.focus_mode = Control.FOCUS_ALL
	continue_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	continue_button.custom_minimum_size = Vector2(0, 36)
	continue_button.pressed.connect(_advance_page_or_choice)
	content_box.add_child(continue_button)

func _layout_panel() -> void:
	if not is_instance_valid(panel):
		return
	var viewport_size := get_viewport().get_visible_rect().size
	_shown_position = panel.call("fit_to_viewport", viewport_size)
	if state == &"hidden" or state == &"active":
		panel.position = _shown_position
	if is_instance_valid(choices_box):
		call_deferred("_refresh_choice_layout")

func _render_page() -> void:
	if pages.is_empty():
		return
	var page := pages[page_index]
	var speaker := String(page.get("speaker", "旁白"))
	speaker_label.text = speaker
	portrait.texture = null
	if speaker == "我":
		portrait.texture = PLAYER_PORTRAIT
	elif speaker == "可蒂" or String(page.get("portrait", "")) == "keti":
		var expression := String(page.get("expression", "crying" if bool(page.get("crying", false)) else "neutral"))
		portrait.texture = KETI_PORTRAITS.get(expression, KETI_PORTRAITS.neutral)
	portrait.visible = portrait.texture != null
	portrait_placeholder.visible = not portrait.visible
	var narration := speaker == "旁白"
	panel.get_node("Layout/PortraitFrame").visible = not narration
	speaker_label.visible = not narration
	panel.get_node("Layout/DividerFade").visible = true
	_center_portrait()
	sub_label.text = String(page.get("sub", ""))
	sub_label.visible = false
	body_label.text = String(page.get("text", ""))
	continue_button.visible = page_index + 1 < pages.size() and not name_edit.visible
	if DisplayServer.get_name() != "headless" and is_instance_valid(interact_audio): interact_audio.play()
	choices.assign(page.get("choices", []))
	selected_choice_index = 0
	for child in choices_box.get_children():
		choices_box.remove_child(child)
		child.queue_free()
	for index in range(choices.size()):
		var choice := choices[index]
		var button := Button.new()
		var choice_text := "%d. %s" % [index + 1, choice.get("label", "继续")]
		button.custom_minimum_size = Vector2(0, 36)
		button.focus_mode = Control.FOCUS_ALL
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var choice_label := Label.new()
		choice_label.text = choice_text
		choice_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		choice_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		choice_label.set_anchors_preset(Control.PRESET_FULL_RECT)
		choice_label.offset_left = 10.0
		choice_label.offset_top = 10.0
		choice_label.offset_right = -10.0
		choice_label.offset_bottom = -10.0
		choice_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		choice_label.add_theme_font_size_override("font_size", 18)
		button.add_child(choice_label)
		button.focus_entered.connect(func(i = index): _set_choice_index(i, false))
		button.mouse_entered.connect(func(i = index): _set_choice_index(i, true))
		button.pressed.connect(func(i = index): choice_selected.emit(String(choices[i].id)))
		choices_box.add_child(button)
	if not choices.is_empty() and state == &"active":
		_set_choice_index(0)
	call_deferred("_refresh_choice_layout")

func _advance_page_or_choice() -> void:
	if state == &"entering":
		_finish_enter()
		return
	if state != &"active": return
	if name_edit.visible:
		_submit_name()
		return
	if page_index + 1 < pages.size():
		page_index += 1
		_render_page()
		return
	if not choices.is_empty():
		choice_selected.emit(String(choices[selected_choice_index].id))

func _center_portrait() -> void:
	if portrait.texture == null:
		return
	var source := portrait.texture
	if not _portrait_regions.has(source):
		var region := source.get_image().get_used_rect()
		# Share bounds across Keti expressions to avoid facial animation jitter.
		if source in KETI_PORTRAITS.values():
			for expression_texture in KETI_PORTRAITS.values():
				region = region.merge(expression_texture.get_image().get_used_rect())
		var centered := AtlasTexture.new()
		centered.atlas = source
		centered.region = region
		_portrait_regions[source] = centered
	portrait.texture = _portrait_regions[source]
	# Align to the visible frame, not the differently padded source canvases.
	var border := panel.get_node("Layout/PortraitFrame/Border") as Control
	var clip := portrait.get_parent() as Control
	clip.position = border.position + Vector2(2, 2)
	clip.size = border.size - Vector2(4, 4)
	portrait.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

func _refresh_choice_layout() -> void:
	if is_instance_valid(content_box) and is_instance_valid(content_scroll):
		content_box.custom_minimum_size.y = content_scroll.size.y
	if not is_instance_valid(choices_box):
		return
	if choices_box.size.x <= 1.0:
		return
	for child in choices_box.get_children():
		var button := child as Button
		if not is_instance_valid(button) or button.get_child_count() == 0:
			continue
		var choice_label := button.get_child(0) as Label
		if not is_instance_valid(choice_label):
			continue
		var button_width := button.size.x if button.size.x > 1.0 else choices_box.size.x
		var label_width := maxf(1.0, button_width - 20.0)
		var label_height := UI_FONT.get_multiline_string_size(choice_label.text, HORIZONTAL_ALIGNMENT_LEFT, label_width, 18).y
		var line_count := maxi(1, ceili(label_height / UI_FONT.get_height(18)))
		label_height += choice_label.get_theme_constant("line_spacing") * (line_count - 1)
		button.custom_minimum_size.y = maxf(36.0, label_height + 20.0)

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
	if not choices.is_empty():
		_set_choice_index(selected_choice_index)

func _set_choice_index(index: int, grab_focus := true) -> void:
	if choices.is_empty():
		selected_choice_index = 0
		return
	selected_choice_index = posmod(index, choices.size())
	var buttons := choices_box.get_children()
	if selected_choice_index >= buttons.size():
		return
	var button := buttons[selected_choice_index] as Button
	if grab_focus and is_instance_valid(button):
		button.grab_focus()

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
