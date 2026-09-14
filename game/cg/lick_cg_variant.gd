class_name LickCgVariant
extends Resource

## Data-only presentation preset. It deliberately contains no story or save state.
@export var display_name: String = "人类脚（占位）"
@export var skin_color: Color = Color("#e8b39a")
@export var accent_color: Color = Color("#c87970")
@export var subject_scale: Vector2 = Vector2.ONE
@export var subject_offset: Vector2 = Vector2(300, 215)
@export var contact_offset: Vector2 = Vector2(-90, 82)

static func human_female() -> LickCgVariant:
	var v := LickCgVariant.new()
	v.display_name = "女性脚（占位）"
	v.skin_color = Color("#f0b9a2")
	v.accent_color = Color("#d77f86")
	v.subject_scale = Vector2(1.0, 0.92)
	v.subject_offset = Vector2(300, 218)
	v.contact_offset = Vector2(-96, 83)
	return v

static func monster() -> LickCgVariant:
	var v := LickCgVariant.new()
	v.display_name = "怪物脚（占位）"
	v.skin_color = Color("#83c39a")
	v.accent_color = Color("#3a7e62")
	v.subject_scale = Vector2(1.14, 1.08)
	v.subject_offset = Vector2(300, 208)
	v.contact_offset = Vector2(-108, 92)
	return v

static func ajian_foot() -> LickCgVariant:
	var v := human_female()
	v.display_name = "阿见脚（占位）"
	v.subject_scale = Vector2(1.08, 1.0)
	v.subject_offset = Vector2(300, 212)
	v.contact_offset = Vector2(-102, 88)
	return v
