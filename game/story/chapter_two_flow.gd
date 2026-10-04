extends Node
## Chapter-specific routing; all persistent facts belong to SessionState.

const MAP := &"chapter2_slice"
const COT := Vector2(1080, 420)
var director: Node
var actor_context := StringName()
var dialogue_source: Dictionary = {}

func setup(owner_director: Node) -> void:
	director = owner_director
	dialogue_source = JSON.parse_string(FileAccess.get_file_as_string("res://game/story/chapter_two.dialogue"))

func state() -> SessionState:
	return director.session.state

func world() -> StoryMap:
	return director.session.current_world

func bind_world(active_world: StoryMap) -> void:
	actor_context = &""
	for node in active_world.get_tree().get_nodes_in_group(&"npc"):
		if not active_world.is_ancestor_of(node): continue
		node.defeat_mode = "downed"
		node.damageable = true
		node.allow_hostile_interaction = true
	var carrier_id := StringName(state().chapter_two.get("stretcher", ""))
	if not carrier_id.is_empty():
		var carrier_actor := active_world.get_story_actor(carrier_id)
		if is_instance_valid(carrier_actor):
			var actor: Dictionary = state().actors[String(carrier_id)]
			carrier_actor.restore_persistent_state({"hp": float(actor.get("hp", 0.0)), "active": true, "damageable": true, "is_dead": false, "is_downed": bool(actor.get("transport_down", false)) or float(actor.get("hp", 0.0)) <= 0.0, "defeat_mode": "downed", "hostile": bool(actor.get("wake_hostile", actor.get("hostile", false)))})
			carrier_actor.attach_to_carrier(active_world.player, Vector2(0, -8))
	_sync_cart()
	resume()

func resume() -> void:
	director.current_id = "ch2_explore"
	state().story["chapter"] = "第二章"
	state().story["current_node"] = "ch2_explore"
	_refresh_goal()
	if not bool(state().chapter_two.get("intro_seen", false)):
		show("intro")

func _refresh_goal() -> void:
	if state().current_map != MAP: return
	var progress := state().chapter_two
	var goal := "打开车厢，找到可蒂"
	if bool(progress.get("inner_latch", false)): goal = "带可蒂到右边的渡口休息台"
	if bool(progress.get("settled", false)): goal = "唤醒可蒂，和她约好一起旅行"
	if bool(progress.get("duo", false)): goal = "可蒂已经与你结伴 · 本轮试玩结束"
	director.goal_changed.emit(goal)
	var score_label := director.session.hud.get_node("SafeArea/SocialScore") as Label
	score_label.visible = true
	score_label.text = "声望 %d  /  恐惧 %d" % [int(state().social.get("reputation", 0)), int(state().social.get("fear", 0))]
	director.session.status_label.visible = true

func show(dialogue_id: String, actor_id := StringName()) -> void:
	actor_context = actor_id
	director.current_id = "ch2_" + dialogue_id
	var dialogue: Dictionary = Dictionary(dialogue_source[dialogue_id]).duplicate(true)
	# Follow-ups share the same interaction options, but never replay a
	# completed quest offer. Prose and option labels still live in .dialogue.
	var choices: Array = dialogue.get("choices", dialogue_source.get(dialogue.get("choices_from", ""), {}).get("choices", []))
	var available: Array = []
	for choice in choices:
		var action := String(choice.get("action", ""))
		if action in ["negotiate", "key"] and bool(state().chapter_two.get("outer_lock", false)): continue
		if action == "lever" and bool(state().chapter_two.get("inner_latch", false)): continue
		if action == "duo" and bool(state().chapter_two.get("duo", false)): continue
		if action == "dismount" and dialogue_id.begins_with("keti_") and (not bool(state().chapter_two.get("duo", false)) or String(state().player.get("rider", "")) != "keti"): continue
		if action == "ride" and (not bool(state().chapter_two.get("duo", false)) or String(state().player.get("rider", "")) == "keti"): continue
		available.append(choice)
	dialogue["choices"] = available
	director._show_dialogue(director.current_id, dialogue)

func _dialogue_seen(dialogue_id: String, actor_id: StringName) -> bool:
	return bool(state().chapter_two.get("dialogues_seen", {}).get("%s:%s" % [actor_id, dialogue_id], false))

func _social_event(actor_id: StringName, action: String) -> bool:
	return bool(state().social.get("applied_events", {}).get("ch2:caravan:%s:%s" % [actor_id, action], false))

