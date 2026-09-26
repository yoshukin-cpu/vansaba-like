extends CanvasLayer

signal retry_pressed
signal staff_pressed
signal title_pressed

var focus_idx: int = 0
## クリア時はメニューなし (ボタン全非表示)。何か押したらスタッフロールへ。
var is_clear: bool = false

@onready var title_label: Label = $Center/VBox/Title
@onready var stats_label: Label = $Center/VBox/Stats
@onready var press_hint: Label = $Center/VBox/PressHint
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
	if is_clear:
		if event.is_action_pressed("ui_accept"):
			get_viewport().set_input_as_handled()
			staff_pressed.emit()
			return
		if event is InputEventJoypadButton and event.pressed:
			if (event as InputEventJoypadButton).button_index == JOY_BUTTON_A:
				get_viewport().set_input_as_handled()
				staff_pressed.emit()
				return
		if event is InputEventMouseButton and event.pressed:
			if (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
				get_viewport().set_input_as_handled()
				staff_pressed.emit()
				return
		return
	if event is InputEventJoypadButton and event.pressed:
		if (event as InputEventJoypadButton).button_index == JOY_BUTTON_A:
			# 先に handled にする (通知先でシーンが作り直されるため)
			get_viewport().set_input_as_handled()
			if focus_idx == 0:
				retry_pressed.emit()
			else:
				title_pressed.emit()

func show_result(clear: bool, time_s: String, lv: int, kills: int, score: int = 0) -> void:
	is_clear = clear
	title_label.text = "CLEAR!" if clear else "GAME OVER"
	stats_label.text = "生存時間 %s / Lv %d / 撃破 %d / スコア %d" % [time_s, lv, kills, score]
	press_hint.visible = clear
	retry_btn.visible = not clear
	title_btn.visible = not clear
	visible = true
	focus_idx = 0
	if not clear:
		retry_btn.grab_focus()
