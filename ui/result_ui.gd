extends CanvasLayer
## クリア時はスタッフロールへのボタン付きリザルト。GAME OVER時は従来メニュー。

signal retry_pressed
signal staff_pressed
signal title_pressed

var focus_idx: int = 0

@onready var title_label: Label = $Center/VBox/Title
@onready var stats_label: Label = $Center/VBox/Stats
@onready var retry_btn: Button = $Center/VBox/RetryBtn
@onready var staff_btn: Button = $Center/VBox/StaffBtn
@onready var title_btn: Button = $Center/VBox/TitleBtn

func _ready() -> void:
	visible = false
	retry_btn.pressed.connect(func() -> void: retry_pressed.emit())
	staff_btn.pressed.connect(func() -> void: staff_pressed.emit())
	title_btn.pressed.connect(func() -> void: title_pressed.emit())
	retry_btn.focus_entered.connect(_on_focus.bind(0))
	staff_btn.focus_entered.connect(_on_focus.bind(1))
	title_btn.focus_entered.connect(_on_focus.bind(2))

func _on_focus(i: int) -> void:
	focus_idx = i

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventJoypadButton and event.pressed:
		if (event as InputEventJoypadButton).button_index == JOY_BUTTON_A:
			# 先に handled にする (通知先でシーンが作り直されるため)
			get_viewport().set_input_as_handled()
			if focus_idx == 0:
				retry_pressed.emit()
			elif focus_idx == 1:
				staff_pressed.emit()
			else:
				title_pressed.emit()

func show_result(clear: bool, time_s: String, lv: int, kills: int, score: int = 0) -> void:
	title_label.text = "CLEAR!" if clear else "GAME OVER"
	stats_label.text = "生存時間 %s / Lv %d / 撃破 %d / スコア %d" % [time_s, lv, kills, score]
	# スタッフロールへ進めるのはクリア時のみ。
	staff_btn.visible = clear
	visible = true
	focus_idx = 0
	retry_btn.grab_focus()