func _hurt(actor_id: StringName) -> bool:
	var actor: Dictionary = state().actors.get(String(actor_id), {})
	return bool(actor.get("resentful", false)) or bool(actor.get("hostile", false)) or _social_event(actor_id, "swallow") or _social_event(actor_id, "assault")

func _merchant_dialogue() -> String:
	if _hurt(&"caravan_merchant"): return "merchant_hurt"
	if _social_event(&"caravan_merchant", "threat"): return "merchant_threatened"
	if bool(state().chapter_two.get("settled", false)) or (bool(state().chapter_two.get("inner_latch", false)) and not _keti_in_cart()): return "merchant_rescued"
	if bool(state().chapter_two.get("inner_latch", false)): return "merchant_cart_open"
	if bool(state().chapter_two.get("outer_lock", false)): return "merchant_open"
	return "merchant_repeat" if _dialogue_seen("merchant", &"caravan_merchant") else "merchant"

func _keti_in_cart() -> bool:
	var keti := world().get_story_actor(&"keti")
	return is_instance_valid(keti) and keti.visible and not keti.is_riding() and keti.global_position.distance_to(Vector2(552, 324)) < 100

func _keti_dialogue(npc: NpcActor) -> String:
	if bool(state().chapter_two.get("duo", false)):
		return "keti_duo_hurt" if _hurt(&"keti") else "keti_duo"
	if bool(state().chapter_two.get("settled", false)) and npc.global_position.distance_to(COT) < 100:
		if _hurt(&"keti"): return "keti_cot_hurt"
		return "keti_cot_repeat" if _dialogue_seen("keti_cot", &"keti") else "keti_cot"
	return "keti_awake_repeat" if _dialogue_seen("keti_awake", &"keti") else "keti_awake"

func interact_actor(actor_id: StringName) -> void:
	var npc := world().get_story_actor(actor_id)
	if not is_instance_valid(npc) or not npc.visible: return
	if actor_id == &"keti" and not bool(state().chapter_two.get("duo", false)) and not bool(state().chapter_two.get("inner_latch", false)):
		show("locked")
		return
	var actor := Dictionary(state().actors.get(String(actor_id), {}))
	actor["met"] = true
	state().actors[String(actor_id)] = actor
	if npc.is_downed:
		show("keti_down" if actor_id == &"keti" else "npc_down", actor_id)
	elif actor_id == &"caravan_merchant":
		show(_merchant_dialogue(), actor_id)
	elif actor_id == &"keti":
		show(_keti_dialogue(npc), actor_id)
	elif _hurt(actor_id):
		show("npc_hurt", actor_id)
	elif _social_event(actor_id, "threat"):
		show("npc_threatened", actor_id)
	else:
		var greeting := String(actor_id) if dialogue_source.has(String(actor_id)) else "npc"
		show(greeting + "_repeat" if _dialogue_seen(greeting, actor_id) and dialogue_source.has(greeting + "_repeat") else greeting, actor_id)

func interact_item(item_id: StringName) -> void:
	match item_id:
		&"ch2_key": show("key_open" if bool(state().chapter_two.get("outer_lock", false)) else "key")
		&"ch2_lever": show("lever_open" if bool(state().chapter_two.get("inner_latch", false)) else "lever")
		&"ch2_cart":
			if not bool(state().chapter_two.get("inner_latch", false)):
				show("cart_unlocked" if bool(state().chapter_two.get("outer_lock", false)) else "cart")
			else:
				show("cart_open" if _keti_in_cart() else "cart_empty")
		&"ch2_cot": show("cot_done" if bool(state().chapter_two.get("duo", false)) else "cot")

func _sync_cart() -> void:
	if state().current_map != MAP: return
	# The scene gate flag is a projection of chapter progress, never a second fact.
	var opened := bool(state().chapter_two.get("inner_latch", false))
	state().flags["ch2_cart_open"] = opened
	var gate := world().layout.get_node("Interactables/CartGate") as StoryGate
	gate.setup(state().flags)

func on_harmed(actor_id: StringName, was_hostile: bool, _source: StringName) -> void:
	if state().current_map != MAP: return
	var actor: Dictionary = state().actors.get(String(actor_id), {})
	actor["resentful"] = true
	actor["wake_hostile"] = was_hostile
	actor["hp"] = world().get_story_actor(actor_id).hp
	state().actors[String(actor_id)] = actor
	if not was_hostile: _score(actor_id, "assault", 1)

func _score(actor_id: StringName, action: String, fear: int) -> void:
	state().apply_social_event("ch2:caravan:%s:%s" % [actor_id, action], 0, fear)
	_refresh_goal()

