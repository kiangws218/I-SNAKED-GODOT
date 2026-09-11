class_name HealthDisplay
extends HBoxContainer

const HEART_TEXTURE := preload("res://assets/ui/heart.png")

@export_range(12, 64, 1) var icon_size := 28
@export var empty_tint := Color(0.18, 0.28, 0.22, 0.55)

var current_health := 0
var maximum_health := 0


func _ready() -> void:
	add_theme_constant_override("separation", 4)
	if maximum_health == 0:
		set_health(3, 3)


func set_health(current: int, maximum: int) -> void:
	current_health = maxi(0, current)
	maximum_health = maxi(0, maximum)
	for child in get_children():
		remove_child(child)
		child.free()
	for index in range(maximum_health):
		var heart := TextureRect.new()
		heart.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		heart.texture = HEART_TEXTURE
		heart.custom_minimum_size = Vector2(icon_size, icon_size)
		heart.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		heart.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		heart.modulate = Color.WHITE if index < current_health else empty_tint
		heart.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(heart)
