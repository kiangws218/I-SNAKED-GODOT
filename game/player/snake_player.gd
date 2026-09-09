class_name SnakePlayer
extends CharacterBody2D

signal died(reason: String)
signal danger_changed(active: bool, seconds_left: float)
signal resources_changed
signal health_changed(current: int, maximum: int)
signal damaged(reason: StringName)
signal actor_released(payload: Dictionary, at_position: Vector2)
signal actor_interacted(payload: Dictionary)

const TILE_SIZE := 24.0
const MAX_DIRECTION_QUEUE := 3
const MIN_LENGTH := 3
const SHOT_INTERVAL := 0.42
const SPIT_BRAKE_SECONDS := 0.12
const SPIT_SPEED_RESPONSE := 28.0
const CUT_COOLDOWN := 10.0
const NODE_EXEMPTION_RADIUS := 1.15 * TILE_SIZE
const HIT_FLASH_SECONDS := 0.12
const DANGER_FLASH_PERIOD := 0.16
const PROJECTILE_SCENE := preload("res://game/projectiles/bean_projectile.tscn")
const RING_NODE_SCENE := preload("res://game/nodes/ring_node.tscn")

@export var base_speed := 4.0 * TILE_SIZE
@export var boost_multiplier := 2.0
@export var rescue_seconds := 0.5
@export var self_collision_radius := 0.62 * TILE_SIZE
@export var rescue_probe_radius := 0.5 * TILE_SIZE
@export var neck_guard := 4
@export var play_sfx := true

@onready var body_chain: BodyChain = $BodyChain
@onready var spit_audio: AudioStreamPlayer = $SpitAudio
@onready var pickup_audio: AudioStreamPlayer = $PickupAudio
@onready var node_audio: AudioStreamPlayer = $NodeAudio
@onready var hurt_audio: AudioStreamPlayer = $HurtAudio

var direction := Vector2.RIGHT
var direction_queue: Array[Vector2] = []
var danger_kind := ""
var danger_seconds_left := 0.0
var is_dead := false
var current_speed := 0.0
var inventory := StomachInventory.new()
var node_unlocked := false
var node_charges := 0
var cut_cooldown_left := 0.0
var shot_cooldown_left := 0.0
var spit_brake_left := 0.0
var placed_nodes: Array[RingNode] = []
var _last_sampled_input := Vector2.ZERO
var _special_spit_latched := false
var _spit_smoothing_active := false
var max_hearts := 3
var hearts := 3
var invulnerability_left := 0.0
var hit_flash_left := 0.0
var feedback_color := Color.TRANSPARENT


func _ready() -> void:
	reset_at(global_position)


func _physics_process(delta: float) -> void:
	invulnerability_left = maxf(0.0, invulnerability_left - delta)
	hit_flash_left = maxf(0.0, hit_flash_left - delta)
	_update_visual_feedback()
	shot_cooldown_left = maxf(0.0, shot_cooldown_left - delta)
	cut_cooldown_left = maxf(0.0, cut_cooldown_left - delta)
	if is_dead:
		if Input.is_action_just_pressed("interact"):
			get_tree().reload_current_scene()
		return
	var bean_selected_before_spit := inventory.selected_id() == StomachInventory.BEAN_ID
	var did_spit := _handle_resource_input()
	if did_spit:
		_spit_smoothing_active = true
		if not bean_selected_before_spit:
			spit_brake_left = SPIT_BRAKE_SECONDS
	var bean_spray_held := (
		Input.is_action_pressed("spit")
		and inventory.selected_id() == StomachInventory.BEAN_ID
		and inventory.bean_ammo(body_chain.segment_count, MIN_LENGTH) > 0
	)
	if bean_spray_held:
		_spit_smoothing_active = true
	_update_nodes()
	var held_direction := _sample_direction_input()
	apply_next_direction()
	if inventory.is_overweight():
		current_speed = 0.0
		return
	var boosting := not held_direction.is_zero_approx() and held_direction.is_equal_approx(direction)
	if spit_brake_left > 0.0:
		spit_brake_left = maxf(0.0, spit_brake_left - delta)
	var target_speed := 0.0 if bean_spray_held or spit_brake_left > 0.0 else base_speed * (boost_multiplier if boosting else 1.0)
	if _spit_smoothing_active:
		current_speed = lerpf(current_speed, target_speed, 1.0 - exp(-SPIT_SPEED_RESPONSE * delta))
		if spit_brake_left <= 0.0 and absf(current_speed - target_speed) < 0.5:
			current_speed = target_speed
			_spit_smoothing_active = false
	else:
		current_speed = target_speed
	simulate_motion(delta, boosting, current_speed)


