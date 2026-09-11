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

const CONTROL_ACTIONS := {
	"SpitKeys": &"spit",
	"PlaceKeys": &"place_node",
	"TailKeys": &"cut_tail",
	"PreviousKeys": &"inventory_previous",
	"NextKeys": &"inventory_next",
	"InteractKeys": &"interact",
	"PauseKeys": &"pause",
}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	music_slider.value_changed.connect(_on_slider_changed)
	sfx_slider.value_changed.connect(_on_slider_changed)
	view_controls_button.pressed.connect(show_controls)
	back_button.pressed.connect(_on_back_pressed)
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
	back_button.grab_focus()


func show_audio() -> void:
	_showing_controls = false
	audio_content.visible = true
	controls_content.visible = false
	title_label.text = "设置"


func _on_back_pressed() -> void:
	if not handle_back():
		back_requested.emit()


func handle_back() -> bool:
	if not _showing_controls:
		return false
	show_audio()
	view_controls_button.grab_focus()
	return true


func _refresh_control_labels() -> void:
	var grid := $Center/Panel/Margin/VBox/ControlsContent/ControlsGrid
	grid.get_node("MoveKeys").text = "  ·  ".join([
		_action_keys(&"move_up"),
		_action_keys(&"move_left"),
		_action_keys(&"move_down"),
		_action_keys(&"move_right"),
	])
	for label_name in CONTROL_ACTIONS:
		grid.get_node(label_name).text = _action_keys(CONTROL_ACTIONS[label_name])


func _action_keys(action: StringName) -> String:
	var labels: Array[String] = []
	for event in InputMap.action_get_events(action):
		if not event is InputEventKey:
			continue
		var key_event := event as InputEventKey
		var code := key_event.physical_keycode if key_event.physical_keycode != KEY_NONE else key_event.keycode
		var label := _key_label(code)
		if not label.is_empty() and not labels.has(label):
			labels.append(label)
	return " / ".join(labels) if not labels.is_empty() else "—"


func _key_label(code: Key) -> String:
	match code:
		KEY_SPACE: return "空格"
		KEY_ENTER: return "Enter"
		KEY_ESCAPE: return "Esc"
		KEY_UP: return "↑"
		KEY_DOWN: return "↓"
		KEY_LEFT: return "←"
		KEY_RIGHT: return "→"
		_: return OS.get_keycode_string(code).to_upper()


func _on_slider_changed(_value: float) -> void:
	_refresh_labels()
	if not _configuring:
		levels_changed.emit(music_slider.value, sfx_slider.value)


func _refresh_labels() -> void:
	music_value.text = "%d%%" % roundi(music_slider.value)
	sfx_value.text = "%d%%" % roundi(sfx_slider.value)
