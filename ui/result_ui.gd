extends CanvasLayer
## クリア時はスタッフロールへのボタン付きリザルト。GAME OVER時は従来メニュー。

signal retry_pressed
signal staff_pressed
signal title_pressed

var focus_idx: int = 0
## クリア時はメニューなし。何か押したら暗転フェードしてスタッフロールへ。
var is_clear: bool = false
var _leaving: bool = false

@onready var title_label: Label = $Center/VBox/Title
@onready var stats_label: Label = $Center/VBox/Stats
@onready var coin_label: Label = $Center/VBox/CoinLabel
@onready var unlock_label: Label = $Center/VBox/UnlockLabel
@onready var retry_btn: Button = $Center/VBox/RetryBtn
@onready var title_btn: Button = $Center/VBox/TitleBtn
@onready var dim: ColorRect = $Dim

## Dim の通常濃度。フェードではここから不透明にする。
const DIM_ALPHA := 0.75

func _ready() -> void:
	visible = false
	retry_btn.pressed.connect(func() -> void: retry_pressed.emit())
	title_btn.pressed.connect(func() -> void: title_pressed.emit())
	retry_btn.focus_entered.connect(_on_focus.bind(0))
	title_btn.focus_entered.connect(_on_focus.bind(1))

func _on_focus(i: int) -> void:
	focus_idx = i

## スタッフロールへ: CLEAR!/戦績は残し、Dim を不透明にして他を消してから通知する。
func _on_staff_button() -> void:
	if _leaving or not visible:
		return
	_leaving = true
	retry_btn.disabled = true
	title_btn.disabled = true
	var tw: Tween = create_tween()
	tw.tween_property(dim, "color:a", 1.0, 0.6)
	tw.tween_callback(func() -> void: staff_pressed.emit())

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	# クリア時はメニューなし。どれかを押したらスタッフロールへ。
	if is_clear:
		if event.is_action_pressed("ui_accept"):
			get_viewport().set_input_as_handled()
			_on_staff_button()
			return
		if event is InputEventJoypadButton and event.pressed:
			if (event as InputEventJoypadButton).button_index == JOY_BUTTON_A:
				get_viewport().set_input_as_handled()
				_on_staff_button()
				return
		if event is InputEventMouseButton and event.pressed:
			if (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
				get_viewport().set_input_as_handled()
				_on_staff_button()
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

func show_result(clear: bool, time_s: String, lv: int, kills: int, score: int = 0, difficulty: String = "", unlock_text: String = "", coins_text: String = "") -> void:
	is_clear = clear
	title_label.text = "CLEAR!" if clear else "GAME OVER"
	var stats: String = "生存時間 %s / Lv %d / 撃破 %d / スコア %d" % [time_s, lv, kills, score]
	if difficulty != "":
		stats = "難易度: %s\n%s" % [difficulty, stats]
	stats_label.text = stats
	# クリアで新規解放があれば「解放: ○○!」を1行足す (D41)。
	unlock_label.text = unlock_text
	unlock_label.visible = unlock_text != ""
	# コイン確定行 (v1.8・D66)。実ノード流用のためスタッフロールにもそのまま載る。
	coin_label.text = coins_text
	coin_label.visible = coins_text != ""
	retry_btn.visible = not clear
	title_btn.visible = not clear
	_leaving = false
	dim.color.a = DIM_ALPHA
	retry_btn.disabled = false
	title_btn.disabled = false
	visible = true
	focus_idx = 0
	if not clear:
		retry_btn.grab_focus()
