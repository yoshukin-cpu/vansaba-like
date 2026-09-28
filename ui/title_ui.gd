extends CanvasLayer

signal start_pressed
signal quit_pressed
## v1.8: タイトルの「強化」「オプション」(SPEC §35.8)。
signal upgrade_pressed
signal options_pressed

const DiffDB := preload("res://data/difficulty_db.gd")
const SaveData := preload("res://systems/save_data.gd")

@onready var start_btn: Button = $Center/VBox/StartBtn
## v1.8 追補3 (D83): 強化/オプション/終了は画面左側に縦並び (LeftMenu)。
@onready var quit_btn: Button = $LeftMenu/QuitBtn
@onready var upgrade_btn: Button = $LeftMenu/UpgradeBtn
@onready var options_btn: Button = $LeftMenu/OptionsBtn
@onready var coin_label: Label = $Center/VBox/CoinLabel
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
## モーダル (強化/オプション) を開く直前にフォーカスしていたボタン (閉じた後の戻り先)。
var _last_focus: Button = null

func _ready() -> void:
	start_btn.pressed.connect(func() -> void: start_pressed.emit())
	quit_btn.pressed.connect(func() -> void: quit_pressed.emit())
	upgrade_btn.pressed.connect(func() -> void: _remember_focus(); upgrade_pressed.emit())
	options_btn.pressed.connect(func() -> void: _remember_focus(); options_pressed.emit())
	left_btn.pressed.connect(func() -> void: _cycle(-1))
	right_btn.pressed.connect(func() -> void: _cycle(1))
	# D83: 左側に縦並びにしたメニューの上下移動を明示配線する (左右では動かさない)。
	# 中央の「はじめる」→ 左メニューを ↓ で降り、↑ で戻る。端では循環する。
	start_btn.focus_neighbor_bottom = start_btn.get_path_to(upgrade_btn)
	start_btn.focus_neighbor_top = start_btn.get_path_to(quit_btn)
	upgrade_btn.focus_neighbor_bottom = upgrade_btn.get_path_to(options_btn)
	upgrade_btn.focus_neighbor_top = upgrade_btn.get_path_to(start_btn)
	options_btn.focus_neighbor_bottom = options_btn.get_path_to(quit_btn)
	options_btn.focus_neighbor_top = options_btn.get_path_to(upgrade_btn)
	quit_btn.focus_neighbor_top = quit_btn.get_path_to(options_btn)
	quit_btn.focus_neighbor_bottom = quit_btn.get_path_to(start_btn)
	# D45: 解放条件の有無でレイアウトが動かないよう、行の高さを固定して常時表示する。
	diff_lock.custom_minimum_size = Vector2(0, 22)
	diff_lock.show()
	refresh_difficulty()
	start_btn.grab_focus()

## 開いているモーダル (オプション/強化) があれば入力を譲る (v1.8・D74)。
func _modal_open() -> bool:
	for n: Node in get_tree().get_nodes_in_group("modal_ui"):
		if n is CanvasLayer and (n as CanvasLayer).visible:
			return true
	return false

## モーダル (オプション/強化) を閉じた後にフォーカスを戻す (v1.8・D74)。
## 修正: 「はじめる」が無効 (ロック中の難易度) のときは、開く前にフォーカスしていた
## 有効なボタン (無ければ左メニューの先頭) へ戻す。以前は disabled のとき何もしなかったため、
## フォーカスが空のままになり、囲みが消えて ↑↓ でも移動できなくなっていた (パッド不具合)。
func focus_start() -> void:
	if not visible:
		return
	_focus_fallback()


## モーダルを開く直前にフォーカスしていたボタンを記憶する (閉じた後の戻り先)。
func _remember_focus() -> void:
	var f: Control = get_viewport().gui_get_focus_owner()
	if f is Button and not (f as Button).disabled:
		_last_focus = f as Button


## フォーカスが空のときに入れるボタン: はじめる (有効時) → 直前のボタン → 左メニュー先頭。
func _focus_fallback() -> void:
	if not start_btn.disabled:
		start_btn.grab_focus()
		return
	if _last_focus != null and is_instance_valid(_last_focus) and not _last_focus.disabled:
		_last_focus.grab_focus()
		return
	for b: Button in [upgrade_btn, options_btn, quit_btn]:
		if not b.disabled:
			b.grab_focus()
			return

## 所持コインの表示 (v1.8・D65)。強化で購入した後に main から呼ばれる。
func refresh_coins() -> void:
	if coin_label != null:
		coin_label.text = "所持コイン %d" % SaveData.coins

## D46: スティックがニュートラルに戻ったら再び切替可能にする。
func _process(_delta: float) -> void:
	if not visible or _modal_open():
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
	refresh_coins()

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
	# ロック中は暗くする (要求どおり)。D81: 難易度選択自体が無効な間 (未クリア) は「ノーマル」も暗くする。
	var dim: bool = (not selector_on) or (not unlocked)
	diff_name.modulate = Color(0.42, 0.42, 0.48, 1) if dim else Color(1, 1, 1, 1)
	# D81: 選択自体が無効な間は ◀▶ も無効表示 (押しても何も起きないことを見た目で示す)。
	left_btn.disabled = not selector_on
	right_btn.disabled = not selector_on
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
	if not visible or _modal_open():
		return
	if event is InputEventKey and (event as InputEventKey).echo:
		return
	# 保険: フォーカスが空 (モーダルを閉じた直後など) でも ↑↓ でメニューに入れるようにする。
	# フォーカスがあるときの移動は Godot のフォーカス移動に任せる (ここでは何もしない)。
	var up_pressed: bool = event.is_action_pressed("ui_up") or event.is_action_pressed("move_up")
	var down_pressed: bool = event.is_action_pressed("ui_down") or event.is_action_pressed("move_down")
	if up_pressed or down_pressed:
		if get_viewport().gui_get_focus_owner() == null:
			get_viewport().set_input_as_handled()
			_focus_fallback()
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
## 修正: 「終了」の判定を先に行う。start_btn.disabled を先に見ると、ロック中の難易度を
## 選んでいる間はパッドのAが「終了」でも握りつぶされ、終われなくなる (キー/マウスは
## ボタン自身が処理するため、パッドのみで起きる不具合)。
func confirm_focused() -> void:
	var f: Control = get_viewport().gui_get_focus_owner()
	if f == quit_btn:
		quit_btn.pressed.emit()
		return
	if f == upgrade_btn:
		upgrade_btn.pressed.emit()
		return
	if f == options_btn:
		options_btn.pressed.emit()
		return
	if start_btn.disabled:
		return
	start_btn.pressed.emit()
