class_name EnemyProjectile
extends CharacterBody2D

const TILE_SIZE := 24.0
const LIFETIME := 10.0

var flight_direction := Vector2.RIGHT
var speed := 2.0 * TILE_SIZE
var age := 0.0
var player: SnakePlayer
var source: EnemyActor
var reflected_by_body := false
var _body_bounce_cooldown := 0.0


func launch(origin: Vector2, direction: Vector2, speed_cells: float, target: SnakePlayer, owner_enemy: EnemyActor) -> void:
	global_position = origin
	flight_direction = direction.normalized()
	speed = speed_cells * TILE_SIZE
	player = target
	source = owner_enemy
	age = 0.0
	reflected_by_body = false


func _physics_process(delta: float) -> void:
	age += delta
	_body_bounce_cooldown = maxf(0.0, _body_bounce_cooldown - delta)
	if age >= LIFETIME or not is_instance_valid(player):
		queue_free()
		return
	var collision := move_and_collide(flight_direction * speed * delta)
	if collision:
		queue_free()
		return
	if _body_bounce_cooldown <= 0.0:
		var normal := _player_body_normal()
		if not normal.is_zero_approx():
			flight_direction = flight_direction.bounce(normal).normalized()
			reflected_by_body = true
			_body_bounce_cooldown = 0.12
			global_position += flight_direction * 2.0
	if global_position.distance_to(player.global_position) < 0.58 * TILE_SIZE:
		player.take_damage(1, &"enemy_projectile")
		queue_free()


func _player_body_normal() -> Vector2:
	for index in range(2, player.body_chain.segments.size()):
		var delta := global_position - player.body_chain.segments[index]
		if delta.length() < 0.4 * TILE_SIZE:
			return delta.normalized() if not delta.is_zero_approx() else -flight_direction
	return Vector2.ZERO


func _draw() -> void:
	draw_circle(Vector2.ZERO, 7.5, Color("b55088"))
	draw_line(-flight_direction * 8.5, flight_direction * 8.5, Color("ffd3e8"), 2.0)
