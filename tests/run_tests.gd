extends SceneTree

var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_test_project_contract()
	_test_body_chain()
	_test_inventory_contract()
	_test_enclosure_detector()
	await _test_real_input_and_rescue()
	await _test_n2_input_dispatch()
	await _test_n2_real_resource_input()
	_test_n3_contract()
	await _test_n3_real_paths()
	if failures.is_empty():
		print("N3 TESTS PASSED (INCLUDING N1/N2 REGRESSION)")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _test_project_contract() -> void:
	var version := Engine.get_version_info()
	check(version.major == 4 and version.minor == 7 and version.patch == 2, "Godot 4.7.2")
	check(ProjectSettings.get_setting("application/config/name") == "I SNAKED-GODOT", "项目名称")
	check(ProjectSettings.get_setting("application/run/main_scene") == "res://game/main.tscn", "主场景设置")
	for action in [
		"move_up", "move_down", "move_left", "move_right", "spit",
		"place_node", "cut_tail", "inventory_previous", "inventory_next",
		"interact", "pause",
	]:
		check(InputMap.has_action(action), "输入动作：%s" % action)
	check(_has_key("move_up", KEY_W) and _has_key("move_up", KEY_UP), "上移默认绑定")
	check(_has_key("move_down", KEY_S) and _has_key("move_down", KEY_DOWN), "下移默认绑定")
	check(_has_key("move_left", KEY_A) and _has_key("move_left", KEY_LEFT), "左移默认绑定")
	check(_has_key("move_right", KEY_D) and _has_key("move_right", KEY_RIGHT), "右移默认绑定")
	check(_has_key("spit", KEY_J) and _has_key("spit", KEY_SPACE), "吐出默认绑定 J / 空格")
	check(_has_key("inventory_previous", KEY_Q) and _has_key("inventory_next", KEY_E), "胃袋 Q / E 默认绑定")
	check(_has_key("cut_tail", KEY_K) and _has_key("place_node", KEY_F), "断尾 K / 节点 F 默认绑定")
	for layer_index in range(1, 11):
		check(
			not String(ProjectSettings.get_setting("layer_names/2d_physics/layer_%d" % layer_index, "")).is_empty(),
			"物理层命名：%d" % layer_index,
		)
	for scene_path in [
		"res://game/main.tscn", "res://game/test_arena.tscn", "res://game/player/snake_player.tscn",
		"res://game/projectiles/bean_projectile.tscn", "res://game/projectiles/enemy_projectile.tscn",
		"res://game/nodes/ring_node.tscn", "res://game/actors/enemy_actor.tscn", "res://game/actors/npc_actor.tscn",
	]:
		check(ResourceLoader.exists(scene_path), "场景存在：%s" % scene_path)
	for audio_path in [
		"res://assets/audio/spit.wav", "res://assets/audio/pickup.wav", "res://assets/audio/node.wav",
		"res://assets/audio/hurt.wav", "res://assets/audio/interact.wav", "res://assets/audio/prison.wav",
	]:
		check(ResourceLoader.exists(audio_path), "N2/N3 音效存在：%s" % audio_path)
	check(ResourceLoader.exists("res://assets/enemies/mushroom/idle.png"), "蘑菇待机素材存在")
	check(ResourceLoader.exists("res://assets/enemies/slime/idle.png"), "史莱姆素材存在")
	var production_audio: Array[String] = []
	for file_name in DirAccess.get_files_at("res://assets/audio"):
		if not file_name.ends_with(".import"):
			production_audio.append(file_name)
	production_audio.sort()
	check(production_audio == ["hurt.wav", "interact.wav", "node.wav", "pickup.wav", "prison.wav", "spit.wav"], "N2/N3 只导入已选音效")


func _test_body_chain() -> void:
	var chain := BodyChain.new()
	root.add_child(chain)
	chain.reset(Vector2(240, 240), Vector2.RIGHT)
	check(chain.segments.size() == 4, "初始四节身体")
	check(chain.segments[1].is_equal_approx(Vector2(216, 240)), "身体间距 1 格")
	chain.set_segment_count(12, Vector2(240, 240))
	var grown_spacing_valid := true
	for index in range(chain.segments.size() - 1):
		if not is_equal_approx(chain.segments[index].distance_to(chain.segments[index + 1]), 24.0):
			grown_spacing_valid = false
			break
	check(grown_spacing_valid, "原地增长后尾部轨迹不会塌缩")
	chain.segment_count = 256
	chain.reset(Vector2(240, 240), Vector2.RIGHT)
	var started := Time.get_ticks_usec()
	var samples_ms: Array[float] = []
	for index in range(120):
		var sample_started := Time.get_ticks_usec()
		chain.record_head(Vector2(240 + index, 240))
		samples_ms.append((Time.get_ticks_usec() - sample_started) / 1000.0)
	var elapsed_ms := (Time.get_ticks_usec() - started) / 1000.0
	samples_ms.sort()
	var average_ms := elapsed_ms / samples_ms.size()
	var p95_ms := samples_ms[floori((samples_ms.size() - 1) * 0.95)]
	check(chain.segments.size() == 256, "256 节压力样本完整")
	var spacing_valid := true
	for index in range(chain.segments.size() - 1):
		if not is_equal_approx(chain.segments[index].distance_to(chain.segments[index + 1]), 24.0):
			spacing_valid = false
			break
	check(spacing_valid, "256 节完整轨迹保持 1 格间距")
	check(average_ms <= 2.0 and p95_ms <= 4.0, "256 节重建满足 60 FPS 预算")
	print("N1 BODY STRESS: 256 segments, 120 rebuilds, avg %.3f ms, p95 %.3f ms" % [average_ms, p95_ms])
	chain.segments.assign([
		Vector2(240, 240), Vector2(216, 240), Vector2(192, 240), Vector2(168, 240),
		Vector2(144, 240), Vector2(240, 250),
	])
	check(chain.collides_with_tail(Vector2(240, 250), 0.62 * 24.0, 4), "第 4 节后自撞")
	check(not chain.collides_with_tail(Vector2(168, 240), 1.0, 4), "索引 3 是最后一个颈部豁免节")
	check(chain.collides_with_tail(Vector2(144, 240), 1.0, 4), "索引 4 是第一个自撞节")
	check(not chain.collides_with_tail(Vector2(250, 250), 10.0, 4), "自撞阈值严格小于")
	chain.queue_free()