func choose(choice_id: String) -> void:
	var epoch: int = director.flow_epoch
	var source_dialogue := String(director.current_id).trim_prefix("ch2_")
	var source_actor := actor_context
	var selected: Dictionary = director.runner.choose(choice_id)
	if not bool(selected.get("ok", false)): return
	director.panel.set_input_locked(true)
	var result: Dictionary = await execute(String(selected.get("action", "")), actor_context)
	if epoch != director.flow_epoch: return
	if not bool(result.get("ok", false)):
		director.panel.set_input_locked(false)
		director.status_changed.emit(String(result.get("message", "请先完成前一步。")))
		return
	# Record a completed conversation only after a successful choice. Merely
	# opening or cancelling its panel must not suppress an unread introduction.
	var seen: Dictionary = state().chapter_two.get("dialogues_seen", {})
	seen["%s:%s" % [source_actor, source_dialogue]] = true
	state().chapter_two["dialogues_seen"] = seen
	var presentation: Dictionary = selected.choice.get("presentation", {})
	if not presentation.is_empty():
		director.panel.set_presentation_expression(String(presentation.get("portrait_expression", "")), String(presentation.get("portrait_id", "")))
		await director.session.play_cg(presentation)
		if epoch != director.flow_epoch: return
	director.panel.set_input_locked(false)
	director.panel.close()
	director.pause_requested.emit(&"dialogue", false)
	director._finish_world_interaction()
	director.current_id = "ch2_explore"
	_refresh_goal()
	var next := String(result.get("next", selected.get("next", "")))
	if not next.is_empty(): show(next, actor_context)

func _fail(message: String) -> Dictionary:
	return {"ok": false, "message": message}

func _board_keti(keti: NpcActor) -> bool:
	var active_world := world()
	var player := active_world.player
	if not is_instance_valid(keti) or not is_instance_valid(player) or player.is_dead:
		return false
	var original_position := keti.global_position
	if String(state().player.get("rider", "")) == "keti":
		return keti.is_riding()
	if not String(state().player.get("rider", "")).is_empty() or not keti.can_attach_to_carrier(player):
		return false
	var boarding_epoch: int = director.flow_epoch
	var boarding_map: StringName = state().current_map
	player.set_movement_locked(true)
	director.pause_requested.emit(&"cutscene", true)
	var boarded: bool = await keti.walk_to_carrier(player)
	var still_current: bool = boarding_epoch == director.flow_epoch and state().current_map == boarding_map and director.session.current_world == active_world and is_instance_valid(player) and is_instance_valid(keti)
	if boarded and not still_current and is_instance_valid(keti) and keti.is_riding():
		keti.detach_from_carrier(original_position)
	if still_current and boarded:
		state().player["rider"] = "keti"
		var actor: Dictionary = state().actors["keti"]
		actor.merge({"status": "riding", "location": "rider", "hp": keti.hp}, true)
		actor.erase("transport_down")
		state().actors["keti"] = actor
	if is_instance_valid(player): player.set_movement_locked(false)
	if boarding_epoch == director.flow_epoch:
		director.pause_requested.emit(&"cutscene", false)
	return still_current and boarded

