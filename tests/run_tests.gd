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
	_test_n4_contract()
	await _test_n4_real_paths()
	await _test_n5_n6_contract()
	await _test_n7_chapter_one_contract()
	await _test_n7_integrated_story_paths()
	if failures.is_empty():
		print("N7 TESTS PASSED (INCLUDING N1-N6 REGRESSION)")
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
	check(is_equal_approx(SnakePlayer.CONTACT_HITSTOP_SECONDS, 0.025), "怪物接触卡肉 25ms")
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
	check(player.contact_hitstop_left > 0.0 and slime._contact_hitstop_left > 0.0, "怪物接触同时短暂停顿蛇与敌人")
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


func _test_n4_contract() -> void:
	check(StoryMapCatalog.ORDER == [&"prologue_tutorial", &"wilderness", &"forest", &"cave"], "N4 四张剧情地图顺序固定")
	check(StoryMapCatalog.MAPS[&"prologue_tutorial"].size == Vector2i(72, 48), "教学地图 72×48")
	var forest_layout: Node = load("res://game/maps/levels/forest.tscn").instantiate()
	check(forest_layout.get_node("Triggers/ExitToCave") is MapExit, "森林洞口是编辑器可摆放的 MapExit")
	var authored_pillar: BridgePillar = forest_layout.get_node("Interactables/ForestBridgePillar")
	check(authored_pillar.charge_seconds == 3.0 and authored_pillar.requires_node, "桥柱参数由场景 Inspector 保存")
	var cave_layout: Node = load("res://game/maps/levels/cave.tscn").instantiate()
	check(cave_layout.get_node("Triggers/ExitToForest") is MapExit, "洞窟出口是编辑器可摆放的 MapExit")
	forest_layout.free()
	cave_layout.free()
	check(ResourceLoader.exists("res://assets/tiles/story_tileset.tres"), "共享剧情 TileSet 存在")
	var tile_set: TileSet = load("res://assets/tiles/story_tileset.tres")
	check(tile_set.tile_size == Vector2i(24, 24) and tile_set.get_physics_layers_count() == 1, "共享 TileSet 使用 24px 并自带 World 碰撞")
	var state := SessionState.new()
	var snapshot := state.to_dictionary()
	for key in ["story", "player", "inventory", "body", "mechanisms", "rewards", "encounters", "items", "gold", "checkpoint_snapshot"]:
		check(snapshot.has(key), "存档状态覆盖字段：%s" % key)
	check(not state.load_dictionary({"current_map": "missing", "checkpoint_map": "missing"}).ok, "未知地图存档拒绝载入")


