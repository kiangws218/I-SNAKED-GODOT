extends Node2D

var _player: CgPlayer
var _variants: Array[LickCgVariant] = [LickCgVariant.human_female(), LickCgVariant.monster()]
var _index := 0
var _status: Label

func _ready() -> void:
	_player = CgPlayer.new()
	add_child(_player)
	_player.cue.connect(_on_cue)
	_player.finished.connect(func(): _status.text = "播放完成  |  R 重播  |  V 切换变体  |  Esc 取消")
	var ui := CanvasLayer.new()
	add_child(ui)
	_status = Label.new()
	_status.position = Vector2(16, 14)
	_status.text = "CG 试验场  |  女性脚（占位）  |  R 重播  |  V 切换变体"
	_status.add_theme_color_override("font_color", Color("#e8edf5"))
	ui.add_child(_status)
	var hint := Label.new()
	hint.position = Vector2(16, 450)
	hint.text = "左侧舞台安全区：自适应   （右侧模拟对话框区域）"
	hint.add_theme_color_override("font_color", Color("#8e9ab5"))
	ui.add_child(hint)
	var dialogue := ColorRect.new()
	dialogue.position = Vector2(507, 0)
	dialogue.size = Vector2(261, 480)
	dialogue.color = Color("#171d31")
	ui.add_child(dialogue)
	var dlabel := Label.new()
	dlabel.position = Vector2(24, 170)
	dlabel.text = "对话框预留区\n（试验场模拟）\n\n角色头像\n表情：惊讶"
	dlabel.add_theme_color_override("font_color", Color("#aeb9d3"))
	dialogue.add_child(dlabel)
	_player.play_lick(_variants[_index])
	if "--capture-cg-review" in OS.get_cmdline_user_args():
		_capture_review.call_deferred()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_R:
			_player.play_lick(_variants[_index])
		elif event.keycode == KEY_V:
			_index = (_index + 1) % _variants.size()
			_status.text = "CG 试验场  |  " + _variants[_index].display_name + "  |  R 重播"
			_player.play_lick(_variants[_index])
		elif event.keycode == KEY_ESCAPE:
			_player.cancel()
			_status.text = "已取消  |  R 重播  |  V 切换变体"

func _on_cue(name: String) -> void:
	_status.text = _variants[_index].display_name + "  |  cue: " + name + "  |  R 重播  |  V 切换变体"

func _capture_review() -> void:
	await get_tree().create_timer(1.25, true).timeout
	get_viewport().get_texture().get_image().save_png("res://.godot/cg_review_female.png")
	_index = 1
	_player.play_lick(_variants[_index])
	await get_tree().create_timer(1.25, true).timeout
	get_viewport().get_texture().get_image().save_png("res://.godot/cg_review_monster.png")
	get_tree().quit()
