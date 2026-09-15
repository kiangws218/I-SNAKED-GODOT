class_name MusicCatalog
extends Resource

## Static collection of music cue definitions.
##
## No lookup cache is kept here: Resources are definitions, while all
## playback and transition state belongs to MusicDirector.
@export var cues: Array = []


func get_cue(cue_id: StringName) -> Resource:
	if cue_id == &"":
		return null
	for cue in cues:
		if cue != null and _cue_id(cue) == cue_id:
			return cue
	return null


func has_cue(cue_id: StringName) -> bool:
	return get_cue(cue_id) != null


func cue_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for cue in cues:
		if cue != null:
			var id := _cue_id(cue)
			if id != &"" and not ids.has(id):
				ids.append(id)
	return ids


func _cue_id(cue: Resource) -> StringName:
	var value = cue.get("id")
	if value == null or StringName(value) == &"":
		value = cue.get("cue_id")
	return StringName(value) if value != null else &""
