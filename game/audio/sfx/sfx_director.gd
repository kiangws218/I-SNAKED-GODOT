class_name SfxDirector
extends Node

## Pooled playback boundary for both UI/non-spatial and world/2D SFX.
## No global singleton is used: instantiate this scene where playback is owned.

@export var catalog: Resource
@export_range(1, 128, 1) var default_pool_size: int = 16
@export var pool_parent_path: NodePath = NodePath("Players")

var _rng := RandomNumberGenerator.new()
var _players: Array[AudioStreamPlayer] = []
var _spatial_players: Array[AudioStreamPlayer2D] = []
var _last_played_at: Dictionary = {}


func _ready() -> void:
	_rng.randomize()
	_ensure_pool_parent()


func _exit_tree() -> void:
	# Release active decoders before a session is removed or the window closes.
	stop_all()
	for player in _players:
		if is_instance_valid(player): player.stream = null
	for player in _spatial_players:
		if is_instance_valid(player): player.stream = null


func play_sfx(sfx_id: StringName, options: Dictionary = {}) -> Dictionary:
	var result := _base_result(sfx_id)
	if sfx_id.is_empty():
		result.code = &"missing_id"
		return result
	if not is_instance_valid(catalog):
		result.code = &"missing_catalog"
		return result
	if not catalog.has_method("get_definition"):
		result.code = &"invalid_catalog"
		return result
	var definition: Resource = catalog.get_definition(sfx_id)
	if not is_instance_valid(definition):
		result.code = &"missing_id"
		return result
	if not definition.has_method("get_valid_streams"):
		result.code = &"invalid_definition"
		return result
	var streams: Array = definition.get_valid_streams()
	if streams.is_empty():
		result.code = &"missing_stream"
		return result

	var now := Time.get_ticks_usec() / 1000000.0
	var last := float(_last_played_at.get(sfx_id, -INF))
	if definition.cooldown > 0.0 and now - last < definition.cooldown:
		result.code = &"cooldown"
		result.remaining = maxf(0.0, definition.cooldown - (now - last))
		return result

	var position_value = options.get("global_position", options.get("position", null))
	if position_value is Vector2i:
		position_value = Vector2(position_value)
	var use_spatial: bool = bool(definition.spatial) or position_value is Vector2
	var player = _acquire_player(use_spatial, sfx_id, definition.max_instances)
	if player == null:
		result.code = &"pool_full"
		result.player_kind = &"2d" if use_spatial else &"non_spatial"
		return result

	var variant := _rng.randi_range(0, streams.size() - 1)
	var stream: AudioStream = streams[variant]
	var volume_range: Vector2 = definition.normalized_volume_range()
	var pitch_range: Vector2 = definition.normalized_pitch_range()
	var volume_db := float(options.get("volume_db", _rng.randf_range(volume_range.x, volume_range.y)))
	var pitch_scale := float(options.get("pitch_scale", _rng.randf_range(pitch_range.x, pitch_range.y)))
	if not is_finite(volume_db) or not is_finite(pitch_scale):
		_release_player(player)
		result.code = &"invalid_options"
		return result
	pitch_scale = maxf(0.01, pitch_scale)

	player.stream = stream
	player.bus = definition.bus if not definition.bus.is_empty() else &"SFX"
	player.volume_db = volume_db
	player.pitch_scale = pitch_scale
	player.set_meta(&"sfx_id", sfx_id)
	if use_spatial:
		var spatial_player: AudioStreamPlayer2D = player as AudioStreamPlayer2D
		if position_value is Vector2:
			spatial_player.global_position = position_value
		spatial_player.play()
		result.player_kind = &"2d"
	else:
		(player as AudioStreamPlayer).play()
		result.player_kind = &"non_spatial"
	_last_played_at[sfx_id] = now
	result.ok = true
	result.code = &"played"
	result.variant = variant
	result.volume_db = volume_db
	result.pitch_scale = pitch_scale
	return result


func stop_all() -> void:
	for player in _players:
		if is_instance_valid(player):
			player.stop()
	for player in _spatial_players:
		if is_instance_valid(player):
			player.stop()


func _base_result(sfx_id: StringName) -> Dictionary:
	return {"ok": false, "code": &"error", "id": sfx_id, "player_kind": &""}


func _ensure_pool_parent() -> Node:
	var parent := get_node_or_null(pool_parent_path)
	if parent == null:
		parent = Node.new()
		parent.name = "Players"
		add_child(parent)
	return parent


func _acquire_player(spatial: bool, sfx_id: StringName, max_instances: int):
	var pool = _spatial_players if spatial else _players
	var active_for_id := 0
	for player in pool:
		if is_instance_valid(player) and player.playing and StringName(player.get_meta(&"sfx_id", &"")) == sfx_id:
			active_for_id += 1
	if active_for_id >= maxi(1, max_instances):
		return null
	for player in pool:
		if is_instance_valid(player) and not player.playing:
			return player
	if pool.size() >= default_pool_size:
		return null
	var player = AudioStreamPlayer2D.new() if spatial else AudioStreamPlayer.new()
	player.name = ("Sfx2D_%d" if spatial else "Sfx_%d") % pool.size()
	_ensure_pool_parent().add_child(player)
	pool.append(player)
	return player


func _release_player(player) -> void:
	if is_instance_valid(player):
		player.stop()