func _test_n4_real_paths() -> void:
	var map := StoryMap.new()
	root.add_child(map)
	map.setup(&"prologue_tutorial", {})
	await physics_frame
	check(map.ground_layer is TileMapLayer and map.wall_layer is TileMapLayer, "地图使用独立 TileMapLayer 地表/碰撞层")
	check(map.get_node("MapLayout") != null and map.ground_layer.get_used_cells().size() > 0, "地图从可编辑场景实例化而非运行时逐格生成")
	check(map.get_node_or_null("ExitMarker") == null, "地图出口不生成蓝色提示球")
	check(map.ground_layer.get_cell_source_id(Vector2i(8, 24)) == 0, "教学出生区真实绘制地表瓦片")
	check(map.wall_layer.get_cell_source_id(Vector2i(3, 16)) == 0, "地图边界真实绘制碰撞瓦片")
	check(map.ground_layer.z_index < map.player.body_chain.z_index, "不透明地表绘制在蛇身下方")
	check(map.wall_layer.get_cell_source_id(Vector2i(49, 15)) == -1, "教学门使用独立碰撞体且边界预留门洞")
	var first_map_bean: BeanProjectile
	for child in map.get_children():
		if child is BeanProjectile:
			first_map_bean = child
			break
	first_map_bean.collected.emit(first_map_bean.payload)
	check(map.item_states.has("prologue_tutorial:bean:16:24"), "固定地图豆使用稳定键记录到 items 状态")
	var gate: FragileGate = map.get_node("MapLayout/Interactables/TutorialFragileGate")
	var dummy: BeanProjectile = load("res://game/projectiles/bean_projectile.tscn").instantiate()
	root.add_child(dummy)
	gate.hit_by_bean(dummy)
	gate.hit_by_bean(dummy)
	check(gate.progress == 2 and not bool(map.flags.get("tutorial_fragile_gate", false)), "易碎门前两豆只累计进度")
	gate.hit_by_bean(dummy)
	check(bool(map.flags.get("tutorial_fragile_gate", false)), "易碎门第三豆开启并持久化标记")
	await process_frame
	check(not is_instance_valid(gate) and map.wall_layer.get_cell_source_id(Vector2i(49, 15)) == -1, "教学门开启后原位置留下可通行缺口")
	dummy.queue_free()
	map.queue_free()
	await process_frame

	var forest := StoryMap.new()
	root.add_child(forest)
	forest.setup(&"forest", {})
	await physics_frame
	var all_forest_beans_landed := true
	for child in forest.get_children():
		if child is BeanProjectile and not child.is_landed:
			all_forest_beans_landed = false
	check(all_forest_beans_landed, "森林预置豆出生即落地，不从画外飞入")
	var perf_started := Time.get_ticks_usec()
	for index in range(600):
		forest.bridge_pillar._physics_process(1.0 / 60.0)
	var idle_scan_ms := (Time.get_ticks_usec() - perf_started) / 1000.0
	print("N4 FOREST IDLE: 600 pillar ticks in %.3f ms" % idle_scan_ms)
	check(idle_scan_ms < 250.0, "远离桥柱且无节点时不扫描整张森林地图")
	var bridge_ring: RingNode = load("res://game/nodes/ring_node.tscn").instantiate()
	forest.add_child(bridge_ring)
	bridge_ring.setup(Vector2i(87, 29), (Vector2(87, 29) + Vector2(0.5, 0.5)) * StoryMap.TILE_SIZE)
	forest.player.placed_nodes.append(bridge_ring)
	var ring := _n4_pillar_ring(true)
	forest.player.body_chain.occupied_cells.erase(bridge_ring.cell)
	forest.step_pillar(1.0, ring)
	check(is_zero_approx(forest.pillar_progress), "未穿过环形节点的身体闭环不能给桥柱充能")
	forest.player.body_chain.occupied_cells[bridge_ring.cell] = true
	forest.step_pillar(1.0, ring)
	check(is_equal_approx(forest.pillar_progress, 1.0), "节点闭环开始为桥柱充能")
	forest.step_pillar(1.0, {})
	check(is_equal_approx(forest.pillar_progress, 0.8), "桥柱中断按网页版每秒 0.2 秒回退")
	forest.step_pillar(2.2, ring)
	check(forest.pillar_done and bool(forest.flags.get("forest_bridge_open", false)), "桥柱累计满 3 秒永久打开断桥")
	check(forest.wall_layer.get_cell_source_id(Vector2i(92, 30)) == -1, "断桥完成后清除同一 TileMap 碰撞")
	forest.queue_free()
	await process_frame

	var cave_items: Dictionary = {}
	var cave := StoryMap.new()
	root.add_child(cave)
	cave.setup(&"cave", {}, &"", cave_items)
	cave.player.set_physics_process(false)
	cave.player.play_sfx = false
	cave.player.global_position = Vector2(58.5, 16.5) * StoryMap.TILE_SIZE
	await physics_frame
	await physics_frame
	await process_frame
	var ring_pickup: StoryPickup = cave.get_node("MapLayout/Pickups/RingNodePickup")
	check(not ring_pickup.auto_collect and not ring_pickup.consumed and ring_pickup.visible, "洞窟环形节点不再自动拾取，等待剧情选择")
	cave.queue_free()
	await process_frame

	var save_dir := "res://.godot/n4_test_saves"
	var store := SaveStore.new(save_dir)
	for slot in range(1, 4):
		store.delete_slot(slot)
	check(store.save_slot(1, {"current_map": "forest", "value": 1}).ok, "槽位 1 可保存")
	check(store.save_slot(2, {"current_map": "cave", "value": 2}).ok, "槽位 2 独立保存")
	check(int(store.load_slot(1).data.value) == 1 and int(store.load_slot(2).data.value) == 2, "三槽数据互不串位")
	check(store.save_slot(1, {"current_map": "forest", "value": 9}).ok and int(store.load_slot(1).data.value) == 9, "同槽覆盖保存")
	check(store.delete_slot(2).ok and store.load_slot(2).empty, "槽位删除后为空")
	_write_n4_save(store, 2, "{broken")
	check(store.load_slot(2).error.code == &"CORRUPT_JSON", "损坏 JSON 返回明确错误")
	_write_n4_save(store, 2, JSON.stringify({"schema_version": 99, "state": {}}))
	check(store.load_slot(2).error.code == &"SCHEMA_TOO_NEW", "未来版本存档拒绝载入")
	_write_n4_save(store, 2, JSON.stringify({"schema_version": 0, "state": {}}))
	check(store.load_slot(2).error.code == &"SCHEMA_UNSUPPORTED", "缺失迁移返回明确错误")
	for slot in range(1, 4):
		store.delete_slot(slot)

	var session: GameSession = load("res://game/main.tscn").instantiate()
	root.add_child(session)
	await physics_frame
	session.start_new_game(1)
	await process_frame
	check(session.current_world.map_id == &"prologue_tutorial", "Session 从教学地图启动")
	await session.load_map(&"cave", &"", true)
	check(session.current_world.map_id == &"cave" and session.state.checkpoint_map == &"cave", "跨图销毁重建并记录入口检查点")
	session.current_world.player.set_physics_process(false)
	session.current_world.player.play_sfx = false
	session.state.flags["caveEntered"] = true
	session.story.current_id = "cave_explore"
	var session_ring: StoryPickup = session.current_world.get_node("MapLayout/Pickups/RingNodePickup")
	session_ring.interaction_requested.emit(session_ring)
	await process_frame
	session.dialogue._finish_enter()
	session.story._on_choice("eat")
	await process_frame
	session.set_pause_reason(&"dialogue", false)
	session.dialogue.close()
	await session.load_map(&"forest")
	check(session.current_world.player.node_unlocked and session.current_world.player.node_charges == 1, "洞窟取得的环形节点经 Session 换图保留到森林")
	await session.load_map(&"cave")
	var checkpoint_length := session.current_world.player.body_chain.segment_count
	session.current_world.player.set_length(checkpoint_length + 4)
	session.current_world.player.hearts = 1
	await session.retry_checkpoint()
	check(session.current_world.map_id == &"cave" and session.current_world.player.hearts == 3, "死亡重试重建当前检查点且恢复满生命")
	check(session.current_world.player.body_chain.segment_count == checkpoint_length, "死亡重试恢复检查点资源快照而非临死状态")
	session.queue_free()
	await process_frame


