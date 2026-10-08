class_name SettingsPanel
extends Control

signal levels_changed(music_percent: float, sfx_percent: float)
signal back_requested

@onready var title_label: Label = $Center/Panel/Margin/VBox/Title
@onready var audio_content: VBoxContainer = $Center/Panel/Margin/VBox/AudioContent
@onready var controls_content: VBoxContainer = $Center/Panel/Margin/VBox/ControlsContent
@onready var music_slider: HSlider = $Center/Panel/Margin/VBox/AudioContent/MusicRow/MusicSlider
@onready var music_value: Label = $Center/Panel/Margin/VBox/AudioContent/MusicRow/MusicValue
@onready var sfx_slider: HSlider = $Center/Panel/Margin/VBox/AudioContent/SfxRow/SfxSlider
@onready var sfx_value: Label = $Center/Panel/Margin/VBox/AudioContent/SfxRow/SfxValue
@onready var view_controls_button: Button = $Center/Panel/Margin/VBox/AudioContent/ViewControls
@onready var back_button: Button = $Center/Panel/Margin/VBox/Back

var _configuring := false
var _showing_controls := false
var bindings_store := InputBindingsStore.new()
var capture_action := StringName()
var capture_slot := -1
var _eat_release: Key = KEY_NONE
const CONTROL_HINT := "点击主键或备用键修改 · 菜单仍用 Enter / 方向键 / Esc"
@onready var binding_rows: VBoxContainer = $Center/Panel/Margin/VBox/ControlsContent/Scroll/Rows
@onready var binding_hint: Label = $Center/Panel/Margin/VBox/ControlsContent/Hint
@onready var reset_all_button: Button = $Center/Panel/Margin/VBox/ControlsContent/ResetAll

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	music_slider.value_changed.connect(_on_slider_changed)
	sfx_slider.value_changed.connect(_on_slider_changed)
	view_controls_button.pressed.connect(show_controls)
	back_button.pressed.connect(_on_back_pressed)
	bindings_store.load_settings()
	for row in binding_rows.get_children():
		row.capture_requested.connect(begin_capture)
		row.reset_requested.connect(_reset_binding)
	reset_all_button.pressed.connect(_reset_all_bindings)
	visibility_changed.connect(func():
		if not visible: cancel_capture())
	show_audio()
	_refresh_control_labels()
	_refresh_labels()


func configure(music_percent: float, sfx_percent: float) -> void:
	show_audio()
	_configuring = true
	music_slider.value = clampf(music_percent, 0.0, 100.0)
	sfx_slider.value = clampf(sfx_percent, 0.0, 100.0)
	_configuring = false
	_refresh_labels()


func focus_first() -> void:
	if _showing_controls:
		back_button.grab_focus()
	else:
		music_slider.grab_focus()


func show_controls() -> void:
	_showing_controls = true
	audio_content.visible = false
	controls_content.visible = true
	title_label.text = "键位"
	binding_hint.text = CONTROL_HINT
	_refresh_control_labels()
	back_button.grab_focus()


func show_audio() -> void:
	cancel_capture()
	_showing_controls = false
	audio_content.visible = true
	controls_content.visible = false
	title_label.text = "设置"


func _on_back_pressed() -> void:
	if not handle_back():
		back_requested.emit()


func handle_back() -> bool:
	if not capture_action.is_empty():
		cancel_capture()
		return true
	if not _showing_controls:
		return false
	show_audio()
	view_controls_button.grab_focus()
	return true


func _refresh_control_labels() -> void:
	for row in binding_rows.get_children(): row.refresh(bindings_store)

func configure_bindings(store: InputBindingsStore) -> void:
	bindings_store = store
	_refresh_control_labels()

func begin_capture(action: StringName, slot: int) -> void:
	if not visible or not _showing_controls: return
	cancel_capture()
	capture_action = action
	capture_slot = slot
	for row in binding_rows.get_children():
		if row.action == action: row.set_capturing(slot)
	binding_hint.text = "请按新按键 · Esc 取消 · Backspace 删除备用键"
	back_button.disabled = true
	reset_all_button.disabled = true
	var focused := get_viewport().gui_get_focus_owner()
	if is_instance_valid(focused): focused.release_focus()

func cancel_capture() -> void:
	var old_action := capture_action
	var old_slot := capture_slot
	capture_action = &""
	capture_slot = -1
	if not is_node_ready(): return
	back_button.disabled = false
	reset_all_button.disabled = false
	_refresh_control_labels()
	if not old_action.is_empty():
		binding_hint.text = CONTROL_HINT
		for row in binding_rows.get_children():
			if row.action == old_action:
				(row.primary if old_slot == 0 else row.secondary).grab_focus()

func _input(event: InputEvent) -> void:
	if not visible or not _showing_controls: return
	if event is InputEventKey:
		var code: Key = event.physical_keycode if event.physical_keycode != KEY_NONE else event.keycode
		if not event.pressed:
			if not capture_action.is_empty() or code == _eat_release:
				get_viewport().set_input_as_handled()
				if code == _eat_release: _eat_release = KEY_NONE
			return
		if capture_action.is_empty(): return
		get_viewport().set_input_as_handled()
		if event.echo: return
		_eat_release = code
		if code == KEY_ESCAPE:
			cancel_capture()
			return
		if event.ctrl_pressed or event.alt_pressed or event.meta_pressed or event.shift_pressed:
			binding_hint.text = "请使用单个普通按键，不使用组合键。"
			return
		var result := bindings_store.set_binding(capture_action, capture_slot, KEY_NONE if code == KEY_BACKSPACE else code)
		if result.get("ok", false):
			cancel_capture()
			binding_hint.text = "已保存 · " + CONTROL_HINT
		else:
			binding_hint.text = String(result.get("message", "该键不能使用，请换一个。"))
	elif not capture_action.is_empty():
		get_viewport().set_input_as_handled()

func _reset_binding(action: StringName) -> void:
	if not capture_action.is_empty(): return
	var result := bindings_store.reset_action(action)
	_refresh_control_labels()
	binding_hint.text = "已恢复该项默认键位" if result.get("ok", false) else String(result.get("message", "无法恢复，请先恢复全部默认。"))

func _reset_all_bindings() -> void:
	if not capture_action.is_empty(): return
	var result := bindings_store.reset_all()
	_refresh_control_labels()
	binding_hint.text = "已恢复全部默认键位" if result.get("ok", false) else String(result.get("message", "键位保存失败。"))


func _on_slider_changed(_value: float) -> void:
	_refresh_labels()
	if not _configuring:
		levels_changed.emit(music_slider.value, sfx_slider.value)


func _refresh_labels() -> void:
	music_value.text = "%d%%" % roundi(music_slider.value)
	sfx_value.text = "%d%%" % roundi(sfx_slider.value)
