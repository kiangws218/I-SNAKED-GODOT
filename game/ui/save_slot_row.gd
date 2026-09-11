class_name SaveSlotRow
extends PanelContainer

signal primary_requested(slot: int, mode: StringName)
signal delete_requested(slot: int)

@onready var info_label: Label = $Margin/Row/Info
@onready var primary_button: Button = $Margin/Row/Primary
@onready var delete_button: Button = $Margin/Row/Delete

var slot_id := 1
var action_mode: StringName = &"load"


func _ready() -> void:
	primary_button.pressed.connect(func(): primary_requested.emit(slot_id, action_mode))
	delete_button.pressed.connect(func(): delete_requested.emit(slot_id))


func configure(slot: Dictionary, mode: StringName) -> void:
	slot_id = int(slot.get("slot", 1))
	action_mode = mode
	var exists := bool(slot.get("exists", false))
	var corrupted := bool(slot.get("corrupted", false))
	if corrupted:
		info_label.text = "槽位 %d  ·  存档损坏\n可以删除后重新开始" % slot_id
	elif exists:
		info_label.text = "槽位 %d  ·  %s\n%s  ·  %s" % [slot_id, slot.get("player_name", "未命名"), slot.get("chapter", "序章"), slot.get("updated_at", "")]
	else:
		info_label.text = "槽位 %d\n空存档" % slot_id
	if mode == &"new":
		primary_button.text = "已有存档" if exists else "开始"
		primary_button.disabled = exists or corrupted
	else:
		primary_button.text = "读取"
		primary_button.disabled = not exists or corrupted
	delete_button.disabled = not exists
