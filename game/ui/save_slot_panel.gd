class_name SaveSlotPanel
extends Control

signal new_game_requested(slot: int)
signal load_game_requested(slot: int)
signal delete_requested(slot: int)
signal back_requested

const SLOT_ROW_SCENE := preload("res://game/ui/save_slot_row.tscn")

@onready var title_label: Label = $Center/Panel/Margin/VBox/Title
@onready var slots_box: VBoxContainer = $Center/Panel/Margin/VBox/Slots
@onready var back_button: Button = $Center/Panel/Margin/VBox/Back

var mode: StringName = &"load"
var slots: Array[Dictionary] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	back_button.pressed.connect(func(): back_requested.emit())


func configure(slot_data: Array[Dictionary], requested_mode: StringName) -> void:
	slots = slot_data
	mode = requested_mode
	title_label.text = "选择新游戏槽位" if mode == &"new" else "加载游戏"
	_render()


func focus_first() -> void:
	for child in slots_box.get_children():
		var button := child.get_node_or_null("Margin/Row/Primary") as Button
		if button and not button.disabled:
			button.grab_focus()
			return
	back_button.grab_focus()


func _render() -> void:
	for child in slots_box.get_children():
		slots_box.remove_child(child)
		child.queue_free()
	for slot in slots:
		var row: SaveSlotRow = SLOT_ROW_SCENE.instantiate()
		slots_box.add_child(row)
		row.configure(slot, mode)
		row.primary_requested.connect(_on_primary)
		row.delete_requested.connect(func(slot_id: int): delete_requested.emit(slot_id))


func _on_primary(slot: int, selected_mode: StringName) -> void:
	if selected_mode == &"new":
		new_game_requested.emit(slot)
	else:
		load_game_requested.emit(slot)