func _input(event: InputEvent) -> void:
	if is_dead or (event is InputEventKey and event.echo):
		return
	if event.is_action_pressed("inventory_previous"):
		inventory.cycle(-1)
		resources_changed.emit()
	elif event.is_action_pressed("inventory_next"):
		inventory.cycle(1)
		resources_changed.emit()
	elif event.is_action_pressed("cut_tail"):
		cut_tail()
	elif event.is_action_pressed("place_node"):
		place_node()
	elif event.is_action_pressed("interact"):
		_interact_with_nearest_actor()


func reset_at(spawn_position: Vector2, spawn_direction := Vector2.RIGHT) -> void:
	global_position = spawn_position
	direction = spawn_direction.normalized()
	direction_queue.clear()
	danger_kind = ""
	danger_seconds_left = 0.0
	is_dead = false
	current_speed = base_speed
	shot_cooldown_left = 0.0
	spit_brake_left = 0.0
	cut_cooldown_left = 0.0
	_special_spit_latched = false
	_spit_smoothing_active = false
	_last_sampled_input = Vector2.ZERO
	hearts = max_hearts
	invulnerability_left = 0.0
	hit_flash_left = 0.0
	feedback_color = Color.TRANSPARENT
	if is_node_ready():
		body_chain.reset(global_position, direction)
		body_chain.feedback_color = feedback_color
	queue_redraw()
	resources_changed.emit()
	health_changed.emit(hearts, max_hearts)


func set_length(value: int) -> void:
	body_chain.set_segment_count(maxi(MIN_LENGTH + inventory.occupied_length(), value), global_position)
	resources_changed.emit()


func add_special_item(item_id: StringName, metadata := {}) -> bool:
	if not inventory.add_item(item_id, metadata):
		return false
	body_chain.set_segment_count(body_chain.segment_count + int(StomachInventory.DEFINITIONS[item_id].length), global_position)
	resources_changed.emit()
	return true


func grant_node_charges(amount: int, unlock := true) -> int:
	if unlock:
		node_unlocked = true
	node_charges = clampi(node_charges + amount, 0, 3)
	resources_changed.emit()
	return node_charges


func try_spit() -> bool:
	if shot_cooldown_left > 0.0 or is_dead:
		return false
	var payload: Dictionary
	if inventory.selected_id() == StomachInventory.BEAN_ID:
		if inventory.bean_ammo(body_chain.segment_count, MIN_LENGTH) <= 0:
			return false
		payload = {"id": &"bean", "damage": 4, "length": 1, "weight": 0}
	else:
		payload = inventory.consume_selected()
		if payload.is_empty():
			return false
	var used_length := int(payload.get("length", 1))
	body_chain.set_segment_count(body_chain.segment_count - used_length, global_position)
	var projectile: BeanProjectile = PROJECTILE_SCENE.instantiate()
	get_parent().add_child(projectile)
	projectile.released_actor.connect(_on_actor_released)
	projectile.actor_interacted.connect(_on_actor_interacted)
	projectile.launch(payload, global_position + direction * TILE_SIZE * 0.9, direction, self)
	if play_sfx:
		spit_audio.play()
	shot_cooldown_left = SHOT_INTERVAL
	resources_changed.emit()
	return true


func cut_tail() -> int:
	if cut_cooldown_left > 0.0 or is_dead:
		return 0
	var keep := MIN_LENGTH + inventory.occupied_length()
	var removed := body_chain.segment_count - keep
	if removed <= 0:
		return 0
	var old_segments := body_chain.segments.duplicate()
	body_chain.set_segment_count(keep, global_position)
	var recovered := floori(removed * 0.6)
	for index in range(recovered):
		var projectile: BeanProjectile = PROJECTILE_SCENE.instantiate()
		get_parent().add_child(projectile)
		var tail_index := mini(old_segments.size() - 1, keep + index)
		projectile.launch({"id": &"bean", "damage": 4, "length": 1, "weight": 0}, old_segments[tail_index], direction.rotated(PI), self)
		projectile.age = 0.25
		projectile.land()
	cut_cooldown_left = CUT_COOLDOWN
	resources_changed.emit()
	return recovered


