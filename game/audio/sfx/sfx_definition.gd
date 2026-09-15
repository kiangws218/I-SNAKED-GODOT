class_name SfxDefinition
extends Resource

## Immutable authoring data for one semantic sound effect.
## Runtime state (cooldowns, active players and random selection) belongs to
## SfxDirector; a catalog resource is safe to share between scenes.

@export var id: StringName
@export var streams: Array[AudioStream] = []
@export var bus: StringName = &"SFX"
@export var spatial: bool = false
@export_range(-80.0, 24.0, 0.01) var volume_db_min: float = 0.0
@export_range(-80.0, 24.0, 0.01) var volume_db_max: float = 0.0
@export_range(0.01, 4.0, 0.001) var pitch_scale_min: float = 1.0
@export_range(0.01, 4.0, 0.001) var pitch_scale_max: float = 1.0
@export_range(0.0, 60.0, 0.001) var cooldown: float = 0.0
@export_range(1, 64, 1) var max_instances: int = 4

# Compatibility spellings for data authored by callers using the longer
# names. The exported fields above remain the single serialized source of
# truth, so changing an asset path never changes a semantic ID.
var sfx_id: StringName:
	get:
		return id
	set(value):
		id = value
var variants: Array[AudioStream]:
	get:
		return streams
	set(value):
		streams = value
var stream: AudioStream:
	get:
		return streams[0] if not streams.is_empty() else null
	set(value):
		streams = [] if value == null else [value]
var cooldown_seconds: float:
	get:
		return cooldown
	set(value):
		cooldown = value
var min_interval: float:
	get:
		return cooldown
	set(value):
		cooldown = value
var max_polyphony: int:
	get:
		return max_instances
	set(value):
		max_instances = value
var polyphony: int:
	get:
		return max_instances
	set(value):
		max_instances = value
var bus_name: StringName:
	get:
		return bus
	set(value):
		bus = value


func is_valid_definition() -> bool:
	return not id.is_empty() and not get_valid_streams().is_empty()


func get_valid_streams() -> Array[AudioStream]:
	var result: Array[AudioStream] = []
	for stream in streams:
		if is_instance_valid(stream):
			result.append(stream)
	return result


func normalized_volume_range() -> Vector2:
	return Vector2(minf(volume_db_min, volume_db_max), maxf(volume_db_min, volume_db_max))


func normalized_pitch_range() -> Vector2:
	return Vector2(maxf(0.01, minf(pitch_scale_min, pitch_scale_max)), maxf(0.01, maxf(pitch_scale_min, pitch_scale_max)))