func _test_n5_n6_contract() -> void:
	var runner := DialogueRunner.new()
	var graph_result := runner.load_graph()
	check(graph_result.ok, "N5 剧情图无悬空跳转")
	check(graph_result.nodes == 139 and graph_result.actions == 58 and graph_result.conditions == 18, "N7 剧情图包含 139 节点/58 动作/18 条件")
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://game/story/story_manifest.json"))
	check(manifest.nodes.size() == 139 and manifest.actions.size() == 58 and manifest.conditions.size() == 18 and manifest.flags.size() == 42, "N7 逐 ID 清单包含 139 节点/58 动作/18 条件/42 flag")
	var variables := {"flags": {}}
	var first := runner.begin("dialogue_1", runner.nodes.dialogue_1.dialogue, variables, func(_name): return true)
	check(first.line_id == "dialogue_1.page.0" and first.page_count == 3, "N5 对话稳定行 ID 与分页")
	check(runner.advance_page().line_id == "dialogue_1.page.1", "N5 对话逐页推进")

	var session: GameSession = load("res://game/main.tscn").instantiate()
	root.add_child(session)
	await process_frame
	check(session.current_world == null and session.menus.main_menu.visible, "N5 启动进入三槽主菜单")
	check(session.menus.slots_box.get_child_count() == 3, "N5 主菜单展示三个存档槽")
	var unknown := await session.story.execute_command("notAStoryCommand")
	check(not unknown.ok and unknown.error == "UNKNOWN_COMMAND", "N5 未知剧情命令显式失败")
	var chapter_explore := await session.story.execute_command("chapterExplore")
	check(chapter_explore.ok and chapter_explore.get("error", "") != "DEFERRED_OUT_OF_STAGE", "N7 第一章命令不再标记阶段外")
	var manifest_actions: Array = manifest.actions
	var deferred_actions: Array[String] = []
	for action in manifest_actions:
		if not StoryDirector.N6_ACTIONS.has(action) and not StoryDirector.N7_ACTIONS.has(action):
			deferred_actions.append(String(action))
	check(deferred_actions.is_empty() and manifest_actions.size() == 58, "N7 58 个剧情动作全部进入可执行门禁")

	session.start_new_game(1)
	await process_frame
	check(session.story.current_id == "tutorial_1" and session.current_world.map_id == &"prologue_tutorial", "N6 新游戏从真实教学地图开始")
	for index in range(3): session.current_world.player.try_collect_payload({"id": &"bean"})
	await process_frame
	check(session.story.current_id == "dialogue_1" and session.dialogue.state == &"entering", "N6 吃三豆触发首段对话")
	check(paused, "N6 对话期间冻结世界")
	session.dialogue._finish_enter()
	check(session.dialogue.page_index == 0, "N5 完成弹入不跳过首句")
	session.story._on_choice("go")
	await process_frame
	check(session.story.current_id == "tutorial_2" and not paused, "N6 对话选择后丝滑退出并恢复世界")
	for index in range(3):
		session.current_world.player.shot_cooldown_left = 0.0
		session.current_world.player.try_spit()
	await process_frame
	check(session.story.current_id == "dialogue_2", "N6 吐三豆进入破墙提示")
	session.dialogue._finish_enter()
	session.dialogue.page_index = session.dialogue.pages.size() - 1
	session.story._on_choice("go")
	await process_frame
	for index in range(2): session.current_world.player.try_collect_payload({"id": &"bean"})
	var gate: FragileGate = session.current_world.get_node("MapLayout/Interactables/TutorialFragileGate")
	var dummy := BeanProjectile.new()
	for index in range(3): gate.hit_by_bean(dummy)
	dummy.free()
	await process_frame
	check(session.story.current_id == "dialogue_3", "N6 吃满五豆且教学门真实机关完成后推进剧情")
	session.dialogue._finish_enter()
	session.dialogue.page_index = session.dialogue.pages.size() - 1
	session.story._on_choice("go")
	await process_frame
	session.story.map_exit(&"wilderness", &"")
	await process_frame
	check(session.current_world.map_id == &"wilderness" and session.story.current_id == "wilderness_keti_wait", "N6 走出教学地图进入荒野")
	check(session.current_world.get_node_or_null("MapLayout/Actors/Keti") != null, "N6 荒野从场景加载可蒂实体")
	session._on_exit_reached(&"forest", &"")
	await process_frame
	check(session.current_world.map_id == &"wilderness", "N6 可蒂事件完成前荒野出口保持锁定")
	session.story._on_actor_event(&"keti", &"interacted")
	await process_frame
	check(session.story.current_id == "keti_question", "N6 接触可蒂进入分支对话")
	session.dialogue._finish_enter()
	session.story._on_choice("yes")
	await process_frame
	check(session.story.current_id == "keti_cry", "N6 可蒂对话分支可达")
	session.dialogue._finish_enter()
	session.story._on_choice("save")
	await process_frame
	session.dialogue._finish_enter()
	session.story._on_choice("fight")
	await process_frame
	check(session.story.current_id == "wilderness_slimes" and session.story.enemies_left == 2, "N6 保护路线真实生成两只史莱姆")
	for index in range(2): session.current_world.story_enemy_defeated.emit(&"slime")
	await process_frame
	check(session.story.current_id == "keti_saved", "N6 击败史莱姆进入可蒂存活结局")
	session.dialogue._finish_enter()
	session.story._on_choice("name")
	await process_frame
	check(session.story.current_id == "input_player_name" and session.dialogue.name_edit.visible, "N6 序章结尾进入姓名输入")
	session.dialogue._finish_enter()
	var story_gate: StoryGate = session.current_world.get_story_gate(&"wilderness_forest_gate")
	check(story_gate != null and not story_gate.is_open, "N7 序章完成前荒野出口有可编辑实体石门阻挡")
	story_gate.animation_player.speed_scale = 100.0
	session.current_world.camera.focus_seconds = 0.0
	session.current_world.camera.restore_seconds = 0.0
	await session.story._on_name_submitted("测试蛇")
	check(session.current_world.map_id == &"wilderness" and session.story.current_id == "prologue_complete" and story_gate.is_open, "N7 命名后聚焦石门并升起，保留玩家手动通过")
	session.current_world.story_actor_interacted.emit(&"keti")
	await process_frame
	check(session.story.current_id == "keti_after_prologue" and "测试蛇" in session.dialogue.body_label.text, "N7 序章完成后可蒂会用玩家姓名继续对话")
	session.dialogue._finish_enter()
	session.story._on_choice("continue")
	await process_frame
	check(session.story.current_id == "free_explore", "N7 可蒂指引对话结束后进入可重复互动的探索态")
	session.current_world.story_actor_interacted.emit(&"keti")
	await process_frame
	check(session.story.current_id == "keti_after_prologue" and "测试蛇" in session.dialogue.body_label.text, "N7 free_explore 中再次接触可蒂仍展示含玩家姓名的对话")
	session.dialogue._finish_enter()
	session.story._on_choice("continue")
	await process_frame
	await session._on_exit_reached(&"forest", &"forest_from_wilderness")
	check(session.current_world.map_id == &"forest" and session.story.current_id == "chapter1_explore", "N7 穿过出口渐隐进入森林并停在第一章起点")
	await session._on_exit_reached(&"wilderness", &"wilderness_from_forest")
	check(session.current_world.map_id == &"wilderness", "N7 森林保留可编辑回程出口并能返回荒野")
	check(session.state.story.get("player_name", "") == "测试蛇", "N6 玩家姓名写入可序列化剧情状态")
	await session.load_map(&"wilderness")
	session.current_world.player.play_sfx = false
	var eaten := await session.story.execute_command("eatKeti")
	check(eaten.ok and session.current_world.player.inventory.count_item(&"keti") == 1, "N6 吞入可蒂写入真实胃袋与身长")
	check("可蒂" in session.inventory_slots.text, "N6 胃袋 HUD 立即显示吞入的可蒂")
	var blurred := await session.story.execute_command("memoryBlur")
	check(blurred.ok and session.current_world.player.inventory.count_item(&"keti") == 0, "N6 记忆模糊按 0.13 秒节奏吐尽豆并吐出角色")
	var released_keti_projectile: BeanProjectile
	for child in session.current_world.get_children():
		if child is BeanProjectile and child.payload.get("id", &"") == &"keti":
			released_keti_projectile = child
			break
	check(released_keti_projectile != null and released_keti_projectile.process_mode == Node.PROCESS_MODE_ALWAYS, "剧情吐出物使用独立暂停处理域")
	var cinematic_start := released_keti_projectile.global_position
	paused = true
	for index in range(4): await physics_frame
	check(released_keti_projectile.global_position.distance_to(cinematic_start) > 1.0, "对白暂停时仍看得到剧情吐出演出")
	released_keti_projectile.land()
	paused = false
	await process_frame
	var restored_keti: NpcActor = session.current_world.get_node("MapLayout/Actors/Keti")
	check(restored_keti.visible and is_equal_approx(restored_keti.hp, 14.0), "吐出的可蒂恢复原 NPC 外形和生命而非蓝球")
	await session.retry_checkpoint()
	restored_keti = session.current_world.get_node("MapLayout/Actors/Keti")
	check(restored_keti.visible and String(session.state.actors.keti.status) == "unconscious", "N7 可蒂吞吐结果进入检查点，重建地图后仍为可互动 NPC")
	session.current_world.player.global_position = restored_keti.global_position
	await physics_frame
	await physics_frame
	check(session.current_world.active_npc == restored_keti, "吐出的可蒂恢复真实 NPC 接触互动")
	check(session.story.current_id == "keti_unconscious", "N7 可蒂在重载后仍能进入昏迷互动分支")
	session.current_world.finish_actor_interaction()
	session.dialogue.interact_audio.stop()
	session.queue_free()
	paused = false
	await process_frame

	for map_id in StoryMapCatalog.ORDER:
		var layout_path := String(StoryMapCatalog.get_map(map_id).scene)
		check(ResourceLoader.exists(layout_path), "可编辑 TileMap 场景存在：%s" % map_id)

	var loot_enemy: EnemyActor = load("res://game/actors/enemy_actor.tscn").instantiate()
	root.add_child(loot_enemy)
	loot_enemy.set_physics_process(false)
	loot_enemy.death_hit_direction = Vector2.LEFT
	loot_enemy.death_head_distance = 0.0
	var near_burst := loot_enemy.make_loot_burst(6)
	loot_enemy.death_head_distance = 8.0 * EnemyActor.TILE_SIZE
	var far_burst := loot_enemy.make_loot_burst(6)
	check(is_equal_approx(EnemyActor.LOOT_BURST_SPEED_SCALE, 0.6), "怪物掉豆初速度降为原手感的 60%")
	var near_min := INF
	var far_max := 0.0
	var directions: Dictionary = {}
	for launch_data in near_burst:
		near_min = minf(near_min, float(launch_data.speed))
		directions["%.3f" % Vector2(launch_data.direction).angle()] = true
	for launch_data in far_burst: far_max = maxf(far_max, float(launch_data.speed))
	check(near_min > far_max, "近距离击杀的豆子泼洒力度显著高于远距离击杀")
	check(directions.size() > 1 and Vector2(near_burst[0].direction).dot(Vector2.LEFT) > 0.0, "战利品沿受击方向随机扇形泼洒")
	loot_enemy.queue_free()
	await process_frame

	var loot_map := StoryMap.new()
	root.add_child(loot_map)
	loot_map.setup(&"wilderness", {})
	loot_map.player.set_physics_process(false)
	loot_map.player.play_sfx = false
	var victim := loot_map.spawn_enemy(&"slime", loot_map.player.global_position + Vector2(12, 0))
	var killing_bean: BeanProjectile = load("res://game/projectiles/bean_projectile.tscn").instantiate()
	loot_map.add_child(killing_bean)
	killing_bean.launch({"id": &"bean", "damage": 99}, loot_map.player.global_position, Vector2.RIGHT, loot_map.player)
	victim.take_projectile_hit(99.0, killing_bean)
	await process_frame
	var flying_drops := 0
	for child in loot_map.get_children():
		if child is BeanProjectile and child != killing_bean and not child.is_landed and child.speed > BeanProjectile.INITIAL_SPEED:
			flying_drops += 1
	check(flying_drops == 2, "怪物死亡在真实地图生成两颗高速飞散豆而非原地落豆")
	loot_map.queue_free()
	await process_frame