func place_node() -> bool:
	if not node_unlocked or node_charges <= 0 or is_dead:
		return false
	var cell := Vector2i(floori(global_position.x / TILE_SIZE), floori(global_position.y / TILE_SIZE))
	for ring in placed_nodes:
		if is_instance_valid(ring) and ring.cell == cell and not ring.finished:
			return false
	var ring: RingNode = RING_NODE_SCENE.instantiate()
	get_parent().add_child(ring)
	ring.setup(cell, global_position)
	ring.reclaimed.connect(_on_node_reclaimed)
	ring.destroyed.connect(_on_node_destroyed)
	placed_nodes.append(ring)
	node_charges -= 1
	if play_sfx:
		node_audio.play()
	resources_changed.emit()
	return true


func active_node_centers() -> Array[Vector2]:
	var centers: Array[Vector2] = []
	for ring in placed_nodes:
		if is_instance_valid(ring) and not ring.finished:
			centers.append(ring.global_position)
	return centers


func queue_direction(candidate: Vector2) -> bool:
	if candidate.is_zero_approx():
		return false
	var normalized := Vector2(signf(candidate.x), signf(candidate.y)).normalized()
	var reference: Vector2 = direction_queue.back() if not direction_queue.is_empty() else direction
	if normalized.is_equal_approx(reference) or normalized.dot(reference) < -0.999:
		return false
	direction_queue.append(normalized)
	if direction_queue.size() > MAX_DIRECTION_QUEUE:
		direction_queue.pop_front()
	return true


func apply_next_direction() -> bool:
	while not direction_queue.is_empty():
		var candidate: Vector2 = direction_queue.pop_front()
		if candidate.dot(direction) < -0.999:
			continue
		direction = candidate
		queue_redraw()
		return true
	return false


func simulate_motion(delta: float, boosting: bool, requested_speed := -1.0) -> void:
	current_speed = requested_speed if requested_speed >= 0.0 else base_speed * (boost_multiplier if boosting else 1.0)
	var motion := direction * current_speed * minf(delta, 0.05)
	if not danger_kind.is_empty():
		danger_seconds_left = maxf(danger_seconds_left - minf(delta, 0.05), 0.0)
		var probe_length := maxf(motion.length(), TILE_SIZE * 0.05)
		if _motion_is_safe(direction * probe_length, rescue_probe_radius):
			_clear_danger()
		else:
			if danger_seconds_left <= 0.000001:
				_die(danger_kind)
			else:
				danger_changed.emit(true, danger_seconds_left)
			return
	if not _motion_is_safe(motion, self_collision_radius):
		_enter_danger("wall" if test_move(global_transform, motion) else "self")
		return
	move_and_collide(motion)
	body_chain.record_head(global_position)


func _sample_direction_input() -> Vector2:
	var input_vector := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if input_vector.is_zero_approx():
		_last_sampled_input = Vector2.ZERO
		return Vector2.ZERO
	input_vector = input_vector.normalized()
	if not input_vector.is_equal_approx(_last_sampled_input):
		queue_direction(input_vector)
		_last_sampled_input = input_vector
	return input_vector


func _motion_is_safe(motion: Vector2, tail_radius: float) -> bool:
	if test_move(global_transform, motion):
		return false
	return not body_chain.collides_with_tail(
		global_position + motion,
		tail_radius,
		neck_guard,
		active_node_centers(),
		NODE_EXEMPTION_RADIUS,
	)


func _handle_resource_input() -> bool:
	if Input.is_action_pressed("spit"):
		if inventory.selected_id() == StomachInventory.BEAN_ID:
			return try_spit()
		elif not _special_spit_latched:
			_special_spit_latched = try_spit()
			return _special_spit_latched
	else:
		_special_spit_latched = false
	return false


func _update_nodes() -> void:
	for ring in placed_nodes.duplicate():
		if is_instance_valid(ring):
			ring.update_body_occupancy(body_chain.occupied_cells)