func _test_inventory_contract() -> void:
	var inventory := StomachInventory.new()
	check(inventory.slot_count() == 1 and inventory.selected_id() == &"bean", "豆子永久槽")
	check(inventory.current_weight() == 0 and inventory.occupied_length() == 0, "豆槽零重量零长度")
	check(inventory.add_item(&"iron_sword") and inventory.add_item(&"iron_sword"), "铁剑可堆叠加入")
	check(inventory.count_item(&"iron_sword") == 2 and inventory.slot_count() == 2, "同类铁剑共用槽")
	check(inventory.current_weight() == 4 and inventory.occupied_length() == 2, "铁剑重量与占长")
	check(inventory.add_item(&"healing_potion"), "药水加入")
	check(inventory.current_weight() == 5 and inventory.occupied_length() == 3, "特殊物品累计值")
	check(not inventory.add_item(&"ajie", {"hp": 7, "story_id": "ajie"}), "超过承重 6 时拒绝吞入")
	check(inventory.bean_ammo(12) == 6, "豆弹药保护最短长度与特殊占长")
	check(inventory.cycle(1) == &"iron_sword", "E 选择下一个胃袋槽")
	var sword := inventory.consume_selected()
	check(sword.id == &"iron_sword" and sword.damage == 8, "铁剑先扣库存并保留伤害")
	check(inventory.count_item(&"iron_sword") == 1, "铁剑每次只消耗一件")
	inventory.cycle(-1)
	check(inventory.selected_id() == &"bean", "Q 循环回豆槽")
	var actor_inventory := StomachInventory.new()
	check(actor_inventory.add_item(&"lisi", {"hp": 9, "story_id": "lisi"}), "角色载荷可加入")
	actor_inventory.cycle(1)
	var actor_payload := actor_inventory.consume_selected()
	check(actor_payload.metadata.hp == 9 and actor_payload.metadata.story_id == "lisi", "角色投射保留生命与身份")
	var exact_capacity := StomachInventory.new()
	check(exact_capacity.add_item(&"iron_sword") and exact_capacity.add_item(&"iron_sword") and exact_capacity.add_item(&"iron_sword"), "重量恰好 6 仍允许")
	check(exact_capacity.current_weight() == 6 and not exact_capacity.add_item(&"healing_potion"), "承重上限严格为 6")
	var bones := StomachInventory.new()
	check(bones.add_item(&"character_bones", {"story_id": "ajie"}), "角色骨头保留原身份元数据")
	bones.cycle(1)
	check(bones.consume_selected().metadata.story_id == "ajie", "骨头吐出后身份不丢失")
	check(int(StomachInventory.DEFINITIONS[&"keti_corpse"].length) == 2 and not StomachInventory.DEFINITIONS[&"keti_corpse"].has("actor"), "可蒂尸体占两节且不是昏迷角色")


func _test_enclosure_detector() -> void:
	var bounds := Rect2i(0, 0, 7, 7)
	var ring: Dictionary[Vector2i, StringName] = {}
	for x in range(2, 5):
		ring[Vector2i(x, 2)] = &"body"
		ring[Vector2i(x, 4)] = &"body"
	for y in range(2, 5):
		ring[Vector2i(2, y)] = &"body"
		ring[Vector2i(4, y)] = &"body"
	var regions := EnclosureDetector.find_regions(bounds, ring)
	check(regions.size() == 1 and regions[0].cells.has(Vector2i(3, 3)), "四邻接洪泛识别身体封闭区")
	check(regions[0].touches_body and not regions[0].touches_node, "普通身体围圈分类")
	ring.erase(Vector2i(3, 2))
	check(EnclosureDetector.find_regions(bounds, ring).is_empty(), "一格断口立即解除围圈")
	ring[Vector2i(3, 2)] = &"node"
	regions = EnclosureDetector.find_regions(bounds, ring)
	check(regions.size() == 1 and regions[0].touches_node and regions[0].touches_body, "节点封口围圈分类")


