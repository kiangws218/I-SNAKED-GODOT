class_name StoryDirector
extends Node

signal pause_requested(reason: StringName, active: bool)
signal goal_changed(text: String)
signal status_changed(text: String)

const N6_ACTIONS := {
	"loadMap": true, "waitForWall": true, "waitForExit": true, "spawnSlimes": true,
	"eatKeti": true, "eatCorpse": true, "waitForMemoryBlur": true,
	"memoryBlur": true, "nameInput": true, "banner": true,
}

const N7_ACTIONS := {
	"caveExplore": true, "chapterExplore": true, "claimBanditCombatReward": true,
	"claimCampEatAjie": true, "claimCampEatLisi": true, "claimCampLick": true,
	"claimCampReward": true, "cutAjianRope": true, "drinkSoup": true,
	"dropSword": true, "healAjian": true, "lickRescuedAjian": true,
	"mountAjian": true, "payBandits": true, "releaseAjian": true,
	"releaseAjie": true, "releaseBuck": true, "releaseLisi": true,
	"releaseMiro": true, "resolveAjianRewake": true, "resolveBanditThreat": true,
	"revealAjian": true, "reverseBanditRobbery": true, "rewakeAjianFace": true,
	"rewakeAjianFoot": true, "spawnGoblinEncounter": true, "startAjieCombat": true,
	"startBanditCombat": true, "storyEnd": true, "swallowAjian": true,
	"swallowAjie": true, "swallowBuck": true, "swallowLisi": true,
	"swallowMiro": true, "takePotion": true, "takeRing": true,
	"takeSword": true, "tradeSword": true, "waitAjieCombat": true,
	"waitBanditCombat": true, "waitCaveCombat": true, "waitDownedInteraction": true,
	"wakeAjianFace": true, "wakeAjianFoot": true, "wakeAjieFace": true,
	"wakeAjieFoot": true, "wakeLisiFace": true, "wakeLisiFoot": true,
}

var session: GameSession
var panel: DialoguePanel
var runner := DialogueRunner.new()
var nodes: Dictionary = {}
var current_id := ""
var counters := {"tutorialBeansEaten": 0, "tutorialBeansSpit": 0, "chapterBeansEaten": 0, "chapterBeansSpit": 0}
var enemies_left := 0
var memory_timer_started := false
var combat_kind := StringName()
var encounter_expected := 0
var pending_map_node := ""

func setup(owner_session: GameSession, dialogue_panel: DialoguePanel) -> Dictionary:
	session = owner_session
	panel = dialogue_panel
	panel.choice_selected.connect(_on_choice)
	panel.name_submitted.connect(_on_name_submitted)
	var result := runner.load_graph()
	nodes = runner.nodes
	return result

func start(id := "prologue_start") -> void:
	counters = {"tutorialBeansEaten": 0, "tutorialBeansSpit": 0, "chapterBeansEaten": 0, "chapterBeansSpit": 0}
	session.state.story["counters"] = counters.duplicate(true)
	enemies_left = 0
	memory_timer_started = false
	combat_kind = StringName()
	encounter_expected = 0
	enter_node(id)

func resume() -> void:
	counters = Dictionary(session.state.story.get("counters", counters)).duplicate(true)
	var saved := String(session.state.story.get("current_node", "prologue_start"))
	enter_node(saved if nodes.has(saved) else "prologue_start")

func bind_world(world: StoryMap) -> void:
	world.player.bean_collected.connect(func(): notify(&"PLAYER_BEAN_EATEN"))
	world.player.bean_spit.connect(func(): notify(&"PLAYER_BEAN_SPIT"))
	world.story_actor_interacted.connect(func(id: StringName): _on_actor_event(id, &"interacted"))
	world.story_actor_defeated.connect(func(id: StringName): _on_actor_event(id, &"died"))
	world.story_enemy_defeated.connect(func(_kind: StringName):
		enemies_left = maxi(0, enemies_left - 1)
		if combat_kind == &"goblin": session.state.encounters["cave_goblins_remaining"] = enemies_left
		notify(&"ENEMIES_DEFEATED"))
	world.story_trigger_entered.connect(_on_story_trigger)
	if world.has_signal("story_item_interacted"):
		world.connect("story_item_interacted", _on_story_item_interacted)
	if world.has_signal("story_item_collected"):
		world.story_item_collected.connect(_on_story_item_collected)
	if not pending_map_node.is_empty():
		var next := pending_map_node
		pending_map_node = ""
		enter_node(next)