func try_collect_payload(payload: Dictionary) -> bool:
	var item_id: StringName = payload.get("id", &"bean")
	if item_id == &"bean":
		body_chain.set_segment_count(body_chain.segment_count + 1, global_position)
	else:
		var metadata: Dictionary = payload.get("metadata", {})
		if not inventory.add_item(item_id, metadata):
			return false
		body_chain.set_segment_count(body_chain.segment_count + int(payload.get("length", 1)), global_position)
	resources_changed.emit()
	if play_sfx:
		pickup_audio.play()
	return true


func take_damage(amount: int, reason: StringName = &"damage") -> bool:
	if amount <= 0 or invulnerability_left > 0.0 or is_dead:
		return false
	hearts = maxi(0, hearts - amount)
	invulnerability_left = 1.0
	hit_flash_left = HIT_FLASH_SECONDS
	_update_visual_feedback()
	if play_sfx:
		hurt_audio.play()
	health_changed.emit(hearts, max_hearts)
	damaged.emit(reason)
	queue_redraw()
	if hearts == 0:
		_die(String(reason))
	return true


func heal(amount: int) -> int:
	if amount <= 0 or is_dead:
		return 0
	var before := hearts
	hearts = mini(max_hearts, hearts + amount)
	if hearts != before:
		health_changed.emit(hearts, max_hearts)
		queue_redraw()
	return hearts - before


func restore_direction(saved_direction: Vector2) -> void:
	if saved_direction.is_zero_approx():
		return
	direction = saved_direction.normalized()
	direction_queue.clear()
	_last_sampled_input = Vector2.ZERO
	queue_redraw()


func _on_actor_released(payload: Dictionary, at_position: Vector2) -> void:
	actor_released.emit(payload, at_position)


func _on_actor_interacted(payload: Dictionary) -> void:
	actor_interacted.emit(payload)


func _interact_with_nearest_actor() -> bool:
	var nearest: BeanProjectile
	var nearest_distance := INF
	for child in get_parent().get_children():
		if child is BeanProjectile and child.actor_released and not child.actor_interaction_emitted:
			var distance := global_position.distance_to(child.global_position)
			if distance < BeanProjectile.PICKUP_RADIUS and distance < nearest_distance:
				nearest = child
				nearest_distance = distance
	return nearest.interact() if nearest else false


func _on_node_reclaimed(ring: RingNode) -> void:
	placed_nodes.erase(ring)
	node_charges = mini(3, node_charges + 1)
	ring.queue_free()
	if play_sfx:
		node_audio.play()
	resources_changed.emit()


func _on_node_destroyed(ring: RingNode) -> void:
	placed_nodes.erase(ring)
	ring.queue_free()
	resources_changed.emit()


func _enter_danger(kind: String) -> void:
	danger_kind = kind
	danger_seconds_left = rescue_seconds
	danger_changed.emit(true, danger_seconds_left)
	_update_visual_feedback()


func _clear_danger() -> void:
	danger_kind = ""
	danger_seconds_left = 0.0
	danger_changed.emit(false, 0.0)
	_update_visual_feedback()


func _die(kind: String) -> void:
	is_dead = true
	current_speed = 0.0
	died.emit(kind)
	queue_redraw()


func _update_visual_feedback() -> void:
	feedback_color = Color.TRANSPARENT
	if not danger_kind.is_empty():
		var elapsed := rescue_seconds - danger_seconds_left
		if fmod(elapsed, DANGER_FLASH_PERIOD) < DANGER_FLASH_PERIOD * 0.5:
			feedback_color = Color("ff4f4f")
	elif hit_flash_left > 0.0:
		feedback_color = Color.WHITE
	if is_node_ready():
		body_chain.feedback_color = feedback_color
		body_chain.queue_redraw()
	queue_redraw()


func _draw() -> void:
	var head_color := feedback_color if feedback_color.a > 0.0 else Color("ff5d5d") if is_dead else Color("63c74d")
	draw_circle(Vector2.ZERO, 10.0, head_color)
	draw_circle(direction * 4.5 + direction.rotated(-PI * 0.5) * 3.0, 1.7, Color.WHITE)
	draw_circle(direction * 4.5 + direction.rotated(PI * 0.5) * 3.0, 1.7, Color.WHITE)
