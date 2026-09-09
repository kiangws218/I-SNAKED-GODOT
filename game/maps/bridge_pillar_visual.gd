class_name BridgePillar
extends Node2D

signal completed(pillar: BridgePillar)

const TILE_SIZE := 24.0
const SCAN_INTERVAL := 0.1

@export var pillar_id: StringName = &"forest_bridge_pillar"
@export_range(0.1, 30.0, 0.1) var charge_seconds := 3.0
@export var requires_node := true
@export var scan_bounds := Rect2i(80, 20, 17, 20)
@export var barrier_cells := Rect2i(92, 27, 4, 6)
@export_range(1.0, 30.0, 0.5) var active_radius_tiles := 14.0
@export_node_path("AnimationPlayer") var completion_animation_player: NodePath
@export var completion_animation: StringName = &"lower"

var progress := 0.0
var done := false
var player: SnakePlayer
var _scan_elapsed := 0.0

func setup(target: SnakePlayer, restored := false) -> void:
	player = target
	done = restored
	progress = charge_seconds if restored else 0.0
	queue_redraw()

func _physics_process(delta: float) -> void:
	if done or not is_instance_valid(player):
		return
	_scan_elapsed += delta
	if _scan_elapsed < SCAN_INTERVAL:
		return
	var elapsed := _scan_elapsed
	_scan_elapsed = 0.0
	if player.placed_nodes.is_empty() or player.global_position.distance_to(global_position) > active_radius_tiles * TILE_SIZE:
		step_charge(elapsed, {})
		return
	var blocked: Dictionary = {}
	for cell in player.body_chain.occupied_cells:
		if scan_bounds.has_point(cell):
			blocked[cell] = &"body"
	for ring in player.placed_nodes:
		if is_instance_valid(ring) and not ring.finished and scan_bounds.has_point(ring.cell):
			blocked[ring.cell] = &"node"
	step_charge(elapsed, blocked)

func step_charge(delta: float, blocked: Dictionary) -> void:
	var pillar_cell := Vector2i(floori(global_position.x / TILE_SIZE), floori(global_position.y / TILE_SIZE))
	var enclosed := false
	for region in EnclosureDetector.find_regions(scan_bounds, blocked):
		if region.cells.has(pillar_cell) and region.touches_body and (region.touches_node or not requires_node):
			enclosed = true
			break
	progress = minf(charge_seconds, progress + delta) if enclosed else maxf(0.0, progress - delta * 0.2)
	queue_redraw()
	if progress >= charge_seconds:
		done = true
		play_completion_animation()
		completed.emit(self)

func play_completion_animation() -> void:
	if completion_animation_player.is_empty():
		return
	var animation_player := get_node_or_null(completion_animation_player) as AnimationPlayer
	if animation_player and animation_player.has_animation(completion_animation):
		animation_player.play(completion_animation)

func _draw() -> void:
	draw_circle(Vector2.ZERO, 18.0, Color("ffd76e") if done else Color("ff8f5e"))
	draw_circle(Vector2.ZERO, 11.0, Color("58465c"))
	var ratio := 1.0 if done else progress / maxf(charge_seconds, 0.001)
	draw_arc(Vector2.ZERO, 22.0, -PI * 0.5, -PI * 0.5 + TAU * ratio, 24, Color("fff1a8"), 4.0)
