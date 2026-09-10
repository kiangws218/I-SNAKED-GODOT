class_name EnemyActor
extends CharacterBody2D

signal health_changed(current: float, maximum: float)
signal defeated(enemy: EnemyActor, bean_drops: int)
signal shot_fired(projectile: EnemyProjectile)

const TILE_SIZE := 24.0
const PROJECTILE_SCENE := preload("res://game/projectiles/enemy_projectile.tscn")
const LOOT_BURST_SPEED_SCALE := 0.6
const TYPES := {
	&"slime": {"hp": 14.0, "speed": 2.0, "radius": 0.55, "drops": 2},
	&"mushroom": {"hp": 16.0, "speed": 0.0, "radius": 0.62, "drops": 2, "cadence": 4.0, "telegraph": 0.7, "bullet_speed": 2.0},
	&"goblin": {"hp": 8.0, "speed": 0.0, "radius": 0.62, "drops": 2, "cadence": 2.2, "telegraph": 0.55, "bullet_speed": 3.0},
}

@export_enum("slime", "mushroom", "goblin") var enemy_kind: String = "slime"
@export var spawn_id: StringName
@export var initially_active := true
@export_category("Stat Overrides")
@export var hp_override := -1.0
@export var speed_override := -1.0
@export var attack_cadence_override := -1.0
@export var telegraph_override := -1.0
@export var projectile_speed_override := -1.0

var player: SnakePlayer
var hp := 1.0
var max_hp := 1.0
var move_speed := 0.0
var radius := 0.5 * TILE_SIZE
var bean_drops := 0
var shot_timer := 0.0
var warning_active := false
var is_dead := false
var death_hit_direction := Vector2.RIGHT
var death_head_distance := 8.0 * TILE_SIZE
var _recoil_left := 0.0
var _contact_hitstop_left := 0.0


func _ready() -> void:
	var definition: Dictionary = TYPES.get(enemy_kind, TYPES[&"slime"])
	max_hp = hp_override if hp_override > 0.0 else float(definition.hp)
	hp = max_hp
	move_speed = (speed_override if speed_override >= 0.0 else float(definition.speed)) * TILE_SIZE
	radius = float(definition.radius) * TILE_SIZE
	bean_drops = int(definition.drops)
	shot_timer = _attack_cadence(definition)
	$Mushroom.visible = enemy_kind == &"mushroom"
	$Slime.visible = enemy_kind == &"slime"
	if $Mushroom.visible:
		$Mushroom.play(&"idle")
	if $Slime.visible:
		$Slime.play(&"idle")
	$Hurtbox.body_entered.connect(_on_hurtbox_body_entered)
	add_to_group(&"enemy")
	add_to_group(&"prison_target")
	set_enemy_active(initially_active)
	queue_redraw()


func setup(target: SnakePlayer) -> void:
	player = target


func _physics_process(delta: float) -> void:
	if is_dead or not is_instance_valid(player):
		return
	var movement_delta := maxf(0.0, delta - _contact_hitstop_left)
	_contact_hitstop_left = maxf(0.0, _contact_hitstop_left - delta)
	if movement_delta <= 0.0:
		return
	if _recoil_left > 0.0:
		_recoil_left = maxf(0.0, _recoil_left - movement_delta)
		move_and_collide(velocity * movement_delta)
		velocity = velocity.move_toward(Vector2.ZERO, 18.0 * TILE_SIZE * movement_delta)
	elif enemy_kind == &"slime":
		_move_toward_player(movement_delta)
	else:
		_update_ranged(movement_delta)
	_damage_player_on_head_contact()


func _move_toward_player(delta: float) -> void:
	var direction := global_position.direction_to(player.global_position)
	velocity = direction * move_speed
	var candidate := global_position + velocity * delta
	if _body_normal(candidate).is_zero_approx():
		move_and_collide(velocity * delta)
	else:
		velocity = Vector2.ZERO


func _update_ranged(delta: float) -> void:
	var definition: Dictionary = TYPES.get(enemy_kind, TYPES[&"mushroom"])
	shot_timer -= delta
	var next_warning := shot_timer <= _telegraph(definition)
	if next_warning != warning_active:
		warning_active = next_warning
		queue_redraw()
	if shot_timer > 0.0:
		return
	shot_timer += _attack_cadence(definition)
	warning_active = false
	var projectile: EnemyProjectile = PROJECTILE_SCENE.instantiate()
	get_parent().add_child(projectile)
	projectile.launch(global_position, global_position.direction_to(player.global_position), _projectile_speed(definition), player, self)
	shot_fired.emit(projectile)
	queue_redraw()


func _damage_player_on_head_contact() -> void:
	if global_position.distance_to(player.global_position) >= radius + 0.38 * TILE_SIZE:
		return
	if player.take_damage(1, &"enemy_contact"):
		_contact_hitstop_left = SnakePlayer.CONTACT_HITSTOP_SECONDS
		var away := player.global_position.direction_to(global_position)
		if away.is_zero_approx():
			away = Vector2.RIGHT
		velocity = away * 6.0 * TILE_SIZE
		_recoil_left = 0.16


