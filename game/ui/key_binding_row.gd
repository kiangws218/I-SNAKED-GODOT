class_name KeyBindingRow
extends HBoxContainer

signal capture_requested(action: StringName, slot: int)
signal reset_requested(action: StringName)

@export var action: StringName = &"move_up"
@onready var action_label: Label = $Action
@onready var primary: Button = $Primary
@onready var secondary: Button = $Secondary
@onready var reset_button: Button = $Reset

func _ready() -> void:
	primary.pressed.connect(func(): capture_requested.emit(action, 0))
	secondary.pressed.connect(func(): capture_requested.emit(action, 1))
	reset_button.pressed.connect(func(): reset_requested.emit(action))
	action_label.text = InputBindingsStore.ACTION_LABELS.get(action, String(action))

func refresh(store: InputBindingsStore) -> void:
	var keys := store.keys_for(action)
	primary.text = store.key_label(keys[0]) if not keys.is_empty() else "—"
	secondary.text = store.key_label(keys[1]) if keys.size() > 1 else "—"
	primary.tooltip_text = "点击修改主键：" + primary.text
	secondary.disabled = action == &"pause"
	secondary.tooltip_text = "Esc 固定用于返回" if secondary.disabled else "点击修改备用键：" + secondary.text

func set_capturing(slot: int) -> void:
	(primary if slot == 0 else secondary).text = "请按键…"
