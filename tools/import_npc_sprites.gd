extends SceneTree

# Reproducible NPC import. No AI calls; source pixels are never overwritten.
const PROFILES := "res://tools/npc_sprite_profiles.json"
const ARTIFACTS := ["walk.png", "idle.png", "frames.tres"]
var config: Dictionary
var threshold := 0.94

func _initialize() -> void:
	config = _read_json(PROFILES)
	if config.is_empty():
		quit(1)
		return
	threshold = float(config.background_threshold)
	var selected := ""
	var force := false
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--character="):
			selected = argument.trim_prefix("--character=")
		elif argument == "--force":
			force = true
	var found := false
	for profile: Dictionary in config.characters:
		if not selected.is_empty() and selected != String(profile.id):
			continue
		found = true
		if not _import_character(profile, force):
			quit(1)
			return
	if not found:
		push_error("Unknown character: " + selected)
		quit(1)
		return
	print("NPC SPRITE IMPORT COMPLETE")
	quit(0)

func _read_json(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}

func _import_character(profile: Dictionary, force: bool) -> bool:
	var id := String(profile.id)
	if id not in ["keti", "ajie", "lisi", "ajian", "buck", "miro"]:
		push_error("Invalid asset id")
		return false
	var folder := "res://assets/characters/" + id + "/"
	var signature := (FileAccess.get_sha256(folder + "source.png") + JSON.stringify(profile) + FileAccess.get_sha256(PROFILES) + FileAccess.get_sha256("res://tools/import_npc_sprites.gd")).sha256_text()
	var receipt := _read_json(folder + "import_receipt.json") if FileAccess.file_exists(folder + "import_receipt.json") else {}
	var unchanged := String(receipt.get("signature", "")) == signature
	for artifact in ARTIFACTS:
		unchanged = unchanged and FileAccess.file_exists(folder + artifact) and String(receipt.get(artifact, "")) == FileAccess.get_sha256(folder + artifact)
	if unchanged and not force:
		print("SKIP ", id, " (source, profile and outputs unchanged)")
		return true
	var source := Image.load_from_file(folder + "source.png")
	var expected := Vector2i(int(profile.source_size[0]), int(profile.source_size[1]))
	if source == null or source.get_size() != expected or profile.cells.size() != 12:
		push_error("Invalid source or frame profile: " + id)
		return false
	var cells: Array[Image] = []
	var maximum_height := 0
	for rectangle: Array in profile.cells:
		var region := Rect2i(int(rectangle[0]), int(rectangle[1]), int(rectangle[2]), int(rectangle[3]))
		if not Rect2i(Vector2i.ZERO, source.get_size()).encloses(region):
			push_error("Crop outside source: " + id)
			return false
		var cell := source.get_region(region)
		_remove_external_background(cell)
		var bounds := cell.get_used_rect()
		if bounds.size.x < 8 or bounds.size.y < 16:
			push_error("Empty or invalid frame: " + id)
			return false
		maximum_height = maxi(maximum_height, bounds.size.y)
		cells.append(cell)
	# One common scale for all 12 frames, never resize each tight crop separately.
	var scale := float(profile.get("scale_divisor", float(maximum_height) / float(profile.get("target_height", 32))))
	var frame_size := Vector2i(int(config.frame_size[0]), int(config.frame_size[1]))
	var canvas_size := Vector2i(roundi(frame_size.x * scale), roundi(frame_size.y * scale))
	var anchor := Vector2i(roundi(frame_size.x * 0.5 * scale), roundi(int(config.foot_y) * scale))
	var atlas := Image.create(frame_size.x * 3, frame_size.y * 4, false, Image.FORMAT_RGBA8)
	atlas.fill(Color.TRANSPARENT)
	var evidence: Array[Dictionary] = []
	for index in range(12):
		var cell := cells[index]
		var bounds := cell.get_used_rect()
		var band := int(profile.get("foot_band", maxi(4, roundi(bounds.size.y * 0.2))))
		var axis := _foot_axis(cell, bounds, band)
		var destination := Vector2i(anchor.x - axis + bounds.position.x, anchor.y - bounds.size.y)
		if destination.x < 0 or destination.y < 0 or destination.x + bounds.size.x > canvas_size.x:
			push_error("Frame would be clipped: " + id + " frame " + str(index))
			return false
		var canvas := Image.create(canvas_size.x, canvas_size.y, false, Image.FORMAT_RGBA8)
		canvas.fill(Color.TRANSPARENT)
		canvas.blit_rect(cell, bounds, destination)
		canvas.resize(frame_size.x, frame_size.y, Image.INTERPOLATE_NEAREST)
		# Correct integer nearest sampling rounding, retaining the same frame scale.
		var shift := int(config.foot_y) - canvas.get_used_rect().end.y
		if shift != 0:
			var aligned := Image.create(frame_size.x, frame_size.y, false, Image.FORMAT_RGBA8)
			aligned.fill(Color.TRANSPARENT)
			aligned.blit_rect(canvas, Rect2i(Vector2i.ZERO, frame_size), Vector2i(0, shift))
			canvas = aligned
		atlas.blit_rect(canvas, Rect2i(Vector2i.ZERO, frame_size), Vector2i((index % 3) * frame_size.x, (index / 3) * frame_size.y))
		evidence.append({"source_bounds": [bounds.position.x, bounds.position.y, bounds.size.x, bounds.size.y], "axis": axis})
	if atlas.save_png(folder + "walk.png") != OK or atlas.get_region(Rect2i(frame_size.x, 0, frame_size.x, frame_size.y)).save_png(folder + "idle.png") != OK:
		push_error("Cannot save generated atlas: " + id)
		return false
	if not _write_text(folder + "frames.tres", _frames_text(id, frame_size)):
		return false
	receipt = {"signature": signature, "pipeline_version": config.pipeline_version, "common_scale": scale, "frames": evidence}
	for artifact in ARTIFACTS:
		receipt[artifact] = FileAccess.get_sha256(folder + artifact)
	if not _write_text(folder + "import_receipt.json", JSON.stringify(receipt, "\t") + "\n"):
		return false
	print("IMPORT ", id, ": 12 frames, ", frame_size, ", common scale=", scale)
	return true

