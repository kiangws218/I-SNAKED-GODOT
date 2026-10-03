class_name LickCgVariant
extends Resource

## Data-only presentation preset. It deliberately contains no story or save state.
@export var display_name: String = "人类脚"
@export_group("角色脚部微调")
@export var foot_offset: Vector2 = Vector2.ZERO
@export var foot_scale: Vector2 = Vector2.ONE
@export_range(-180.0, 180.0, 0.5) var foot_rotation_degrees: float = 0.0
@export var foot_tint: Color = Color.WHITE
@export_group("脚部素材")
@export var foot_asset_id: StringName = &"human_female"
@export_group("怪物占位回退")
@export var skin_color: Color = Color("#e8b39a")
@export var accent_color: Color = Color("#c87970")
@export var subject_scale: Vector2 = Vector2.ONE
@export var subject_offset: Vector2 = Vector2(300, 215)
@export var contact_offset: Vector2 = Vector2(-90, 82)

static func human_female() -> LickCgVariant:
	return _load_preset("res://game/cg/variants/lisi_foot.tres")

static func monster() -> LickCgVariant:
	return _load_preset("res://game/cg/variants/monster_foot.tres")

static func ajian_foot() -> LickCgVariant:
	return _load_preset("res://game/cg/variants/ajian_foot.tres")

static func ajie_foot() -> LickCgVariant:
	return _load_preset("res://game/cg/variants/ajie_foot.tres")

static func keti_foot() -> LickCgVariant:
	return _load_preset("res://game/cg/variants/keti_foot.tres")

static func _load_preset(path: String) -> LickCgVariant:
	var preset := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REUSE) as LickCgVariant
	assert(preset != null, "Missing lick CG variant: %s" % path)
	return preset.duplicate(true) as LickCgVariant
