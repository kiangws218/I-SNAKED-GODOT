class_name StomachInventory
extends RefCounted

const MAX_WEIGHT := 6
const BEAN_ID := &"bean"

const DEFINITIONS := {
	&"iron_sword": {"length": 1, "weight": 2, "damage": 8, "stackable": true},
	&"healing_potion": {"length": 1, "weight": 1, "healing": 1, "stackable": false},
	&"ajie": {"length": 1, "weight": 3, "actor": true, "stackable": false},
	&"lisi": {"length": 1, "weight": 3, "actor": true, "stackable": false},
	&"ajian": {"length": 1, "weight": 3, "actor": true, "stackable": false},
	&"bake": {"length": 1, "weight": 3, "actor": true, "stackable": false},
	&"miluo": {"length": 1, "weight": 3, "actor": true, "stackable": false},
	&"character_bones": {"length": 1, "weight": 1, "damage": 2, "stackable": false},
	&"keti_corpse": {"length": 2, "weight": 3, "stackable": false},
}

var entries: Array[Dictionary] = []
var selected_index := 0


func slot_count() -> int:
	return entries.size() + 1


func selected_id() -> StringName:
	if selected_index == 0 or entries.is_empty():
		return BEAN_ID
	return entries[selected_index - 1].id


func selected_payload() -> Dictionary:
	if selected_index == 0 or entries.is_empty():
		return {"id": BEAN_ID, "damage": 4}
	return entries[selected_index - 1].duplicate(true)


func cycle(step: int) -> StringName:
	selected_index = posmod(selected_index + step, slot_count())
	return selected_id()


func add_item(item_id: StringName, metadata := {}) -> bool:
	if not DEFINITIONS.has(item_id):
		return false
	var definition: Dictionary = DEFINITIONS[item_id]
	if current_weight() + int(definition.weight) > MAX_WEIGHT:
		return false
	if bool(definition.stackable) and metadata.is_empty():
		for entry in entries:
			if entry.id == item_id and not entry.has("metadata"):
				entry.count += 1
				return true
	var entry := {
		"id": item_id,
		"count": 1,
		"length": int(definition.length),
		"weight": int(definition.weight),
	}
	for key in definition:
		if not entry.has(key):
			entry[key] = definition[key]
	if not metadata.is_empty():
		entry.metadata = metadata.duplicate(true)
	entries.append(entry)
	return true


func consume_selected() -> Dictionary:
	if selected_index == 0 or entries.is_empty():
		return {}
	var entry: Dictionary = entries[selected_index - 1]
	var payload := entry.duplicate(true)
	payload.count = 1
	entry.count -= 1
	if entry.count <= 0:
		entries.remove_at(selected_index - 1)
		selected_index = mini(selected_index, entries.size())
	return payload


func current_weight() -> int:
	var total := 0
	for entry in entries:
		total += int(entry.weight) * int(entry.count)
	return total


func occupied_length() -> int:
	var total := 0
	for entry in entries:
		total += int(entry.length) * int(entry.count)
	return total


func bean_ammo(body_length: int, minimum_length := 3) -> int:
	return maxi(0, body_length - minimum_length - occupied_length())


func count_item(item_id: StringName) -> int:
	var total := 0
	for entry in entries:
		if entry.id == item_id:
			total += int(entry.count)
	return total


func is_overweight() -> bool:
	return current_weight() > MAX_WEIGHT
