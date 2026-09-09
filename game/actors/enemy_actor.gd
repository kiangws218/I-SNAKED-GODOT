class_name EnemyActor
extends CharacterBody2D

signal health_changed(current: float, maximum: float)
signal defeated(enemy: EnemyActor, bean_drops: int)
signal shot_fired(projectile: EnemyProjectile)

const TILE_SIZE := 24.0
const PROJECTILE_SCENE := preload("res://game/projectiles/enemy_projectile.tscn")
const TYPES := {
	&"slime": {"hp": 14.0, "speed": 2.0, "radius": 0.55, "drops": 2},
	&"mushroom": {"hp": 16.0, "speed": 0.0, "radius": 0.62, "drops": 2, "cadence": 4.0, "telegraph": 0.7, "bullet_speed": 2.0},
}

@export var enemy_kind: StringName = &"slime"

var player: SnakePlayer
var hp := 1.0
var max_hp := 1.0
var move_speed := 0.0
var radius := 0.5 * TILE_SIZE
var bean_drops := 0
var shot_timer := 0.0
var warning_active := false
var is_dead := false
var _recoil_left := 0.0
var _contact_hitstop_left := 0.0


func _ready() -> void:
	var definition: Dictionary = TYPES.get(enemy_kind, TYPES[&"slime"])
	max_hp = float(definition.hp)
	hp = max_hp
	move_speed = float(definition.speed) * TILE_SIZE
	radius = float(definition.radius) * TILE_SIZE
	bean_drops = int(definition.drops)
	shot_timer = float(definition.get("cadence", 0.0))
	$Mushroom.visible = enemy_kind == &"mushroom"
	$Slime.visible = enemy_kind == &"slime"
	if $Mushroom.visible:
		$Mushroom.play(&"idle")
	if $Slime.visible:
		$Slime.play(&"idle")
	$Hurtbox.body_entered.connect(_on_hurtbox_body_entered)
	add_to_group(&"enemy")
	add_to_group(&"prison_target")
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
	var definition: Dictionary = TYPES[&"mushroom"]
	shot_timer -= delta
	var next_warning := shot_timer <= float(definition.telegraph)
	if next_warning != warning_active:
		warning_active = next_warning
		queue_redraw()
	if shot_timer > 0.0:
		return
	shot_timer += float(definition.cadence)
	warning_active = false
	var projectile: EnemyProjectile = PROJECTILE_SCENE.instantiate()
	get_parent().add_child(projectile)
	projectile.launch(global_position, global_position.direction_to(player.global_position), float(definition.bullet_speed), player, self)
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
		defeated.emit(self, bean_drops)
		queue_free()
	return applied


func is_prison_target() -> bool:
	return not is_dead


func _on_hurtbox_body_entered(body: Node2D) -> void:
	if body is BeanProjectile:
		body.hit_target(self)


func _draw() -> void:
	if warning_active:
		draw_arc(Vector2.ZERO, radius + 5.0, 0.0, TAU, 24, Color("ffd76e"), 2.0)
	var width := 2.0 * radius * clampf(hp / max_hp, 0.0, 1.0)
	draw_rect(Rect2(Vector2(-radius, -radius - 7.0), Vector2(width, 3.0)), Color("ef8354"))
