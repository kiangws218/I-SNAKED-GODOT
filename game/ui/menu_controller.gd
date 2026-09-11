class_name MenuController
extends CanvasLayer

signal new_game(slot: int)
signal continue_game(slot: int)
signal delete_slot(slot: int)
signal resume_requested
signal reload_requested
signal save_requested
signal home_requested
signal exit_requested

@onready var main_menu: ColorRect = $MainMenu
@onready var pause_menu: ColorRect = $PauseMenu
@onready var slot_panel: SaveSlotPanel = $SaveSlotPanel
@onready var settings_panel: SettingsPanel = $SettingsPanel
@onready var slots_box: VBoxContainer = $SaveSlotPanel/Center/Panel/Margin/VBox/Slots

var settings_store := AudioSettingsStore.new()
var _slots: Array[Dictionary] = []
var _overlay_origin: StringName = &"main"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 30
	settings_store.load_settings()
	settings_panel.configure(settings_store.music_percent, settings_store.sfx_percent)
	_connect_buttons()
	pause_menu.visible = false
	slot_panel.visible = false
	settings_panel.visible = false


func show_main(slots: Array[Dictionary]) -> void:
	update_slots(slots)
	main_menu.visible = true
	pause_menu.visible = false
	slot_panel.visible = false
	settings_panel.visible = false
	_focus_later($MainMenu/Center/Panel/Margin/VBox/Start)


func update_slots(slots: Array[Dictionary]) -> void:
	_slots = slots
	slot_panel.configure(_slots, slot_panel.mode)


func hide_all() -> void:
	main_menu.visible = false
	pause_menu.visible = false
	slot_panel.visible = false
	settings_panel.visible = false


func show_pause() -> void:
	if main_menu.visible:
		return
	pause_menu.visible = true
	slot_panel.visible = false
	settings_panel.visible = false
	_focus_later($PauseMenu/Center/Panel/Margin/VBox/Resume)


func hide_pause() -> void:
	pause_menu.visible = false
	slot_panel.visible = false
	settings_panel.visible = false


func is_blocking() -> bool:
	return main_menu.visible or pause_menu.visible or slot_panel.visible or settings_panel.visible


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("pause") or event.is_echo():
		return
	if settings_panel.visible or slot_panel.visible:
		_close_overlay()
		get_viewport().set_input_as_handled()
	elif pause_menu.visible:
		resume_requested.emit()
		get_viewport().set_input_as_handled()


func _connect_buttons() -> void:
	$MainMenu/Center/Panel/Margin/VBox/Start.pressed.connect(func(): _open_slots(&"new", &"main"))
	$MainMenu/Center/Panel/Margin/VBox/Load.pressed.connect(func(): _open_slots(&"load", &"main"))
	$MainMenu/Center/Panel/Margin/VBox/Settings.pressed.connect(func(): _open_settings(&"main"))
	$MainMenu/Center/Panel/Margin/VBox/Exit.pressed.connect(func(): exit_requested.emit())
	$PauseMenu/Center/Panel/Margin/VBox/Resume.pressed.connect(func(): resume_requested.emit())
	$PauseMenu/Center/Panel/Margin/VBox/Save.pressed.connect(func(): save_requested.emit())
	$PauseMenu/Center/Panel/Margin/VBox/Load.pressed.connect(func(): _open_slots(&"load", &"pause"))
	$PauseMenu/Center/Panel/Margin/VBox/Settings.pressed.connect(func(): _open_settings(&"pause"))
	$PauseMenu/Center/Panel/Margin/VBox/Home.pressed.connect(func(): home_requested.emit())
	$PauseMenu/Center/Panel/Margin/VBox/Exit.pressed.connect(func(): exit_requested.emit())
	slot_panel.new_game_requested.connect(func(slot: int): new_game.emit(slot))
	slot_panel.load_game_requested.connect(func(slot: int): continue_game.emit(slot))
	slot_panel.delete_requested.connect(func(slot: int): delete_slot.emit(slot))
	slot_panel.back_requested.connect(_close_overlay)
	settings_panel.levels_changed.connect(func(music: float, sfx: float): settings_store.set_levels(music, sfx))
	settings_panel.back_requested.connect(_close_overlay)


func _open_slots(mode: StringName, origin: StringName) -> void:
	_overlay_origin = origin
	slot_panel.configure(_slots, mode)
	slot_panel.visible = true
	settings_panel.visible = false
	slot_panel.call_deferred("focus_first")


func _open_settings(origin: StringName) -> void:
	_overlay_origin = origin
	settings_panel.configure(settings_store.music_percent, settings_store.sfx_percent)
	settings_panel.visible = true
	slot_panel.visible = false
	settings_panel.call_deferred("focus_first")


func _close_overlay() -> void:
	slot_panel.visible = false
	settings_panel.visible = false
	if _overlay_origin == &"pause":
		_focus_later($PauseMenu/Center/Panel/Margin/VBox/Resume)
	else:
		_focus_later($MainMenu/Center/Panel/Margin/VBox/Start)


func _focus_later(control: Control) -> void:
	control.call_deferred("grab_focus")