func _test_real_input_and_rescue() -> void:
	var arena: Node = load("res://game/test_arena.tscn").instantiate()
	root.add_child(arena)
	await physics_frame
	var player: SnakePlayer = arena.get_node("SnakePlayer")
	player.set_physics_process(false)
	player.play_sfx = false
	player.reset_at(Vector2(300, 240), Vector2.RIGHT)
	check(not player.queue_direction(Vector2.LEFT), "反向输入不占方向队列")
	check(player.queue_direction(Vector2.DOWN), "安全方向进入队列")
	check(player.apply_next_direction(), "应用安全方向")
	check(player.direction.is_equal_approx(Vector2.DOWN), "禁止 180 度掉头")
	player.reset_at(Vector2(300, 240), Vector2.RIGHT)
	player.queue_direction(Vector2(1, 1))
	player.apply_next_direction()
	check(is_equal_approx(player.direction.length(), 1.0), "斜向速度归一化")
	player.reset_at(Vector2(300, 240), Vector2.RIGHT)
	check(not player.queue_direction(Vector2.RIGHT), "重复方向不入队")
	for candidate in [Vector2.UP, Vector2.DOWN, Vector2.UP, Vector2.DOWN]:
		player.queue_direction(candidate)
	check(player.direction_queue.size() == 1, "相对未来方向的反向输入不占队列")
	player.queue_direction(Vector2.LEFT)
	player.queue_direction(Vector2.DOWN)
	player.queue_direction(Vector2.RIGHT)
	check(player.direction_queue.size() == 3, "方向队列上限 3 个有效方向")

	player.reset_at(Vector2(300, 240), Vector2.RIGHT)
	var cardinal_start := player.global_position
	player.simulate_motion(0.05, false)
	var cardinal_distance := cardinal_start.distance_to(player.global_position)
	player.reset_at(Vector2(300, 240), Vector2(1, 1))
	var diagonal_start := player.global_position
	player.simulate_motion(0.05, false)
	var diagonal_distance := diagonal_start.distance_to(player.global_position)
	check(is_equal_approx(cardinal_distance, diagonal_distance), "斜向实际位移不额外加速")
	player.reset_at(Vector2(300, 240), Vector2.RIGHT)
	var boost_start := player.global_position
	player.simulate_motion(0.05, true)
	check(is_equal_approx(boost_start.distance_to(player.global_position), cardinal_distance * 2.0), "冲刺实际位移为 2 倍")

	player.reset_at(Vector2(300, 240), Vector2.RIGHT)
	player.body_chain.segments.assign([
		Vector2(300, 240), Vector2(276, 240), Vector2(252, 240), Vector2(228, 240),
		Vector2(312, 240),
	])
	player.simulate_motion(0.05, true)
	check(player.danger_kind == "self", "玩家物理状态机进入自撞救援窗")
	player.queue_direction(Vector2.UP)
	player.apply_next_direction()
	var rescue_start := player.global_position
	player.simulate_motion(0.05, true)
	check(player.danger_kind.is_empty() and not player.is_dead, "自撞后安全转向成功")
	check(player.global_position.y < rescue_start.y, "自撞脱险后继续移动")

	player.reset_at(Vector2(480, 240), Vector2.RIGHT)
	player._enter_danger("wall")
	for index in range(9):
		player.simulate_motion(0.05, false)
	check(not player.is_dead, "救援窗第 9 个 0.05 秒仍存活")
	player.queue_direction(Vector2.UP)
	player.apply_next_direction()
	player.simulate_motion(0.05, false)
	check(not player.is_dead and player.danger_kind.is_empty(), "0.5 秒边界先判安全方向")
	player.reset_at(Vector2(480, 240), Vector2.RIGHT)
	player._enter_danger("wall")
	for index in range(10):
		player.simulate_motion(0.05, false)
	check(player.is_dead, "0.5 秒无安全方向则死亡")

	player.set_physics_process(true)
	player.reset_at(Vector2(300, 240), Vector2.RIGHT)
	_send_key(KEY_D, true)
	await process_frame
	await physics_frame
	await physics_frame
	check(is_equal_approx(player.current_speed, player.base_speed * 2.0), "InputEventKey 按住当前方向触发 2 倍速")
	_send_key(KEY_D, false)
	await process_frame
	await physics_frame
	await physics_frame
	check(not Input.is_action_pressed("move_right"), "InputEventKey 释放状态进入 InputMap")
	check(is_equal_approx(player.current_speed, player.base_speed), "释放按键恢复基础速度并继续移动")

	player.reset_at(Vector2(480, 240), Vector2.RIGHT)
	_send_key(KEY_D, true)
	await process_frame
	for index in range(10):
		await physics_frame
		if not player.danger_kind.is_empty():
			break
	check(player.danger_kind == "wall", "InputMap 物理碰撞进入墙体救援窗")
	_send_key(KEY_D, false)
	_send_key(KEY_W, true)
	for index in range(4):
		await physics_frame
		if player.danger_kind.is_empty():
			break
	_send_key(KEY_W, false)
	check(player.danger_kind.is_empty() and not player.is_dead, "安全转向解除救援窗")
	check(player.direction.y < 0.0, "救援方向生效")

	player.reset_at(Vector2(480, 240), Vector2.RIGHT)
	_send_key(KEY_D, true)
	await process_frame
	for index in range(50):
		await physics_frame
		if player.is_dead:
			break
	_send_key(KEY_D, false)
	check(player.is_dead, "救援窗超时后死亡")
	arena.queue_free()
	await process_frame


