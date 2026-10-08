class_name BossArena
extends Node2D

const CELL := 24.0
const BEAN_SCENE := preload("res://game/projectiles/bean_projectile.tscn")
@export_category("Independent Battle")
@export_range(3, 120) var initial_length := 24
@export_range(1, 10) var initial_hearts := 3
@export_range(0, 3) var node_charges := 3
@export var arena_cells := Rect2i(1, 1, 70, 46)
@export var stakes_follow_boss_on_activation := true
@export var preview_resolution := Vector2i(1280, 800)
@export var summon_scene: PackedScene = preload("res://game/actors/enemy_actor.tscn")

@onready var player: SnakePlayer = $Battle/SnakePlayer
@onready var boss: RockCocoonBoss = $Battle/Boss
@onready var prison: PrisonController = $Battle/PrisonController
var elapsed := 0.0
var outcome := ""
var battle_paused := false
var defeat_reason := ""
var _prison_clock := 0.0
var _world_cells: Dictionary = {}
var _stake_offsets: Dictionary = {}
var _previous_canvas := Vector2i.ZERO

func _ready() -> void:
	var bindings := InputBindingsStore.new()
	bindings.load_settings()
	_previous_canvas = get_window().content_scale_size
	get_window().content_scale_size = preview_resolution
	if DisplayServer.get_name() != "headless": get_window().size = preview_resolution
	player.set_length(initial_length)
	player.reset_at($Battle/SpawnPoints/PlayerSpawn.global_position)
	player.max_hearts = initial_hearts
	player.hearts = initial_hearts
	player.node_unlocked = true
	player.node_charges = node_charges
	boss.global_position = $Battle/SpawnPoints/BossSpawn.global_position
	boss.setup(player, Rect2(Vector2(arena_cells.position) * CELL, Vector2(arena_cells.size) * CELL))
	for stake in $Battle/StakeLayout.get_children():
		if stake is BlueCrystalStake:
			_stake_offsets[stake] = stake.global_position - boss.global_position
			stake.destroyed.connect(_on_stake_destroyed)
	boss.phase_changed.connect(_on_phase_changed)
	boss.summon_requested.connect(_summon_slime)
	boss.defeated.connect(_finish.bind("victory"))
	player.died.connect(_on_player_died)
	$UI/Hud/PauseButton.pressed.connect(toggle_pause)
	$UI/PausePanel/ResumeButton.pressed.connect(toggle_pause)
	$UI/PausePanel/RetryButton.pressed.connect(retry)
	$UI/ResultPanel/RetryButton.pressed.connect(retry)
	$UI/Hud/Controls.text = "↑%s ←%s ↓%s →%s · 转向\n%s 吐豆 · %s 放节点 · %s 断尾 · %s 暂停" % [bindings.key_text(&"move_up"), bindings.key_text(&"move_left"), bindings.key_text(&"move_down"), bindings.key_text(&"move_right"), bindings.key_text(&"spit"), bindings.key_text(&"place_node"), bindings.key_text(&"cut_tail"), bindings.key_text(&"pause")]
	# The editable collision nodes are the sole source of the enclosure grid.
	_cache_world_cells.call_deferred()
	_refresh_hud()

func _exit_tree() -> void:
	if is_instance_valid(get_window()): get_window().content_scale_size = _previous_canvas

func _process(delta: float) -> void:
	if not battle_paused and outcome.is_empty() and not get_tree().paused:
		elapsed += delta
	_refresh_hud()

func _physics_process(delta: float) -> void:
	if battle_paused or not outcome.is_empty() or get_tree().paused: return
	_prison_clock += delta
	if _prison_clock >= 0.12:
		step_enclosures(_prison_clock)
		_prison_clock = 0.0

func _input(event: InputEvent) -> void:
	if event is not InputEventKey or not event.pressed or event.echo: return
	var code: Key = event.physical_keycode if event.physical_keycode != 0 else event.keycode
	if (event.is_action_pressed("pause") or code == KEY_ESCAPE) and outcome.is_empty():
		toggle_pause()
		get_viewport().set_input_as_handled()
	elif not outcome.is_empty() and code in [KEY_R, KEY_ENTER, KEY_SPACE]:
		retry.call_deferred()
		get_viewport().set_input_as_handled()

func toggle_pause() -> void:
	if not outcome.is_empty(): return
	battle_paused = not battle_paused
	get_tree().paused = battle_paused
	$UI/PausePanel.visible = battle_paused
	if battle_paused: $UI/PausePanel/ResumeButton.grab_focus()

func retry() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()

func _on_player_died(reason: String) -> void:
	defeat_reason = reason
	_finish("defeat")

func _finish(result: String) -> void:
	if not outcome.is_empty(): return
	outcome = result
	battle_paused = false
	get_tree().paused = true
	$UI/PausePanel.hide()
	$UI/ResultPanel.show()
	$UI/ResultPanel/Title.text = "茧母击破！" if result == "victory" else ("这回被碾扁了…" if defeat_reason == "boss_crush" else "你寄了！")
	$UI/ResultPanel/Summary.text = "用时 %.1f 秒\n剩余身长 %d 节 · 剩余心数 %d\n按 Enter / R 再战一次" % [elapsed, player.body_chain.segment_count, player.hearts]
	$UI/ResultPanel/RetryButton.grab_focus()
	_clear_seeds()

