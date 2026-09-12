extends SceneTree

var failures: Array[String] = []
var player_scene: PackedScene = load("res://game/player/snake_player.tscn")
var enemy_scene: PackedScene = load("res://game/actors/enemy_actor.tscn")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var player := player_scene.instantiate() as SnakePlayer
	root.add_child(player)
	await process_frame
	player.set_physics_process(false)
	player.global_position = Vector2.ZERO

	var camera := Camera2D.new()
	camera.position = Vector2.ZERO
	root.add_child(camera)
	camera.make_current()
	await process_frame

	var enemy := enemy_scene.instantiate() as EnemyActor
	enemy.enemy_kind = "slime"
	enemy.speed_override = 1.0
	root.add_child(enemy)
	enemy.setup(player)
	await process_frame
	enemy.set_physics_process(false)

	_test_camera_bounded_aggro(enemy)
	_test_camera_reentry(enemy)
	enemy.queue_free()
	camera.queue_free()
	await process_frame
	await _test_headless_default(player)

	player.queue_free()
	await process_frame
	if failures.is_empty():
		print("ENEMY AGGRO FEEDBACK TESTS PASSED")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _test_camera_bounded_aggro(enemy: EnemyActor) -> void:
	enemy.global_position = Vector2(1000, 0)
	var before := enemy.global_position
	enemy._physics_process(2.9)
	check(not enemy._offscreen_aggro_suspended, "离开相机视野未满 3 秒仍保持追击")
	check(enemy.global_position != before, "离开视野前仍执行默认追击")
	enemy._physics_process(0.2)
	check(enemy._offscreen_aggro_suspended, "离开当前相机视野连续 3 秒后停止仇恨")
	check(enemy.velocity.is_zero_approx(), "停止仇恨后敌人速度归零")


func _test_camera_reentry(enemy: EnemyActor) -> void:
	enemy.global_position = Vector2(100, 0)
	var before := enemy.global_position
	enemy._physics_process(0.1)
	check(not enemy._offscreen_aggro_suspended, "重新进入相机视野后恢复仇恨")
	check(enemy.global_position != before, "重新进入视野后继续默认追击")


func _test_headless_default(player: SnakePlayer) -> void:
	var enemy := enemy_scene.instantiate() as EnemyActor
	enemy.enemy_kind = "slime"
	enemy.speed_override = 1.0
	root.add_child(enemy)
	enemy.setup(player)
	await process_frame
	enemy.set_physics_process(false)
	enemy.global_position = Vector2(5000, 0)
	var before := enemy.global_position
	enemy._physics_process(4.0)
	check(not enemy._offscreen_aggro_suspended, "无活动相机时采用可见默认，不误停仇恨")
	check(enemy.global_position != before, "无活动相机时保留默认追击")
	enemy.queue_free()
	await process_frame


func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
