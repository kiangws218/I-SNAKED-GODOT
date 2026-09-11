class_name SettingsPanel
extends Control

signal levels_changed(music_percent: float, sfx_percent: float)
signal back_requested

@onready var music_slider: HSlider = $Center/Panel/Margin/VBox/MusicRow/MusicSlider
@onready var music_value: Label = $Center/Panel/Margin/VBox/MusicRow/MusicValue
@onready var sfx_slider: HSlider = $Center/Panel/Margin/VBox/SfxRow/SfxSlider
@onready var sfx_value: Label = $Center/Panel/Margin/VBox/SfxRow/SfxValue
@onready var back_button: Button = $Center/Panel/Margin/VBox/Back

var _configuring := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	music_slider.value_changed.connect(_on_slider_changed)
	sfx_slider.value_changed.connect(_on_slider_changed)
	back_button.pressed.connect(func(): back_requested.emit())
	_refresh_labels()


func configure(music_percent: float, sfx_percent: float) -> void:
	_configuring = true
	music_slider.value = clampf(music_percent, 0.0, 100.0)
	sfx_slider.value = clampf(sfx_percent, 0.0, 100.0)
	_configuring = false
	_refresh_labels()


func focus_first() -> void:
	music_slider.grab_focus()


func _on_slider_changed(_value: float) -> void:
	_refresh_labels()
	if not _configuring:
		levels_changed.emit(music_slider.value, sfx_slider.value)


func _refresh_labels() -> void:
	music_value.text = "%d%%" % roundi(music_slider.value)
	sfx_value.text = "%d%%" % roundi(sfx_slider.value)

