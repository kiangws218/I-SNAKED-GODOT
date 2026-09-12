class_name BeanProjectile
extends CharacterBody2D

signal collected(payload: Dictionary)
signal released_actor(payload: Dictionary, at_position: Vector2)
signal actor_interacted(payload: Dictionary)

const TILE_SIZE := 24.0
const INITIAL_SPEED := 13.0 * TILE_SIZE
const INITIAL_DRAG := 0.8 * TILE_SIZE
const BOUNCED_DRAG := 4.5 * TILE_SIZE
## Non-bean payloads retain their existing 0.75 baseline, then lose this
## fraction of launch speed for each unit of weight above one.
const HEAVY_INITIAL_SPEED_PENALTY := 0.08
const HEAVY_INITIAL_SPEED_MIN_SCALE := 0.55
## Actors already use their payload weight as drag; this is their additional
## resistance, kept separate so ordinary beans keep the old rebound feel.
const ACTOR_EXTRA_DRAG := 1.5 * TILE_SIZE
const LAND_SPEED := 0.35 * TILE_SIZE
const BOUNCE_RETAIN_MIN := 0.58
const BOUNCE_RETAIN_MAX := 0.94
const BOUNCE_ANGLE_FAR := 0.30
const BOUNCE_ANGLE_CLOSE := 1.20
const BOUNCE_MIN_CLOSE_ANGLE := 0.55
const CLOSE_BOUNCE_DISTANCE := 6.0 * TILE_SIZE
const LIFETIME := 6.0
const PICKUP_RADIUS := 0.6 * TILE_SIZE
const POTION_ARM_DELAY := 0.22
const POTION_BODY_HIT_RADIUS := 16.0
const BEAN_TEXTURE := preload("res://assets/items/bean.svg")
const GREEN_POTION_TEXTURE := preload("res://assets/items/green_potion.png")
const PLACEHOLDER_TEXTURES := {
	&"iron_sword": preload("res://assets/placeholders/kenney/tiny_dungeon/items/iron_sword.png"),
	&"keti": preload("res://assets/characters/keti/idle.png"),
	&"keti_corpse": preload("res://assets/characters/keti/idle.png"),
	&"ajie": preload("res://assets/characters/ajie/idle.png"),
	&"lisi": preload("res://assets/characters/lisi/idle.png"),
	&"ajian": preload("res://assets/characters/ajian/idle.png"),
	&"buck": preload("res://assets/characters/buck/idle.png"),
	&"bake": preload("res://assets/characters/buck/idle.png"),
	&"miro": preload("res://assets/characters/miro/idle.png"),
	&"miluo": preload("res://assets/characters/miro/idle.png"),
}

var payload := {"id": &"bean", "damage": 4}
var flight_direction := Vector2.RIGHT
var speed := INITIAL_SPEED
var age := 0.0
var has_bounced := false
var is_landed := false
var source: SnakePlayer
var actor_released := false
var actor_interaction_emitted := false
var flight_distance := 0.0
var _last_target_id := 0
var _target_hit_cooldown := 0.0


func launch(data: Dictionary, origin: Vector2, direction: Vector2, owner_player: SnakePlayer, cinematic := false) -> void:
	payload = data.duplicate(true)
	global_position = origin
	flight_direction = direction.normalized()
	source = owner_player
	process_mode = Node.PROCESS_MODE_ALWAYS if cinematic else Node.PROCESS_MODE_INHERIT
	speed = INITIAL_SPEED
	if data.get("id", &"bean") != &"bean":
		speed *= 0.75
		var payload_weight := maxf(0.0, float(data.get("weight", 1)))
		var heavy_weight := maxf(0.0, payload_weight - 1.0)
		speed *= maxf(
			HEAVY_INITIAL_SPEED_MIN_SCALE,
			1.0 - heavy_weight * HEAVY_INITIAL_SPEED_PENALTY,
		)
	age = 0.0
	has_bounced = false
	is_landed = false
	flight_distance = 0.0
	queue_redraw()


