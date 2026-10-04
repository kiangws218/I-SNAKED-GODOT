class_name BlueCrystalStake
extends Node2D

signal destroyed(stake: BlueCrystalStake)
@export_range(0.1, 30, 0.1) var required_capture_seconds := 3.0
@export_range(0, 1000, 1) var shield_damage := 25.0
var active := false
var is_destroyed := false
var capture_seconds := 0.0

func _ready() -> void:
	$ProgressBar.max_value = required_capture_seconds
	_update_visuals()

func activate() -> void:
	active = true
	_update_visuals()

func step_capture(delta: float, enclosed_by_body: bool) -> void:
	if not active or is_destroyed: return
	# The web mechanic accumulates progress; leaving only pauses capture.
	if enclosed_by_body: capture_seconds = minf(required_capture_seconds, capture_seconds + maxf(0.0, delta))
	if capture_seconds >= required_capture_seconds:
		is_destroyed = true
		destroyed.emit(self)
	_update_visuals()

func _update_visuals() -> void:
	visible = active
	$Visual.modulate = Color("637580") if is_destroyed else Color.WHITE
	$ProgressBar.value = capture_seconds
	$ProgressBar.visible = active and not is_destroyed
