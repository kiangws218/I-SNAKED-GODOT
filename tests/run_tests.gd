extends SceneTree

var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_test_project_contract()
	_test_body_chain()
	await _test_real_input_and_rescue()
	if failures.is_empty():
		print("N1 TESTS PASSED")
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
	for layer_index in range(1, 11):
		check(
			not String(ProjectSettings.get_setting("layer_names/2d_physics/layer_%d" % layer_index, "")).is_empty(),
			"物理层命名：%d" % layer_index,
		)
	for scene_path in ["res://game/main.tscn", "res://game/test_arena.tscn", "res://game/player/snake_player.tscn"]:
		check(ResourceLoader.exists(scene_path), "场景存在：%s" % scene_path)


func _test_body_chain() -> void:
	var chain := BodyChain.new()
	root.add_child(chain)
	chain.reset(Vector2(240, 240), Vector2.RIGHT)
	check(chain.segments.size() == 4, "初始四节身体")
	check(chain.segments[1].is_equal_approx(Vector2(216, 240)), "身体间距 1 格")
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


func _test_real_input_and_rescue() -> void:
	var arena: Node = load("res://game/test_arena.tscn").instantiate()
	root.add_child(arena)
	await physics_frame
	var player: SnakePlayer = arena.get_node("SnakePlayer")
	player.set_physics_process(false)
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


func _has_key(action: StringName, physical_keycode: Key) -> bool:
	for event in InputMap.action_get_events(action):
		if event is InputEventKey and event.physical_keycode == physical_keycode:
			return true
	return false


func _send_key(physical_keycode: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = physical_keycode
	event.physical_keycode = physical_keycode
	event.pressed = pressed
	Input.parse_input_event(event)


func check(condition: bool, label: String) -> void:
	if not condition:
		failures.append("FAILED: %s" % label)
