class_name SessionState
extends RefCounted

const DEFAULT_MAP := &"prologue_tutorial"
var slot := 1
var current_map: StringName = DEFAULT_MAP
var checkpoint_map: StringName = DEFAULT_MAP
var checkpoint_entry: StringName = &""
var checkpoint_snapshot: Dictionary = {}
var flags: Dictionary = {}
var player: Dictionary = {"length": 4, "hearts": 3, "max_hearts": 3, "node_unlocked": false, "node_charges": 0, "inventory": [], "selected_index": 0, "rider": ""}
var story: Dictionary = {"story_id": "prologue", "chapter": "tutorial", "current_node": null}
var inventory: Dictionary = {}
var body: Dictionary = {}
var mechanisms: Dictionary = {}
var rewards: Dictionary = {}
var encounters: Dictionary = {}
var items: Dictionary = {}
var actors: Dictionary = {
	"keti": {"status": "alive", "location": "wilderness", "hp": 14.0, "max_hp": 14.0, "met": false, "damageable": true},
	"ajie": {"status": "alive", "location": "forest", "hp": 8.0, "max_hp": 8.0, "met": false, "damageable": false},
	"lisi": {"status": "alive", "location": "forest", "hp": 8.0, "max_hp": 8.0, "met": false, "damageable": false},
	"ajian": {"status": "bound_unconscious", "location": "cave", "hp": 8.0, "max_hp": 8.0, "met": false, "damageable": false},
	"buck": {"status": "alive", "location": "forest", "hp": 8.0, "max_hp": 8.0, "met": false, "damageable": false},
	"miro": {"status": "alive", "location": "forest", "hp": 8.0, "max_hp": 8.0, "met": false, "damageable": false},
}
var gold := 0

func to_dictionary() -> Dictionary:
	return {"current_map": String(current_map), "checkpoint_map": String(checkpoint_map), "checkpoint_entry": String(checkpoint_entry), "checkpoint_snapshot": checkpoint_snapshot.duplicate(true), "flags": flags.duplicate(true), "player": player.duplicate(true), "story": story.duplicate(true), "inventory": inventory.duplicate(true), "body": body.duplicate(true), "mechanisms": mechanisms.duplicate(true), "rewards": rewards.duplicate(true), "encounters": encounters.duplicate(true), "items": items.duplicate(true), "actors": actors.duplicate(true), "gold": gold}

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
	actors = Dictionary(data.get("actors", actors)).duplicate(true)
	gold = int(data.get("gold", 0))
	return {"ok": true}

func remember_checkpoint() -> void:
	checkpoint_snapshot = {
		"player": player.duplicate(true), "flags": flags.duplicate(true), "mechanisms": mechanisms.duplicate(true),
		"rewards": rewards.duplicate(true), "encounters": encounters.duplicate(true), "items": items.duplicate(true),
		"inventory": inventory.duplicate(true), "body": body.duplicate(true), "actors": actors.duplicate(true), "gold": gold,
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
	actors = Dictionary(checkpoint_snapshot.get("actors", actors)).duplicate(true)
	gold = int(checkpoint_snapshot.get("gold", gold))

func prepare_released_pair_forest_return() -> bool:
	if _actor_status(&"ajie") != &"unconscious" or _actor_status(&"lisi") != &"unconscious":
		return false
	if _player_inventory_has(&"ajie") or _player_inventory_has(&"lisi"):
		return false
	for actor_id in [&"ajie", &"lisi"]:
		var key := String(actor_id)
		var actor: Dictionary = Dictionary(actors.get(key, {})).duplicate(true)
		actor["status"] = "alive"
		actor["location"] = "forest"
		actor["hp"] = maxf(1.0, float(actor.get("max_hp", 8.0)))
		actor["damageable"] = true
		actor["hostile"] = true
		actor["spawn_anchor"] = "camp_return_%s" % key
		actor.erase("position")
		actors[key] = actor
	flags["releasedPairReturnedHostile"] = true
	return true

func _actor_status(actor_id: StringName) -> StringName:
	return StringName(Dictionary(actors.get(String(actor_id), {})).get("status", ""))

func _player_inventory_has(item_id: StringName) -> bool:
	for raw_entry in Array(player.get("inventory", [])):
		var entry := Dictionary(raw_entry)
		if StringName(entry.get("id", "")) == item_id:
			return true
	return false