func notify(event: StringName) -> void:
	match event:
		&"PLAYER_BEAN_EATEN":
			counters.tutorialBeansEaten += 1
			if String(session.state.story.get("chapter", "")) == "第一章": counters.chapterBeansEaten += 1
		&"PLAYER_BEAN_SPIT":
			counters.tutorialBeansSpit += 1
			if String(session.state.story.get("chapter", "")) == "第一章": counters.chapterBeansSpit += 1
	session.state.story["counters"] = counters.duplicate(true)
	if String(session.state.story.get("chapter", "")) == "第一章" and not bool(session.state.flags.get("chapter1HungerSeen", false)) and not bool(session.state.flags.get("chapter1HungerPending", false)):
		if int(counters.chapterBeansEaten) >= 10 or int(counters.chapterBeansSpit) >= 10:
			session.state.flags["chapter1HungerPending"] = true
			if current_id == "chapter1_explore":
				enter_node("chapter1_hunger")
				return
	if current_id == "tutorial_1" and _condition("tutorialBeans3"):
		enter_node("dialogue_1")
	elif current_id == "tutorial_2" and _condition("tutorialSpit3"):
		enter_node("dialogue_2")
	elif current_id == "dialogue_2" and _tutorial_wall_ready():
		enter_node("dialogue_3")
	elif current_id in ["wilderness_slimes", "eaten_slimes"] and _condition("enemiesCleared"):
		enter_node("keti_saved" if current_id == "wilderness_slimes" and not bool(session.state.flags.get("keti_dead", false)) else "keti_memory_wait")
	elif current_id == "chapter1_combat_pending" and combat_kind == &"ajie" and _condition("enemiesCleared"):
		_set_actor_status(&"ajie", "downed")
		enter_node("chapter1_ajie_downed_wait")
	elif current_id == "bandit_combat" and combat_kind == &"bandit" and _condition("enemiesCleared"):
		_set_actor_status(&"buck", "downed")
		_set_actor_status(&"miro", "downed")
		enter_node("bandit_search")
	elif current_id == "cave_goblin_combat" and combat_kind == &"goblin" and _condition("enemiesCleared"):
		session.state.flags["goblinsDefeated"] = true
		session.state.encounters.erase("cave_goblins_remaining")
		enter_node("cave_ajian_critical" if _condition("ajianCritical") else "cave_ajian_rescued")

func mechanism_completed(id: StringName) -> void:
	if id == &"tutorial_fragile_gate" and current_id == "dialogue_2" and _tutorial_wall_ready():
		enter_node("dialogue_3")
	elif id == &"forest_bridge_pillar":
		session.state.flags["bridgeLowered"] = true
		status_changed.emit("桥桩充能完成，吊桥已经放下！")

func map_exit(target: StringName, entry: StringName) -> bool:
	if session.state.current_map == &"prologue_tutorial":
		if current_id in ["dialogue_3", "tutorial_free_play"]:
			enter_node("wilderness_start")
		else:
			status_changed.emit("出口尚未开放：先完成教学")
		return true
	if session.state.current_map == &"wilderness" and not bool(session.state.flags.get("prologue_complete", false)):
		status_changed.emit("出口尚未开放：先完成可蒂事件")
		return true
	if session.state.current_map == &"forest" and target == &"cave" and not bool(session.state.flags.get("caveEntered", false)):
		pending_map_node = "cave_intro"
	elif session.state.current_map == &"forest" and target == &"cave":
		pending_map_node = "cave_goblin_combat" if bool(session.state.flags.get("goblinFightStarted", false)) and not bool(session.state.flags.get("goblinsDefeated", false)) else "cave_explore"
	elif session.state.current_map == &"cave" and target == &"forest":
		pending_map_node = "chapter1_explore"
	return false

func enter_node(id: String) -> Dictionary:
	if not nodes.has(id):
		status_changed.emit("剧情错误：未知节点 %s" % id)
		return {"ok": false, "error": "UNKNOWN_NODE"}
	current_id = id
	session.state.story.current_node = id
	var node: Dictionary = nodes[id]
	var progress: Dictionary = node.get("progress", {})
	if not progress.is_empty(): session.state.story.chapter = String(progress.get("chapter", session.state.story.chapter))
	goal_changed.emit(_goal_text(node.get("goal", {})))
	if node.has("enter"):
		var action_result := await _run_action(String(node.enter.get("action", "")), node.enter, id)
		if not action_result.ok: return action_result
		if bool(action_result.get("waiting", false)): return action_result
	if node.has("dialogue"):
		_show_dialogue(id, node.dialogue)
		return {"ok": true, "waiting": true}
	if node.has("wait"):
		return {"ok": true, "waiting": true}
	var next := String(node.get("next", ""))
	if not next.is_empty():
			return await enter_node(next)
	return {"ok": true}

func _start_exploration(area: StringName) -> Dictionary:
	if area == &"forest" and bool(session.state.flags.get("chapter1HungerPending", false)) and not bool(session.state.flags.get("chapter1HungerSeen", false)):
		return await enter_node("chapter1_hunger")
	if area == &"cave" and not bool(session.state.flags.get("caveEntered", false)):
		session.state.flags["caveEntered"] = true
	return {"ok": true, "waiting": true}

func _player() -> SnakePlayer:
	return session.current_world.player if is_instance_valid(session.current_world) and is_instance_valid(session.current_world.player) else null

func _has_item(item_id: StringName) -> bool:
	var player := _player()
	if player != null:
		return player.inventory.count_item(item_id) > 0
	for entry in state_player_inventory():
		if StringName(entry.get("id", "")) == item_id and int(entry.get("count", 1)) > 0:
			return true
	return false

func state_player_inventory() -> Array:
	return Array(session.state.player.get("inventory", []))

func _actor_state(actor_id: StringName) -> Dictionary:
	var actors: Dictionary = session.state.actors
	if not actors.has(String(actor_id)):
		actors[String(actor_id)] = {"status": "alive", "location": "unknown", "hp": 8.0, "max_hp": 8.0, "met": false}
	return Dictionary(actors[String(actor_id)])

func _actor_status(actor_id: StringName) -> StringName:
	return StringName(_actor_state(actor_id).get("status", "alive"))

func _actor_alive(actor_id: StringName) -> bool:
	return _actor_status(actor_id) == &"alive"

func _set_actor_status(actor_id: StringName, status: StringName, location := "forest") -> void:
	var current := _actor_state(actor_id)
	current["status"] = String(status)
	current["location"] = location
	current["met"] = true
	if status in [&"alive", &"bound_awake"] and float(current.get("hp", 0.0)) <= 0.0:
		current["hp"] = 1.0
	session.state.actors[String(actor_id)] = current

