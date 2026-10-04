extends SceneTree

const ARENA_SCENE: PackedScene = preload("res://game/boss/boss_arena.tscn")
const SEED_SCENE: PackedScene = preload("res://game/boss/boss_seed.tscn")
const BEAN_SCENE: PackedScene = preload("res://game/projectiles/bean_projectile.tscn")
const CELL := 24.0

var failures: Array[String] = []
var checks := 0
var arena: BossArena


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	arena = await _new_arena()
	await _test_scene_and_real_input()
	_test_damage_phase_and_volley()
	await _test_seed_collision_and_reflection()
	_test_stake_capture_and_prison()
	_test_summons()
	await _test_contact_crush_and_tail_drops()
	await _test_victory_freeze_and_enter_retry()
	await _test_defeat_freeze_and_r_retry()
	_input_release(KEY_P)
	Input.action_release("spit")
	paused = false
	if failures.is_empty():
		print("BOSS ARENA TESTS PASSED: %d checks" % checks)
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		print("BOSS ARENA TESTS FAILED: %d checks, %d failures" % [checks, failures.size()])
		quit(1)


func _new_arena() -> BossArena:
	paused = false
	var instance := ARENA_SCENE.instantiate() as BossArena
	get_root().add_child(instance)
	current_scene = instance
	instance.player.set_physics_process(false)
	instance.boss.set_physics_process(false)
	await process_frame
	await physics_frame
	return instance


func _test_scene_and_real_input() -> void:
	check(arena is BossArena and arena.player != null and arena.boss != null and arena.prison != null, "独立场景装配玩家、Boss 与囚笼控制器")
	check(arena.player.body_chain.segment_count == 24 and arena.player.global_position == Vector2(660, 588), "独立战斗按 24 节和指定出生点初始化")
	check(arena.boss.hp == 220.0 and arena.boss.max_hp == 220.0 and arena.elapsed >= 0.0, "Boss 战初始生命和计时器独立初始化")
	var elapsed_before := arena.elapsed
	_push_key(KEY_P, true)
	await process_frame
	check(arena.battle_paused and paused and arena.get_node("UI/PausePanel").visible, "真实 P 输入暂停 Boss 战并显示暂停面板")
	_push_key(KEY_P, false)
	await process_frame
	_push_key(KEY_P, true)
	await process_frame
	check(not arena.battle_paused and not paused and not arena.get_node("UI/PausePanel").visible, "再次真实 P 输入恢复 Boss 战")
	_push_key(KEY_P, false)
	await process_frame
	check(arena.elapsed >= elapsed_before, "暂停恢复后战斗计时保持有效")

	# Send the actual J key through Godot's input queue; the spawned projectile must hit the native Hurtbox.
	arena.boss.global_position = Vector2(920, 500)
	arena.player.global_position = Vector2(760, 500)
	arena.player.direction = Vector2.RIGHT
	arena.player.body_chain.reset(arena.player.global_position, arena.player.direction)
	arena.player.set_physics_process(true)
	var bean_before := arena.boss.hp
	var spit_count := [0]
	arena.player.bean_spit.connect(func(): spit_count[0] += 1)
	_push_key(KEY_J, true)
	Input.flush_buffered_events()
	await process_frame
	await physics_frame
	await process_frame
	await physics_frame
	_push_key(KEY_J, false)
	arena.player.set_physics_process(false)
	await _physics_frames(18)
	var observed_hit := arena.boss.hp < bean_before
	check(observed_hit, "真实 J 吐出的豆通过 Area2D Hurtbox 命中 Boss 并造成伤害")