func _physics_process(delta: float) -> void:
	age += delta
	_target_hit_cooldown = maxf(0.0, _target_hit_cooldown - delta)
	if age >= LIFETIME and not is_landed:
		land()
	if not is_landed:
		var previous_position := global_position
		var collision := move_and_collide(flight_direction * speed * delta)
		flight_distance += previous_position.distance_to(global_position)
		if (
			payload.id == &"healing_potion"
			and age >= POTION_ARM_DELAY
			and _source_body_sweep_hit(previous_position, global_position)
		):
			source.heal(int(payload.get("healing", 1)))
			queue_free()
			return
		if collision:
			var collider := collision.get_collider()
			if payload.id == &"bean" and is_instance_valid(collider) and collider.has_method("hit_by_bean"):
				collider.hit_by_bean(self)
			_on_collision(collision.get_normal())
		elif age >= POTION_ARM_DELAY and is_instance_valid(source):
			var body_normal := _source_body_collision_normal()
			if not body_normal.is_zero_approx():
				_on_collision(body_normal)
		var payload_weight := maxf(1.0, float(payload.get("weight", 1)))
		var drag := (BOUNCED_DRAG if has_bounced else INITIAL_DRAG) * payload_weight
		if _is_actor_payload():
			drag += ACTOR_EXTRA_DRAG
		speed = maxf(0.0, speed - drag * delta)
		if speed < LAND_SPEED:
			land()
		elif payload.id == &"bean" and age >= POTION_ARM_DELAY and is_instance_valid(source):
			if global_position.distance_to(source.global_position) < PICKUP_RADIUS:
				if source.try_collect_payload(payload):
					collected.emit(payload.duplicate(true))
					queue_free()
		elif payload.id == &"healing_potion" and age >= POTION_ARM_DELAY and is_instance_valid(source):
			if global_position.distance_to(source.global_position) < 0.7 * TILE_SIZE:
				source.heal(int(payload.get("healing", 1)))
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
	var angle_range := BOUNCE_ANGLE_FAR
	var minimum_angle := 0.0
	if not has_bounced:
		var closeness := 1.0 - clampf(flight_distance / CLOSE_BOUNCE_DISTANCE, 0.0, 1.0)
		angle_range = lerpf(BOUNCE_ANGLE_FAR, BOUNCE_ANGLE_CLOSE, closeness)
		minimum_angle = BOUNCE_MIN_CLOSE_ANGLE * closeness
	var angle := randf_range(minimum_angle, angle_range)
	if randf() < 0.5:
		angle = -angle
	flight_direction = flight_direction.bounce(normal).rotated(angle).normalized()
	speed *= randf_range(BOUNCE_RETAIN_MIN, BOUNCE_RETAIN_MAX)
	has_bounced = true


func land() -> void:
	if is_landed:
		return
	is_landed = true
	speed = 0.0
	collision_layer = 0
	collision_mask = 0
	if _is_actor_payload():
		actor_released = true
		var actor_payload := payload.duplicate(true)
		var metadata: Dictionary = actor_payload.get("metadata", {}).duplicate(true)
		metadata["unconscious"] = true
		metadata["interactable"] = true
		actor_payload["metadata"] = metadata
		actor_payload["actor"] = true
		payload = actor_payload
		released_actor.emit(payload.duplicate(true), global_position)
	process_mode = Node.PROCESS_MODE_INHERIT
	queue_redraw()


func _source_body_collision_normal() -> Vector2:
	for index in range(2, source.body_chain.segments.size()):
		var delta := global_position - source.body_chain.segments[index]
		if delta.length() < 16.0:
			return delta.normalized() if not delta.is_zero_approx() else -flight_direction
	return Vector2.ZERO


func _source_body_sweep_hit(sweep_start: Vector2, sweep_end: Vector2) -> bool:
	if not is_instance_valid(source) or source.body_chain == null:
		return false
	for index in range(2, source.body_chain.segments.size()):
		var body_point: Vector2 = source.body_chain.segments[index]
		var closest := Geometry2D.get_closest_point_to_segment(body_point, sweep_start, sweep_end)
		if body_point.distance_to(closest) <= POTION_BODY_HIT_RADIUS:
			return true
	return false