func _consume_pickup(item_id: StringName) -> bool:
	if not is_instance_valid(session.current_world):
		return true
	if session.current_world.consume_story_pickup(item_id):
		return true
	for node in session.current_world._layout_nodes():
		if node is StoryPickup and (node.item_id == item_id or node.pickup_id == item_id) and not node.consumed:
			node.consume()
			return true
	return false

func _take_item(item_id: StringName, flag: String) -> Dictionary:
	if bool(session.state.flags.get(flag, false)):
		return {"ok": true}
	var player := _player()
	if player == null or not StomachInventory.DEFINITIONS.has(item_id):
		return {"ok": false, "error": "MISSING_ITEM", "item": item_id}
	var definition: Dictionary = StomachInventory.DEFINITIONS[item_id]
	if player.inventory.current_weight() + int(definition.get("weight", 0)) > StomachInventory.MAX_WEIGHT:
		return {"ok": false, "error": "STOMACH_FULL", "item": item_id}
	if not _consume_pickup(item_id):
		return {"ok": false, "error": "MISSING_ITEM", "item": item_id}
	if not player.add_special_item(item_id):
		return {"ok": false, "error": "STOMACH_FULL", "item": item_id}
	session.state.flags[flag] = true
	return {"ok": true}

func _take_ring() -> Dictionary:
	if bool(session.state.flags.get("chapter1RingTaken", false)):
		return {"ok": true}
	var player := _player()
	if player == null or not _consume_pickup(&"ring"):
		return {"ok": false, "error": "MISSING_ITEM", "item": "ring"}
	player.grant_node_charges(1, true)
	session.state.flags["chapter1RingTaken"] = true
	return {"ok": true}

func _drink_soup() -> Dictionary:
	if bool(session.state.flags.get("caveSoupDrunk", false)):
		return {"ok": true}
	var player := _player()
	if player == null or not _consume_pickup(&"soup"):
		return {"ok": false, "error": "MISSING_ITEM", "item": "soup"}
	player.heal(1)
	session.state.flags["caveSoupDrunk"] = true
	return {"ok": true}

func _swallow_actor(actor_id: StringName) -> Dictionary:
	if _has_item(actor_id):
		return {"ok": true}
	if _actor_status(actor_id) not in [&"alive", &"downed", &"unconscious", &"critical", &"bound_unconscious"]:
		return {"ok": false, "error": "ACTOR_UNAVAILABLE", "actor": actor_id}
	var player := _player()
	var actor := _actor_state(actor_id)
	if player == null or not player.add_special_item(actor_id, {"actor_id": actor_id, "hp": float(actor.get("hp", 8.0))}):
		return {"ok": false, "error": "STOMACH_FULL", "actor": actor_id}
	_set_actor_status(actor_id, &"swallowed", "stomach")
	if is_instance_valid(session.current_world):
		session.current_world.remove_story_actor(actor_id)
	if actor_id == &"ajian":
		session.state.flags["ajianSwallowedOnce"] = true
	return {"ok": true}

func _spit_item(item_id: StringName) -> bool:
	var player := _player()
	if player == null:
		return false
	if player.has_method("spit_item"):
		return player.spit_item(item_id, true, true)
	for index in range(player.inventory.entries.size()):
		if player.inventory.entries[index].id != item_id:
			continue
		var old := player.inventory.selected_index
		player.inventory.selected_index = index + 1
		player.shot_cooldown_left = 0.0
		var result := player.try_spit(true)
		player.inventory.selected_index = mini(old, player.inventory.entries.size())
		return result
	return false

func _release_actor(actor_id: StringName) -> Dictionary:
	if not _has_item(actor_id):
		return {"ok": false, "error": "ACTOR_NOT_SWALLOWED", "actor": actor_id}
	if not _spit_item(actor_id):
		return {"ok": false, "error": "SPIT_FAILED", "actor": actor_id}
	_set_actor_status(actor_id, &"unconscious", String(session.state.current_map))
	return {"ok": true}

func _drop_sword() -> Dictionary:
	if not _has_item(&"iron_sword"):
		return {"ok": false, "error": "SWORD_NOT_HELD"}
	if not _spit_item(&"iron_sword"):
		return {"ok": false, "error": "SPIT_FAILED", "item": "iron_sword"}
	session.state.flags["chapter1SwordRecognizedPending"] = false
	return {"ok": true}

func _wake_actor(actor_id: StringName, method: StringName) -> Dictionary:
	if _actor_status(actor_id) not in [&"unconscious", &"bound_unconscious", &"critical"]:
		return {"ok": true}
	var status := &"bound_awake" if actor_id == &"ajian" and _actor_status(actor_id) == &"bound_unconscious" else &"alive"
	_set_actor_status(actor_id, status, String(session.state.current_map))
	var npc := session.current_world.get_story_actor(actor_id) if is_instance_valid(session.current_world) else null
	if is_instance_valid(npc):
		npc.restore_persistent_state({"active": true, "damageable": actor_id == &"ajian", "is_dead": false, "is_downed": false, "hp": maxf(1.0, npc.hp)})
	if actor_id == &"ajian":
		session.state.flags["ajianFound"] = true
		session.state.flags["ajianAwake"] = true
		session.state.flags["lickWakeLearned"] = true
		session.state.flags["ajianFirstWakeMethod"] = String(method)
		session.state.flags["ajianFaceLicked"] = method == &"face"
		session.state.flags["ajianFootLicked"] = method == &"foot"
	return {"ok": true}

