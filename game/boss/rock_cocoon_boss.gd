class_name RockCocoonBoss
extends CharacterBody2D

signal health_changed(current: float, maximum: float)
signal shield_changed(current: float, maximum: float)
signal phase_changed(phase: int)
signal volley_fired(pattern: String, count: int)
signal summon_requested
signal crushed_tail(count: int)
signal defeated

const CELL := 24.0
const SEED_SCENE := preload("res://game/boss/boss_seed.tscn")
const BEAN_SCENE := preload("res://game/projectiles/bean_projectile.tscn")
@export var tuning: BossTuning

var player: SnakePlayer
var hp := 220.0
var max_hp := 220.0
var shield := 0.0
var phase_two := false
var is_dead := false
var stun_left := 0.0
var arena_bounds := Rect2(24, 24, 1680, 1104)
var radius := 72.0
var _target := Vector2.ZERO
var _target_left := 0.0
var _wave_left := 3.0
var _burst_left := 0
var _burst_clock := 0.0
var _ring_pattern := false
var _rotation := 0.0
var _summon_left := 9.0
var _crush_left := 0.0
var _flash_left := 0.0
var _projectile_hits: Dictionary[int, int] = {}

func _ready() -> void:
	if tuning == null: tuning = BossTuning.new()
	max_hp = maxf(1.0, tuning.max_hp)
	hp = max_hp
	radius = ($CollisionShape2D.shape as CircleShape2D).radius
	_wave_left = tuning.first_wave_delay
	_summon_left = tuning.first_summon_delay
	$Hurtbox.body_entered.connect(_on_hurtbox_entered)
	add_to_group(&"enemy")
	add_to_group(&"prison_target")
	_update_visuals()

func setup(target: SnakePlayer, bounds: Rect2) -> void:
	player = target
	arena_bounds = bounds
	_target = global_position

func _physics_process(delta: float) -> void:
	if is_dead or not is_instance_valid(player) or player.is_dead: return
	_crush_left = maxf(0.0, _crush_left - delta)
	_flash_left = maxf(0.0, _flash_left - delta)
	if stun_left > 0.0:
		stun_left = maxf(0.0, stun_left - delta)
		velocity = Vector2.ZERO
	else:
		_move(delta)
		_step_attacks(delta)
	apply_contact_crush()
	_update_visuals()

func _move(delta: float) -> void:
	_target_left -= delta
	if _target_left <= 0.0 or global_position.distance_to(_target) < 1.5 * CELL:
		_target_left = randi_range(tuning.target_seconds_min, maxi(tuning.target_seconds_min, tuning.target_seconds_max))
		var safe := arena_bounds.grow(-radius - CELL)
		_target = Vector2(randf_range(safe.position.x, safe.end.x), randf_range(safe.position.y, safe.end.y))
	var speed := tuning.phase_two_speed_cells if phase_two else tuning.phase_one_speed_cells
	velocity = global_position.direction_to(_target) * speed * CELL
	move_and_slide()

func _step_attacks(delta: float) -> void:
	if _burst_left > 0:
		_burst_clock -= delta
		if _burst_clock <= 0.0:
			_fire_volley()
			_burst_left -= 1
			_burst_clock = maxf(0.05, tuning.burst_gap)
			if _burst_left == 0:
				_wave_left = tuning.phase_two_wave_interval if phase_two else tuning.phase_one_wave_interval
	else:
		_wave_left -= delta
		if _wave_left <= 0.0:
			_ring_pattern = not _ring_pattern
			_burst_left = maxi(1, tuning.shots_per_burst)
			_burst_clock = 0.0
	if not phase_two:
		_summon_left -= delta
		if _summon_left <= 0.0:
			_summon_left = maxf(0.1, tuning.summon_interval)
			summon_requested.emit()

