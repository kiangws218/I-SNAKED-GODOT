class_name SfxCatalog
extends Resource

## Shared read-only collection of semantic SFX definitions.
@export var definitions: Array[Resource] = []

var sfx_definitions: Array[Resource]:
	get:
		return definitions
	set(value):
		definitions = value


func get_definition(sfx_id: StringName) -> Resource:
	if sfx_id.is_empty():
		return null
	for definition in definitions:
		if is_instance_valid(definition) and definition.id == sfx_id:
			return definition
	return null


func has_id(sfx_id: StringName) -> bool:
	return get_definition(sfx_id) != null


func validate_catalog() -> Dictionary:
	var seen: Dictionary = {}
	var issues: Array[String] = []
	for index in definitions.size():
		var definition: Resource = definitions[index]
		if not is_instance_valid(definition):
			issues.append("definition_%d_missing" % index)
			continue
		if definition.id.is_empty():
			issues.append("definition_%d_missing_id" % index)
		elif seen.has(definition.id):
			issues.append("duplicate_id:%s" % String(definition.id))
		else:
			seen[definition.id] = true
		if definition.get_valid_streams().is_empty():
			issues.append("definition_%d_missing_stream" % index)
	return {"ok": issues.is_empty(), "code": &"ok" if issues.is_empty() else &"invalid_catalog", "issues": issues, "count": definitions.size()}