func execute(action: String, actor_id: StringName) -> Dictionary:
	var progress := state().chapter_two
	var companion_action := actor_id == &"keti" and bool(progress.get("duo", false)) and action in ["ride", "dismount", "eat", "attack", "face", "foot", "leave", ""]
	if not is_instance_valid(world()): return _fail("已经离开这张地图。")
	if state().current_map != MAP and not companion_action: return _fail("已经离开这张地图。")
	var npc := world().get_story_actor(actor_id) if not actor_id.is_empty() else null
	match action:
		"intro": progress["intro_seen"] = true
		"negotiate", "threat":
			var threatened_before := _social_event(actor_id, "threat")
			if action == "threat" and actor_id != &"caravan_merchant":
				if not is_instance_valid(npc) or not npc.visible or npc.is_downed: return _fail("他现在没法回答。")
				_score(actor_id, "threat", 2)
				return {"ok": true, "next": "npc_threat_again" if threatened_before else "npc_threat_reply"}
			if actor_id != &"caravan_merchant" or not is_instance_valid(npc) or not npc.visible or npc.is_downed: return _fail("他现在没法回答。工具箱里有备用钥匙。")
			if bool(progress.get("outer_lock", false)):
				if action == "threat":
					_score(actor_id, "threat", 2)
					return {"ok": true, "next": "npc_threat_again" if threatened_before else "npc_threat_reply"}
				return {"ok": true, "next": _merchant_dialogue()}
			progress["outer_lock"] = true
			if action == "threat": _score(actor_id, "threat", 2)
			return {"ok": true, "next": "threat_reply" if action == "threat" else "deal_reply"}
		"key":
			if bool(progress.get("outer_lock", false)): return {"ok": true, "next": "key_open"}
			progress["outer_lock"] = true
			world().consume_story_pickup(&"ch2_key")
		"lever":
			if not bool(progress.get("outer_lock", false)): return _fail("外面的锁还没开：找商人，或取工具箱里的钥匙。")
			if bool(progress.get("inner_latch", false)): return {"ok": true, "next": "lever_open"}
			progress["inner_latch"] = true
			_sync_cart()
		"eat", "protect":
			if not is_instance_valid(npc) or not npc.visible or npc.is_riding(): return _fail("先把这个人放下来。")
			if actor_id == &"keti" and not bool(progress.get("inner_latch", false)): return _fail("车门还没开。")
			if action == "protect" and (actor_id != &"keti" or not npc.is_downed or not bool(progress.get("inner_latch", false))): return _fail("保护转移只用于已经开门的昏迷可蒂。")
			world().capture_actor_states()
			var result: Dictionary = director._swallow_actor(actor_id)
			if not bool(result.get("ok", false)): return _fail("胃袋已满，请退出对话，先吐出物品或角色。")
			if action == "eat": _score(actor_id, "swallow", 3)
		"attack":
			if not is_instance_valid(npc) or not npc.visible or npc.is_downed or npc.is_riding(): return _fail("他已经倒下，或者需要先放下来。")
			if actor_id == &"keti" and not bool(progress.get("inner_latch", false)): return _fail("车门还没开。")
			npc.take_damage(npc.hp, &"choice_attack")
			return {"ok": true, "next": "keti_down" if actor_id == &"keti" else "npc_down"}
		"face", "foot":
			if not is_instance_valid(npc) or not npc.visible or not npc.is_downed or npc.is_riding(): return _fail("先把昏迷的人放到地上。")
			if actor_id == &"keti" and not bool(progress.get("inner_latch", false)): return _fail("车门还没开。")
			var actor: Dictionary = state().actors.get(String(actor_id), {})
			var previous_hostile := bool(actor.get("wake_hostile", actor.get("hostile", npc.hostile)))
			npc.restore_persistent_state({"hp": maxf(1.0, npc.hp), "active": true, "damageable": true, "is_dead": false, "is_downed": false, "hostile": previous_hostile, "defeat_mode": "downed"})
			actor["status"] = "alive"
			actor["hp"] = npc.hp
			actor["hostile"] = previous_hostile
			actor["location"] = String(state().current_map)
			actor["damageable"] = true
			actor.erase("transport_down")
			state().actors[String(actor_id)] = actor
			if actor_id == &"keti":
				if progress.has("first_wake"): return {"ok": true, "next": "keti_rewake_reply"}
				progress["first_wake"] = action
				return {"ok": true, "next": "keti_foot_reply" if action == "foot" else "keti_face_reply"}
			return {"ok": true, "next": "wake_reply"}
		"stretcher":
			if actor_id != &"keti" or not is_instance_valid(npc) or not npc.visible or not bool(progress.get("inner_latch", false)): return _fail("先打开车门，找到可蒂。")
			if not String(state().player.get("rider", "")).is_empty(): return _fail("蛇背上已经有乘客，请先到休息台让他下来。")
			if not npc.attach_to_carrier(world().player, Vector2(0, -8)): return _fail("现在无法安置担架。")
			progress["stretcher"] = "keti"
			state().player["rider"] = "keti"
			var actor: Dictionary = state().actors["keti"]
			actor["status"] = "riding"
			actor["location"] = "rider"
			actor["transport_down"] = npc.is_downed
		"ride":
			if actor_id != &"keti" or not bool(progress.get("duo", false)) or not is_instance_valid(npc) or not npc.visible or npc.is_dead or npc.is_downed: return _fail("可蒂现在无法上蛇。先让她醒来。")
			if not String(state().player.get("rider", "")).is_empty(): return _fail("蛇背上已经有乘客，请先让他下来，再叫可蒂上蛇。")
			if not await _board_keti(npc): return _fail("可蒂没能上蛇，走近她后可以再试一次。")
		"settle":
			if not bool(progress.get("inner_latch", false)): return _fail("先打开车门，把可蒂带出来。")
			if world().player.global_position.distance_to(Vector2(1008, 420)) > 80: return _fail("先到渡口的休息台旁边。")
			var keti := world().get_story_actor(&"keti")
			var actor: Dictionary = state().actors["keti"]
			var swallowed := world().player.inventory.count_item(&"keti") > 0
			var carried := is_instance_valid(keti) and keti.is_riding()
			if not swallowed and not carried and (not is_instance_valid(keti) or not keti.visible or keti.global_position.distance_to(COT) > 120): return _fail("需要把可蒂带到这里，不能隔空搬人。")
			var down := swallowed or (is_instance_valid(keti) and keti.is_downed)
			var current_hp := float(actor.get("hp", 0.0)) if swallowed or not is_instance_valid(keti) else keti.hp
			if swallowed: world().player.consume_inventory_item(&"keti")
			if not is_instance_valid(keti) or keti.player == null: keti = world().spawn_npc(&"keti", COT)
			if keti.is_riding(): keti.detach_from_carrier(COT)
			keti.global_position = COT
			keti.restore_persistent_state({"hp": current_hp, "active": true, "damageable": true, "is_dead": false, "is_downed": down, "defeat_mode": "downed", "hostile": bool(actor.get("wake_hostile", actor.get("hostile", false)))})
			actor.merge({"status": "unconscious" if down else "alive", "location": String(MAP), "position": [COT.x, COT.y], "hp": keti.hp}, true)
			actor.erase("transport_down")
			state().actors["keti"] = actor
			progress["stretcher"] = ""
			if state().player.get("rider", "") == "keti": state().player["rider"] = ""
			progress["settled"] = true
			actor_context = &"keti"
			return {"ok": true, "next": "keti_down" if down else _keti_dialogue(keti)}
		"dismount":
			var passenger_id := StringName(state().player.get("rider", ""))
			if passenger_id.is_empty(): passenger_id = StringName(progress.get("stretcher", ""))
			var passenger := world().get_story_actor(passenger_id)
			if passenger_id.is_empty() or not is_instance_valid(passenger) or not passenger.is_riding(): return _fail("蛇背上现在没有乘客。")
			var direct_rider_interaction := actor_id == passenger_id and passenger_id == &"keti" and bool(progress.get("duo", false))
			if not direct_rider_interaction and world().player.global_position.distance_to(Vector2(1008, 420)) > 80: return _fail("先到渡口的休息台旁边。")
			var landing := COT + Vector2(0, 96)
			if direct_rider_interaction:
				landing = world().player.body_chain.segments[1] + world().player.direction.orthogonal().normalized() * 36.0
			if not passenger.detach_from_carrier(landing): return _fail("现在无法放下乘客。")
			var actor: Dictionary = state().actors[String(passenger_id)]
			var wake_hostile := bool(actor.get("wake_hostile", actor.get("hostile", passenger.hostile)))
			passenger.restore_persistent_state({"hp": passenger.hp, "active": true, "damageable": true, "is_dead": false, "is_downed": passenger.is_downed, "defeat_mode": "downed", "hostile": wake_hostile})
			actor.merge({"status": "unconscious" if passenger.is_downed else "alive", "location": String(state().current_map), "position": [passenger.global_position.x, passenger.global_position.y], "hp": passenger.hp, "damageable": true, "defeat_mode": "downed"}, true)
			actor.erase("transport_down")
			state().actors[String(passenger_id)] = actor
			state().player["rider"] = ""
			if progress.get("stretcher", "") == String(passenger_id): progress["stretcher"] = ""
		"duo":
			var keti := world().get_story_actor(&"keti")
			if actor_id != &"keti" or not bool(progress.get("settled", false)) or not is_instance_valid(keti) or not keti.visible or keti.is_downed or keti.is_riding() or keti.global_position.distance_to(COT) > 100 or world().player.inventory.count_item(&"keti") > 0: return _fail("先把可蒂安置在渡口，再叫醒她。")
			if bool(progress.get("duo", false)): return {"ok": true, "next": _keti_dialogue(keti)}
			var seat_available := String(state().player.get("rider", "")).is_empty() and keti.can_attach_to_carrier(world().player)
			if seat_available and not await _board_keti(keti): return _fail("可蒂没能上蛇，走近她后可以再试一次。")
			progress["duo"] = true
			if seat_available:
				state().actors["keti"]["status"] = "riding"
				state().actors["keti"]["location"] = "rider"
			state().apply_social_event("ch2:quest:reunite_keti", 3, 0)
			return {"ok": true, "next": "ending" if seat_available else "ending_occupied"}
		"", "leave": pass
		_: return _fail("未知的第二章行动。")
	return {"ok": true}