func _fire_volley() -> void:
	var count := (tuning.phase_two_ring_count if phase_two else tuning.phase_one_ring_count) if _ring_pattern else (tuning.phase_two_aim_count if phase_two else tuning.phase_one_aim_count)
	var speed := tuning.phase_two_seed_speed_cells if phase_two else tuning.phase_one_seed_speed_cells
	var start_angle := _rotation if _ring_pattern else global_position.direction_to(player.global_position).angle()
	for index in range(maxi(1, count)):
		var angle := start_angle + TAU * index / maxi(1, count) if _ring_pattern else start_angle + (index - (count - 1) * 0.5) * tuning.aim_spread
		var seed := SEED_SCENE.instantiate() as BossSeed
		get_parent().add_child(seed)
		seed.launch(global_position, Vector2.from_angle(angle), (speed if _ring_pattern else speed + tuning.aimed_speed_bonus_cells) * CELL, player, self, tuning.seed_lifetime, tuning.reflected_seed_damage)
	if _ring_pattern: _rotation += tuning.ring_rotation_step
	volley_fired.emit("ring" if _ring_pattern else "aimed", count)

func take_damage(amount: float, _source := &"projectile") -> float:
	if is_dead or amount <= 0.0: return 0.0
	var effective := amount * (tuning.shield_damage_multiplier if shield > 0.0 else 1.0)
	var absorbed := minf(shield, effective)
	shield -= absorbed
	var applied := minf(hp, effective - absorbed)
	hp -= applied
	_flash_left = 0.1
	if hp <= 0.0:
		is_dead = true
		set_physics_process(false)
		$Hurtbox.set_deferred("monitoring", false)
		$CollisionShape2D.set_deferred("disabled", true)
		defeated.emit()
	elif not phase_two and hp <= max_hp * tuning.phase_two_ratio:
		phase_two = true
		shield = maxf(0.0, tuning.shield_capacity)
		phase_changed.emit(2)
	health_changed.emit(hp, max_hp)
	shield_changed.emit(shield, tuning.shield_capacity)
	_update_visuals()
	return applied

func take_projectile_hit(amount: float, projectile: BeanProjectile) -> float:
	var id := projectile.get_instance_id()
	var now := Time.get_ticks_msec()
	if now - _projectile_hits.get(id, -1000) < 300: return 0.0
	_projectile_hits[id] = now
	return take_damage(amount, &"projectile")

func break_shield(amount: float, all_stakes_destroyed: bool) -> void:
	if is_dead or not phase_two: return
	shield = maxf(0.0, shield - maxf(0.0, amount))
	if all_stakes_destroyed:
		shield = 0.0
		stun_left = tuning.shield_break_stun
	shield_changed.emit(shield, tuning.shield_capacity)
	_update_visuals()

func apply_contact_crush() -> void:
	if not is_instance_valid(player) or player.is_dead or is_dead: return
	if global_position.distance_to(player.global_position) < radius + 0.38 * CELL:
		# Contact with this huge boss is fatal, independently of heart iframes.
		player._die("boss_crush")
		return
	if _crush_left > 0.0: return
	var old_segments := player.body_chain.segments.duplicate()
	for index in range(1, old_segments.size()):
		if global_position.distance_to(old_segments[index]) >= radius + 0.3 * CELL: continue
		var minimum := SnakePlayer.MIN_LENGTH + player.inventory.occupied_length()
		var old_length := player.body_chain.segment_count
		var remaining := maxi(minimum, index)
		if remaining >= old_length: return
		player.set_length(remaining)
		for lost in range(remaining, old_length):
			var bean := BEAN_SCENE.instantiate() as BeanProjectile
			get_parent().add_child(bean)
			var spot: Vector2 = old_segments[mini(lost, old_segments.size() - 1)]
			var away := global_position.direction_to(spot).rotated(randf_range(-0.35, 0.35))
			bean.launch({"id": &"bean", "damage": 4, "length": 1, "weight": 0}, spot, away, player)
			bean.speed = randf_range(7.0, 11.0) * CELL
		_crush_left = maxf(0.1, tuning.body_crush_cooldown)
		crushed_tail.emit(old_length - remaining)
		return

func is_prison_target() -> bool:
	return not is_dead

func _on_hurtbox_entered(body: Node2D) -> void:
	if body is BeanProjectile and not is_dead: body.hit_target(self)

func _update_visuals() -> void:
	$Visual/Shield.visible = shield > 0.0 and not is_dead
	var spikes := get_node_or_null("Visual/Spikes")
	if spikes: spikes.visible = phase_two
	modulate = Color("ffb4a0") if _flash_left > 0.0 else (Color("808080") if is_dead else Color.WHITE)
