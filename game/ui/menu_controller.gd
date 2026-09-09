class_name MenuController
extends CanvasLayer

const UI_FONT := preload("res://assets/fonts/fusion-pixel-10px-monospaced-zh_hans.ttf")

signal new_game(slot: int)
signal continue_game(slot: int)
signal delete_slot(slot: int)
signal resume_requested
signal reload_requested
signal home_requested

var main_menu: ColorRect
var pause_menu: ColorRect
var slots_box: VBoxContainer
var _slots: Array[Dictionary] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 30
	main_menu = _make_screen(Color("10162bdf"))
	pause_menu = _make_screen(Color("090d18cc"))
	main_menu.add_theme_font_override("font", UI_FONT)
	pause_menu.add_theme_font_override("font", UI_FONT)
	_build_main()
	_build_pause()
	pause_menu.visible = false

func show_main(slots: Array[Dictionary]) -> void:
	_slots = slots
	main_menu.visible = true
	pause_menu.visible = false
	_render_slots()

func hide_all() -> void:
	main_menu.visible = false
	pause_menu.visible = false

func show_pause() -> void:
	if main_menu.visible:
		return
	pause_menu.visible = true

func hide_pause() -> void:
	pause_menu.visible = false

func is_blocking() -> bool:
	return main_menu.visible or pause_menu.visible

func _make_screen(color: Color) -> ColorRect:
	var screen := ColorRect.new()
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.color = color
	add_child(screen)
	return screen

func _build_main() -> void:
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.position = Vector2(-270, -195)
	box.size = Vector2(540, 390)
	box.add_theme_constant_override("separation", 12)
	main_menu.add_child(box)
	var title := Label.new()
	title.text = "I SNAKED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 38)
	box.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "剧情模式 · 选择存档槽"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(subtitle)
	slots_box = VBoxContainer.new()
	slots_box.add_theme_constant_override("separation", 10)
	box.add_child(slots_box)

func _render_slots() -> void:
	for child in slots_box.get_children():
		child.queue_free()
	for slot in _slots:
		var id := int(slot.slot)
		var row := HBoxContainer.new()
		row.custom_minimum_size.y = 62
		var info := Label.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if bool(slot.get("corrupted", false)):
			info.text = "槽位 %d\n存档损坏（可删除重建）" % id
		elif bool(slot.get("exists", false)):
			info.text = "槽位 %d · %s\n%s  %s" % [id, slot.get("player_name", "未命名"), slot.get("chapter", "序章"), slot.get("updated_at", "")]
		else:
			info.text = "槽位 %d\n空" % id
		row.add_child(info)
		var primary := Button.new()
		primary.text = "继续" if bool(slot.get("exists", false)) and not bool(slot.get("corrupted", false)) else "新游戏"
		primary.pressed.connect(func():
			if bool(slot.get("exists", false)) and not bool(slot.get("corrupted", false)): continue_game.emit(id)
			else: new_game.emit(id))
		row.add_child(primary)
		var erase := Button.new()
		erase.text = "删除"
		erase.disabled = not bool(slot.get("exists", false))
		erase.pressed.connect(func(): delete_slot.emit(id))
		row.add_child(erase)
		slots_box.add_child(row)

func _build_pause() -> void:
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.position = Vector2(-130, -150)
	box.size = Vector2(260, 300)
	box.add_theme_constant_override("separation", 12)
	pause_menu.add_child(box)
	var title := Label.new()
	title.text = "暂停"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	box.add_child(title)
	_add_button(box, "继续", func(): resume_requested.emit())
	_add_button(box, "读取检查点", func(): reload_requested.emit())
	_add_button(box, "设置（后续完善）", func(): pass)
	_add_button(box, "返回标题", func(): home_requested.emit())

func _add_button(parent: VBoxContainer, label: String, action: Callable) -> void:
	var button := Button.new()
	button.text = label
	button.custom_minimum_size.y = 42
	button.pressed.connect(action)
	parent.add_child(button)
