class_name BossSeed
extends CharacterBody2D

var player: SnakePlayer
var boss: Node2D
var direction := Vector2.RIGHT
var speed := 50.4
var lifetime := 12.0
var reflected_damage := 6.0
var reflected_by_body := false
var _bounce_left := 0.0

func launch(origin: Vector2, heading: Vector2, pixels_per_second: float, target: SnakePlayer, source: Node2D, life: float, damage: float) -> void:
	global_position = origin
	direction = heading.normalized()
	speed = pixels_per_second
	player = target
	boss = source
	lifetime = life
	reflected_damage = damage

func _physics_process(delta: float) -> void:
	if is_queued_for_deletion(): return
	lifetime -= delta
	_bounce_left = maxf(0.0, _bounce_left - delta)
	if lifetime <= 0.0 or not is_instance_valid(player) or player.is_dead:
		queue_free()
		return
	var previous := global_position
	var hit := move_and_collide(direction * speed * delta)
	if hit:
		direction = direction.bounce(hit.get_normal()).normalized()
		global_position += direction * 1.0
	if _bounce_left <= 0.0:
		for index in range(2, player.body_chain.segments.size()):
			var point: Vector2 = player.body_chain.segments[index]
			var closest := Geometry2D.get_closest_point_to_segment(point, previous, global_position)
			if point.distance_to(closest) >= 0.4 * 24.0: continue
			var normal := (closest - point).normalized()
			if normal.is_zero_approx(): normal = -direction
			direction = direction.bounce(normal).normalized()
			reflected_by_body = true
			_bounce_left = 0.12
			global_position += direction * 2.0
			modulate = Color("80dfff")
			break
	if reflected_by_body and is_instance_valid(boss) and not boss.is_dead:
		var closest := Geometry2D.get_closest_point_to_segment(boss.global_position, previous, global_position)
		if closest.distance_to(boss.global_position) < boss.radius + 0.3 * 24.0:
			boss.take_damage(reflected_damage, &"reflected_seed")
			queue_free()
			return
	var head_closest := Geometry2D.get_closest_point_to_segment(player.global_position, previous, global_position)
	if head_closest.distance_to(player.global_position) < 0.58 * 24.0:
		player.take_damage(1, &"boss_seed")
		queue_free()
