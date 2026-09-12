class_name DeathScreen
extends CanvasLayer

signal reload_requested
signal home_requested

@onready var overlay: ColorRect = $Overlay
@onready var reload_button: Button = $Overlay/Center/Panel/Margin/VBox/Reload
@onready var home_button: Button = $Overlay/Center/Panel/Margin/VBox/Home
@onready var message: Label = $Overlay/Center/Panel/Margin/VBox/Message

func _ready() -> void:
	reload_button.pressed.connect(func(): reload_requested.emit())
	home_button.pressed.connect(func(): home_requested.emit())
	hide_screen()

func show_screen(has_save: bool) -> void:
	message.text = "读取当前槽最近保存的进度" if has_save else "没有手动存档，将回到最近检查点"
	overlay.visible = true
	reload_button.disabled = false
	home_button.disabled = false
	reload_button.call_deferred("grab_focus")

func hide_screen() -> void:
	overlay.visible = false

func is_open() -> bool:
	return overlay.visible
