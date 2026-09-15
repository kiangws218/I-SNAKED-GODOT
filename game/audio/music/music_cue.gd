class_name MusicCue
extends Resource

## Static definition for one piece of music.
##
## A cue's id is authored data and is deliberately not generated from the
## stream path. This keeps map and save references stable when audio assets
## are replaced.
@export var id: StringName = &""
@export var stream: AudioStream
@export var volume_db: float = 0.0

# Compatibility spelling for callers that prefer an explicit cue_id name.
# `id` remains the serialized source of truth, so renaming an audio stream
# cannot change a cue reference.
var cue_id: StringName:
	get:
		return id
	set(value):
		id = value


func is_usable() -> bool:
	return id != &"" and stream != null