func _cut_ajian_rope() -> Dictionary:
	if bool(session.state.flags.get("ajianUntied", false)):
		return {"ok": true}
	if _actor_status(&"ajian") not in [&"bound_awake", &"bound_unconscious"]:
		return {"ok": false, "error": "AJIAN_NOT_BOUND"}
	_set_actor_status(&"ajian", &"alive", "cave")
	var npc := session.current_world.get_story_actor(&"ajian") if is_instance_valid(session.current_world) else null
	if is_instance_valid(npc):
		npc.damageable = false
		npc.set_actor_active(true)
	session.state.flags["ajianUntied"] = true
	return {"ok": true}

func _spawn_goblins(restoring := false) -> Dictionary:
	if bool(session.state.flags.get("goblinsDefeated", false)):
		return {"ok": true, "waiting": true}
	if bool(session.state.flags.get("goblinFightStarted", false)) and not restoring:
		return {"ok": true, "waiting": true}
	if not is_instance_valid(session.current_world):
		return {"ok": false, "error": "WORLD_UNAVAILABLE"}
	var ids := [&"cave_goblin_origin_01", &"cave_goblin_origin_02"]
	var wanted := clampi(int(session.state.encounters.get("cave_goblins_remaining", 2)), 1, ids.size()) if restoring else ids.size()
	var spawned := 0
	for id in ids:
		if spawned >= wanted:
			break
		if session.current_world.spawn_enemy_at(id) != null:
			spawned += 1
	if spawned == 0:
		return {"ok": false, "error": "MISSING_SPAWN_POINT"}
	enemies_left = spawned
	encounter_expected = spawned
	combat_kind = &"goblin"
	session.state.flags["goblinFightStarted"] = true
	session.state.encounters["cave_goblins_remaining"] = spawned
	var ajian := session.current_world.get_story_actor(&"ajian")
	if is_instance_valid(ajian):
		ajian.damageable = true
	return {"ok": true, "waiting": true}

func _start_combat(kind: StringName) -> Dictionary:
	combat_kind = kind
	encounter_expected = 2
	if kind == &"ajie":
		enemies_left = 1
		encounter_expected = 1
		session.state.flags["ajieCombatStarted"] = true
		var ajie := session.current_world.get_story_actor(&"ajie") if is_instance_valid(session.current_world) else null
		if is_instance_valid(ajie):
			ajie.defeat_mode = "downed"
			ajie.damageable = true
			if ajie.has_method("start_combat"):
				ajie.start_combat(_player())
	elif kind == &"bandit":
		enemies_left = (1 if _actor_alive(&"buck") else 0) + (1 if _actor_alive(&"miro") else 0)
		encounter_expected = enemies_left
		session.state.flags["banditCombatStarted"] = true
		for actor_id in [&"buck", &"miro"]:
			if not _actor_alive(actor_id):
				continue
			var bandit := session.current_world.get_story_actor(actor_id) if is_instance_valid(session.current_world) else null
			if is_instance_valid(bandit):
				bandit.defeat_mode = "downed"
				bandit.damageable = true
				if bandit.has_method("start_combat"):
					bandit.start_combat(_player())
	# Actor/enemy scripts may expose richer combat controls. Keep this optional
	# so the story layer remains data-driven and editor-authored.
	return {"ok": true}

func _wait_combat(kind: StringName) -> Dictionary:
	combat_kind = kind
	if encounter_expected == 0:
		if kind == &"goblin" and bool(session.state.flags.get("goblinFightStarted", false)) and not bool(session.state.flags.get("goblinsDefeated", false)):
			return _spawn_goblins(true)
		if kind == &"ajie" and _actor_alive(&"ajie"):
			_start_combat(&"ajie")
		elif kind == &"bandit":
			_start_combat(&"bandit")
	if _condition("enemiesCleared") and encounter_expected > 0:
		notify(&"ENEMIES_DEFEATED")
	return {"ok": true, "waiting": true}

func _resolve_bandits(outcome: String, gold_delta: int) -> Dictionary:
	if bool(session.state.flags.get("banditResolved", false)):
		return {"ok": true}
	if gold_delta < 0 and session.state.gold < -gold_delta:
		return {"ok": false, "error": "INSUFFICIENT_GOLD"}
	session.state.gold = maxi(0, session.state.gold + gold_delta)
	session.state.flags["banditResolved"] = true
	session.state.flags["banditClueKnown"] = true
	session.state.flags["banditOutcome"] = outcome
	if gold_delta > 0:
		session.state.flags["banditRewardClaimed"] = true
	return {"ok": true}

func _trade_sword() -> Dictionary:
	if not _has_item(&"iron_sword"):
		return {"ok": false, "error": "SWORD_NOT_HELD"}
	var player := _player()
	if player == null or player.consume_inventory_item(&"iron_sword").is_empty():
		return {"ok": false, "error": "SPIT_FAILED"}
	session.state.flags["banditResolved"] = true
	session.state.flags["banditClueKnown"] = true
	session.state.flags["banditOutcome"] = "sword"
	return {"ok": true}

func _claim_bandit_reward() -> Dictionary:
	if bool(session.state.flags.get("banditRewardClaimed", false)):
		return {"ok": true}
	session.state.gold += 6
	session.state.flags["banditRewardClaimed"] = true
	session.state.flags["banditResolved"] = true
	session.state.flags["banditClueKnown"] = true
	session.state.flags["banditOutcome"] = "combat"
	return {"ok": true}

func _claim_camp_reward() -> Dictionary:
	if bool(session.state.flags.get("campRewardClaimed", false)):
		return {"ok": true}
	session.state.gold += 10
	session.state.flags["campRewardClaimed"] = true
	session.state.flags["campRewardKind"] = "gold"
	return {"ok": true}

