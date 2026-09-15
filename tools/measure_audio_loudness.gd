extends SceneTree

var capture: AudioEffectCapture
var player: AudioStreamPlayer
const TARGET_RMS_DBFS := -18.0
const PEAK_CEILING_DBFS := -1.0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var bus := AudioServer.get_bus_index(&"SFX")
	if bus < 0:
		printerr("SFX bus not found")
		quit(1)
		return
	capture = AudioEffectCapture.new()
	capture.buffer_length = 8.0
	AudioServer.add_bus_effect(bus, capture)
	player = AudioStreamPlayer.new()
	player.bus = &"SFX"
	root.add_child(player)
	var report: Dictionary = {}
	var files := DirAccess.get_files_at("res://assets/audio")
	files.sort()
	for file_name in files:
		if file_name.ends_with(".import") or not file_name.get_extension().to_lower() in ["wav", "ogg"]:
			continue
		var stream := load("res://assets/audio/" + file_name) as AudioStream
		if stream == null:
			printerr("Could not load " + file_name)
			continue
		capture.clear_buffer()
		player.stream = stream
		player.play()
		for _frame in range(6):
			await process_frame
		while player.playing:
			await process_frame
		for _frame in range(3):
			await process_frame
		var frame_count := capture.get_frames_available()
		var samples := capture.get_buffer(frame_count)
		var sum_squares := 0.0
		var peak := 0.0
		for sample in samples:
			var left := absf(sample.x)
			var right := absf(sample.y)
			peak = maxf(peak, maxf(left, right))
			sum_squares += (sample.x * sample.x + sample.y * sample.y) * 0.5
		var rms := sqrt(sum_squares / maxf(1.0, float(samples.size())))
		var rms_dbfs := linear_to_db(maxf(rms, 0.000001))
		var peak_dbfs := linear_to_db(maxf(peak, 0.000001))
		report[file_name] = {
			"frames": samples.size(),
			"rms_dbfs": rms_dbfs,
			"peak_dbfs": peak_dbfs,
			"recommended_volume_db": minf(TARGET_RMS_DBFS - rms_dbfs, PEAK_CEILING_DBFS - peak_dbfs),
		}
	print(JSON.stringify(report))
	quit(0)
