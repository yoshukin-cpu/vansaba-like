extends CanvasLayer

signal retry_pressed
signal title_pressed

var focus_idx: int = 0

@onready var title_label: Label = $Center/VBox/Title
@onready var stats_label: Label = $Center/VBox/Stats
@onready var retry_btn: Button = $Center/VBox/RetryBtn
@onready var title_btn: Button = $Center/VBox/TitleBtn

func _ready() -> void:
	visible = false
	retry_btn.pressed.connect(func() -> void: retry_pressed.emit())
	title_btn.pressed.connect(func() -> void: title_pressed.emit())
	retry_btn.focus_entered.connect(_on_focus.bind(0))
	title_btn.focus_entered.connect(_on_focus.bind(1))

func _on_focus(i: int) -> void:
	focus_idx = i

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventJoypadButton and event.pressed:
		if (event as InputEventJoypadButton).button_index == JOY_BUTTON_A:
			if focus_idx == 0:
				retry_pressed.emit()
			else:
				title_pressed.emit()
			get_viewport().set_input_as_handled()

func show_result(clear: bool, time_s: String, lv: int, kills: int) -> void:
	title_label.text = "CLEAR!" if clear else "GAME OVER"
	stats_label.text = "生存時間 %s / Lv %d / 撃破 %d" % [time_s, lv, kills]
	visible = true
	focus_idx = 0
	retry_btn.grab_focus()