func _claim_camp_lick() -> Dictionary:
	if bool(session.state.flags.get("campRewardClaimed", false)):
		return {"ok": true}
	session.state.flags["campRewardClaimed"] = true
	session.state.flags["campRewardKind"] = "lick"
	return {"ok": true}

func _claim_camp_eat(actor_id: StringName) -> Dictionary:
	if bool(session.state.flags.get("campRewardClaimed", false)):
		return {"ok": true}
	var result := _swallow_actor(actor_id)
	if not result.ok:
		return result
	session.state.flags["campRewardClaimed"] = true
	session.state.flags["campRewardKind"] = "eat"
	session.state.flags["campRewardActor"] = String(actor_id)
	return {"ok": true}

func _heal_ajian() -> Dictionary:
	var player := _player()
	if player == null or not _has_item(&"healing_potion"):
		return {"ok": false, "error": "POTION_NOT_HELD"}
	var potion := player.consume_inventory_item(&"healing_potion")
	if potion.is_empty():
		return {"ok": false, "error": "POTION_NOT_HELD"}
	_set_actor_status(&"ajian", &"alive", "cave")
	session.state.flags["ajianCritical"] = false
	var ajian := session.current_world.get_story_actor(&"ajian") if is_instance_valid(session.current_world) else null
	if is_instance_valid(ajian):
		ajian.wake(1.0)
		ajian.damageable = false
	return {"ok": true}

func _rewake_ajian(method: StringName) -> Dictionary:
	var previous := String(session.state.flags.get("ajianFirstWakeMethod", method))
	session.state.flags["ajianRewakeReaction"] = ("same_" if previous == String(method) else "switch_") + String(method)
	session.state.flags["ajianFaceLicked"] = method == &"face"
	session.state.flags["ajianFootLicked"] = method == &"foot"
	if not bool(session.state.flags.get("ajianCritical", false)):
		_set_actor_status(&"ajian", &"alive", "cave")
	return {"ok": true}

func _resolve_ajian_rewake() -> Dictionary:
	if bool(session.state.flags.get("ajianCritical", false)):
		return await enter_node("cave_ajian_critical_brief")
	var reaction := String(session.state.flags.get("ajianRewakeReaction", "same_face"))
	return await enter_node("cave_ajian_rewake_" + reaction)

func _reveal_ajian() -> Dictionary:
	session.state.flags["ajianIdentityKnown"] = true
	if bool(session.state.flags.get("chapter1MeetingSeen", false)) or bool(session.state.flags.get("findAjianAccepted", false)):
		return await enter_node("cave_ajian_reveal_known")
	return await enter_node("cave_ajian_reveal_unknown")

func _mount_ajian() -> Dictionary:
	if not _has_item(&"ajian") and _actor_status(&"ajian") not in [&"alive", &"unconscious"]:
		return {"ok": false, "error": "AJIAN_UNAVAILABLE"}
	if _has_item(&"ajian"):
		var player := _player()
		player.consume_inventory_item(&"ajian")
	session.state.player["rider"] = "ajian"
	_set_actor_status(&"ajian", &"riding", "rider")
	var npc := session.current_world.get_story_actor(&"ajian") if is_instance_valid(session.current_world) else null
	var player := _player()
	if is_instance_valid(npc) and player != null and npc.has_method("attach_to_carrier"):
		npc.attach_to_carrier(player, Vector2.ZERO)
	return {"ok": true}

func execute_command(action: String, parameters := {}) -> Dictionary:
	return await _run_action(action, parameters, current_id)

