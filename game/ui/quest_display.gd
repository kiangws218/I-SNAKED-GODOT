class_name QuestDisplay
extends PanelContainer

@onready var quest_label: Label = $Margin/Quest


func set_quest(title: String, active: bool) -> void:
	visible = active
	quest_label.text = "当前任务\n" + title

