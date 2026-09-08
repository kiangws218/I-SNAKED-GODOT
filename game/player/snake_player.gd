class_name SnakePlayer
extends CharacterBody2D

signal died(reason: String)
signal danger_changed(active: bool, seconds_left: float)

const TILE_SIZE := 24.0
const MAX_DIRECTION_QUEUE := 3

@export var base_speed := 4.0 * TILE_SIZE
@export var boost_multiplier := 2.0
@export var rescue_seconds := 0.5
@export var self_collision_radius := 0.62 * TILE_SIZE
@export var rescue_probe_radius := 0.5 * TILE_SIZE
@export var neck_guard := 4

@onready var body_chain: BodyChain = $BodyChain

var direction := Vector2.RIGHT
var direction_queue: Array[Vector2] = []
var danger_kind := ""
var danger_seconds_left := 0.0
var is_dead := false
var current_speed := 0.0
var _last_sampled_input := Vector2.ZERO


func _ready() -> void:
	reset_at(global_position)


func _physics_process(delta: float) -> void:
	if is_dead:
		if Input.is_action_just_pressed("interact"):
			get_tree().reload_current_scene()
		return
	var held_direction := _sample_direction_input()
	apply_next_direction()
	var boosting := not held_direction.is_zero_approx() and held_direction.is_equal_approx(direction)
	simulate_motion(delta, boosting)


func reset_at(spawn_position: Vector2, spawn_direction := Vector2.RIGHT) -> void:
	global_position = spawn_position
	direction = spawn_direction.normalized()
	direction_queue.clear()
	danger_kind = ""
	danger_seconds_left = 0.0
	is_dead = false
	current_speed = base_speed
	_last_sampled_input = Vector2.ZERO
	if is_node_ready():
		body_chain.reset(global_position, direction)
	queue_redraw()


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


func simulate_motion(delta: float, boosting: bool) -> void:
	current_speed = base_speed * (boost_multiplier if boosting else 1.0)
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
	return not body_chain.collides_with_tail(global_position + motion, tail_radius, neck_guard)


func _enter_danger(kind: String) -> void:
	danger_kind = kind
	danger_seconds_left = rescue_seconds
	danger_changed.emit(true, danger_seconds_left)
	queue_redraw()


func _clear_danger() -> void:
	danger_kind = ""
	danger_seconds_left = 0.0
	danger_changed.emit(false, 0.0)
	queue_redraw()


func _die(kind: String) -> void:
	is_dead = true
	current_speed = 0.0
	died.emit(kind)
	queue_redraw()


func _draw() -> void:
	var head_color := Color("ff5d5d") if is_dead or not danger_kind.is_empty() else Color("63c74d")
	draw_circle(Vector2.ZERO, 10.0, head_color)
	draw_circle(direction * 4.5 + direction.rotated(-PI * 0.5) * 3.0, 1.7, Color.WHITE)
	draw_circle(direction * 4.5 + direction.rotated(PI * 0.5) * 3.0, 1.7, Color.WHITE)
