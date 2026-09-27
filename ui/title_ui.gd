extends CanvasLayer

signal start_pressed
signal quit_pressed

const DiffDB := preload("res://data/difficulty_db.gd")
const SaveData := preload("res://systems/save_data.gd")

@onready var start_btn: Button = $Center/VBox/StartBtn
@onready var quit_btn: Button = $Center/VBox/QuitBtn
@onready var left_btn: Button = $Center/VBox/DiffRow/LeftBtn
@onready var right_btn: Button = $Center/VBox/DiffRow/RightBtn
@onready var diff_name: Label = $Center/VBox/DiffRow/DiffName
@onready var diff_lock: Label = $Center/VBox/DiffLock
@onready var params_title: Label = $ParamsPanel/ParamsTitle
@onready var params_text: Label = $ParamsPanel/ParamsText

## 表示中の難易度エントリ [{"key", "unlocked"}] (解放済み + 次の1件)。
var _entries: Array = []
var _idx: int = 0
## D46: スティック連続切替防止のラッチ。Motion で切替えたらニュートラルまで無効。
var _diff_axis_armed: bool = true

func _ready() -> void:
	start_btn.pressed.connect(func() -> void: start_pressed.emit())
	quit_btn.pressed.connect(func() -> void: quit_pressed.emit())
	left_btn.pressed.connect(func() -> void: _cycle(-1))
	right_btn.pressed.connect(func() -> void: _cycle(1))
	# D45: 解放条件の有無でレイアウトが動かないよう、行の高さを固定して常時表示する。
	diff_lock.custom_minimum_size = Vector2(0, 22)
	diff_lock.show()
	refresh_difficulty()
	start_btn.grab_focus()

## D46: スティックがニュートラルに戻ったら再び切替可能にする。
func _process(_delta: float) -> void:
	if not visible:
		return
	if absf(Input.get_joy_axis(0, JOY_AXIS_LEFT_X)) < 0.2:
		_diff_axis_armed = true

## セーブの解放状況から表示リストを作り、前回選択 (last) にカーソルを合わせる。
## 起動時 (_ready) と、main がセーブ/CLI を適用した後に呼ばれる (§31.6)。
func refresh_difficulty() -> void:
	_entries = DiffDB.selector_entries(SaveData.cleared, SaveData.insane_cleared)
	var start_key: String = SaveData.last
	if not _is_playable(start_key):
		start_key = "normal"
	_idx = 0
	for i: int in range(_entries.size()):
		if str((_entries[i] as Dictionary)["key"]) == start_key:
			_idx = i
			break
	_update_display()

func _is_playable(key: String) -> bool:
	for e: Dictionary in _entries:
		if str(e["key"]) == key:
			return bool(e["unlocked"])
	return false

func _current() -> Dictionary:
	if _entries.is_empty():
		return {"key": "normal", "unlocked": true}
	return _entries[_idx] as Dictionary

## タイトルで選択中の難易度キー (main が開始時に読む)。
func selected_key() -> String:
	return str(_current()["key"])

## 左右切替。セレクタ未解放 (1度もクリアしていない) 間は切替不可 (D40)。
## 解放後はロック中の項目 (次の1件) へも移動できる (開始は不可)。
func _cycle(dir: int) -> void:
	if SaveData.cleared.is_empty():
		return
	if _entries.size() <= 1:
		return
	_idx = (_idx + dir + _entries.size()) % _entries.size()
	var audio: Node = get_tree().get_first_node_in_group("audio")
	if audio != null:
		audio.call("play", "ui")
	_update_display()

func _update_display() -> void:
	var cur: Dictionary = _current()
	var key: String = str(cur["key"])
	var unlocked: bool = bool(cur["unlocked"])
	var selector_on: bool = not SaveData.cleared.is_empty()
	diff_name.text = DiffDB.display_name(key)
	# ロック中は暗くして鍵マークを出す (要求どおり)。
	diff_name.modulate = Color(1, 1, 1, 1) if unlocked else Color(0.42, 0.42, 0.48, 1)
	# D45: 表示の有無にかかわらず他の表示位置を固定するため、hide() せず空行で領域を残す。
	if not selector_on:
		diff_lock.text = "🔒 1度クリアすると難易度選択が解放されます"
	elif not unlocked:
		diff_lock.text = "🔒 " + DiffDB.unlock_requirement_text(key)
	else:
		diff_lock.text = ""
	diff_lock.show()
	# ロック中は「はじめる」を無効化する (D40)。
	start_btn.disabled = not unlocked
	params_title.text = "難易度パラメータ (%s)" % DiffDB.display_name(key)
	var text := ""
	for l: Array in DiffDB.param_lines(key):
		text += "%s +%d%%\n" % [str(l[0]), int(l[1])]
	params_text.text = text.strip_edges()

## キーの確定 (Enter/Space) は、フォーカス中のボタンが ui_accept を処理して
## 自身の pressed を出すため、ここでは扱わない。
## (ここで ui_accept を拾うと、フォーカスを無視して常に「はじめる」が
##  動いてしまい、「終了」を選んでもゲームが始まる)
## パッドの A は既定の ui_accept に含まれておらずボタンが反応しないため、
## フォーカス中のボタンへ明示的に振り分ける (§27.2)。
func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and (event as InputEventKey).echo:
		return
	# 難易度の左右切替 (←→ / 十字キー / 左スティック)。ロック中は _cycle が無効。
	# D46: Motion 由来 (スティック) は倒しっぱなしで連続発火するため、ラッチで1回だけにする。
	if event.is_action_pressed("ui_left") or event.is_action_pressed("move_left"):
		if event is InputEventJoypadMotion and not _diff_axis_armed:
			return
		if event is InputEventJoypadMotion:
			_diff_axis_armed = false
		get_viewport().set_input_as_handled()
		_cycle(-1)
		return
	if event.is_action_pressed("ui_right") or event.is_action_pressed("move_right"):
		if event is InputEventJoypadMotion and not _diff_axis_armed:
			return
		if event is InputEventJoypadMotion:
			_diff_axis_armed = false
		get_viewport().set_input_as_handled()
		_cycle(1)
		return
	if event is InputEventJoypadButton and event.pressed:
		if (event as InputEventJoypadButton).button_index == JOY_BUTTON_A:
			# 先に handled にする (確定先でツリーから外れることがあるため)
			get_viewport().set_input_as_handled()
			confirm_focused()

## フォーカス中のボタンを押す (マウスクリックと同じ経路)。
## ロック中の難易度では開始しない (D40)。
func confirm_focused() -> void:
	if start_btn.disabled:
		return
	if get_viewport().gui_get_focus_owner() == quit_btn:
		quit_btn.pressed.emit()
	else:
		start_btn.pressed.emit()