func _test_n2_real_resource_input() -> void:
	var arena: Node = load("res://game/test_arena.tscn").instantiate()
	root.add_child(arena)
	await physics_frame
	var player: SnakePlayer = arena.get_node("SnakePlayer")
	player.set_physics_process(false)
	player.play_sfx = false
	player.reset_at(Vector2(300, 240), Vector2.RIGHT)
	player.inventory = StomachInventory.new()
	player.set_length(8)
	var start_position := player.global_position
	Input.action_press("spit")
	player._physics_process(1.0 / 60.0)
	check(player.body_chain.segment_count == 7, "真实 J 输入消耗一节普通豆身长")
	var first_spit_speed := player.current_speed
	var first_spit_distance := player.global_position.distance_to(start_position)
	check(first_spit_distance > 0.0 and first_spit_distance < player.base_speed / 60.0, "成功吐豆触发平滑制动而非急停")
	var projectile_count := 0
	for child in arena.get_children():
		if child is BeanProjectile:
			projectile_count += 1
	check(projectile_count == 1, "真实 J 输入只生成一个载荷")
	player._physics_process(1.0 / 60.0)
	check(player.body_chain.segment_count == 7, "射速冷却阻止同帧连发")
	for index in range(13):
		player._physics_process(1.0 / 60.0)
	check(player.body_chain.segment_count == 7 and player.current_speed < first_spit_speed * 0.1, "长按 J 连射时平滑减速至完全静止")
	var repeat_wait := 14.0 / 60.0
	while player.body_chain.segment_count == 7 and repeat_wait < 0.45:
		player._physics_process(1.0 / 60.0)
		repeat_wait += 1.0 / 60.0
	check(player.body_chain.segment_count == 6 and repeat_wait <= 0.44, "连续吐豆间隔缩短到约 0.42 秒")
	Input.action_release("spit")
	for index in range(12):
		player._physics_process(1.0 / 60.0)
	check(player.current_speed > player.base_speed * 0.95, "松开 J 后平滑恢复正常速度")

	player.add_special_item(&"iron_sword")
	player.add_special_item(&"iron_sword")
	var inventory_length := player.body_chain.segment_count
	player._input(_key_event(KEY_E, true))
	check(player.inventory.selected_id() == &"iron_sword", "真实 E 输入循环选择铁剑")
	player.shot_cooldown_left = 0.0
	Input.action_press("spit")
	player._physics_process(1.0 / 60.0)
	check(player.inventory.count_item(&"iron_sword") == 1, "特殊投射物生成前先扣库存")
	check(player.body_chain.segment_count == inventory_length - 1, "吐出铁剑释放其占用长度")
	player._physics_process(0.5)
	check(player.inventory.count_item(&"iron_sword") == 1, "长按不会连续吐出特殊物品")
	Input.action_release("spit")
	player._physics_process(1.0 / 60.0)

	player.inventory = StomachInventory.new()
	player.set_length(8)
	player.cut_cooldown_left = 0.0
	var charges_before_cut := player.node_charges
	var landed_before := 0
	for child in arena.get_children():
		if child is BeanProjectile and child.is_landed and child.payload.id == &"bean":
			landed_before += 1
	player._input(_key_event(KEY_K, true))
	check(player.body_chain.segment_count == 3, "真实 K 输入断尾保留三节")
	check(player.cut_cooldown_left > 9.9, "断尾启动 10 秒冷却")
	check(player.node_charges == charges_before_cut, "断尾不重置节点充能")
	var landed_beans := 0
	for child in arena.get_children():
		if child is BeanProjectile and child.is_landed and child.payload.id == &"bean":
			landed_beans += 1
	check(landed_beans == landed_before + 3, "断下五节精确回收 floor(5×60%) 三豆")

	player.grant_node_charges(1)
	var charge_before_place := player.node_charges
	player._input(_key_event(KEY_F, true))
	check(player.placed_nodes.size() == 1 and player.node_charges == charge_before_place - 1, "真实 F 输入当前格放置节点并扣充能")
	var placed: RingNode = player.placed_nodes[0]
	check(placed.hp == 2, "节点基础 HP 为 2")
	check(placed.get_node("Sprite2D").global_position.is_equal_approx(player.global_position), "节点视觉落在放置时的蛇身中心")
	placed.update_body_occupancy({placed.cell: true})
	placed.update_body_occupancy({})
	await process_frame
	check(player.placed_nodes.is_empty() and player.node_charges == charge_before_place, "身体完全离格后节点回收且只返还一次")
	check(player.place_node(), "回收充能可以再次放置节点")
	var doomed: RingNode = player.placed_nodes[0]
	var charge_after_second_place := player.node_charges
	doomed.damage(2)
	await process_frame
	check(player.placed_nodes.is_empty() and player.node_charges == charge_after_second_place, "节点 HP 归零后摧毁且不返还充能")

	var projectile: BeanProjectile = load("res://game/projectiles/bean_projectile.tscn").instantiate()
	arena.add_child(projectile)
	projectile.launch({"id": &"bean", "damage": 4, "length": 1, "weight": 0}, Vector2(200, 200), Vector2.RIGHT, player)
	check(is_equal_approx(projectile.speed, 13.0 * BeanProjectile.TILE_SIZE), "豆子初速提高到 13 格每秒")
	check(is_equal_approx(BeanProjectile.INITIAL_DRAG / BeanProjectile.TILE_SIZE, 0.8), "豆子飞行阻力降低到 0.8")
	check(is_equal_approx(BeanProjectile.BOUNCED_DRAG / BeanProjectile.TILE_SIZE, 4.5), "豆子反弹后阻力降低到 4.5")
	projectile._on_collision(Vector2.LEFT)
	var first_retain := projectile.speed / BeanProjectile.INITIAL_SPEED
	check(projectile.has_bounced and first_retain >= BeanProjectile.BOUNCE_RETAIN_MIN and first_retain <= BeanProjectile.BOUNCE_RETAIN_MAX, "豆首次碰撞使用随机保速区间")
	var close_angle := absf(projectile.flight_direction.angle_to(Vector2.LEFT))
	check(close_angle >= BeanProjectile.BOUNCE_MIN_CLOSE_ANGLE and close_angle <= BeanProjectile.BOUNCE_ANGLE_CLOSE + 0.001, "极近首次碰撞强制扩大偏转")
	var first_bounce_speed := projectile.speed
	projectile._on_collision(Vector2.RIGHT)
	var second_retain := projectile.speed / first_bounce_speed
	check(not projectile.is_landed and second_retain >= BeanProjectile.BOUNCE_RETAIN_MIN and second_retain <= BeanProjectile.BOUNCE_RETAIN_MAX, "后续碰撞继续随机反弹而非提前落地")
	var bounce_samples: Dictionary[String, bool] = {}
	for index in range(10):
		projectile.flight_direction = Vector2.RIGHT
		projectile.speed = BeanProjectile.INITIAL_SPEED
		projectile.has_bounced = false
		projectile.flight_distance = 0.0
		projectile._on_collision(Vector2.LEFT)
		bounce_samples["%.3f/%.3f" % [projectile.speed, projectile.flight_direction.y]] = true
	check(bounce_samples.size() > 1, "连续豆子的随机力度与方向不会全部重合")
	projectile.flight_direction = Vector2.RIGHT
	projectile.speed = BeanProjectile.INITIAL_SPEED
	projectile.has_bounced = false
	projectile.flight_distance = BeanProjectile.CLOSE_BOUNCE_DISTANCE
	projectile._on_collision(Vector2.LEFT)
	check(absf(projectile.flight_direction.angle_to(Vector2.LEFT)) <= BeanProjectile.BOUNCE_ANGLE_FAR + 0.001, "远距离首次碰撞只使用基础随机偏转")
	projectile.speed = BeanProjectile.LAND_SPEED - 0.01
	projectile._physics_process(0.01)
	check(projectile.is_landed, "豆低于 0.35 格每秒落地")
	var wall_projectile: BeanProjectile = load("res://game/projectiles/bean_projectile.tscn").instantiate()
	arena.add_child(wall_projectile)
	wall_projectile.set_physics_process(false)
	wall_projectile.launch({"id": &"bean", "damage": 4, "length": 1, "weight": 0}, Vector2(720, 240), Vector2.RIGHT, player)
	for index in range(12):
		wall_projectile._physics_process(1.0 / 60.0)
		if wall_projectile.has_bounced:
			break
	check(wall_projectile.has_bounced and wall_projectile.flight_direction.x < 0.0, "真实 World 碰撞使豆反射")
	var wall_closeness := 1.0 - clampf(wall_projectile.flight_distance / BeanProjectile.CLOSE_BOUNCE_DISTANCE, 0.0, 1.0)
	check(absf(wall_projectile.flight_direction.angle_to(Vector2.LEFT)) >= BeanProjectile.BOUNCE_MIN_CLOSE_ANGLE * wall_closeness, "真实近墙碰撞按飞行距离提高最小偏转")
	var projectile_shape: CircleShape2D = wall_projectile.get_node("CollisionShape2D").shape
	check(projectile_shape.radius >= 7.0, "豆子尺寸只比单节蛇身略小")
	var potion: BeanProjectile = load("res://game/projectiles/bean_projectile.tscn").instantiate()
	arena.add_child(potion)
	potion.launch({"id": &"healing_potion", "length": 1, "weight": 1}, Vector2(200, 200), Vector2.RIGHT, player)
	potion._on_collision(Vector2.LEFT)
	check(potion.is_queued_for_deletion(), "药水首次碰撞立即破碎")
	var actor: BeanProjectile = load("res://game/projectiles/bean_projectile.tscn").instantiate()
	arena.add_child(actor)
	actor.launch({"id": &"lisi", "length": 1, "weight": 3, "actor": true, "metadata": {"hp": 9, "story_id": "lisi"}}, Vector2(200, 200), Vector2.RIGHT, player)
	actor.land()
	check(actor.is_landed and actor.payload.metadata.hp == 9 and actor.payload.metadata.unconscious, "角色落地保留身份生命并转为昏迷可互动")
	actor.global_position = player.global_position
	player._input(_key_event(KEY_ENTER, true))
	check(actor.actor_interaction_emitted and not actor.interact(), "一次互动只交给最近角色且不能重复提交")
	player.inventory = StomachInventory.new()
	player.inventory.add_item(&"iron_sword")
	player.inventory.add_item(&"iron_sword")
	player.inventory.add_item(&"iron_sword")
	var blocked_pickup: BeanProjectile = load("res://game/projectiles/bean_projectile.tscn").instantiate()
	arena.add_child(blocked_pickup)
	blocked_pickup.set_physics_process(false)
	blocked_pickup.launch({"id": &"iron_sword", "length": 1, "weight": 2}, player.global_position, Vector2.RIGHT, player)
	blocked_pickup.age = 1.0
	blocked_pickup.land()
	blocked_pickup._physics_process(0.01)
	check(not blocked_pickup.is_queued_for_deletion(), "满负重拾取失败时特殊物品留在地面")

	player.inventory.entries.append({"id": &"test_weight", "count": 1, "length": 0, "weight": 7})
	var overweight_start := player.global_position
	player._physics_process(1.0 / 60.0)
	check(player.global_position.is_equal_approx(overweight_start), "超重停止移动但资源输入入口仍运行")

	var chain := BodyChain.new()
	root.add_child(chain)
	chain.segments.assign([Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2(24, 0)])
	check(chain.collides_with_tail(Vector2(24, 0), 1.0, 4), "无节点时身体会自撞")
	check(not chain.collides_with_tail(Vector2(24, 0), 1.0, 4, [Vector2(12, 12)], 1.15 * 24.0), "节点半径内身体段获得穿越豁免")
	chain.queue_free()
	player.spit_audio.stop()
	player.pickup_audio.stop()
	player.node_audio.stop()
	arena.queue_free()
	await process_frame
	await process_frame


