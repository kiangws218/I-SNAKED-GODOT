class_name InventoryCarousel
extends Control

const ICONS := {
	&"bean": preload("res://assets/items/bean.svg"),
	&"iron_sword": preload("res://assets/placeholders/kenney/tiny_dungeon/items/iron_sword.png"),
	&"healing_potion": preload("res://assets/items/green_potion.png"),
	&"character_bones": preload("res://assets/items/bones.svg"),
	&"keti": preload("res://assets/placeholders/kenney/tiny_dungeon/characters/keti.png"),
	&"keti_corpse": preload("res://assets/placeholders/kenney/tiny_dungeon/characters/keti.png"),
	&"ajie": preload("res://assets/placeholders/kenney/tiny_dungeon/characters/ajie.png"),
	&"lisi": preload("res://assets/placeholders/kenney/tiny_dungeon/characters/lisi.png"),
	&"ajian": preload("res://assets/placeholders/kenney/tiny_dungeon/characters/ajian.png"),
	&"buck": preload("res://assets/placeholders/kenney/tiny_dungeon/characters/buck.png"),
	&"miro": preload("res://assets/placeholders/kenney/tiny_dungeon/characters/miro.png"),
}

const NAMES := {
	&"bean": "豆子", &"iron_sword": "铁剑", &"healing_potion": "治疗药水",
	&"keti": "可蒂", &"keti_corpse": "可蒂", &"ajie": "阿杰", &"lisi": "丽丝",
	&"ajian": "阿见", &"buck": "巴克", &"miro": "米洛", &"character_bones": "遗骨",
}

@onready var track: Control = $Track
@onready var left_slot: VBoxContainer = $Track/Left
@onready var center_slot: VBoxContainer = $Track/Center
@onready var right_slot: VBoxContainer = $Track/Right

var _selected_index := -1
var _slide_tween: Tween


func set_inventory(entries: Array, selected_index: int, bean_ammo: int, _current_weight: int, _maximum_weight: int) -> void:
	var slots: Array[Dictionary] = [{"id": &"bean", "count": bean_ammo}]
	for raw_entry in entries:
		var entry: Dictionary = raw_entry
		slots.append({"id": StringName(entry.get("id", "")), "count": int(entry.get("count", 1))})
	var safe_index := clampi(selected_index, 0, slots.size() - 1)
	var direction := 0
	if _selected_index >= 0 and _selected_index != safe_index:
		var forward := posmod(safe_index - _selected_index, slots.size())
		direction = 1 if forward == 1 else -1
	_selected_index = safe_index
	_set_slot(center_slot, slots[safe_index], true)
	if slots.size() == 1:
		left_slot.visible = false
		right_slot.visible = false
	elif slots.size() == 2:
		left_slot.visible = true
		right_slot.visible = false
		_set_slot(left_slot, slots[posmod(safe_index - 1, slots.size())], false)
	else:
		left_slot.visible = true
		right_slot.visible = true
		_set_slot(left_slot, slots[posmod(safe_index - 1, slots.size())], false)
		_set_slot(right_slot, slots[posmod(safe_index + 1, slots.size())], false)
	if direction != 0:
		_animate_slide(direction)


func _set_slot(slot: VBoxContainer, data: Dictionary, primary: bool) -> void:
	var item_id := StringName(data.get("id", ""))
	var icon := slot.get_node("Icon") as TextureRect
	var label := slot.get_node("Name") as Label
	var count := slot.get_node("Count") as Label
	icon.texture = ICONS.get(item_id) as Texture2D
	icon.modulate = Color.WHITE if icon.texture else Color(0.4, 0.8, 0.5, 0.5)
	label.text = NAMES.get(item_id, String(item_id))
	count.text = "×%d" % int(data.get("count", 1))
	count.visible = primary
	slot.modulate.a = 1.0 if primary else 0.72


func _animate_slide(direction: int) -> void:
	if _slide_tween and _slide_tween.is_valid():
		_slide_tween.kill()
	track.position = Vector2(direction * 34.0, 0.0)
	track.modulate.a = 0.65
	_slide_tween = create_tween().set_parallel(true)
	_slide_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_slide_tween.tween_property(track, "position", Vector2.ZERO, 0.2)
	_slide_tween.tween_property(track, "modulate:a", 1.0, 0.16)