func _test_damage_phase_and_volley() -> void:
	var phase_count := [0]
	arena.boss.phase_changed.connect(func(_phase: int): phase_count[0] += 1)
	var before := arena.boss.hp
	var applied := arena.boss.take_damage(4.0)
	check(is_equal_approx(applied, 4.0) and is_equal_approx(arena.boss.hp, before - 4.0), "普通豆伤害按基础值扣 Boss 生命")
	var to_half := arena.boss.hp - 110.0
	arena.boss.take_damage(to_half)
	check(arena.boss.phase_two and arena.boss.shield == 100.0 and phase_count[0] == 1, "生命降至半血时只触发一次二阶段并生成 100 护盾")
	check(arena.boss.take_damage(10.0) == 0.0 and arena.boss.shield == 97.5, "护盾期间普通伤害乘 0.25 并先消耗护盾")
	arena.boss.take_damage(20.0)
	check(phase_count[0] == 1, "二阶段不会因后续伤害重复触发")

	var volley := {"pattern": "", "count": 0}
	arena.boss.volley_fired.connect(func(pattern: String, count: int):
		volley.pattern = pattern
		volley.count = count
	)
	arena.boss._ring_pattern = true
	arena.boss._fire_volley()
	check(volley.pattern == "ring" and volley.count == 12, "二阶段环形齐射发射 12 枚种子弹")
	arena.boss._ring_pattern = false
	arena.boss._fire_volley()
	check(volley.pattern == "aimed" and volley.count == 5, "二阶段瞄准齐射发射 5 枚种子弹")
	arena._clear_seeds()
	arena.boss.phase_two = false
	arena.boss._ring_pattern = false
	arena.boss._fire_volley()
	check(volley.pattern == "aimed" and volley.count == 4, "第一阶段瞄准齐射发射 4 枚种子弹")
	arena._clear_seeds()
	var first_phase_volley_times: Array[Dictionary] = []
	var burst_time := [0.0]
	arena.boss.volley_fired.connect(func(pattern: String, count: int):
		if pattern == "ring":
			first_phase_volley_times.append({"count": count, "time": burst_time[0]})
	)
	arena.boss._ring_pattern = false
	arena.boss._burst_left = 0
	arena.boss._wave_left = 0.0
	for delta in [0.01, 0.01, 0.49, 0.02]:
		burst_time[0] += delta
		arena.boss._step_attacks(delta)
	check(first_phase_volley_times.size() == 2 and first_phase_volley_times[0].count == 9 and first_phase_volley_times[1].count == 9, "第一阶段单轮环形攻击分两次各发 9 枚")
	if first_phase_volley_times.size() == 2:
		var gap: float = first_phase_volley_times[1].time - first_phase_volley_times[0].time
		check(absf(gap - 0.5) < 0.03, "两次齐射之间间隔 0.5 秒")
	arena._clear_seeds()


func _test_seed_collision_and_reflection() -> void:
	# A seed collides with the arena's real boundary StaticBody2D and reverses its x direction.
	var wall_seed := _spawn_seed(Vector2(1695, 300), Vector2.RIGHT)
	wall_seed.speed = 2400.0
	await physics_frame
	check(wall_seed.direction.x < 0.0, "Boss 种子弹撞场地实体墙后反弹")
	wall_seed.queue_free()
	await process_frame

	# Arrange a real body segment on the seed path and the stationary boss beyond it.
	arena.player.global_position = Vector2(550, 470)
	arena.player.body_chain.reset(arena.player.global_position, Vector2.RIGHT)
	arena.player.body_chain.segments[2] = Vector2(900, 604)
	arena.boss.global_position = Vector2(1000, 600)
	arena.boss.shield = 0.0
	arena.boss.hp = 180.0
	var reflected := _spawn_seed(Vector2(820, 600), Vector2.RIGHT)
	reflected.speed = 2400.0
	for _i in range(10):
		await physics_frame
		if reflected.reflected_by_body:
			break
	check(reflected.reflected_by_body, "Boss 种子弹穿过蛇身后被真实链节反射")
	var hp_before := arena.boss.hp
	for _i in range(10):
		await physics_frame
		if not is_instance_valid(reflected) or reflected.is_queued_for_deletion():
			break
	check(is_equal_approx(hp_before - arena.boss.hp, 6.0), "反射种子弹命中 Boss 造成 6 点伤害")