func _n4_pillar_ring(include_node: bool) -> Dictionary:
	var blocked: Dictionary = {}
	for x in range(86, 89):
		blocked[Vector2i(x, 29)] = &"body"
		blocked[Vector2i(x, 31)] = &"body"
	for y in range(29, 32):
		blocked[Vector2i(86, y)] = &"body"
		blocked[Vector2i(88, y)] = &"body"
	if include_node:
		blocked[Vector2i(87, 29)] = &"node"
	return blocked


func _test_n7_chapter_one_contract() -> void:
	for map_id in StoryMapCatalog.ORDER:
		var definition: Dictionary = StoryMapCatalog.get_map(map_id)
		check(not definition.has("spawn") and not definition.has("npcs") and not definition.has("items"), "N7 坐标不再由 Catalog 持有：%s" % map_id)
		var layout: Node = load(String(definition.scene)).instantiate()
		for group_name in ["Actors", "Interactables", "Pickups", "Triggers", "SpawnPoints"]:
			check(layout.get_node_or_null(group_name) != null, "N7 地图可编辑分组 %s/%s" % [map_id, group_name])
		check(layout.get_node_or_null("SpawnPoints/Default") is MapEntry, "N7 默认出生点可拖拽：%s" % map_id)
		layout.free()

	var world := StoryMap.new()
	root.add_child(world)
	world.setup(&"wilderness", {})
	world.player.set_physics_process(false)
	var keti: NpcActor = world.get_node("MapLayout/Actors/Keti")
	check(keti.placeholder_sprite.texture != null, "Kenney 可蒂占位贴图已接入 N7A NPC")
	world.camera.focus_seconds = 0.0
	world.camera.restore_seconds = 0.0
	world._on_npc_interaction_requested(keti, world.player)
	await process_frame


	check(world.active_npc == keti and world.camera.position.is_zero_approx() and world.camera.zoom.is_equal_approx(Vector2.ONE), "N7 无剧情对白的直接 NPC 接触不触发镜头放大")
	world.finish_actor_interaction()
	await process_frame
	check(world.active_npc == null and world.camera.position.is_zero_approx() and world.camera.zoom.is_equal_approx(Vector2.ONE), "N7 互动结束镜头平滑恢复")
	world.queue_free()
	await process_frame

	var forest_world := StoryMap.new()
	root.add_child(forest_world)
	forest_world.setup(&"forest", {})
	var ajie: NpcActor = forest_world.get_node("MapLayout/Actors/Ajie")
	check(not ajie.visible and ajie.player == null, "N7 未激活 NPC 保留编辑器摆位但不参与运行")
	check(forest_world.activate_npc(&"ajie") == ajie and ajie.visible and ajie.player == forest_world.player, "N7 剧情可按 npc_id 激活预摆角色")
	for npc_name in ["Ajie", "Lisi", "Buck", "Miro"]:
		var npc: NpcActor = forest_world.get_node("MapLayout/Actors/%s" % npc_name)
		check(npc.placeholder_sprite.texture != null, "Kenney 森林 NPC 占位贴图已接入：%s" % npc_name)
	check(StoryPickup.PLACEHOLDER_TEXTURES.get(&"iron_sword") != null, "Kenney 铁剑拾取占位贴图可加载")
	check(BeanProjectile.GREEN_POTION_TEXTURE != null, "制作人指定的 Green Potion 投射贴图可加载")
	check(not ajie.damageable, "N7 剧情 NPC 在正式战斗动作前不会被豆子提前击倒")
	var automatic_enemies: Array[EnemyActor] = []
	for child in forest_world.get_children():
		if child is EnemyActor:
			automatic_enemies.append(child)
	check(automatic_enemies.size() == 5, "N7 森林五个 Inspector 出生点自动生成常驻敌人")
	var defeated_spawn := automatic_enemies[0].spawn_id
	automatic_enemies[0].take_damage(999.0, &"n7_persistence")
	await process_frame
	forest_world.capture_enemy_states()
	var saved_encounters := forest_world.encounter_states.duplicate(true)
	forest_world.queue_free()
	await process_frame
	var restored_forest := StoryMap.new()
	root.add_child(restored_forest)
	restored_forest.setup(&"forest", {}, &"", {}, {}, saved_encounters)
	var restored_enemy_ids: Dictionary = {}
	for child in restored_forest.get_children():
		if child is EnemyActor:
			restored_enemy_ids[String(child.spawn_id)] = true
	check(restored_enemy_ids.size() == 4 and not restored_enemy_ids.has(String(defeated_spawn)), "N7 常驻敌人死亡状态跨重建保持且不会复活")
	restored_forest.queue_free()
	await process_frame

	var wilderness_layout: Node = load("res://game/maps/levels/wilderness.tscn").instantiate()
	var forest_exit: MapExit = wilderness_layout.get_node("Triggers/ExitToForest")
	check(not forest_exit.is_unlocked({}) and forest_exit.is_unlocked({"prologue_complete": true}), "N7 出口锁定条件由场景 Inspector 配置")
	wilderness_layout.free()

	var transition: ScreenTransition = load("res://game/ui/screen_transition.tscn").instantiate()
	root.add_child(transition)
	await transition.fade_out()
	check(is_equal_approx(transition.shade.modulate.a, 1.0), "N7 全屏转场可渐黑")
	await transition.fade_in()
	check(is_zero_approx(transition.shade.modulate.a), "N7 全屏转场可恢复")
	transition.queue_free()
	await process_frame

	var authored_forest: Node = load("res://game/maps/levels/forest.tscn").instantiate()
	var authored_ajian: NpcActor = authored_forest.get_node("Actors/Ajian")
	var authored_pillar: Node = authored_forest.get_node("Interactables/ForestBridgePillar")
	var authored_animation := authored_pillar.get_node_or_null("AnimationPlayer") as AnimationPlayer
	check(authored_ajian.npc_id == &"ajian" and not authored_ajian.initially_active, "N7 森林场景保留可编辑阿见摆位")
	check(authored_forest.get_node("Ground") is TileMapLayer and authored_forest.get_node("Collision") is TileMapLayer, "N7 森林地表与碰撞仍由 TileMapLayer 编辑")
	check(authored_animation != null and authored_animation.has_animation(&"lower"), "N7 桥柱场景挂载可编辑 AnimationPlayer")
	authored_forest.free()

	var state := SessionState.new()
	var state_ajie: Dictionary = state.actors["ajie"]
	state_ajie["status"] = "downed"
	state.gold = 4
	var encoded := state.to_dictionary()
	var loaded_state := SessionState.new()
	var load_result := loaded_state.load_dictionary(encoded)
	check(load_result.ok and String(loaded_state.actors["ajie"].get("status", "")) == "downed", "N7 角色状态随存档序列化并恢复")
	state.remember_checkpoint()
	state_ajie["status"] = "swallowed"
	state.gold = 10
	state.restore_checkpoint()
	check(String(state.actors["ajie"].get("status", "")) == "downed" and state.gold == 4, "N7 检查点恢复角色状态与金币")
	var critical_actor: NpcActor = load("res://game/actors/npc_actor.tscn").instantiate()
	root.add_child(critical_actor)
	critical_actor.restore_persistent_state({"hp": 0.0, "is_dead": false, "is_downed": false, "active": true})
	check(not critical_actor.is_dead and not critical_actor.is_downed and critical_actor.visible, "N7 阿见 critical 零血状态读档后仍保留可互动实体")
	critical_actor.queue_free()
	await process_frame

	var cave_session: GameSession = load("res://game/main.tscn").instantiate()
	root.add_child(cave_session)
	await process_frame
	cave_session.state.flags["caveEntered"] = true
	await cave_session.load_map(&"cave", &"", true)
	cave_session.story.current_id = "cave_explore"
	cave_session.current_world.player.set_physics_process(false)
	cave_session.current_world.player.play_sfx = false
	var ring_pickup_n7: StoryPickup = cave_session.current_world.get_node("MapLayout/Pickups/RingNodePickup")
	check(not ring_pickup_n7.auto_collect and not ring_pickup_n7.consumed, "N7 环形节点靠近时不自动收集")
	ring_pickup_n7.interaction_requested.emit(ring_pickup_n7)
	await process_frame
	check(cave_session.story.current_id == "chapter1_ring" and not ring_pickup_n7.consumed, "N7 剧情物品互动打开环形节点对白")
	cave_session.dialogue._finish_enter()
	cave_session.story._on_choice("eat")
	await process_frame
	check(cave_session.state.flags.get("chapter1RingTaken", false) and cave_session.current_world.player.node_charges == 1 and ring_pickup_n7.consumed, "N7 环形节点由对白选择后才消耗并给予充能")
	cave_session.set_pause_reason(&"dialogue", false)
	cave_session.dialogue.close()
	cave_session.story.current_id = "cave_explore"
	cave_session.state.flags["goblinFightStarted"] = false
	var goblin_spawn := await cave_session.story.execute_command("spawnGoblinEncounter")
	var goblins: Array[EnemyActor] = []
	for child in cave_session.current_world.get_children():
		if child is EnemyActor and child.enemy_kind == "goblin":
			goblins.append(child)
	var goblin_ids: Dictionary = {}
	for goblin in goblins:
		goblin_ids[String(goblin.spawn_id)] = true
	check(goblin_spawn.ok and goblins.size() == 2 and goblin_ids.size() == 2, "N7 哥布林遭遇生成两只且类型/身份唯一")
	cave_session.queue_free()
	paused = false
	await process_frame

	var forest_session: GameSession = load("res://game/main.tscn").instantiate()
	root.add_child(forest_session)
	await process_frame
	forest_session.state.flags.clear()
	forest_session.state.actors = SessionState.new().actors.duplicate(true)
	forest_session.state.actors["ajian"] = {"status": "alive", "location": "forest", "hp": 8.0, "max_hp": 8.0, "met": true}
	await forest_session.load_map(&"forest", &"", true)
	forest_session.story.current_id = "chapter1_explore"
	var chapter_player := forest_session.current_world.player
	chapter_player.set_physics_process(false)
	chapter_player.play_sfx = false
	chapter_player.inventory = StomachInventory.new()
	chapter_player.set_length(8)
	var swallow_ajie := await forest_session.story.execute_command("swallowAjie")
	var swallow_lisi := await forest_session.story.execute_command("swallowLisi")
	var swallowed_ids: Dictionary = {}
	for entry in chapter_player.inventory.entries:
		if entry.has("metadata"):
			swallowed_ids[String(entry.metadata.get("actor_id", ""))] = true
	check(swallow_ajie.ok and swallow_lisi.ok and swallowed_ids.has("ajie") and swallowed_ids.has("lisi") and swallowed_ids.size() == 2, "N7 角色吞入保留各自唯一身份")
	var release_ajie := await forest_session.story.execute_command("releaseAjie")
	var release_lisi := await forest_session.story.execute_command("releaseLisi")
	var ajie_projectile := _find_actor_projectile(forest_session.current_world, &"ajie")
	var lisi_projectile := _find_actor_projectile(forest_session.current_world, &"lisi")
	check(release_ajie.ok and release_lisi.ok and ajie_projectile != null and lisi_projectile != null, "N7 角色吐出生成可追踪载荷")
	if ajie_projectile != null and lisi_projectile != null:
		check(StringName(ajie_projectile.payload.metadata.actor_id) == &"ajie" and StringName(lisi_projectile.payload.metadata.actor_id) == &"lisi", "N7 角色吐出不串用身份")
		ajie_projectile.land()
		lisi_projectile.land()
		await process_frame
		check(String(forest_session.state.actors.ajie.status) == "unconscious" and String(forest_session.state.actors.lisi.status) == "unconscious", "N7 阿杰与丽丝吐出后保留两个唯一昏迷状态")
		await forest_session.load_map(&"cave", &"", true)
		await forest_session.load_map(&"forest", &"forest_cave_return", true)
		var returned_ajie := forest_session.current_world.get_story_actor(&"ajie")
		var returned_lisi := forest_session.current_world.get_story_actor(&"lisi")
		var ajie_camp: MapEntry = forest_session.current_world.get_node("MapLayout/SpawnPoints/AjieCampReturn")
		var lisi_camp: MapEntry = forest_session.current_world.get_node("MapLayout/SpawnPoints/LisiCampReturn")
		check(is_instance_valid(returned_ajie) and is_instance_valid(returned_lisi) and returned_ajie.hostile and returned_lisi.hostile and not returned_ajie.is_downed and not returned_lisi.is_downed, "N7 两人都吐出后离图再返回，在森林恢复为清醒敌对 NPC")
		check(returned_ajie.global_position.distance_to(ajie_camp.global_position) < StoryMap.TILE_SIZE and returned_lisi.global_position.distance_to(lisi_camp.global_position) < StoryMap.TILE_SIZE, "N7 回营地坐标由 forest.tscn 可编辑定位点决定")
		var returned_player := forest_session.current_world.player
		check(returned_player.inventory.count_item(&"ajie") == 0 and returned_player.inventory.count_item(&"lisi") == 0 and String(forest_session.state.actors.ajie.status) == "alive" and String(forest_session.state.actors.lisi.status) == "alive", "N7 回营地迁移不复制实体、不残留胃袋载荷且不误写死亡")
		await forest_session.retry_checkpoint()
		var pair_counts := {&"ajie": 0, &"lisi": 0}
		for npc in forest_session.get_tree().get_nodes_in_group(&"npc"):
			if forest_session.current_world.is_ancestor_of(npc) and npc is NpcActor and pair_counts.has(npc.npc_id):
				pair_counts[npc.npc_id] += 1
		returned_ajie = forest_session.current_world.get_story_actor(&"ajie")
		returned_lisi = forest_session.current_world.get_story_actor(&"lisi")
		check(pair_counts[&"ajie"] == 1 and pair_counts[&"lisi"] == 1 and returned_ajie.hostile and returned_lisi.hostile, "N7 检查点重建仍只有两个唯一敌对 NPC")
		var pair_roundtrip := SessionState.new()
		check(pair_roundtrip.load_dictionary(forest_session.state.to_dictionary()).ok and bool(pair_roundtrip.actors.ajie.hostile) and bool(pair_roundtrip.actors.lisi.hostile), "N7 双人清醒敌对状态可序列化并读档")

	var partial_pair := SessionState.new()
	partial_pair.actors.ajie.status = "unconscious"
	partial_pair.actors.lisi.status = "alive"
	check(not partial_pair.prepare_released_pair_forest_return() and String(partial_pair.actors.ajie.status) == "unconscious", "N7 只吐出一人时不提前触发双人回营迁移")

	chapter_player = forest_session.current_world.player
	var ajian := forest_session.current_world.get_story_actor(&"ajian")
	chapter_player.add_special_item(&"ajian", {"actor_id": &"ajian"})
	var mount_result := await forest_session.story.execute_command("mountAjian")
	check(mount_result.ok and chapter_player.inventory.count_item(&"ajian") == 0 and forest_session.state.player.rider == "ajian" and is_instance_valid(ajian) and ajian.is_riding(), "N7 阿见可从胃袋转为骑乘且状态唯一")

	forest_session.state.flags.clear()
	forest_session.state.gold = 0
	await forest_session.story.execute_command("claimCampReward")
	await forest_session.story.execute_command("claimCampReward")
	check(forest_session.state.gold == 10 and forest_session.state.flags.get("campRewardClaimed", false), "N7 营地十金币奖励幂等")
	forest_session.state.flags.erase("banditResolved")
	forest_session.state.gold = 5
	await forest_session.story.execute_command("payBandits")
	await forest_session.story.execute_command("payBandits")
	check(forest_session.state.gold == 2 and forest_session.state.flags.get("banditOutcome", "") == "paid", "N7 劫匪支付三金币且幂等")
	forest_session.state.flags.erase("banditResolved")
	forest_session.state.gold = 0
	await forest_session.story.execute_command("reverseBanditRobbery")
	await forest_session.story.execute_command("reverseBanditRobbery")
	check(forest_session.state.gold == 6 and forest_session.state.flags.get("banditOutcome", "") == "robbed", "N7 劫匪反抢六金币且幂等")
	forest_session.queue_free()
	paused = false
	await process_frame


