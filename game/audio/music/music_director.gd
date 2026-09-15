class_name MusicDirector
extends Node

## Persistent music playback coordinator. Place one instance under a
## persistent owner (for example GameSession) so map changes do not restart
## the music. This node does not own session state or an event bus.
@export var catalog: Resource
@export_range(0.0, 30.0, 0.05, "suffix:s") var default_fade_seconds: float = 1.0
@export var music_bus: StringName = &"Music"
@export var autoplay_cue_id: StringName = &""

var _players: Array[AudioStreamPlayer] = []
var _active_player_index: int = -1
var _current_cue: StringName = &""
var _generation: int = 0
var _transition_tween: Tween


func _ready() -> void:
	_ensure_players()
	if autoplay_cue_id != &"":
		call_deferred("play_cue", autoplay_cue_id)


## Starts a cue, or crossfades from the currently active player.
##
## Results intentionally use a small stable vocabulary so callers can handle
## missing optional audio without making it an error path.
func play_cue(cue_id: StringName) -> Dictionary:
	if cue_id == &"":
		return _result(false, "invalid_cue_id", false)
	if catalog == null:
		return _result(false, "missing_catalog", false)
	var cue: Resource = catalog.call("get_cue", cue_id) as Resource
	if cue == null:
		return _result(false, "missing_cue", false)
	var cue_stream := cue.get("stream") as AudioStream
	if cue_stream == null:
		return _result(false, "missing_stream", false)

	_ensure_players()
	if _players.size() < 2:
		return _result(false, "missing_player", false)

	# Calling play for the currently playing cue must be idempotent. In
	# particular, do not reset playback position during map re-entry.
	if _current_cue == cue_id and _active_player_index >= 0:
		var active := _players[_active_player_index]
		if active.playing and active.stream == cue_stream:
			return _result(true, "reused", true)

	var transition_generation := _begin_transition()
	var incoming_index := 0 if _active_player_index != 0 else 1
	var incoming := _players[incoming_index]
	var outgoing: AudioStreamPlayer = null
	if _active_player_index >= 0 and _active_player_index < _players.size():
		outgoing = _players[_active_player_index]

	# The incoming slot may still be finishing an earlier transition.
	if incoming != outgoing:
		incoming.stop()
	incoming.stream = cue_stream
	incoming.bus = music_bus
	incoming.volume_db = -80.0
	incoming.play()

	_current_cue = cue_id
	_active_player_index = incoming_index
	var fade_seconds := _normalise_fade(default_fade_seconds)
	if outgoing == null or not outgoing.playing:
		incoming.volume_db = float(cue.get("volume_db"))
		return _result(true, "started", false)
	if fade_seconds <= 0.0:
		outgoing.stop()
		incoming.volume_db = float(cue.get("volume_db"))
		return _result(true, "crossfaded", false)

	var tween := create_tween().set_parallel(true)
	_transition_tween = tween
	tween.tween_method(_set_volume_guarded.bind(incoming, transition_generation), -80.0, float(cue.get("volume_db")), fade_seconds)
	tween.tween_method(_set_volume_guarded.bind(outgoing, transition_generation), outgoing.volume_db, -80.0, fade_seconds)
	tween.chain().tween_callback(_stop_player_guarded.bind(outgoing, transition_generation))
	return _result(true, "crossfaded", false)


## Stops current music. A negative fade uses default_fade_seconds.
func stop_music(fade_seconds: float = -1.0) -> Dictionary:
	_ensure_players()
	var outgoing: AudioStreamPlayer = null
	if _active_player_index >= 0 and _active_player_index < _players.size():
		outgoing = _players[_active_player_index]
	var had_music := outgoing != null and outgoing.playing
	var transition_generation := _begin_transition()
	_current_cue = &""
	_active_player_index = -1
	if not had_music:
		for player in _players:
			if player.playing:
				player.stop()
		return _result(true, "already_stopped", true)

	var duration := _normalise_fade(default_fade_seconds if fade_seconds < 0.0 else fade_seconds)
	if duration <= 0.0:
		for player in _players:
			player.stop()
		return _result(true, "stopped", false)

	var tween := create_tween()
	_transition_tween = tween
	tween.tween_method(_set_volume_guarded.bind(outgoing, transition_generation), outgoing.volume_db, -80.0, duration)
	tween.tween_callback(_stop_player_guarded.bind(outgoing, transition_generation))
	return _result(true, "stopping", false)


func current_cue_id() -> StringName:
	return _current_cue


func _ensure_players() -> void:
	if _players.size() >= 2:
		return
	_players.clear()
	var first := get_node_or_null("PlayerA") as AudioStreamPlayer
	var second := get_node_or_null("PlayerB") as AudioStreamPlayer
	if first == null:
		first = AudioStreamPlayer.new()
		first.name = "PlayerA"
		add_child(first)
	if second == null:
		second = AudioStreamPlayer.new()
		second.name = "PlayerB"
		add_child(second)
	_players = [first, second]
	for player in _players:
		player.bus = String(music_bus)
		player.volume_db = -80.0


func _begin_transition() -> int:
	_generation += 1
	if _transition_tween != null:
		_transition_tween.kill()
		_transition_tween = null
	return _generation


func _set_volume_guarded(value: float, player: AudioStreamPlayer, transition_generation: int) -> void:
	if transition_generation != _generation or not is_instance_valid(player):
		return
	player.volume_db = value


func _stop_player_guarded(player: AudioStreamPlayer, transition_generation: int) -> void:
	if transition_generation != _generation or not is_instance_valid(player):
		return
	player.stop()
	if _transition_tween != null and _transition_tween.is_valid():
		_transition_tween = null


func _normalise_fade(seconds: float) -> float:
	return maxf(seconds, 0.0)


func _result(ok: bool, code: String, reused: bool) -> Dictionary:
	return {"ok": ok, "code": code, "reused": reused}
