class_name GameHud
extends CanvasLayer

@onready var health_display: HealthDisplay = $SafeArea/TopLeft/Health
@onready var quest_display: QuestDisplay = $SafeArea/TopLeft/Quest
@onready var inventory_carousel: InventoryCarousel = $SafeArea/Inventory
@onready var status_label: Label = $SafeArea/Status
@onready var map_label: Label = $SafeArea/DebugMap


func set_health(current: int, maximum: int) -> void:
	health_display.set_health(current, maximum)


func set_inventory(entries: Array, selected_index: int, bean_ammo: int, current_weight: int, maximum_weight: int) -> void:
	inventory_carousel.set_inventory(entries, selected_index, bean_ammo, current_weight, maximum_weight)


func set_find_ajian_quest(active: bool) -> void:
	quest_display.set_quest("寻找阿见", active)


func set_status(text: String) -> void:
	status_label.text = text


func set_map_debug(text: String) -> void:
	map_label.text = text
	map_label.visible = false