func _test_n2_input_dispatch() -> void:
	var arena: Node = load("res://game/test_arena.tscn").instantiate()
	root.add_child(arena)
	await physics_frame
	var player: SnakePlayer = arena.get_node("SnakePlayer")
	player.play_sfx = false
	player.inventory = StomachInventory.new()
	player.reset_at(Vector2(300, 240), Vector2.RIGHT)
	player.set_length(8)
	_send_key(KEY_J, true)
	await process_frame
	await physics_frame
	_send_key(KEY_J, false)
	await process_frame
	check(player.body_chain.segment_count == 7, "SceneTree 分发真实 J 吐出输入")
	player.add_special_item(&"iron_sword")
	_send_key(KEY_E, true)
	await process_frame
	_send_key(KEY_E, false)
	check(player.inventory.selected_id() == &"iron_sword", "SceneTree 分发真实 E 胃袋输入")
	player.inventory = StomachInventory.new()
	player.set_length(8)
	player.cut_cooldown_left = 0.0
	_send_key(KEY_K, true)
	await process_frame
	_send_key(KEY_K, false)
	check(player.body_chain.segment_count == 3, "SceneTree 分发真实 K 断尾输入")
	player.node_charges = 1
	player.node_unlocked = true
	_send_key(KEY_F, true)
	await process_frame
	_send_key(KEY_F, false)
	check(player.placed_nodes.size() == 1 and player.node_charges == 0, "SceneTree 分发真实 F 节点输入")
	player.spit_audio.stop()
	player.node_audio.stop()
	arena.queue_free()
	await process_frame
	await process_frame


