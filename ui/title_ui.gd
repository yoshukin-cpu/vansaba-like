extends CanvasLayer

signal start_pressed
signal quit_pressed

@onready var start_btn: Button = $Center/VBox/StartBtn
@onready var quit_btn: Button = $Center/VBox/QuitBtn

func _ready() -> void:
	start_btn.pressed.connect(func() -> void: start_pressed.emit())
	quit_btn.pressed.connect(func() -> void: quit_pressed.emit())
	start_btn.grab_focus()

## キーの確定 (Enter/Space) は、フォーカス中のボタンが ui_accept を処理して
## 自身の pressed を出すため、ここでは扱わない。
## (ここで ui_accept を拾うと、フォーカスを無視して常に「はじめる」が
##  動いてしまい、「終了」を選んでもゲームが始まる)
## パッドの A は既定の ui_accept に含まれておらずボタンが反応しないため、
## フォーカス中のボタンへ明示的に振り分ける (§27.2)。
func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventJoypadButton and event.pressed:
		if (event as InputEventJoypadButton).button_index == JOY_BUTTON_A:
			# 先に handled にする (確定先でツリーから外れることがあるため)
			get_viewport().set_input_as_handled()
			confirm_focused()

## フォーカス中のボタンを押す (マウスクリックと同じ経路)。
func confirm_focused() -> void:
	if get_viewport().gui_get_focus_owner() == quit_btn:
		quit_btn.pressed.emit()
	else:
		start_btn.pressed.emit()
