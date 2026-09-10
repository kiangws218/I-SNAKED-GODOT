class_name NpcActor
extends Area2D

signal interaction_requested(npc: NpcActor, player: SnakePlayer)
signal health_changed(current: float, maximum: float)
signal defeated(npc: NpcActor)
signal downed(npc: NpcActor)

const TILE_SIZE := 24.0
const ENTER_RADIUS := 0.85 * TILE_SIZE
const RESET_RADIUS := 1.25 * TILE_SIZE
const PLACEHOLDER_TEXTURES := {
	&"keti": preload("res://assets/placeholders/kenney/tiny_dungeon/characters/keti.png"),
	&"ajie": preload("res://assets/placeholders/kenney/tiny_dungeon/characters/ajie.png"),
	&"lisi": preload("res://assets/placeholders/kenney/tiny_dungeon/characters/lisi.png"),
	&"ajian": preload("res://assets/placeholders/kenney/tiny_dungeon/characters/ajian.png"),
	&"buck": preload("res://assets/placeholders/kenney/tiny_dungeon/characters/buck.png"),
	&"miro": preload("res://assets/placeholders/kenney/tiny_dungeon/characters/miro.png"),
}

@export var npc_id: StringName = &"keti"
@export var max_hp := 14.0
@export var damageable := true
@export var initially_active := true
@export_category("Persistence")
@export var persistent_state_id: StringName
@export_enum("dead", "downed") var defeat_mode: String = "dead"
@export_category("Combat")
@export var combat_speed_tiles := 2.2
@export var contact_damage := 1

var hp := 14.0
var player: SnakePlayer
var interaction_count := 0
var interaction_open := false
var is_dead := false
var is_downed := false
var hostile := false
var _carrier: Node2D
var _world_parent: Node
var _riding_offset := Vector2.ZERO
var _contact_armed := true
var _saved_direction := Vector2.RIGHT
var _attack_cooldown_left := 0.0
var _attack_flash_left := 0.0
@onready var placeholder_sprite: Sprite2D = $PlaceholderSprite


func _ready() -> void:
	hp = max_hp
	if persistent_state_id.is_empty():
		persistent_state_id = npc_id
	placeholder_sprite.texture = PLACEHOLDER_TEXTURES.get(npc_id) as Texture2D
	body_entered.connect(_on_body_entered)
	add_to_group(&"npc")
	add_to_group(&"prison_target")
	set_actor_active(initially_active)
	set_process(false)
	queue_redraw()


func setup(target: SnakePlayer) -> void:
	player = target

func restore_from_payload(payload: Dictionary) -> void:
	var metadata: Dictionary = payload.get("metadata", {})
	if metadata.has("hp"):
		hp = clampf(float(metadata.hp), 0.0, max_hp)
	is_downed = hp <= 0.0 and defeat_mode == &"downed"
	is_dead = hp <= 0.0 and not is_downed
	interaction_open = false
	_contact_armed = true
	queue_redraw()

func set_actor_active(active: bool) -> void:
	visible = active
	set_physics_process(active and not is_dead and not is_instance_valid(_carrier))
	set_deferred("monitoring", active)
	var collision := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision:
		collision.set_deferred("disabled", not active)


func _physics_process(delta: float) -> void:
	if not is_instance_valid(player):
		return
	_attack_cooldown_left = maxf(0.0, _attack_cooldown_left - delta)
	_attack_flash_left = maxf(0.0, _attack_flash_left - delta)
	if _attack_flash_left > 0.0:
		queue_redraw()
	var distance := global_position.distance_to(player.global_position)
	if hostile and not is_downed and not is_dead:
		if distance > ENTER_RADIUS:
			global_position += global_position.direction_to(player.global_position) * combat_speed_tiles * TILE_SIZE * minf(delta, 0.05)
		elif contact_damage > 0 and _attack_cooldown_left <= 0.0:
			if player.take_damage(contact_damage, &"enemy_contact"):
				_attack_flash_left = 0.16
				_attack_cooldown_left = 0.55
				queue_redraw()
		return
	if distance < ENTER_RADIUS and _contact_armed:
		_contact_armed = false
		_begin_interaction()
	elif distance > RESET_RADIUS:
		_contact_armed = true


func _process(_delta: float) -> void:
	if not is_instance_valid(_carrier):
		set_process(false)
		return
	var snake := _carrier as SnakePlayer
	if snake and snake.body_chain.segments.size() > 1:
		global_position = snake.body_chain.segments[1] + _riding_offset


func _begin_interaction() -> void:
	if interaction_open:
		return
	interaction_open = true
	interaction_count += 1
	_saved_direction = player.direction
	player.direction_queue.clear()
	interaction_requested.emit(self, player)


func finish_interaction() -> void:
	if not interaction_open:
		return
	interaction_open = false
	if is_instance_valid(player):
		player.restore_direction(_saved_direction)


func take_damage(amount: float, _source := &"projectile") -> float:
	if is_dead or is_downed or not damageable or amount <= 0.0 or hp <= 0.0:
		return 0.0
	var applied := minf(hp, amount)
	hp -= applied
	health_changed.emit(hp, max_hp)
	queue_redraw()
	if hp <= 0.0:
		hostile = false
		if defeat_mode == &"downed":
			is_downed = true
			downed.emit(self)
			queue_redraw()
		else:
			is_dead = true
			set_actor_active(false)
			defeated.emit(self)
	return applied