func _test_n7_integrated_story_paths() -> void:
	var session: GameSession = load("res://game/main.tscn").instantiate()
	root.add_child(session)
	await process_frame
	session.state.flags["prologue_complete"] = true
	session.state.story["chapter"] = "第一章"
	await session.load_map(&"forest", &"", true)
	session.story.current_id = "chapter1_explore"
	check(not session.story.map_exit(&"cave", &""), "N7 森林出口允许进入洞窟")
	await session.load_map(&"cave")
	check(session.story.current_id == "cave_intro", "N7 首次进入洞窟续接洞窟开场而非森林等待")
	session.dialogue._finish_enter()
	session.story._on_choice("continue")
	await process_frame
	check(session.story.current_id == "cave_explore" and bool(session.state.flags.get("caveEntered", false)), "N7 洞窟开场后进入可交互探索")

	var ajian := session.current_world.get_story_actor(&"ajian")
	session.current_world.story_actor_interacted.emit(&"ajian")
	await process_frame
	check(session.story.current_id == "cave_ajian_found", "N7 洞窟阿见按持久状态进入被绑分支")
	var wake := await session.story.execute_command("wakeAjianFace")
	var cut := await session.story.execute_command("cutAjianRope")
	check(wake.ok and cut.ok and String(session.state.actors.ajian.status) == "alive", "N7 阿见唤醒与解绑原子写入唯一角色状态")
	var encounter := await session.story.execute_command("spawnGoblinEncounter")
	session.story.current_id = "cave_goblin_combat"
	var goblins: Array[EnemyActor] = []
	for child in session.current_world.get_children():
		if child is EnemyActor and child.enemy_kind == "goblin": goblins.append(child)
	for goblin in goblins:
		goblin.take_damage(999.0, &"n7_integration")
	await process_frame
	await process_frame
	check(encounter.ok and goblins.size() == 2 and session.story.current_id == "cave_ajian_rescued" and bool(session.state.flags.get("goblinsDefeated", false)), "N7 两名哥布林真实倒下后续接阿见获救分支")

	await session.story.execute_command("revealAjian")
	var mount := await session.story.execute_command("mountAjian")
	check(mount.ok and session.state.player.rider == "ajian" and ajian.is_riding(), "N7 阿见以可见骑乘实体附着蛇身")
	check(not session.story.map_exit(&"forest", &"forest_cave_return"), "N7 洞窟出口允许返回森林")
	await session.load_map(&"forest", &"forest_cave_return")
	var forest_ajian := session.current_world.get_story_actor(&"ajian")
	check(session.story.current_id == "chapter1_explore" and is_instance_valid(forest_ajian) and forest_ajian.is_riding(), "N7 骑乘阿见跨图保持唯一身份与可见表现")
	session.current_world.story_trigger_entered.emit(&"camp_settlement")
	await process_frame
	check(bool(session.state.flags.get("campSettlementSeen", false)) and session.state.player.rider == "" and String(session.state.actors.ajian.location) == "forest" and not forest_ajian.is_riding(), "N7 营地结算让骑乘阿见落地到可编辑森林实例")
	session.queue_free()
	paused = false
	await process_frame

	var combat_session: GameSession = load("res://game/main.tscn").instantiate()
	root.add_child(combat_session)
	await process_frame
	combat_session.state.story["chapter"] = "第一章"
	await combat_session.load_map(&"forest", &"", true)
	combat_session.story.current_id = "chapter1_combat_pending"
	await combat_session.story.execute_command("startAjieCombat")
	await combat_session.story.execute_command("waitAjieCombat")
	var ajie := combat_session.current_world.get_story_actor(&"ajie")
	check(ajie.hostile and ajie.damageable, "N7 阿杰战斗命令实际激活可伤害敌对实体")
	ajie.take_damage(999.0, &"n7_integration")
	await process_frame
	check(ajie.is_downed and combat_session.story.current_id == "chapter1_ajie_downed_wait" and String(combat_session.state.actors.ajie.status) == "downed", "N7 阿杰倒地保留可互动实体并推进剧情")
	combat_session.story.current_id = "bandit_combat"
	await combat_session.story.execute_command("startBanditCombat")
	await combat_session.story.execute_command("waitBanditCombat")
	for actor_id in [&"buck", &"miro"]:
		combat_session.current_world.get_story_actor(actor_id).take_damage(999.0, &"n7_integration")
	await process_frame
	check(combat_session.story.current_id == "bandit_search" and String(combat_session.state.actors.buck.status) == "downed" and String(combat_session.state.actors.miro.status) == "downed", "N7 两名劫匪倒地后进入一次性搜刮分支")
	combat_session.queue_free()
	paused = false
	await process_frame

	var hostage_session: GameSession = load("res://game/main.tscn").instantiate()
	root.add_child(hostage_session)
	await process_frame
	hostage_session.state.story["chapter"] = "第一章"
	await hostage_session.load_map(&"forest", &"forest_from_wilderness", true)
	hostage_session.current_world.player.set_length(8)
	var swallowed := await hostage_session.story.execute_command("swallowBuck")
	hostage_session.story.current_id = "chapter1_explore"
	hostage_session._capture_player()
	var persisted_hostage_state := SessionState.new()
	var persisted_result := persisted_hostage_state.load_dictionary(hostage_session.state.to_dictionary())
	check(persisted_result.ok and String(persisted_hostage_state.actors.buck.status) == "swallowed" and Array(persisted_hostage_state.player.inventory).any(func(entry): return StringName(entry.get("id", "")) == &"buck"), "N7 劫匪人质状态与胃袋载荷可完整序列化读档")
	await hostage_session.load_map(&"wilderness", &"wilderness_from_forest", true)
	await hostage_session.load_map(&"forest", &"forest_from_wilderness", true)
	hostage_session.story.current_id = "chapter1_explore"
	hostage_session.current_world.story_actor_interacted.emit(&"miro")
	await process_frame
	check(swallowed.ok and String(hostage_session.state.actors.buck.status) == "swallowed" and hostage_session.story.current_id == "bandit_hostage_return_hostile", "N7 吞掉一名劫匪后离图再返回，剩余 NPC 触发拼命对话")
	hostage_session.dialogue._finish_enter()
	hostage_session.story._on_choice("fight")
	await process_frame
	var miro := hostage_session.current_world.get_story_actor(&"miro")
	check(hostage_session.story.current_id == "bandit_combat" and hostage_session.story.enemies_left == 1 and miro.hostile, "N7 人质状态下对话后只激活剩余劫匪战斗")
	miro.take_damage(999.0, &"n7_hostage")
	await process_frame
	check(hostage_session.story.current_id == "bandit_search" and String(hostage_session.state.actors.buck.status) == "swallowed", "N7 剩余劫匪倒地后推进剧情且不覆盖胃袋人质状态")
	hostage_session.queue_free()
	paused = false
	await process_frame


func _write_n4_save(store: SaveStore, slot: int, content: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(store.base_dir))
	var file := FileAccess.open(store.base_dir.path_join("slot_%d.json" % slot), FileAccess.WRITE)
	file.store_string(content)
	file.close()


func _find_actor_projectile(world: Node, actor_id: StringName) -> BeanProjectile:
	for child in world.get_children():
		if not child is BeanProjectile:
			continue
		var metadata: Dictionary = child.payload.get("metadata", {})
		var child_actor_id := StringName(metadata.get("actor_id", child.payload.get("id", "")))
		if child_actor_id == actor_id:
			return child
	return null


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