func _test_stake_capture_and_prison() -> void:
	var stakes := _stakes()
	var stake: BlueCrystalStake = stakes[0]
	arena.boss.phase_two = true
	arena.boss.shield = 100.0
	stake.global_position = Vector2(40, 30) * CELL + Vector2.ONE * CELL * 0.5
	var stake_cell := Vector2i((stake.global_position / CELL).floor())
	arena.player.global_position = Vector2(200, 200)
	arena.player.body_chain.set_segment_count(24, arena.player.global_position)
	var starts := stake.capture_seconds
	arena.step_enclosures(1.0)
	check(is_equal_approx(stake.capture_seconds, starts), "没有闭合且接触身体的围笼时蓝晶桩不充能")
	_set_body_loop(stake_cell, 3)
	arena.step_enclosures(1.2)
	var partial := stake.capture_seconds
	check(partial > 1.0 and partial < stake.required_capture_seconds, "真实蛇身闭合区域使蓝晶桩开始累计充能")
	_set_body_line(Vector2(200, 200))
	arena.step_enclosures(0.8)
	check(is_equal_approx(stake.capture_seconds, partial), "离开闭合区域暂停充能且不清零")
	_set_body_loop(stake_cell, 3)
	arena.step_enclosures(1.9)
	check(stake.is_destroyed and is_equal_approx(arena.boss.shield, 75.0), "每桩累计满 3 秒后破坏并造成 25 点护盾伤害")
	var shield_after := arena.boss.shield
	arena.step_enclosures(1.0)
	check(is_equal_approx(arena.boss.shield, shield_after), "已破坏蓝晶桩不会重复扣除护盾")
	for crystal: BlueCrystalStake in stakes:
		if not crystal.is_destroyed:
			crystal.step_capture(3.0, true)
	check(arena.boss.shield == 0.0 and is_equal_approx(arena.boss.stun_left, 2.2), "四桩全部破坏后清空护盾并定身 2.2 秒")
	for crystal: BlueCrystalStake in stakes:
		crystal.step_capture(3.0, true)
	check(arena.boss.shield == 0.0 and is_equal_approx(arena.boss.stun_left, 2.2), "全破后的蓝晶桩不会再次扣盾或刷新定身")

	# Enclose the boss with a second real body loop to check the prison entry burst and DPS.
	arena.boss.hp = 200.0
	arena.boss.shield = 0.0
	var boss_cell := Vector2i((arena.boss.global_position / CELL).floor())
	_set_body_loop(boss_cell, 3)
	arena.step_enclosures(0.2)
	check(arena.boss.hp < 200.0 and arena.prison.active_prisons > 0, "真实身体围笼区域捕获 Boss 并造成囚笼伤害")
	check(arena.boss.hp <= 188.1, "囚笼进入爆发 10 点并叠加持续伤害")


func _test_summons() -> void:
	arena.boss.phase_two = false
	arena.boss.is_dead = false
	arena.boss.global_position = Vector2(1000, 700)
	arena.player.global_position = Vector2(400, 400)
	for _i in range(6):
		arena._summon_slime()
	var slimes := _slimes()
	check(slimes.size() <= 3, "第一阶段史莱姆召唤数量受 3 只上限限制")
	var all_free := true
	for slime: EnemyActor in slimes:
		all_free = all_free and arena._position_free(slime.global_position) and slime.global_position.distance_to(arena.player.global_position) >= 4.0 * CELL
	check(all_free, "史莱姆出生点可用且与玩家至少相距 4 格")
	var summon_count := [0]
	arena.boss.summon_requested.connect(func(): summon_count[0] += 1)
	arena.boss._summon_left = 0.01
	arena.boss._step_attacks(0.02)
	check(summon_count[0] == 1, "第一阶段召唤计时到期时发出一次召唤请求")
	arena.boss.phase_two = true
	arena._summon_slime()
	check(_slimes().size() == slimes.size(), "二阶段不再召唤史莱姆")
	arena.boss._summon_left = 0.01
	arena.boss._step_attacks(20.0)
	check(summon_count[0] == 1, "二阶段不再触发召唤计时")


func _test_contact_crush_and_tail_drops() -> void:
	# Fatal head contact takes precedence over hearts and freezes the result screen.
	arena.boss.global_position = Vector2(800, 500)
	arena.player.global_position = arena.boss.global_position
	arena.player.hearts = 3
	arena.boss.apply_contact_crush()
	check(arena.player.is_dead and arena.outcome == "defeat" and arena.player.hearts == 3, "Boss 碰头直接失败且不依赖生命值归零")
	paused = false
	arena.queue_free()
	await process_frame
	arena = await _new_arena()
	arena.player.set_length(24)
	_push_key(KEY_K, true)
	await process_frame
	_push_key(KEY_K, false)
	await process_frame
	check(arena.player.body_chain.segment_count == SnakePlayer.MIN_LENGTH and _beans_in_battle() == 12, "真实 K 断尾保留最短身长并返还飞行豆")
	arena.player.global_position = Vector2(750, 600)
	arena.boss.global_position = Vector2(1000, 600)
	arena.player.body_chain.set_segment_count(24, arena.player.global_position)
	arena.player.body_chain.segments[4] = arena.boss.global_position + Vector2(70, 0)
	var head_before := arena.player.body_chain.segment_count
	arena.boss.apply_contact_crush()
	check(arena.player.body_chain.segment_count >= SnakePlayer.MIN_LENGTH and arena.player.body_chain.segment_count < head_before, "Boss 碾压身体截尾并至少保留最短蛇身")
	var returned := 0
	for child in arena.get_node("Battle").get_children():
		if child is BeanProjectile:
			returned += 1
	check(returned > 0, "Boss 截下的蛇尾生成可回收豆")