func _run_action(action: String, parameters: Dictionary, source_id: String) -> Dictionary:
	if action.is_empty(): return {"ok": true}
	if not N6_ACTIONS.has(action) and not N7_ACTIONS.has(action):
		var known := false
		for node in nodes.values():
			if String(node.get("enter", {}).get("action", "")) == action: known = true
			for choice in node.get("dialogue", {}).get("choices", []):
				if String(choice.get("action", "")) == action: known = true
		if known: return {"ok": false, "error": "DEFERRED_OUT_OF_STAGE", "action": action}
		return {"ok": false, "error": "UNKNOWN_COMMAND", "action": action}
	match action:
		"loadMap":
			var wanted := StringName(parameters.get("mapId", ""))
			if session.state.current_map != wanted or not is_instance_valid(session.current_world):
				await session.load_map(wanted, StringName(parameters.get("entry", "")))
		"waitForWall":
			return {"ok": true, "waiting": true}
		"waitForExit":
			session.state.flags["tutorial_exit_open"] = true
			_start_exit_timer(source_id)
			return {"ok": true, "waiting": true}
		"spawnSlimes":
			if enemies_left == 0 and is_instance_valid(session.current_world):
				if not session.current_world.has_enemy_spawn(&"keti_slime_1") or not session.current_world.has_enemy_spawn(&"keti_slime_2"):
					return {"ok": false, "error": "MISSING_SPAWN_POINT", "action": action}
				enemies_left = 2
				encounter_expected = 2
				combat_kind = &"slime"
				session.current_world.spawn_enemy_at(&"keti_slime_1")
				session.current_world.spawn_enemy_at(&"keti_slime_2")
			return {"ok": true, "waiting": true}
		"eatKeti", "eatCorpse":
			if not bool(session.state.flags.get("keti_eaten", false)):
				var item_id := &"keti" if action == "eatKeti" else &"keti_corpse"
				if not session.current_world.player.add_special_item(item_id, {"actor_id": &"keti", "hp": 14.0}):
					return {"ok": false, "error": "STOMACH_FULL", "action": action}
				session.state.flags["keti_eaten"] = true
				if action == "eatCorpse": session.state.flags["keti_dead"] = true
				if is_instance_valid(session.current_world): session.current_world.remove_story_actor(&"keti")
		"waitForMemoryBlur":
			_start_memory_timer(source_id)
			return {"ok": true, "waiting": true}
		"memoryBlur":
			if not bool(session.state.flags.get("memory_blurred", false)):
				await _perform_memory_vomit()
				session.state.flags["memory_blurred"] = true
		"nameInput":
			panel.show_name_input()
			pause_requested.emit(&"dialogue", true)
			return {"ok": true, "waiting": true}
		"chapterExplore":
			return await _start_exploration(&"forest")
		"caveExplore":
			return await _start_exploration(&"cave")
		"takeSword":
			return _take_item(&"iron_sword", "chapter1SwordTaken")
		"takeRing":
			return _take_ring()
		"drinkSoup":
			return _drink_soup()
		"takePotion":
			return _take_item(&"healing_potion", "cavePotionTaken")
		"swallowAjie": return _swallow_actor(&"ajie")
		"swallowLisi": return _swallow_actor(&"lisi")
		"swallowAjian": return _swallow_actor(&"ajian")
		"swallowBuck": return _swallow_actor(&"buck")
		"swallowMiro": return _swallow_actor(&"miro")
		"releaseAjie": return _release_actor(&"ajie")
		"releaseLisi": return _release_actor(&"lisi")
		"releaseAjian": return _release_actor(&"ajian")
		"releaseBuck": return _release_actor(&"buck")
		"releaseMiro": return _release_actor(&"miro")
		"dropSword": return _drop_sword()
		"wakeAjianFace": return _wake_actor(&"ajian", &"face")
		"wakeAjianFoot": return _wake_actor(&"ajian", &"foot")
		"wakeAjieFace": return _wake_actor(&"ajie", &"face")
		"wakeAjieFoot": return _wake_actor(&"ajie", &"foot")
		"wakeLisiFace": return _wake_actor(&"lisi", &"face")
		"wakeLisiFoot": return _wake_actor(&"lisi", &"foot")
		"cutAjianRope": return _cut_ajian_rope()
		"spawnGoblinEncounter": return _spawn_goblins()
		"startAjieCombat": return _start_combat(&"ajie")
		"startBanditCombat": return _start_combat(&"bandit")
		"waitAjieCombat": return _wait_combat(&"ajie")
		"waitBanditCombat": return _wait_combat(&"bandit")
		"waitCaveCombat": return _wait_combat(&"goblin")
		"waitDownedInteraction": return {"ok": true, "waiting": true}
		"payBandits": return _resolve_bandits("paid", -3)
		"tradeSword": return _trade_sword()
		"reverseBanditRobbery": return _resolve_bandits("robbed", 6)
		"claimBanditCombatReward": return _claim_bandit_reward()
		"resolveBanditThreat": return _resolve_bandits("threat", 0)
		"claimCampReward": return _claim_camp_reward()
		"claimCampLick": return _claim_camp_lick()
		"claimCampEatAjie": return _claim_camp_eat(&"ajie")
		"claimCampEatLisi": return _claim_camp_eat(&"lisi")
		"lickRescuedAjian":
			session.state.flags["ajianRescueFootLicked"] = true
			return {"ok": true}
		"healAjian": return _heal_ajian()
		"rewakeAjianFace": return _rewake_ajian(&"face")
		"rewakeAjianFoot": return _rewake_ajian(&"foot")
		"resolveAjianRewake": return await _resolve_ajian_rewake()
		"revealAjian": return await _reveal_ajian()
		"mountAjian": return _mount_ajian()
		"storyEnd":
			session.state.flags["storyCompleted"] = true
			status_changed.emit(String(parameters.get("text", "第一章剧情已完成")))
		"banner": status_changed.emit(String(parameters.get("text", "")))
	return {"ok": true}

func _show_dialogue(id: String, dialogue: Dictionary) -> void:
	var pages: Array[Dictionary] = []
	var quests: Dictionary = session.state.story.get("quests", {})
	session.state.story["quests"] = quests
	var variables := {"flags": session.state.flags, "story": session.state.story, "items": session.state.items, "quests": quests}
	var page := runner.begin(id, dialogue, variables, _condition)
	while not page.is_empty():
		pages.append(page)
		if int(page.page) + 1 >= int(page.page_count): break
		page = runner.advance_page()
	panel.show_dialogue(pages)
	pause_requested.emit(&"dialogue", true)

func _on_choice(choice_id: String) -> void:
	var result := runner.choose(choice_id)
	if not result.ok: return
	panel.close()
	pause_requested.emit(&"dialogue", false)
	_finish_world_interaction()
	var action := String(result.get("action", ""))
	if not action.is_empty():
		var command := await _run_action(action, result.choice, current_id)
		if action == "waitForWall" or action == "waitForExit": return
		if not command.ok: return
	var next := String(result.get("next", ""))
	if not next.is_empty(): enter_node(next)

func _on_name_submitted(player_name: String) -> void:
	session.state.story.player_name = player_name
	session.state.flags["prologue_complete"] = true
	panel.close()
	pause_requested.emit(&"dialogue", false)
	_finish_world_interaction()
	enter_node("chapter1_start")

func _finish_world_interaction() -> void:
	if is_instance_valid(session.current_world):
		session.current_world.finish_actor_interaction()

