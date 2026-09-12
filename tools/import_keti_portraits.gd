extends "res://tools/import_npc_sprites.gd"

const FOLDER := "res://assets/portraits/keti/"
const EXPRESSIONS := ["neutral", "happy", "angry", "blushing", "crying", "surprised", "tired", "smug", "terrified"]

func _initialize() -> void:
	var signature := (FileAccess.get_sha256(FOLDER + "source.png") + FileAccess.get_sha256("res://tools/import_keti_portraits.gd")).sha256_text()
	var receipt := _read_json(FOLDER + "receipt.json") if FileAccess.file_exists(FOLDER + "receipt.json") else {}
	var unchanged: bool = receipt.get("signature", "") == signature
	for expression in EXPRESSIONS:
		unchanged = unchanged and FileAccess.file_exists(FOLDER + expression + ".png") and receipt.get(expression, "") == FileAccess.get_sha256(FOLDER + expression + ".png")
	if unchanged and not OS.get_cmdline_user_args().has("--force"):
		print("SKIP KETI PORTRAITS (unchanged)")
		quit(0)
		return
	var source := Image.load_from_file(FOLDER + "source.png")
	if source == null or source.get_size() != Vector2i(1254, 1254):
		push_error("Expected 1254x1254 transparent Keti portrait sheet")
		quit(1)
		return
	receipt = {"signature": signature, "expressions": EXPRESSIONS, "size": [128, 128], "alpha": "preserved from user source"}
	for index in range(9):
		var cell := source.get_region(Rect2i((index % 3) * 418, (index / 3) * 418, 418, 418))
		# Preserve supplied transparency and identical origins; never re-key or clean pixels.
		var canvas := Image.create(432, 432, false, Image.FORMAT_RGBA8)
		canvas.fill(Color.TRANSPARENT)
		canvas.blit_rect(cell, Rect2i(0, 0, 418, 418), Vector2i(7, 7))
		canvas.resize(128, 128, Image.INTERPOLATE_NEAREST)
		if canvas.save_png(FOLDER + EXPRESSIONS[index] + ".png") != OK:
			quit(1)
			return
		receipt[EXPRESSIONS[index]] = FileAccess.get_sha256(FOLDER + EXPRESSIONS[index] + ".png")
	_write_text(FOLDER + "receipt.json", JSON.stringify(receipt, "\t"))
	print("KETI PORTRAITS IMPORTED: 9 expressions, supplied alpha preserved")
	quit(0)