func _test_victory_freeze_and_enter_retry() -> void:
	arena.boss.hp = 1.0
	arena.boss.is_dead = false
	arena.boss.take_damage(1.0)
	check(arena.outcome == "victory" and paused and arena.get_node("UI/ResultPanel").visible, "Boss 生命归零显示胜利结果并冻结战斗")
	var frozen_elapsed := arena.elapsed
	await create_timer(0.08, true).timeout
	check(is_equal_approx(arena.elapsed, frozen_elapsed), "胜利结果期间战斗计时冻结")
	_push_key(KEY_ENTER, true)
	await process_frame
	await process_frame
	_push_key(KEY_ENTER, false)
	await process_frame
	arena = current_scene as BossArena
	check(arena != null and arena.outcome.is_empty() and not paused, "胜利结果真实 Enter 输入重载为新一局")
	if arena != null:
		check(arena.boss.hp == 220.0 and arena.elapsed < 0.15 and arena.player.body_chain.segment_count == 24, "胜利重试恢复满血、零计时和初始身长")
		var fresh_stakes := _stakes()
		var stakes_fresh := fresh_stakes.size() == 4
		for stake: BlueCrystalStake in fresh_stakes:
			stakes_fresh = stakes_fresh and not stake.active and not stake.is_destroyed and stake.capture_seconds == 0.0
		check(stakes_fresh and arena.boss.shield == 0.0, "重试新局恢复四根未激活且未充能的蓝晶桩")


func _test_defeat_freeze_and_r_retry() -> void:
	arena.player._die("test_defeat")
	check(arena.outcome == "defeat" and paused and arena.get_node("UI/ResultPanel").visible, "玩家失败显示失败结果并冻结战斗")
	var frozen_elapsed := arena.elapsed
	await create_timer(0.08, true).timeout
	check(is_equal_approx(arena.elapsed, frozen_elapsed), "失败结果期间战斗计时冻结")
	_push_key(KEY_R, true)
	await process_frame
	await process_frame
	_push_key(KEY_R, false)
	await process_frame
	arena = current_scene as BossArena
	check(arena != null and arena.outcome.is_empty() and not paused, "失败结果真实 R 输入重载为新一局")
	if arena != null:
		check(arena.boss.hp == 220.0 and arena.elapsed < 0.15 and arena.player.hearts == 3, "失败重试恢复 Boss、计时与玩家生命")


func _spawn_seed(origin: Vector2, heading: Vector2) -> BossSeed:
	var seed := SEED_SCENE.instantiate() as BossSeed
	arena.get_node("Battle").add_child(seed)
	seed.launch(origin, heading, 120.0, arena.player, arena.boss, 12.0, 6.0)
	return seed


func _stakes() -> Array[BlueCrystalStake]:
	var result: Array[BlueCrystalStake] = []
	for child in arena.get_node("Battle/StakeLayout").get_children():
		if child is BlueCrystalStake:
			result.append(child)
	return result


func _slimes() -> Array[EnemyActor]:
	var result: Array[EnemyActor] = []
	for child in arena.get_node("Battle").get_children():
		if child is EnemyActor and not child.is_dead:
			result.append(child)
	return result


func _beans_in_battle() -> int:
	var result := 0
	for child in arena.get_node("Battle").get_children():
		if child is BeanProjectile:
			result += 1
	return result


func _set_body_line(head: Vector2) -> void:
	arena.player.global_position = head
	arena.player.body_chain.path = [head, head + Vector2.LEFT * 24.0 * 30.0]
	arena.player.body_chain.set_segment_count(24, head)


func _set_body_loop(center: Vector2i, radius_cells: int) -> void:
	var perimeter: Array[Vector2] = []
	var left := center.x - radius_cells
	var right := center.x + radius_cells
	var top := center.y - radius_cells
	var bottom := center.y + radius_cells
	for x in range(left, right + 1):
		perimeter.append((Vector2(x, top) + Vector2.ONE * 0.5) * CELL)
	for y in range(top + 1, bottom + 1):
		perimeter.append((Vector2(right, y) + Vector2.ONE * 0.5) * CELL)
	for x in range(right - 1, left - 1, -1):
		perimeter.append((Vector2(x, bottom) + Vector2.ONE * 0.5) * CELL)
	for y in range(bottom - 1, top, -1):
		perimeter.append((Vector2(left, y) + Vector2.ONE * 0.5) * CELL)
	arena.player.global_position = perimeter[0]
	arena.player.body_chain.path = perimeter
	arena.player.body_chain.set_segment_count(24, perimeter[0])


func _push_key(key: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = key
	event.physical_keycode = key
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _input_release(key: Key) -> void:
	_push_key(key, false)


func _physics_frames(count: int) -> void:
	for _i in range(count):
		await physics_frame


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		print("FAIL_CHECK_%d" % checks)
		failures.append(message)