func _test_n3_contract() -> void:
	var contract_player := SnakePlayer.new()
	check(contract_player.max_hearts == 3, "玩家最大生命 3 心")
	contract_player.free()
	check(is_equal_approx(EnemyActor.TYPES[&"slime"].hp, 14.0), "史莱姆 HP 14")
	check(is_equal_approx(EnemyActor.TYPES[&"slime"].speed, 2.0), "史莱姆速度 2 格/秒")
	check(int(EnemyActor.TYPES[&"slime"].drops) == 2, "史莱姆死亡掉 2 豆")
	var mushroom: Dictionary = EnemyActor.TYPES[&"mushroom"]
	check(is_equal_approx(mushroom.hp, 16.0) and is_equal_approx(mushroom.speed, 0.0), "蘑菇 HP/速度")
	check(is_equal_approx(mushroom.cadence, 4.0) and is_equal_approx(mushroom.telegraph, 0.7), "蘑菇周期/预警")
	check(is_equal_approx(mushroom.bullet_speed, 2.0), "蘑菇针刺弹速 2 格/秒")
	check(is_equal_approx(PrisonController.PLAIN_BURST, 10.0) and is_equal_approx(PrisonController.PLAIN_DPS, 10.0), "普通监狱 10 burst/10 DPS")
	check(is_equal_approx(PrisonController.NODE_BURST, 15.0) and is_equal_approx(PrisonController.NODE_DPS, 30.0), "节点监狱 15 burst/30 DPS")
	check(is_equal_approx(NpcActor.ENTER_RADIUS, 0.85 * NpcActor.TILE_SIZE) and is_equal_approx(NpcActor.RESET_RADIUS, 1.25 * NpcActor.TILE_SIZE), "NPC 接触迟滞半径")
	var enemy_visual: EnemyActor = load("res://game/actors/enemy_actor.tscn").instantiate()
	check(enemy_visual.get_node("Slime").scale.is_equal_approx(Vector2(1.25, 1.25)), "敌人美术放大到蛇身量级")
	enemy_visual.free()
	var enemy_shot: EnemyProjectile = load("res://game/projectiles/enemy_projectile.tscn").instantiate()
	check(is_equal_approx(enemy_shot.get_node("CollisionShape2D").shape.radius, 7.0), "敌弹碰撞尺寸与豆子相同")
	enemy_shot.free()


