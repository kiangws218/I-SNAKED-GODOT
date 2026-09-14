class_name CgPlayer
extends Control

## Small host for reusable CG performances. It owns only presentation lifetime.
signal finished
signal cue(name: String)
signal cancelled
signal completed(result: Dictionary)

var lick: LickCg

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if not get_parent() is Control:
		_fit_to_viewport()
		get_viewport().size_changed.connect(_fit_to_viewport)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	lick = LickCg.new()
	lick.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	lick.cue.connect(func(name: String): cue.emit(name))
	lick.finished.connect(func():
		hide()
		finished.emit()
	)
	lick.cancelled.connect(func():
		hide()
		cancelled.emit()
	)
	lick.completed.connect(func(result: Dictionary):
		hide()
		completed.emit(result)
	)
	add_child(lick)
	hide()

func _fit_to_viewport() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	position = Vector2.ZERO
	size = get_viewport().get_visible_rect().size

func play_lick(value: LickCgVariant = LickCgVariant.human_female()) -> void:
	# Cancel before showing: cancellation hides the previous run by contract.
	lick.cancel()
	show()
	lick.set_variant(value)
	lick.play_once()

## Stable bridge for future StoryDirector integration. It accepts presentation data,
## but never interprets gameplay state. Callers can await finished or inspect the
## returned acceptance dictionary; cancellation is always safe and idempotent.
func play_presentation(presentation: Dictionary) -> Dictionary:
	var cg_id := String(presentation.get("cg_id", ""))
	if cg_id != "lick" and not cg_id.begins_with("lick."):
		return {"ok": false, "accepted": false, "cancelled": false, "error": "unknown_cg_id", "cg_id": cg_id}
	var variant_id := String(presentation.get("variant", "female"))
	var selected: LickCgVariant
	match variant_id:
		"female", "human_female", "lisi_foot":
			selected = LickCgVariant.human_female()
		"ajian", "ajian_foot":
			selected = LickCgVariant.ajian_foot()
		"monster", "monster_foot":
			selected = LickCgVariant.monster()
		_:
			return {"ok": false, "accepted": false, "cancelled": false, "error": "unknown_variant", "variant": variant_id}
	play_lick(selected)
	var result: Dictionary = await completed
	result["accepted"] = true
	result["cg_id"] = cg_id
	result["variant"] = variant_id
	return result

func play_id(cg_id: String, variant_id: String = "female") -> Dictionary:
	return await play_presentation({"cg_id": cg_id, "variant": variant_id})

func cancel() -> void:
	lick.cancel()
	hide()
