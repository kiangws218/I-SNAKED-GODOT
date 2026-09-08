class_name BeanProjectile
extends CharacterBody2D

signal collected(payload: Dictionary)
signal released_actor(payload: Dictionary, at_position: Vector2)
signal actor_interacted(payload: Dictionary)

const TILE_SIZE := 24.0
const INITIAL_SPEED := 10.0 * TILE_SIZE
const INITIAL_DRAG := 1.5 * TILE_SIZE
const BOUNCED_DRAG := 7.0 * TILE_SIZE
const LAND_SPEED := 0.35 * TILE_SIZE
const BOUNCE_RETAIN_MIN := 0.70
const BOUNCE_RETAIN_MAX := 0.86
const BOUNCE_ANGLE_RANGE := 0.22
const LIFETIME := 6.0
const PICKUP_RADIUS := 0.6 * TILE_SIZE

var payload := {"id": &"bean", "damage": 4}
var flight_direction := Vector2.RIGHT
var speed := INITIAL_SPEED
var age := 0.0
var has_bounced := false
var is_landed := false
var source: SnakePlayer
var actor_released := false
var actor_interaction_emitted := false


func launch(data: Dictionary, origin: Vector2, direction: Vector2, owner_player: SnakePlayer) -> void:
	payload = data.duplicate(true)
	global_position = origin
	flight_direction = direction.normalized()
	source = owner_player
	speed = INITIAL_SPEED
	if data.get("id", &"bean") != &"bean":
		speed *= 0.75
	age = 0.0
	has_bounced = false
	is_landed = false
	queue_redraw()


func _physics_process(delta: float) -> void:
	age += delta
	if age >= LIFETIME and not is_landed:
		land()
	if not is_landed:
		var collision := move_and_collide(flight_direction * speed * delta)
		if collision:
			_on_collision(collision.get_normal())
		elif age >= 0.22 and is_instance_valid(source):
			var body_normal := _source_body_collision_normal()
			if not body_normal.is_zero_approx():
				_on_collision(body_normal)
		var payload_weight := maxf(1.0, float(payload.get("weight", 1)))
		speed = maxf(0.0, speed - (BOUNCED_DRAG if has_bounced else INITIAL_DRAG) * payload_weight * delta)
		if speed < LAND_SPEED:
			land()
		elif payload.id == &"bean" and age >= 0.22 and is_instance_valid(source):
			if global_position.distance_to(source.global_position) < PICKUP_RADIUS:
				if source.try_collect_payload(payload):
					collected.emit(payload.duplicate(true))
					queue_free()
	if is_landed and is_instance_valid(source) and age >= 0.25:
		if global_position.distance_to(source.global_position) <= PICKUP_RADIUS:
			if not bool(payload.get("actor", false)) and source.try_collect_payload(payload):
				collected.emit(payload.duplicate(true))
				queue_free()


func _on_collision(normal: Vector2) -> void:
	if payload.id == &"healing_potion":
		queue_free()
		return
	flight_direction = flight_direction.bounce(normal).rotated(randf_range(-BOUNCE_ANGLE_RANGE, BOUNCE_ANGLE_RANGE)).normalized()
	speed *= randf_range(BOUNCE_RETAIN_MIN, BOUNCE_RETAIN_MAX)
	has_bounced = true


func land() -> void:
	if is_landed:
		return
	is_landed = true
	speed = 0.0
	collision_layer = 0
	collision_mask = 0
	if bool(payload.get("actor", false)):
		actor_released = true
		var actor_payload := payload.duplicate(true)
		var metadata: Dictionary = actor_payload.get("metadata", {}).duplicate(true)
		metadata["unconscious"] = true
		metadata["interactable"] = true
		actor_payload["metadata"] = metadata
		payload = actor_payload
		released_actor.emit(payload.duplicate(true), global_position)
	queue_redraw()


func _source_body_collision_normal() -> Vector2:
	for index in range(2, source.body_chain.segments.size()):
		var delta := global_position - source.body_chain.segments[index]
		if delta.length() < 16.0:
			return delta.normalized() if not delta.is_zero_approx() else -flight_direction
	return Vector2.ZERO


func interact() -> bool:
	if not is_landed or not actor_released or actor_interaction_emitted:
		return false
	actor_interaction_emitted = true
	actor_interacted.emit(payload.duplicate(true))
	return true


func _draw() -> void:
	var item_id: StringName = payload.get("id", &"bean")
	var color := Color("f3d55b")
	if item_id == &"iron_sword":
		color = Color("d9e2e8")
	elif item_id == &"healing_potion":
		color = Color("f06c9b")
	elif bool(payload.get("actor", false)):
		color = Color("69d2e7")
	draw_circle(Vector2.ZERO, 8.0 if is_landed else 7.5, color)
	if has_bounced and not is_landed:
		draw_arc(Vector2.ZERO, 9.5, 0.0, TAU, 12, Color.WHITE, 1.0)