func _test_n3_real_paths() -> void:
	var arena: Node = load("res://game/test_arena.tscn").instantiate()
	root.add_child(arena)
	arena.get_node("InteractAudio").stream = null
	arena.get_node("PrisonAudio").stream = null
	await physics_frame
	var player: SnakePlayer = arena.get_node("SnakePlayer")
	player.play_sfx = false
	player.set_physics_process(false)
	arena.set_process(false)
	player.reset_at(Vector2(300, 240), Vector2.RIGHT)
	player.hearts = player.max_hearts
	player.invulnerability_left = 0.0
	check(player.take_damage(1, &"n3_test") and player.hearts == 2, "头部受伤扣 1 心并保留 3 心上限")
	check(is_equal_approx(player.invulnerability_left, 1.0), "受伤启动 1 秒无敌")
	check(not player.take_damage(1, &"n3_test") and player.hearts == 2, "无敌窗内不重复扣血")
	player.invulnerability_left = 0.0
	check(player.heal(1) == 1 and player.hearts == 3, "治疗回复 1 心")
	check(player.heal(1) == 0 and player.hearts == 3, "治疗不超过最大生命")
	check(player.feedback_color == Color.WHITE and player.body_chain.feedback_color == Color.WHITE, "受伤时整条蛇同步闪白")
	player.hit_flash_left = 0.0
	player._enter_danger("wall")
	check(player.feedback_color == Color("ff4f4f") and player.body_chain.feedback_color == Color("ff4f4f"), "救援窗整条蛇红色闪动")
	player.danger_seconds_left = player.rescue_seconds - 0.1
	player._update_visual_feedback()
	check(player.feedback_color.a == 0.0, "救援窗红色脉冲包含熄灭相位")
	player._clear_danger()
	player.invulnerability_left = 0.0
	check(player.take_damage(1, &"enemy_contact"), "怪物接触触发受伤反馈")
	check(not arena.get_node("Camera2D").offset.is_zero_approx(), "怪物接触触发轻微镜头震动")

	var slime: EnemyActor = arena.get_node("Slime")
	slime.global_position = Vector2(100, 360)
	var chase_start := slime.global_position.distance_to(player.global_position)
	for index in range(30):
		await physics_frame
	check(slime.global_position.distance_to(player.global_position) < chase_start, "史莱姆真实物理帧追击玩家")
	player.hearts = 3
	player.invulnerability_left = 0.0
	player.body_chain.reset(player.global_position, Vector2.RIGHT)
	slime.global_position = Vector2(315, 240)
	slime.velocity = Vector2.ZERO
	for index in range(8):
		await physics_frame
		if player.hearts < 3:
			break
	check(player.hearts == 2 and slime.velocity.x > 0.0, "史莱姆接触头部造成伤害并反弹")
	player.hearts = 3
	player.invulnerability_left = 0.0
	player.body_chain.segments.assign([
		Vector2(300, 240), Vector2(276, 240), Vector2(252, 240), Vector2(228, 240), Vector2(204, 240),
	])
	slime.global_position = Vector2(180, 240)
	slime.velocity = Vector2.ZERO
	for index in range(60):
		await physics_frame
	check(player.hearts == 3 and slime.global_position.x < 245.0, "史莱姆被身体阻挡且不伤害头部")
	slime.set_physics_process(false)

	var mushroom: EnemyActor = arena.get_node("Mushroom")
	mushroom.enemy_kind = &"mushroom"
	mushroom.global_position = Vector2(420, 240)
	mushroom.shot_timer = 4.0
	mushroom.warning_active = false
	await process_frame
	for index in range(200):
		await physics_frame
	check(mushroom.warning_active and _count_n3_enemy_projectiles(arena) == 0, "蘑菇 0.7 秒预警且不提前出弹")
	for index in range(50):
		await physics_frame
		if _count_n3_enemy_projectiles(arena) > 0:
			break
	check(_count_n3_enemy_projectiles(arena) == 1, "蘑菇首个 4 秒周期只发一枚针刺弹")
	var fired: EnemyProjectile = _first_n3_enemy_projectile(arena)
	check(fired != null and is_equal_approx(fired.speed, 2.0 * EnemyProjectile.TILE_SIZE), "针刺弹真实速度 2 格/秒")
	if fired:
		check(fired.flight_direction.x < 0.0, "针刺弹真实瞄准玩家头部")

	player.body_chain.segments.assign([
		Vector2(300, 240), Vector2(276, 240), Vector2(252, 240), Vector2(228, 240), Vector2(204, 240),
	])
	player.hearts = 3
	player.invulnerability_left = 0.0
	var head_shot: EnemyProjectile = load("res://game/projectiles/enemy_projectile.tscn").instantiate()
	arena.add_child(head_shot)
	head_shot.launch(Vector2(360, 240), Vector2.LEFT, 2.0, player, mushroom)
	for index in range(90):
		await physics_frame
		if player.hearts < 3:
			break
	check(player.hearts == 2 and not is_instance_valid(head_shot), "敌弹真实命中头部扣 1 心")
	player.hearts = 3
	player.invulnerability_left = 0.0
	var body_shot: EnemyProjectile = load("res://game/projectiles/enemy_projectile.tscn").instantiate()
	arena.add_child(body_shot)
	body_shot.launch(Vector2(180, 240), Vector2.RIGHT, 2.0, player, mushroom)
	for index in range(90):
		await physics_frame
		if body_shot.reflected_by_body:
			break
	check(body_shot.reflected_by_body and player.hearts == 3, "敌弹真实撞身体反射且不伤头")

	var enemy_target: EnemyActor = slime
	enemy_target.set_physics_process(false)
	enemy_target.global_position = Vector2(420, 300)
	var bean: BeanProjectile = load("res://game/projectiles/bean_projectile.tscn").instantiate()
	arena.add_child(bean)
	bean.launch({"id": &"bean", "damage": 4, "length": 1, "weight": 0}, Vector2(380, 300), Vector2.RIGHT, player)
	for index in range(90):
		await physics_frame
		if enemy_target.hp < enemy_target.max_hp:
			break
	check(is_equal_approx(enemy_target.hp, 10.0) and bean.has_bounced, "豆通过 EnemyHurtbox Area2D 命中敌人")

	var npc: NpcActor = arena.get_node("Keti")
	npc.global_position = Vector2(420, 180)
	npc.damageable = true
	npc.hp = 10.0
	var potion: BeanProjectile = load("res://game/projectiles/bean_projectile.tscn").instantiate()
	arena.add_child(potion)
	potion.launch({"id": &"healing_potion", "healing": 1, "length": 1, "weight": 1}, Vector2(380, 180), Vector2.RIGHT, player)
	for index in range(90):
		await physics_frame
		if npc.hp > 10.0:
			break
	check(is_equal_approx(npc.hp, 11.0) and potion.is_queued_for_deletion(), "药水通过 NPC Area2D 命中并治疗")

	player.direction = Vector2.RIGHT
	player.queue_direction(Vector2.UP)
	player.global_position = npc.global_position
	await physics_frame
	await physics_frame
	check(npc.get_overlapping_bodies().has(player) and npc.interaction_count == 1, "NPC Area2D 接触只请求一次互动")
	for index in range(5):
		await physics_frame
	check(npc.interaction_count == 1, "NPC 停留重叠不重复互动")
	npc.finish_interaction()
	check(player.direction.is_equal_approx(Vector2.RIGHT) and player.direction_queue.is_empty(), "NPC 互动结束恢复原方向")
	player.global_position = npc.global_position + Vector2(32, 0)
	await physics_frame
	player.global_position = npc.global_position
	await physics_frame
	check(npc.interaction_count == 2, "NPC 超过 1.25 格后重入再次互动")

	var enemy_for_prison: EnemyActor = slime
	enemy_for_prison.set_physics_process(false)
	enemy_for_prison.max_hp = 1000.0
	enemy_for_prison.hp = 1000.0
	var bounds := Rect2i(0, 0, 8, 8)
	var blocked := _n3_prison_ring(false)
	enemy_for_prison.global_position = Vector2(3.5, 3.5) * PrisonController.TILE_SIZE
	var plain_prison := PrisonController.new()
	root.add_child(plain_prison)
	plain_prison.step(0.0, bounds, blocked, [enemy_for_prison], [])
	check(is_equal_approx(enemy_for_prison.hp, 990.0), "普通监狱进入瞬时扣 10")
	plain_prison.step(0.5, bounds, blocked, [enemy_for_prison], [])
	check(is_equal_approx(enemy_for_prison.hp, 985.0), "普通监狱持续伤害 10/秒")
	enemy_for_prison.global_position = Vector2(7.5, 3.5) * PrisonController.TILE_SIZE
	plain_prison.step(0.1, bounds, blocked, [enemy_for_prison], [])
	check(is_equal_approx(enemy_for_prison.hp, 985.0), "普通监狱离开后停止伤害")
	enemy_for_prison.global_position = Vector2(3.5, 3.5) * PrisonController.TILE_SIZE
	plain_prison.step(0.1, bounds, blocked, [enemy_for_prison], [])
	check(is_equal_approx(enemy_for_prison.hp, 984.0), "普通监狱重入冷却内只有持续伤害")
	enemy_for_prison.global_position = Vector2(7.5, 3.5) * PrisonController.TILE_SIZE
	plain_prison.step(0.9, bounds, blocked, [enemy_for_prison], [])
	enemy_for_prison.global_position = Vector2(3.5, 3.5) * PrisonController.TILE_SIZE
	plain_prison.step(0.0, bounds, blocked, [enemy_for_prison], [])
	check(is_equal_approx(enemy_for_prison.hp, 974.0), "普通监狱冷却结束重入再次 burst")

	arena.set_process(false)
	var node_ring: RingNode = load("res://game/nodes/ring_node.tscn").instantiate()
	root.add_child(node_ring)
	node_ring.setup(Vector2i(3, 2), Vector2(3.5, 2.5) * PrisonController.TILE_SIZE)
	var node_ring_2: RingNode = load("res://game/nodes/ring_node.tscn").instantiate()
	root.add_child(node_ring_2)
	node_ring_2.setup(Vector2i(4, 2), Vector2(3.5, 2.5) * PrisonController.TILE_SIZE)
	var node_prison := PrisonController.new()
	root.add_child(node_prison)
	enemy_for_prison.hp = 1000.0
	enemy_for_prison.global_position = Vector2(3.5, 3.5) * PrisonController.TILE_SIZE
	var node_blocked := _n3_prison_ring(true)
	node_prison.step(0.0, bounds, node_blocked, [enemy_for_prison], [node_ring, node_ring_2])
	check(is_equal_approx(enemy_for_prison.hp, 985.0), "节点监狱进入瞬时扣 15")
	node_prison.step(0.5, bounds, node_blocked, [enemy_for_prison], [node_ring, node_ring_2])
	check(is_equal_approx(enemy_for_prison.hp, 970.0), "节点监狱持续伤害 30/秒")
	node_prison.step(0.5, bounds, node_blocked, [enemy_for_prison], [node_ring, node_ring_2])
	check(node_ring.hp == 1 and node_ring_2.hp == 2, "节点每秒最多咬一个")
	node_prison.step(1.0, bounds, node_blocked, [enemy_for_prison], [node_ring, node_ring_2])
	check(node_ring.finished and node_ring_2.hp == 2, "节点每秒最多咬一个")
	enemy_for_prison.take_damage(2000.0, &"n3_test")
	await process_frame
	arena._update_hud()
	check(arena.get_node("UI/Info/Text/Combat").text.contains("史莱姆 已击败"), "敌人释放后 HUD 安全显示已击败")

	for child in arena.get_children():
		if child is AudioStreamPlayer:
			child.stop()
			child.stream = null
	arena.queue_free()
	plain_prison.queue_free()
	node_prison.queue_free()
	node_ring.queue_free()
	node_ring_2.queue_free()
	await process_frame
	await process_frame


