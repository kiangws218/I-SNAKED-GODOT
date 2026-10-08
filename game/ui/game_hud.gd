class_name GameHud
extends CanvasLayer

@onready var health_display: HealthDisplay = $SafeArea/TopLeft/Health
@onready var quest_display: QuestDisplay = $SafeArea/TopLeft/Quest
@onready var inventory_carousel: InventoryCarousel = $SafeArea/Inventory
@onready var status_label: Label = $SafeArea/Status
@onready var map_label: Label = $SafeArea/DebugMap
@onready var companion: HBoxContainer = $SafeArea/Companion
@onready var companion_key: Label = $SafeArea/Companion/Key
@onready var companion_hint: Label = $SafeArea/CompanionHint
var _companion_hint_seen := false
var _companion_hint_seconds := 0.0

func _process(delta: float) -> void:
	_companion_hint_seconds = maxf(0.0, _companion_hint_seconds - delta)
	companion_hint.visible = companion.visible and companion.modulate.a > 0.5 and _companion_hint_seconds > 0.0

func reset_companion_hint() -> void:
	_companion_hint_seen = false
	_companion_hint_seconds = 0.0

func set_companion_available(available: bool, combat_blocked: bool) -> void:
	companion.visible = available
	companion.modulate.a = 0.45 if combat_blocked else 0.85
	var key := "T"
	for event in InputMap.action_get_events(&"companion_talk"):
		if event is InputEventKey:
			key = OS.get_keycode_string(event.physical_keycode if event.physical_keycode != KEY_NONE else event.keycode)
			break
	companion_key.text = "先脱离战斗" if combat_blocked else "%s · 交谈" % key
	companion_hint.text = "按 %s 与可蒂交谈" % key
	if available and not combat_blocked and not _companion_hint_seen:
		_companion_hint_seen = true
		_companion_hint_seconds = 3.0
	companion_hint.visible = available and not combat_blocked and _companion_hint_seconds > 0.0


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