func _body_normal(candidate: Vector2) -> Vector2:
	if not is_instance_valid(player):
		return Vector2.ZERO
	for index in range(2, player.body_chain.segments.size()):
		var delta := candidate - player.body_chain.segments[index]
		if delta.length() < radius + 0.4 * TILE_SIZE:
			return delta.normalized() if not delta.is_zero_approx() else -velocity.normalized()
	return Vector2.ZERO


func take_damage(amount: float, _source := &"projectile") -> float:
	if is_dead or amount <= 0.0:
		return 0.0
	var applied := minf(hp, amount)
	hp -= applied
	health_changed.emit(hp, max_hp)
	queue_redraw()
	if hp <= 0.0:
		is_dead = true
		set_enemy_active(false)
		defeated.emit(self, bean_drops)
	return applied


func take_projectile_hit(amount: float, projectile: BeanProjectile) -> float:
	death_hit_direction = projectile.flight_direction.normalized()
	if is_instance_valid(player): death_head_distance = global_position.distance_to(player.global_position)
	return take_damage(amount, &"projectile")


func make_loot_burst(count: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var closeness := 1.0 - clampf(death_head_distance / (8.0 * TILE_SIZE), 0.0, 1.0)
	var distance_boost := lerpf(0.9, 2.35, closeness)
	var base_direction := death_hit_direction if not death_hit_direction.is_zero_approx() else Vector2.RIGHT
	for index in range(count):
		var fan := (float(index) - float(count - 1) * 0.5) * 0.32
		result.append({
			"direction": base_direction.rotated(fan + randf_range(-0.38, 0.38)).normalized(),
			"speed": BeanProjectile.INITIAL_SPEED * LOOT_BURST_SPEED_SCALE * distance_boost * randf_range(0.78, 1.18),
		})
	return result


func is_prison_target() -> bool:
	return not is_dead


func set_enemy_active(active: bool) -> void:
	visible = active
	set_physics_process(active and not is_dead)
	var body_collision := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if body_collision:
		body_collision.set_deferred("disabled", not active)
	var hurtbox := get_node_or_null("Hurtbox") as Area2D
	if hurtbox:
		hurtbox.set_deferred("monitoring", active and not is_dead)


func get_persistent_state() -> Dictionary:
	return {
		"spawn_id": String(spawn_id),
		"enemy_kind": String(enemy_kind),
		"hp": hp,
		"max_hp": max_hp,
		"position": global_position,
		"is_dead": is_dead,
		"active": visible,
	}


func restore_persistent_state(state: Dictionary) -> bool:
	if state.has("spawn_id") and StringName(state.spawn_id) != spawn_id:
		return false
	if state.has("enemy_kind") and StringName(state.enemy_kind) != enemy_kind:
		return false
	if state.has("max_hp"):
		max_hp = maxf(0.0, float(state.max_hp))
	if state.has("position"):
		var saved_position = state.position
		if saved_position is Array and saved_position.size() == 2:
			global_position = Vector2(float(saved_position[0]), float(saved_position[1]))
		elif saved_position is Vector2:
			global_position = saved_position
	hp = clampf(float(state.get("hp", max_hp)), 0.0, max_hp)
	is_dead = bool(state.get("is_dead", hp <= 0.0)) or hp <= 0.0
	if state.has("active"):
		set_enemy_active(bool(state.active))
	else:
		set_enemy_active(not is_dead)
	health_changed.emit(hp, max_hp)
	queue_redraw()
	return true


func _attack_cadence(definition: Dictionary) -> float:
	return attack_cadence_override if attack_cadence_override >= 0.0 else float(definition.get("cadence", 0.0))


func _telegraph(definition: Dictionary) -> float:
	return telegraph_override if telegraph_override >= 0.0 else float(definition.get("telegraph", 0.0))


func _projectile_speed(definition: Dictionary) -> float:
	return projectile_speed_override if projectile_speed_override >= 0.0 else float(definition.get("bullet_speed", 0.0))


func _on_hurtbox_body_entered(body: Node2D) -> void:
	if body is BeanProjectile:
		body.hit_target(self)


func _draw() -> void:
	if enemy_kind == &"goblin":
		draw_circle(Vector2(0, -2), 10.0, Color("7e9f4b"))
		draw_colored_polygon(PackedVector2Array([Vector2(-11, -8), Vector2(-17, -15), Vector2(-8, -11)]), Color("9fbd61"))
		draw_colored_polygon(PackedVector2Array([Vector2(11, -8), Vector2(17, -15), Vector2(8, -11)]), Color("9fbd61"))
		draw_circle(Vector2(-4, -4), 1.7, Color("f7d46b"))
		draw_circle(Vector2(4, -4), 1.7, Color("f7d46b"))
		draw_line(Vector2(-4, 7), Vector2(4, 7), Color("3e3d32"), 2.0)
	if warning_active:
		draw_arc(Vector2.ZERO, radius + 5.0, 0.0, TAU, 24, Color("ffd76e"), 2.0)
	var width := 2.0 * radius * clampf(hp / max_hp, 0.0, 1.0)
	draw_rect(Rect2(Vector2(-radius, -radius - 7.0), Vector2(width, 3.0)), Color("ef8354"))
