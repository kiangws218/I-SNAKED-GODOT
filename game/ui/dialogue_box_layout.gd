extends PanelContainer

@export_category("Dialogue layout")
@export var auto_fit_viewport := true
@export_range(0.2, 0.6, 0.01) var width_ratio := 0.34
@export var minimum_width := 240.0
@export var maximum_width := 360.0
@export var viewport_margin := 16.0

func fit_to_viewport(viewport_size: Vector2) -> Vector2:
	if not auto_fit_viewport:
		return position
	var target_width := clampf(viewport_size.x * width_ratio, minimum_width, maximum_width)
	var target_height := clampf(viewport_size.y - viewport_margin * 2.0, 300.0, 520.0)
	size = Vector2(target_width, target_height)
	return Vector2(viewport_size.x - target_width - viewport_margin, (viewport_size.y - target_height) * 0.5)
