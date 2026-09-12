extends SceneTree

var failures: Array[String] = []
var mount_finished := false
var mount_result := false

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var player := preload("res://game/player/snake_player.tscn").instantiate() as SnakePlayer
	root.add_child(player)
	player.set_physics_process(false)
	player.global_position = Vector2(-100, 0)
	var npc := _npc(&"keti", Vector2.ZERO, player)
	npc.set_physics_process(false)
	player.global_position = Vector2(-15, 0)
	npc._physics_process(0.016)
	check(npc.interaction_count == 1, "首次头触立即请求互动")
	npc.finish_interaction()
	player.global_position = Vector2(28, 0)
	npc._physics_process(0.016)
	player.global_position = Vector2(15, 0)
	npc._physics_process(0.016)
	check(npc.interaction_count == 2, "仅离开头触范围即可重新互动，不必绕远")
	npc.finish_interaction()
	player.global_position = Vector2(-90, 0)
	npc._physics_process(0.016)
	player.global_position = Vector2(90, 0)
	npc._physics_process(0.016)
	check(npc.interaction_count == 3, "高速蛇头扫过人物不漏掉互动")
	npc.queue_free()
	await process_frame
	player.global_position = Vector2(-500, -500)
	var pair := Node2D.new()
	root.add_child(pair)
	var ajie := _npc(&"ajie", Vector2(200, 200), player, pair)
	var lisi := _npc(&"lisi", Vector2(248, 200), player, pair)
	ajie.roam_partner_id = &"lisi"
	lisi.roam_partner_id = &"ajie"
	ajie.set_physics_process(false)
	lisi.set_physics_process(false)
	var start := ajie.global_position
	seed(128)
	for index in range(600):
		ajie._physics_process(0.016)
		lisi._physics_process(0.016)
	check(ajie.global_position.distance_to(start) > 1, "成对角色真实游走")
	check(ajie.global_position.distance_to(ajie._roam_origin) <= ajie.roam_radius + 1, "游走不离开限定区域")
	check(is_equal_approx(ajie.global_position.distance_to(lisi.global_position), 48), "成对游走保持近距离队形")
	var stopped := ajie.global_position
	lisi.interaction_open = true
	ajie._physics_process(0.1)
	check(ajie.global_position == stopped, "同伴交谈时双方停止游走")
	lisi.interaction_open = false
	lisi.global_position = ajie.global_position + Vector2(0, 120)
	ajie.configure_pair_roam()
	check(is_equal_approx(ajie.global_position.distance_to(lisi.global_position), 48), "构建地图时兼容旧存档过远的静态人物队形")
	pair.queue_free()
	await process_frame
	player.global_position = Vector2(400, 400)
	player.body_chain.segments = [Vector2(400, 400), Vector2(376, 400), Vector2(352, 400)]
	var ajian := _npc(&"ajian", Vector2(340, 440), player)
	var before := ajian.global_position
	paused = true
	_mount(ajian, player)
	await create_timer(0.15, true).timeout
	check(not ajian.is_riding() and ajian.global_position.distance_to(before) > 1, "阿见先走近蛇颈，不瞬移登蛇")
	check(String(ajian.character_sprite.animation).begins_with("walk_"), "登蛇走近过程播放已有行走动画")
	await create_timer(1.5, true).timeout
	check(mount_finished and mount_result and ajian.is_riding(), "暂停演出完成后才挂载蛇身")
	check(ajian.global_position.distance_to(player.body_chain.segments[1]) < 1, "登上第二节，挂载首帧不闪到蛇头")
	ajian.detach_from_carrier(Vector2(340, 440))
	mount_finished = false
	mount_result = false
	_mount(ajian, player)
	await create_timer(0.1, true).timeout
	player.is_dead = true
	await create_timer(1.5, true).timeout
	check(mount_finished and not mount_result and not ajian.is_riding(), "登蛇中死亡不提交骑乘状态")
	ajian.queue_free()
	paused = false
	player.queue_free()
	await process_frame
	if failures.is_empty():
		print("NPC ROUND 2 FEEDBACK TESTS PASSED")
		quit(0)
	else:
		for failure in failures: push_error(failure)
		quit(1)

func _mount(npc: NpcActor, player: SnakePlayer) -> void:
	mount_result = await npc.walk_to_carrier(player)
	mount_finished = true

func _npc(id: StringName, at: Vector2, player: SnakePlayer, parent: Node = root) -> NpcActor:
	var npc := preload("res://game/actors/npc_actor.tscn").instantiate() as NpcActor
	npc.npc_id = id
	npc.position = at
	parent.add_child(npc)
	npc.setup(player)
	return npc

func check(condition: bool, message: String) -> void:
	if not condition: failures.append(message)
