extends SceneTree

## Focused contract tests for the reusable CG slice.
## These intentionally use only the public presentation API; story/save state
## is tested by the story suite and must not be owned by the CG player.
var failures: Array[String] = []
var finished_count := 0
var cue_names: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var host := CgPlayer.new()
	root.add_child(host)
	host.finished.connect(func(): finished_count += 1)
	host.cue.connect(func(name: String): cue_names.append(name))
	await _frames(2)

	_check(not host.visible, "CG 播放器初始隐藏")
	_check(host.lick != null, "CG 播放器创建舔舐表现子组件")
	_check(host.lick.get_node_or_null("Stage/Foot") is Sprite2D, "脚部是可在场景编辑器拖放的 Sprite2D")
	_check(host.lick.get_node_or_null("Stage/SnakeRig/SnakeHead") is Sprite2D, "蛇头是可在场景编辑器拖放的 Sprite2D")
	var tongue_node := host.lick.get_node_or_null("Stage/SnakeRig/Tongue") as Sprite2D
	_check(tongue_node != null and is_equal_approx(rad_to_deg(tongue_node.rotation), -30.0), "信子默认向上倾斜 30 度")
	var snake_node := host.lick.get_node_or_null("Stage/SnakeRig/SnakeHead") as Sprite2D
	_check(snake_node != null and snake_node.scale.x >= 0.28, "近景蛇头使用放大后的基础构图")

	# Variant resources are data-only and must actually alter the same scene.
	var female := LickCgVariant.human_female()
	var ajian := LickCgVariant.ajian_foot()
	var monster := LickCgVariant.monster()
	var lisi_preset := load("res://game/cg/variants/lisi_foot.tres") as LickCgVariant
	var ajian_preset := load("res://game/cg/variants/ajian_foot.tres") as LickCgVariant
	_check(lisi_preset != null and ajian_preset != null and lisi_preset.resource_path != ajian_preset.resource_path, "丽丝与阿见使用独立可编辑角色预设")
	_check(female.foot_scale != ajian.foot_scale and female.foot_tint != ajian.foot_tint, "角色预设可独立调整脚部大小与颜色")
	host.play_lick(female)
	await _frames(8)
	_check(host.visible and host.lick.variant == female, "女性脚变体应用到同一舔舐场景")
	_check(host.lick.variant.contact_offset != monster.contact_offset, "变体拥有独立接触点")

	# Starting a second performance supersedes the first; it must not leave two
	# completion callbacks behind.
	host.play_lick(monster)
	await _frames(8)
	_check(host.lick.variant == monster, "怪物脚变体可替换且无需复制播放器")
	_check(finished_count == 0, "替换中的旧 CG 未提前发出完成信号")
	await create_timer(5.0).timeout
	_check(finished_count == 1, "同一时刻只完成一个 CG 播放")
	_check("contact" in cue_names and "reaction_peak" in cue_names, "CG 发出接触与反应 cue")
	_check(not host.visible, "CG 完成后播放器隐藏")

	# Cancellation is terminal for that run: the old tween cannot call finished
	# later, and the host is immediately hidden.
	finished_count = 0
	cue_names.clear()
	host.play_lick(female)
	await _frames(10)
	host.cancel()
	_check(not host.visible, "取消后 CG 立即隐藏")
	await create_timer(5.0).timeout
	_check(finished_count == 0, "取消后的旧 CG 不触发完成回调")
	_check(cue_names.is_empty(), "取消后的旧 CG 不继续发出 cue")

	# Public awaitable contract: cancellation wakes callers, and playback still
	# advances while the gameplay tree is paused for dialogue.
	var cancelled_result: Dictionary = {}
	_collect_result(host, {"cg_id": "lick.foot", "variant": "ajian_foot"}, cancelled_result)
	await _frames(8)
	host.cancel()
	await _frames(2)
	_check(bool(cancelled_result.get("cancelled", false)), "取消会唤醒等待演出的剧情调用方")
	paused = true
	var paused_result: Dictionary = {}
	_collect_result(host, {"cg_id": "lick.foot", "variant": "lisi_foot"}, paused_result)
	await create_timer(3.5, true).timeout
	paused = false
	_check(bool(paused_result.get("ok", false)) and not bool(paused_result.get("cancelled", true)), "对话暂停期间 CG 仍可完整播放")
	var bad_result: Dictionary = await host.play_presentation({"cg_id": "unknown", "variant": "female"})
	_check(not bool(bad_result.get("accepted", true)), "未知 CG id 被稳定接口拒绝")
	var foot_frames := load("res://assets/cg/lick/human_foot_frames.png") as Texture2D
	var snake_head := load("res://assets/cg/lick/snake_head.png") as Texture2D
	var tongue_frames := load("res://assets/cg/lick/tongue_frames.png") as Texture2D
	_check(foot_frames.get_size() == Vector2(1536, 1024), "人类脚序列保持 3×2 的 512 像素帧布局")
	_check(snake_head.get_size() == Vector2(1254, 1254), "蛇头独立透明资源尺寸正确")
	_check(tongue_frames.get_size() == Vector2(2172, 724), "信子序列保持 4×1 的 543 像素帧布局")
	_check(foot_frames.get_image().get_pixel(0, 0).a == 0.0 and snake_head.get_image().get_pixel(0, 0).a == 0.0 and tongue_frames.get_image().get_pixel(0, 0).a == 0.0, "三项 CG 美术资源保留透明背景")

	var graph: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://game/story/story_graph.json"))
	var nodes: Dictionary = graph.get("nodes", {})
	for node_id in ["cave_ajian_found", "camp_ajian_unconscious", "cave_ajian_rewake"]:
		var node: Dictionary = nodes.get(node_id, {})
		var foot_choice: Dictionary = {}
		for choice in node.get("dialogue", {}).get("choices", []):
			if String(choice.get("id", "")) == "foot": foot_choice = choice
		_check(String(foot_choice.get("presentation", {}).get("variant", "")) == "ajian_foot", "%s 的舔脚唤醒选项声明阿见 CG" % node_id)

	# The dialogue contract keeps its visible choice but disables it for the
	# presentation lifetime, preventing double commits from mouse or keyboard.
	var panel := DialoguePanel.new()
	root.add_child(panel)
	panel.show_dialogue([{"speaker": "测试", "text": "选择舔舐", "choices": [{"id": "lick", "label": "舔她的脚"}]}])
	await _frames(8)
	panel._finish_enter()
	panel.set_input_locked(true)
	var button := panel.choices_box.get_child(0) as Button
	_check(panel.input_locked and button.disabled, "CG 期间对话选择被锁定")
	panel.set_input_locked(false)
	_check(not panel.input_locked and not button.disabled, "CG 结束后对话选择恢复")
	panel.queue_free()

	host.queue_free()
	await process_frame
	if failures.is_empty():
		print("CG TESTS PASSED")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)

func _frames(count: int) -> void:
	for _index in range(count):
		await process_frame

func _collect_result(host: CgPlayer, presentation: Dictionary, target: Dictionary) -> void:
	var result: Dictionary = await host.play_presentation(presentation)
	target.merge(result, true)

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
