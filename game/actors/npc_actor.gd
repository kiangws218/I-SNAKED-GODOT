class_name NpcActor
extends Area2D

signal interaction_requested(npc: NpcActor, player: SnakePlayer)
signal health_changed(current: float, maximum: float)
signal defeated(npc: NpcActor)

const TILE_SIZE := 24.0
const ENTER_RADIUS := 0.85 * TILE_SIZE
const RESET_RADIUS := 1.25 * TILE_SIZE

@export var npc_id: StringName = &"keti"
@export var max_hp := 14.0
@export var damageable := true
@export var initially_active := true

var hp := 14.0
var player: SnakePlayer
var interaction_count := 0
var interaction_open := false
var _contact_armed := true
var _saved_direction := Vector2.RIGHT


func _ready() -> void:
	hp = max_hp
	body_entered.connect(_on_body_entered)
	add_to_group(&"npc")
	add_to_group(&"prison_target")
	set_actor_active(initially_active)
	queue_redraw()


func setup(target: SnakePlayer) -> void:
	player = target

func set_actor_active(active: bool) -> void:
	visible = active
	set_physics_process(active)
	set_deferred("monitoring", active)
	var collision := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision:
		collision.set_deferred("disabled", not active)


func _physics_process(_delta: float) -> void:
	if not is_instance_valid(player):
		return
	var distance := global_position.distance_to(player.global_position)
	if distance < ENTER_RADIUS and _contact_armed:
		_contact_armed = false
		_begin_interaction()
	elif distance > RESET_RADIUS:
		_contact_armed = true


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
	if not damageable or amount <= 0.0 or hp <= 0.0:
		return 0.0
	var applied := minf(hp, amount)
	hp -= applied
	health_changed.emit(hp, max_hp)
	queue_redraw()
	if hp <= 0.0:
		defeated.emit(self)
		queue_free()
	return applied


func heal(amount: float) -> float:
	if amount <= 0.0 or hp <= 0.0:
		return 0.0
	var before := hp
	hp = minf(max_hp, hp + amount)
	health_changed.emit(hp, max_hp)
	queue_redraw()
	return hp - before


func is_prison_target() -> bool:
	return hp > 0.0


func _on_body_entered(body: Node2D) -> void:
	if body is BeanProjectile:
		body.hit_target(self)


func _draw() -> void:
	draw_circle(Vector2.ZERO, 10.0, Color("f4f1de"))
	draw_circle(Vector2(0, -7), 6.0, Color("f2cc8f"))
	draw_line(Vector2(0, 3), Vector2(0, 13), Color("81b29a"), 5.0)
	if interaction_open:
		draw_arc(Vector2.ZERO, 16.0, 0.0, TAU, 20, Color("69d2e7"), 2.0)