func _write_text(path: String, content: String) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Cannot write " + path)
		return false
	file.store_string(content)
	file.close()
	return true

func _frames_text(id: String, size: Vector2i) -> String:
	var text := '[gd_resource type="SpriteFrames" load_steps=14 format=3]\n\n[ext_resource type="Texture2D" path="res://assets/characters/%s/walk.png" id="1"]\n' % id
	for row in range(4):
		for column in range(3):
			text += '\n[sub_resource type="AtlasTexture" id="Frame_%d_%d"]\natlas = ExtResource("1")\nregion = Rect2(%d, %d, %d, %d)\n' % [row, column, column * size.x, row * size.y, size.x, size.y]
	var animations: Array[String] = []
	for row in range(4):
		for moving in [false, true]:
			var frames: Array[String] = []
			for column in ([0, 1, 2, 1] if moving else [1]):
				frames.append('{"duration": 1.0, "texture": SubResource("Frame_%d_%d")}' % [row, column])
			animations.append('{"frames": [%s], "loop": true, "name": &"%s_%s", "speed": %s}' % [", ".join(frames), "walk" if moving else "idle", config.directions[row], str(config.fps)])
	return text + '\n[resource]\nanimations = [' + ",\n".join(animations) + ']\n'

func _is_background(color: Color) -> bool:
	return color.a < 0.01 or (color.r >= threshold and color.g >= threshold and color.b >= threshold)

func _remove_external_background(image: Image) -> void:
	image.convert(Image.FORMAT_RGBA8)
	var width := image.get_width()
	var height := image.get_height()
	var visited := PackedByteArray()
	visited.resize(width * height)
	var pending: Array[Vector2i] = []
	for x in range(width):
		pending.append(Vector2i(x, 0))
		pending.append(Vector2i(x, height - 1))
	for y in range(height):
		pending.append(Vector2i(0, y))
		pending.append(Vector2i(width - 1, y))
	var cursor := 0
	while cursor < pending.size():
		var point := pending[cursor]
		cursor += 1
		if point.x < 0 or point.y < 0 or point.x >= width or point.y >= height:
			continue
		var index := point.y * width + point.x
		if visited[index] != 0:
			continue
		visited[index] = 1
		if not _is_background(image.get_pixelv(point)):
			continue
		image.set_pixelv(point, Color.TRANSPARENT)
		for neighbor in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			pending.append(point + neighbor)

func _foot_axis(image: Image, bounds: Rect2i, band: int) -> int:
	var sum_x := 0
	var count := 0
	for y in range(maxi(bounds.position.y, bounds.end.y - band), bounds.end.y):
		for x in range(bounds.position.x, bounds.end.x):
			if image.get_pixel(x, y).a > 0.5:
				sum_x += x
				count += 1
	return roundi(float(sum_x) / maxf(float(count), 1.0))
