class_name QuestDisplay
extends Control

@onready var quest_label: Label = $Quest


func set_quest(title: String, active: bool) -> void:
	visible = active
	quest_label.text = title