func _on_actor_event(actor_id: StringName, event: StringName) -> void:
	if actor_id == &"keti" and current_id == "wilderness_keti_wait":
		if event == &"died":
			session.state.flags["keti_dead"] = true
			enter_node("keti_dead")
		else:
			session.state.flags["keti_contact"] = true
			enter_node("keti_question")
		return
	if actor_id == &"ajian" and event == &"died" and current_id == "cave_goblin_combat":
		session.state.flags["ajianCritical"] = true
		_set_actor_status(&"ajian", &"critical", "cave")
		return
	if event == &"died" and current_id in ["chapter1_combat_pending", "bandit_combat"]:
		_set_actor_status(actor_id, &"downed", String(session.state.current_map))
		if actor_id == &"ajie" and current_id == "chapter1_combat_pending":
			enemies_left = 0
			notify(&"ENEMIES_DEFEATED")
		elif actor_id in [&"buck", &"miro"] and current_id == "bandit_combat":
			enemies_left = maxi(0, enemies_left - 1)
			if _actor_status(&"buck") == &"downed" and _actor_status(&"miro") == &"downed":
				enemies_left = 0
				notify(&"ENEMIES_DEFEATED")
		return
	if current_id == "chapter1_explore":
		_route_chapter_actor(actor_id, event)
	elif current_id == "cave_explore":
		_route_cave_actor(actor_id, event)
	elif current_id == "chapter1_ajie_downed_wait" and actor_id == &"ajie" and event == &"interacted":
		enter_node("chapter1_ajie_downed")
	elif current_id in ["camp_ajian_unconscious", "camp_ajian_resting"] and actor_id == &"ajian" and event == &"interacted":
		enter_node("camp_ajian_unconscious")

func _on_story_trigger(trigger_id: StringName) -> void:
	if current_id != "chapter1_explore":
		return
	match trigger_id:
		&"camp_settlement":
			if _actor_status(&"ajian") in [&"riding", &"unconscious", &"alive"] or _has_item(&"ajian"):
				_enter_camp_settlement()
		&"bridge_approach":
			if bool(session.state.flags.get("bridgeLowered", false)) or bool(session.state.flags.get("forest_bridge_open", false)):
				status_changed.emit("吊桥已经放下")
			elif not bool(session.state.flags.get("bridgeSeen", false)):
				session.state.flags["bridgeSeen"] = true
				status_changed.emit("吊桥被收起了。围住桥桩并持续充能；环形节点在洞窟深处。")

func _on_story_item_interacted(item_id: StringName) -> void:
	if current_id != "chapter1_explore" and current_id != "cave_explore":
		return
	var id := String(item_id).to_lower()
	if current_id == "chapter1_explore":
		if id in ["iron_sword", "sword", "forest_sword"]:
			enter_node("chapter1_sword")
	elif current_id == "cave_explore":
		if id in ["soup", "cave_soup"]:
			enter_node("cave_soup" if not bool(session.state.flags.get("caveSoupDrunk", false)) else "cave_soup_empty")
		elif id in ["healing_potion", "cave_potion"]:
			enter_node("cave_potion")
		elif id in ["ring", "cave_ring"]:
			enter_node("chapter1_ring")

func _on_story_item_collected(item_id: StringName) -> void:
	if item_id == &"ring" and current_id == "cave_explore" and not bool(session.state.flags.get("chapter1RingTaken", false)):
		# Auto-collect is allowed by the authored pickup, but the story flag is
		# still written here so save/reload cannot grant a second charge.
		session.state.flags["chapter1RingTaken"] = true
		enter_node("chapter1_ring_tutorial")

func _route_chapter_actor(actor_id: StringName, _event: StringName) -> void:
	if actor_id == &"buck" or actor_id == &"miro":
		if bool(session.state.flags.get("banditResolved", false)):
			enter_node("bandit_resolved_buck" if actor_id == &"buck" else "bandit_resolved_miro")
		elif combat_kind == &"bandit" and _condition("enemiesCleared"):
			enter_node("bandit_search")
		else:
			enter_node("bandit_intro")
		return
	if actor_id == &"ajian":
		if bool(session.state.flags.get("campSettlementSeen", false)):
			enter_node("camp_ajian_unconscious" if _actor_status(actor_id) == &"unconscious" else "camp_ajian_resting")
		return
	if actor_id not in [&"ajie", &"lisi"]:
		return
	if _actor_status(actor_id) == &"downed" or _actor_status(actor_id) == &"unconscious":
		enter_node("chapter1_ajie_unconscious" if actor_id == &"ajie" else "chapter1_lisi_unconscious")
	elif bool(session.state.flags.get("chapter1SwordRecognizedPending", false)):
		session.state.flags["chapter1SwordRecognizedPending"] = false
		enter_node("chapter1_sword_recognized" if actor_id == &"ajie" or _actor_alive(&"ajie") else "chapter1_sword_recognized_lisi")
	elif bool(session.state.flags.get("findAjianDeclined", false)):
		enter_node("chapter1_quest_request_ajie" if actor_id == &"ajie" else "chapter1_quest_request")
	else:
		if not bool(session.state.flags.get("chapter1MeetingSeen", false)):
			session.state.flags["chapter1MeetingSeen"] = true
		enter_node("chapter1_meeting" if _actor_alive(&"ajie") and _actor_alive(&"lisi") else ("chapter1_ajie_only" if _actor_alive(&"ajie") else "chapter1_lisi_only"))