func hit_target(target: Node2D) -> bool:
	if is_landed or not is_instance_valid(target):
		return false
	var target_id := target.get_instance_id()
	if target_id == _last_target_id and _target_hit_cooldown > 0.0:
		return false
	_last_target_id = target_id
	_target_hit_cooldown = 0.2
	if payload.id == &"healing_potion":
		if target.has_method("heal"):
			target.heal(float(payload.get("healing", 1)))
		queue_free()
		return true
	var damage := float(payload.get("damage", 4))
	if target.has_method("take_projectile_hit"):
		target.take_projectile_hit(damage, self)
	elif target.has_method("take_damage"):
		target.take_damage(damage, &"projectile")
	if _is_actor_payload():
		var metadata: Dictionary = payload.get("metadata", {}).duplicate(true)
		metadata["hp"] = maxf(0.0, float(metadata.get("hp", 1.0)) - damage)
		payload["metadata"] = metadata
	var normal := target.global_position.direction_to(global_position)
	_on_collision(normal if not normal.is_zero_approx() else -flight_direction)
	return true


func interact() -> bool:
	if not is_landed or not actor_released or actor_interaction_emitted:
		return false
	actor_interaction_emitted = true
	actor_interacted.emit(payload.duplicate(true))
	return true


func _is_actor_payload() -> bool:
	if bool(payload.get("actor", false)):
		return true
	var metadata: Dictionary = payload.get("metadata", {})
	return not String(metadata.get("actor_id", "")).is_empty()


func _draw() -> void:
	var item_id: StringName = payload.get("id", &"bean")
	if bool(payload.get("actor", false)) or not String(payload.get("metadata", {}).get("actor_id", "")).is_empty():
		var actor_id := StringName(payload.get("metadata", {}).get("actor_id", item_id))
		var actor_texture := PLACEHOLDER_TEXTURES.get(actor_id) as Texture2D
		if actor_texture:
			var visual_rect := Rect2(-16, -20, 32, 40)
			draw_texture_rect(actor_texture, visual_rect, false)
		else:
			_draw_actor_payload(actor_id)
		if has_bounced and not is_landed:
			draw_arc(Vector2.ZERO, 13.0, 0.0, TAU, 12, Color.WHITE, 1.0)
		return
	if item_id == &"bean":
		draw_texture(BEAN_TEXTURE, Vector2(-8, -8))
		if has_bounced and not is_landed:
			draw_arc(Vector2.ZERO, 9.5, 0.0, TAU, 12, Color.WHITE, 1.0)
		return
	if item_id == &"healing_potion":
		draw_texture_rect(GREEN_POTION_TEXTURE, Rect2(-12, -12, 24, 24), false)
		return
	var texture := PLACEHOLDER_TEXTURES.get(item_id) as Texture2D
	if texture:
		draw_texture_rect(texture, Rect2(-12, -12, 24, 24), false)
		if has_bounced and not is_landed:
			draw_arc(Vector2.ZERO, 13.0, 0.0, TAU, 12, Color.WHITE, 1.0)
		return
	var color := Color("f3d55b")
	if item_id == &"iron_sword":
		color = Color("d9e2e8")
	draw_circle(Vector2.ZERO, 8.0 if is_landed else 7.5, color)
	if has_bounced and not is_landed:
		draw_arc(Vector2.ZERO, 9.5, 0.0, TAU, 12, Color.WHITE, 1.0)


func _draw_actor_payload(actor_id: StringName) -> void:
	var body_color := Color("f4f1de")
	var skin_color := Color("f2cc8f")
	var accent_color := Color("81b29a")
	if actor_id == &"keti":
		body_color = Color("f6d6e9")
		skin_color = Color("ffd8c2")
		accent_color = Color("b96b9c")
	elif actor_id in [&"ajie", &"lisi"]:
		body_color = Color("d8e7f2") if actor_id == &"lisi" else Color("d8c3a5")
		accent_color = Color("5b6ee1") if actor_id == &"lisi" else Color("a84a4a")
	draw_circle(Vector2.ZERO, 9.0, body_color)
	draw_circle(Vector2(0, -7), 5.5, skin_color)
	draw_line(Vector2(-5, 2), Vector2(5, 2), accent_color, 3.0)
	draw_circle(Vector2(-2, -8), 1.0, Color("30323d"))
	draw_circle(Vector2(2, -8), 1.0, Color("30323d"))
	if not is_landed:
		draw_arc(Vector2.ZERO, 12.0, 0.0, TAU, 16, Color("fff1b6"), 1.0)
