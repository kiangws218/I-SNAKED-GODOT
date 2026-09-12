extends SceneTree

var failures: Array[String] = []
var projectile_scene: PackedScene = load("res://game/projectiles/bean_projectile.tscn")
var player_scene: PackedScene = load("res://game/player/snake_player.tscn")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var player := player_scene.instantiate() as SnakePlayer
	root.add_child(player)
	await process_frame
	player.set_physics_process(false)
	player.global_position = Vector2(400, 400)
	player.body_chain.segments = [
		Vector2(400, 400),
		Vector2(376, 400),
		Vector2(352, 400),
	]

	_test_weight_launch_speed(player)
	_test_actor_extra_drag(player)
	await _test_potion_swept_self_hit(player)
	_test_potion_wall_hit(player)

	player.queue_free()
	await process_frame
	if failures.is_empty():
		print("PROJECTILE FEEDBACK TESTS PASSED")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _test_weight_launch_speed(player: SnakePlayer) -> void:
	var bean := _projectile(player, {"id": &"bean", "weight": 0})
	var light := _projectile(player, {"id": &"iron_sword", "weight": 1})
	var heavy := _projectile(player, {"id": &"iron_sword", "weight": 3})
	check(heavy.speed < light.speed, "同类物品重量越高，发射速度越慢")
	check(heavy.speed < bean.speed, "重量 3 物品初速低于普通豆")
	check(is_equal_approx(bean.speed, BeanProjectile.INITIAL_SPEED), "普通豆初速基线未改变")
	bean.queue_free()
	light.queue_free()
	heavy.queue_free()


func _test_actor_extra_drag(player: SnakePlayer) -> void:
	var heavy := _projectile(player, {"id": &"iron_sword", "weight": 3})
	var actor := _projectile(player, {
		"id": &"lisi",
		"weight": 3,
		"actor": true,
		"metadata": {"actor_id": "lisi"},
	})
	var heavy_initial := heavy.speed
	var actor_initial := actor.speed
	heavy._physics_process(0.1)
	actor._physics_process(0.1)
	check(is_equal_approx(heavy_initial, actor_initial), "同重量角色与普通重物初速基线一致")
	check(actor.speed < heavy.speed, "同重量角色受到额外阻力并飞得更近")
	heavy.queue_free()
	actor.queue_free()


func _test_potion_swept_self_hit(player: SnakePlayer) -> void:
	player.hearts = 1
	player.body_chain.segments = [
		Vector2(400, 400),
		Vector2(376, 400),
		Vector2(130, 115),
	]
	var potion := _projectile(player, {
		"id": &"healing_potion",
		"healing": 1,
		"weight": 1,
	}, Vector2(100, 100))
	potion._physics_process(0.05)
	check(player.hearts == 1 and not potion.is_queued_for_deletion(), "药水 0.22 秒前不触发自身蛇身治疗")
	potion._physics_process(0.18)
	check(player.hearts == 2, "药水高速扫过自身第 2 节后蛇身可治疗")
	check(potion.is_queued_for_deletion(), "药水自身蛇身治疗后立即碎裂")

	player.hearts = 1
	var edge_potion := _projectile(player, {
		"id": &"healing_potion",
		"healing": 1,
		"weight": 1,
	}, Vector2(100, 100))
	edge_potion._physics_process(0.05)
	player.body_chain.segments[2] = Vector2(130, 115)
	edge_potion._physics_process(0.18)
	check(player.hearts == 2, "药水距离蛇身 15 像素边缘仍可命中")
	edge_potion.queue_free()
	await process_frame


func _test_potion_wall_hit(player: SnakePlayer) -> void:
	player.hearts = 1
	var potion := _projectile(player, {"id": &"healing_potion", "healing": 1, "weight": 1})
	potion._on_collision(Vector2.LEFT)
	check(player.hearts == 1 and potion.is_queued_for_deletion(), "药水撞墙破碎且不恢复生命")
	potion.queue_free()


func _projectile(player: SnakePlayer, payload: Dictionary, origin := Vector2(100, 100)) -> BeanProjectile:
	var projectile := projectile_scene.instantiate() as BeanProjectile
	root.add_child(projectile)
	projectile.launch(payload, origin, Vector2.RIGHT, player)
	return projectile


func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