func heal(amount: float) -> float:
	if amount <= 0.0 or hp <= 0.0:
		return 0.0
	var before := hp
	hp = minf(max_hp, hp + amount)
	health_changed.emit(hp, max_hp)
	queue_redraw()
	return hp - before


func wake(restored_hp := 1.0) -> void:
	is_dead = false
	is_downed = false
	hostile = false
	hp = clampf(maxf(restored_hp, 1.0), 1.0, max_hp)
	damageable = true
	set_actor_active(true)
	health_changed.emit(hp, max_hp)
	queue_redraw()


func start_combat(target: SnakePlayer) -> bool:
	if is_dead or is_downed or not is_instance_valid(target):
		return false
	player = target
	hostile = true
	damageable = true
	_attack_cooldown_left = 0.0
	interaction_open = false
	set_actor_active(true)
	queue_redraw()
	return true


func stop_combat() -> void:
	hostile = false
	queue_redraw()


func receive_actor_impact(source_position: Vector2, distance := 28.0) -> void:
	var away := source_position.direction_to(global_position)
	if away.is_zero_approx():
		away = Vector2.RIGHT
	var target := global_position + away.normalized() * distance
	var tween := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(self, "global_position", target, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	queue_redraw()


func is_prison_target() -> bool:
	return not is_dead and not is_downed and hp > 0.0


func get_persistent_state() -> Dictionary:
	return {
		"npc_id": String(npc_id),
		"persistent_state_id": String(persistent_state_id),
		"max_hp": max_hp,
		"hp": hp,
		"damageable": damageable,
		"hostile": hostile,
		"defeat_mode": String(defeat_mode),
		"active": visible,
		"is_dead": is_dead,
		"is_downed": is_downed,
	}


func restore_persistent_state(state: Dictionary) -> bool:
	if state.has("npc_id") and StringName(state.npc_id) != npc_id:
		return false
	if state.has("persistent_state_id") and StringName(state.persistent_state_id) != persistent_state_id:
		return false
	if state.has("max_hp"):
		max_hp = maxf(0.0, float(state.max_hp))
	hp = clampf(float(state.get("hp", max_hp)), 0.0, max_hp)
	damageable = bool(state.get("damageable", damageable))
	hostile = bool(state.get("hostile", false))
	if state.has("defeat_mode"):
		defeat_mode = String(state.defeat_mode)
	is_downed = bool(state.get("is_downed", hp <= 0.0 and defeat_mode == &"downed"))
	is_dead = bool(state.get("is_dead", hp <= 0.0 and not is_downed))
	if is_downed:
		is_dead = false
	if hp <= 0.0 and not is_downed and not state.has("is_dead"):
		is_dead = true
	interaction_open = false
	_contact_armed = true
	set_actor_active(bool(state.get("active", not is_dead)) and not is_dead)
	health_changed.emit(hp, max_hp)
	queue_redraw()
	return true


func attach_to_carrier(carrier: Node2D, offset: Vector2) -> bool:
	if not is_instance_valid(carrier) or carrier == self:
		return false
	if is_instance_valid(_carrier):
		detach_from_carrier(global_position)
	_world_parent = get_parent()
	_carrier = carrier
	_riding_offset = offset
	reparent(carrier, false)
	position = offset
	visible = true
	set_process(true)
	set_physics_process(false)
	set_deferred("monitoring", false)
	var collision := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision:
		collision.set_deferred("disabled", true)
	return true


func detach_from_carrier(world_position: Vector2) -> bool:
	if not is_instance_valid(_carrier):
		return false
	var parent := _world_parent if is_instance_valid(_world_parent) else get_tree().current_scene
	if is_instance_valid(parent):
		reparent(parent, false)
	_carrier = null
	_world_parent = null
	_riding_offset = Vector2.ZERO
	set_process(false)
	global_position = world_position
	set_actor_active(visible and not is_dead)
	return true


func is_riding() -> bool:
	return is_instance_valid(_carrier)


func _on_body_entered(body: Node2D) -> void:
	if body is BeanProjectile:
		body.hit_target(self)


func _draw() -> void:
	if placeholder_sprite.texture == null:
		draw_circle(Vector2.ZERO, 10.0, Color("f4f1de"))
		draw_circle(Vector2(0, -7), 6.0, Color("f2cc8f"))
		draw_line(Vector2(0, 3), Vector2(0, 13), Color("81b29a"), 5.0)
	if interaction_open:
		draw_arc(Vector2.ZERO, 16.0, 0.0, TAU, 20, Color("69d2e7"), 2.0)
	if hostile and not is_dead and not is_downed and is_instance_valid(player):
		var attack_direction := global_position.direction_to(player.global_position)
		if attack_direction.is_zero_approx():
			attack_direction = Vector2.RIGHT
		draw_arc(Vector2.ZERO, 17.0, attack_direction.angle() - 0.48, attack_direction.angle() + 0.48, 10, Color("ef8354"), 2.0)
		if _attack_flash_left > 0.0:
			draw_line(attack_direction * 7.0, attack_direction * 27.0, Color("fff1b6"), 4.0)
	if damageable or hostile or hp < max_hp:
		var bar_width := 28.0
		var ratio := clampf(hp / maxf(max_hp, 0.001), 0.0, 1.0)
		draw_rect(Rect2(Vector2(-bar_width * 0.5, -28.0), Vector2(bar_width, 4.0)), Color("30323d"))
		draw_rect(Rect2(Vector2(-bar_width * 0.5, -28.0), Vector2(bar_width * ratio, 4.0)), Color("ef5350"))
