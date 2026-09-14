extends SceneTree

const IDS := ["ajian", "ajie", "buck", "lisi", "miro"]
const EXPRESSIONS := ["neutral", "happy", "angry", "blushing", "crying", "surprised", "tired", "smug", "terrified"]

func _initialize() -> void:
	for id in IDS:
		var folder: String = "res://assets/portraits/" + id + "/"
		var signature := (FileAccess.get_sha256(folder + "source.png") + FileAccess.get_sha256("res://tools/import_npc_portraits.gd")).sha256_text()
		var receipt: Dictionary = {}
		if FileAccess.file_exists(folder + "receipt.json"):
			receipt = JSON.parse_string(FileAccess.get_file_as_string(folder + "receipt.json"))
		var unchanged: bool = receipt.get("signature", "") == signature
		for expression in EXPRESSIONS:
			unchanged = unchanged and receipt.get(expression, "") == FileAccess.get_sha256(folder + expression + ".png")
		if unchanged:
			print("SKIP PORTRAITS: ", id)
			continue
		var source := Image.load_from_file(folder + "source.png")
		if source == null or source.get_size() != Vector2i(1254, 1254):
			push_error("Expected 1254x1254 source: " + id)
			quit(1)
			return
		source.convert(Image.FORMAT_RGBA8)
		receipt = {"signature": signature, "size": [128, 128], "alpha": "preserved from user source"}
		for index in range(9):
			var cell := source.get_region(Rect2i(index % 3 * 418, index / 3 * 418, 418, 418))
			# User-prepared transparency is authoritative. Only slice and resize.
			var canvas := Image.create(432, 432, false, Image.FORMAT_RGBA8)
			canvas.fill(Color.TRANSPARENT)
			canvas.blit_rect(cell, Rect2i(0, 0, 418, 418), Vector2i(7, 7))
			canvas.resize(128, 128, Image.INTERPOLATE_NEAREST)
			if canvas.save_png(folder + EXPRESSIONS[index] + ".png") != OK:
				quit(1)
				return
			receipt[EXPRESSIONS[index]] = FileAccess.get_sha256(folder + EXPRESSIONS[index] + ".png")
		var file := FileAccess.open(folder + "receipt.json", FileAccess.WRITE)
		file.store_string(JSON.stringify(receipt, "\t"))
		print("IMPORTED PORTRAITS: ", id)
	quit(0)

func _remove_checker(image: Image) -> void:
	var original := image.duplicate() as Image
	var visited := PackedByteArray()
	visited.resize(418 * 418)
	var queue: Array[Vector2i] = []
	for index in range(418):
		queue.append(Vector2i(index, 0))
		queue.append(Vector2i(index, 417))
		queue.append(Vector2i(0, index))
		queue.append(Vector2i(417, index))
	var cursor := 0
	while cursor < queue.size():
		var point := queue[cursor]
		cursor += 1
		if point.x < 0 or point.y < 0 or point.x >= 418 or point.y >= 418: continue
		var address := point.y * 418 + point.x
		if visited[address]: continue
		visited[address] = 1
		var color := image.get_pixelv(point)
		if minf(color.r, minf(color.g, color.b)) < 0.55 or maxf(color.r, maxf(color.g, color.b)) - minf(color.r, minf(color.g, color.b)) > 0.12: continue
		image.set_pixelv(point, Color.TRANSPARENT)
		for offset in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			queue.append(point + offset)
	# Restore cut-off light clothing enclosed by the surviving bust outlines.
	for y in range(300, 418):
		var left := -1
		var right := -1
		for x in range(418):
			if image.get_pixel(x, y).a > 0.5:
				if left < 0: left = x
				right = x
		if left >= 0:
			for x in range(left, right + 1):
				image.set_pixel(x, y, original.get_pixel(x, y))