func _route_cave_actor(actor_id: StringName, _event: StringName) -> void:
	if actor_id != &"ajian":
		return
	var state := _actor_status(actor_id)
	if state == &"bound_unconscious":
		enter_node("cave_ajian_found")
	elif state == &"bound_awake":
		enter_node("cave_ajian_untie_return")
	elif state == &"critical" or bool(session.state.flags.get("ajianCritical", false)):
		enter_node("cave_ajian_critical")
	elif state == &"unconscious":
		enter_node("cave_ajian_rewake")
	elif bool(session.state.flags.get("goblinsDefeated", false)):
		enter_node("cave_ajian_destination" if bool(session.state.flags.get("ajianIdentityKnown", false)) else "cave_ajian_rescued")

func _enter_camp_settlement() -> void:
	if bool(session.state.flags.get("campSettlementSeen", false)):
		return
	var ajie := _actor_alive(&"ajie")
	var lisi := _actor_alive(&"lisi")
	var arrival := "stomach" if _has_item(&"ajian") or _actor_status(&"ajian") == &"unconscious" else "rider"
	session.state.flags["campSettlementSeen"] = true
	session.state.flags["campArrivalMethod"] = arrival
	if arrival == "stomach":
		var player := _player()
		if player != null and _has_item(&"ajian"):
			player.consume_inventory_item(&"ajian")
		_set_actor_status(&"ajian", "unconscious", "forest")
	else:
		session.state.player["rider"] = ""
		_set_actor_status(&"ajian", "alive", "forest")
	var ajian := session.current_world.get_story_actor(&"ajian") if is_instance_valid(session.current_world) else null
	if is_instance_valid(ajian):
		if ajian.is_riding(): ajian.detach_from_carrier(ajian.global_position)
		ajian.restore_persistent_state({"active": true, "damageable": false, "is_dead": false, "is_downed": arrival == "stomach", "hp": 0.0 if arrival == "stomach" else maxf(1.0, ajian.hp)})
	if ajie and lisi:
		enter_node("camp_settlement_stomach_both" if arrival == "stomach" else "camp_settlement_rider_both")
	elif ajie:
		enter_node("camp_settlement_stomach_ajie" if arrival == "stomach" else "camp_settlement_rider_ajie")
	elif lisi:
		enter_node("camp_settlement_stomach_lisi" if arrival == "stomach" else "camp_settlement_rider_lisi")
	else:
		enter_node("chapter1_explore")

func _start_memory_timer(source_id: String) -> void:
	if memory_timer_started: return
	memory_timer_started = true
	get_tree().create_timer(6.0).timeout.connect(func():
		memory_timer_started = false
		if current_id == source_id: enter_node("memory_blur"))

func _start_exit_timer(source_id: String) -> void:
	get_tree().create_timer(30.0).timeout.connect(func():
		if current_id == source_id: enter_node("dialogue_4"))

func _perform_memory_vomit() -> void:
	var player := session.current_world.player
	pause_requested.emit(&"cutscene", true)
	var bean_count := player.inventory.bean_ammo(player.body_chain.segment_count, SnakePlayer.MIN_LENGTH)
	player.inventory.selected_index = 0
	for index in range(bean_count):
		player.shot_cooldown_left = 0.0
		player.try_spit(true)
		await get_tree().create_timer(0.13, true, false, true).timeout
	for item_id in [&"keti", &"keti_corpse"]:
		for index in range(player.inventory.entries.size()):
			if player.inventory.entries[index].id == item_id:
				player.inventory.selected_index = index + 1
				player.shot_cooldown_left = 0.0
				player.try_spit(true)
				break
	player.inventory.selected_index = 0
	pause_requested.emit(&"cutscene", false)

func _tutorial_wall_ready() -> bool:
	return int(counters.tutorialBeansEaten) >= 5 and bool(session.state.flags.get("tutorial_fragile_gate", false))

func _condition(name: String) -> bool:
	match name:
		"tutorialBeans3": return int(counters.tutorialBeansEaten) >= 3
		"tutorialSpit3": return int(counters.tutorialBeansSpit) >= 3
		"enemiesCleared": return encounter_expected > 0 and enemies_left <= 0
		"ketiEvent": return bool(session.state.flags.get("keti_dead", false)) or bool(session.state.flags.get("keti_contact", false))
		"freeExploreTimer": return not memory_timer_started
		"ajieAlive": return _actor_alive(&"ajie")
		"lisiAlive": return _actor_alive(&"lisi")
		"buckAlive": return _actor_alive(&"buck")
		"miroAlive": return _actor_alive(&"miro")
		"hasAjie": return _has_item(&"ajie")
		"hasLisi": return _has_item(&"lisi")
		"hasAjian": return _has_item(&"ajian")
		"hasSword": return _has_item(&"iron_sword")
		"hasPotion": return _has_item(&"healing_potion")
		"hasGold3": return session.state.gold >= 3
		"lickWakeLearned": return bool(session.state.flags.get("lickWakeLearned", false))
		"ajianFootAvailable": return not bool(session.state.flags.get("ajianRescueFootLicked", false))
		"canMountAjian": return String(session.state.player.get("rider", "")).is_empty() and (_has_item(&"ajian") or _actor_status(&"ajian") in [&"alive", &"unconscious"])
		"ajianCritical": return bool(session.state.flags.get("ajianCritical", false))
	return bool(session.state.flags.get(name, false))

func _player_can_carry_actor() -> bool:
	var player := _player()
	return player != null and player.inventory.current_weight() + 3 <= StomachInventory.MAX_WEIGHT

func _goal_text(goal: Dictionary) -> String:
	if goal.get("kind", "") == "counter":
		return "%s：%d / %d" % [goal.get("label", "目标"), counters.get(goal.get("counter", ""), 0), goal.get("target", 0)]
	return String(goal.get("text", "继续探索"))