func _n3_prison_ring(node_cap: bool) -> Dictionary:
	var blocked: Dictionary = {}
	for x in range(2, 6):
		blocked[Vector2i(x, 2)] = &"body"
		blocked[Vector2i(x, 5)] = &"body"
	for y in range(2, 6):
		blocked[Vector2i(2, y)] = &"body"
		blocked[Vector2i(5, y)] = &"body"
	if node_cap:
		blocked[Vector2i(3, 2)] = &"node"
	return blocked


func _count_n3_enemy_projectiles(arena: Node) -> int:
	var count := 0
	for child in arena.get_children():
		if child is EnemyProjectile:
			count += 1
	return count


func _first_n3_enemy_projectile(arena: Node) -> EnemyProjectile:
	for child in arena.get_children():
		if child is EnemyProjectile:
			return child
	return null


func _has_key(action: StringName, physical_keycode: Key) -> bool:
	for event in InputMap.action_get_events(action):
		if event is InputEventKey and event.physical_keycode == physical_keycode:
			return true
	return false


func _send_key(physical_keycode: Key, pressed: bool) -> void:
	var event := _key_event(physical_keycode, pressed)
	Input.parse_input_event(event)


func _key_event(physical_keycode: Key, pressed: bool) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = physical_keycode
	event.physical_keycode = physical_keycode
	event.pressed = pressed
	return event


func check(condition: bool, label: String) -> void:
	if not condition:
		failures.append("FAILED: %s" % label)
