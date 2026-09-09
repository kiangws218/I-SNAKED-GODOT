class_name SessionState
extends RefCounted

const DEFAULT_MAP := &"prologue_tutorial"
var slot := 1
var current_map: StringName = DEFAULT_MAP
var checkpoint_map: StringName = DEFAULT_MAP
var checkpoint_entry: StringName = &""
var checkpoint_snapshot: Dictionary = {}
var flags: Dictionary = {}
var player: Dictionary = {"length": 4, "hearts": 3, "max_hearts": 3, "node_unlocked": false, "node_charges": 0, "inventory": [], "selected_index": 0}
var story: Dictionary = {"story_id": "prologue", "chapter": "tutorial", "current_node": null}
var inventory: Dictionary = {}
var body: Dictionary = {}
var mechanisms: Dictionary = {}
var rewards: Dictionary = {}
var encounters: Dictionary = {}
var items: Dictionary = {}
var gold := 0

func to_dictionary() -> Dictionary:
	return {"current_map": String(current_map), "checkpoint_map": String(checkpoint_map), "checkpoint_entry": String(checkpoint_entry), "checkpoint_snapshot": checkpoint_snapshot.duplicate(true), "flags": flags.duplicate(true), "player": player.duplicate(true), "story": story.duplicate(true), "inventory": inventory.duplicate(true), "body": body.duplicate(true), "mechanisms": mechanisms.duplicate(true), "rewards": rewards.duplicate(true), "encounters": encounters.duplicate(true), "items": items.duplicate(true), "gold": gold}

func load_dictionary(data: Dictionary) -> Dictionary:
	var map_id := StringName(data.get("current_map", DEFAULT_MAP))
	var checkpoint_id := StringName(data.get("checkpoint_map", map_id))
	if not StoryMapCatalog.is_valid(map_id) or not StoryMapCatalog.is_valid(checkpoint_id):
		return {"ok": false, "error": {"code": &"INVALID_MAP", "message": "存档包含未知地图"}}
	current_map = map_id
	checkpoint_map = checkpoint_id
	checkpoint_entry = StringName(data.get("checkpoint_entry", &""))
	checkpoint_snapshot = Dictionary(data.get("checkpoint_snapshot", {})).duplicate(true)
	flags = Dictionary(data.get("flags", {})).duplicate(true)
	player = Dictionary(data.get("player", player)).duplicate(true)
	story = Dictionary(data.get("story", story)).duplicate(true)
	inventory = Dictionary(data.get("inventory", {})).duplicate(true)
	body = Dictionary(data.get("body", {})).duplicate(true)
	mechanisms = Dictionary(data.get("mechanisms", {})).duplicate(true)
	rewards = Dictionary(data.get("rewards", {})).duplicate(true)
	encounters = Dictionary(data.get("encounters", {})).duplicate(true)
	items = Dictionary(data.get("items", {})).duplicate(true)
	gold = int(data.get("gold", 0))
	return {"ok": true}

func remember_checkpoint() -> void:
	checkpoint_snapshot = {
		"player": player.duplicate(true), "flags": flags.duplicate(true), "mechanisms": mechanisms.duplicate(true),
		"rewards": rewards.duplicate(true), "encounters": encounters.duplicate(true), "items": items.duplicate(true),
		"inventory": inventory.duplicate(true), "body": body.duplicate(true), "gold": gold,
	}

func restore_checkpoint() -> void:
	if checkpoint_snapshot.is_empty():
		return
	player = Dictionary(checkpoint_snapshot.get("player", player)).duplicate(true)
	flags = Dictionary(checkpoint_snapshot.get("flags", flags)).duplicate(true)
	mechanisms = Dictionary(checkpoint_snapshot.get("mechanisms", mechanisms)).duplicate(true)
	rewards = Dictionary(checkpoint_snapshot.get("rewards", rewards)).duplicate(true)
	encounters = Dictionary(checkpoint_snapshot.get("encounters", encounters)).duplicate(true)
	items = Dictionary(checkpoint_snapshot.get("items", items)).duplicate(true)
	inventory = Dictionary(checkpoint_snapshot.get("inventory", inventory)).duplicate(true)
	body = Dictionary(checkpoint_snapshot.get("body", body)).duplicate(true)
	gold = int(checkpoint_snapshot.get("gold", gold))