func _refresh_hud() -> void:
	$UI/Hud/Health.max_value = boss.max_hp
	$UI/Hud/Health.value = boss.hp
	$UI/Hud/Shield.max_value = maxf(1.0, boss.tuning.shield_capacity)
	$UI/Hud/Shield.value = boss.shield
	$UI/Hud/Shield.visible = boss.phase_two and boss.shield > 0.0
	$UI/Hud/PlayerInfo.text = "身长 %d · 心 %d/%d · 节点 %d" % [player.body_chain.segment_count, player.hearts, player.max_hearts, player.node_charges]
	var hint := "第一阶段 · 吐豆、围困或用身体反弹种子弹"
	if boss.phase_two:
		hint = "蓝晶桩已破 · 茧母加速，小心碰头！" if boss.shield <= 0.0 else "第二阶段 · 用蛇身围住蓝晶桩累计 3 秒，四桩破盾"
	if boss.stun_left > 0.0: hint = "护盾碎裂！趁茧母眩晕反击"
	$UI/Hud/StageHint.text = hint

func _on_phase_changed(_phase: int) -> void:
	_clear_seeds()
	for stake: BlueCrystalStake in _stake_offsets:
		if stakes_follow_boss_on_activation:
			stake.global_position = _nearest_free(boss.global_position + Vector2(_stake_offsets[stake]), 3)
		stake.activate()

func _clear_seeds() -> void:
	for child in $Battle.get_children():
		if child is BossSeed: child.queue_free()

func _on_stake_destroyed(stake: BlueCrystalStake) -> void:
	var all_destroyed := true
	for crystal: BlueCrystalStake in _stake_offsets:
		if not crystal.is_destroyed: all_destroyed = false
	boss.break_shield(stake.shield_damage, all_destroyed)

func _cache_world_cells() -> void:
	_world_cells.clear()
	for y in range(arena_cells.position.y, arena_cells.end.y):
		for x in range(arena_cells.position.x, arena_cells.end.x):
			var cell := Vector2i(x, y)
			var query := PhysicsPointQueryParameters2D.new()
			query.position = (Vector2(cell) + Vector2.ONE * 0.5) * CELL
			query.collision_mask = 1
			if not get_world_2d().direct_space_state.intersect_point(query, 1).is_empty():
				_world_cells[cell] = "world"

func step_enclosures(delta: float) -> void:
	if not outcome.is_empty(): return
	var blocked := _world_cells.duplicate()
	for cell in player.body_chain.occupied_cells:
		if arena_cells.has_point(cell): blocked[cell] = "body"
	for ring in player.placed_nodes:
		if is_instance_valid(ring) and not ring.finished: blocked[ring.cell] = "node"
	var targets: Array = [boss]
	for child in $Battle.get_children():
		if child is EnemyActor and not child.is_dead: targets.append(child)
	prison.step(delta, arena_cells, blocked, targets, player.placed_nodes)
	if not outcome.is_empty(): return
	var regions := EnclosureDetector.find_regions(arena_cells, blocked)
	for stake: BlueCrystalStake in _stake_offsets:
		var enclosed := false
		var cell := Vector2i((stake.global_position / CELL).floor())
		for region in regions:
			if bool(region.touches_body) and region.cells.has(cell): enclosed = true
		stake.step_capture(delta, enclosed)

func _position_free(point: Vector2, clearance := 14.0) -> bool:
	var bounds := Rect2(Vector2(arena_cells.position) * CELL, Vector2(arena_cells.size) * CELL).grow(-clearance)
	if not bounds.has_point(point): return false
	var shape := CircleShape2D.new()
	shape.radius = clearance
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0.0, point)
	query.collision_mask = 1
	return get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty()

func _nearest_free(point: Vector2, search_cells: int) -> Vector2:
	var bounds := Rect2(Vector2(arena_cells.position) * CELL, Vector2(arena_cells.size) * CELL).grow(-18.0)
	var clamped := point.clamp(bounds.position, bounds.end)
	for radius_cells in range(search_cells + 1):
		for y in range(-radius_cells, radius_cells + 1):
			for x in range(-radius_cells, radius_cells + 1):
				var candidate := clamped + Vector2(x, y) * CELL
				if _position_free(candidate): return candidate
	return clamped

func _summon_slime() -> void:
	if boss.phase_two or not outcome.is_empty(): return
	var count := 0
	for child in $Battle.get_children():
		if child is EnemyActor and not child.is_dead: count += 1
	if count >= boss.tuning.summon_limit: return
	for attempt in range(40):
		var point := boss.global_position + Vector2.from_angle(randf() * TAU) * randf_range(boss.tuning.summon_radius_min_cells, boss.tuning.summon_radius_max_cells) * CELL
		if not _position_free(point) or point.distance_to(player.global_position) < 4.0 * CELL: continue
		if summon_scene == null: return
		var slime := summon_scene.instantiate() as EnemyActor
		if slime == null: return
		$Battle.add_child(slime)
		slime.global_position = point
		slime.setup(player)
		slime.defeated.connect(_on_slime_defeated)
		return

func _on_slime_defeated(slime: EnemyActor, drops: int) -> void:
	for launch_data in slime.make_loot_burst(drops):
		var bean := BEAN_SCENE.instantiate() as BeanProjectile
		$Battle.add_child(bean)
		bean.launch({"id": &"bean", "damage": 4, "length": 1, "weight": 0}, slime.global_position, launch_data.direction, player)
		bean.speed = launch_data.speed
