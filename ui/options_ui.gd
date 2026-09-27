extends CanvasLayer
## オプション画面 (SPEC §35.2〜§35.4・§35.13、v1.8/案6)。
## 表示モード / 解像度16件 (4Kまで) / BGM・SE 音量 / スタッフロール再演 (1回クリアで解放・秘密項目) /
## セーブデータ初期化 (確認付き) / 戻る。変更は即時適用 + 即保存する。導線はタイトル画面のみ。
## 操作 (D74/D75): ↑↓ (項目) ←→ (変更) Enter (実行) Esc (戻る) パッド +
## マウス (行クリックで選択・◀▶ / 実行ボタン)。画面内ではフォーカスを使わない (タイトルへキーを漏らさないため)。

signal closed
signal staff_replay_pressed

const SaveData := preload("res://systems/save_data.gd")
const OptDB := preload("res://data/options_db.gd")

const HINT_NORMAL := "↑↓ / スティック: 項目　←→ / ◀▶ / クリック: 変更　Enter / A / クリック: 実行　Esc / B: 戻る"
const HINT_CONFIRM := "←→: はい/いいえ　Enter / A / クリック: 決定　Esc / B: いいえ"

@onready var rows_box: VBoxContainer = $Panel/Rows
@onready var hint_label: Label = $Panel/Hint
@onready var confirm_box: VBoxContainer = $Panel/Confirm
@onready var yes_btn: Button = $Panel/Confirm/ConfirmRow/YesBtn
@onready var no_btn: Button = $Panel/Confirm/ConfirmRow/NoBtn

## 表示中の行 [{id, name, values, index, action, name_label, value_label, left_btn, right_btn, exec_btn}]。
var rows: Array = []
var idx: int = 0
var _axis_armed_v: bool = true
## D82: 左右 (値の変更・確認のはい/いいえ) のスティックラッチ。X軸が戻るまで1回だけ。
var _axis_armed_h: bool = true
## セーブデータ初期化の確認中 (D76)。確認中の idx は 0 = はい / 1 = いいえ。
var confirming: bool = false
var confirm_idx: int = 1


func _ready() -> void:
	visible = false
	add_to_group("modal_ui")
	yes_btn.focus_mode = Control.FOCUS_NONE
	no_btn.focus_mode = Control.FOCUS_NONE
	yes_btn.pressed.connect(func() -> void: _confirm_answer(true))
	no_btn.pressed.connect(func() -> void: _confirm_answer(false))
	confirm_box.hide()


func open() -> void:
	confirming = false
	confirm_box.hide()
	rows_box.show()
	hint_label.text = HINT_NORMAL
	rebuild()
	visible = true
	_axis_armed_v = true
	_axis_armed_h = true
	# D74: タイトルがフォーカスを持ったままだとキーが食われて (a) 画面が操作できない (b) タイトルが動く。
	# モーダル側はフォーカスを使わず _unhandled_input で操作するため、開いた時点で解放する。
	get_viewport().gui_release_focus()


func close() -> void:
	confirming = false
	confirm_box.hide()
	rows_box.show()
	visible = false
	closed.emit()


## 行の構成 (解放状況で変わる)。検証からも呼ぶ。
func rebuild() -> void:
	rows = []
	var mode: String = str(SaveData.options.get("mode", OptDB.MODE_WINDOW))
	rows.append({
		"id": "mode", "name": "表示モード",
		"values": ["ウィンドウ", "フルスクリーン"],
		"index": 0 if mode == OptDB.MODE_WINDOW else 1,
	})
	var res_vals: Array = []
	for i: int in range(OptDB.RESOLUTIONS.size()):
		res_vals.append(OptDB.resolution_label(OptDB.resolution_at(i)))
	rows.append({
		"id": "resolution", "name": "解像度",
		"values": res_vals,
		"index": OptDB.resolution_index(str(SaveData.options.get("resolution", "1152x648"))),
	})
	var vol_vals: Array = []
	for i: int in range(21):
		vol_vals.append("%d%%" % (i * 5))
	rows.append({
		"id": "bgm", "name": "BGM音量", "values": vol_vals,
		"index": int(round(float(SaveData.options.get("bgm", OptDB.DEFAULT_BGM)) / OptDB.VOL_STEP)),
	})
	rows.append({
		"id": "se", "name": "SE音量", "values": vol_vals,
		"index": int(round(float(SaveData.options.get("se", OptDB.DEFAULT_SE)) / OptDB.VOL_STEP)),
	})
	# D64: 1回クリアで解放。解放までは行ごと表示しない (秘密項目)。
	if not SaveData.cleared.is_empty():
		rows.append({"id": "replay", "name": "スタッフロール再演", "values": [], "index": 0, "action": "replay"})
	# D76: 進行状況の初期化 (確認付き)。オプション設定は消さない。
	rows.append({"id": "reset", "name": "セーブデータ初期化", "values": [], "index": 0, "action": "reset"})
	rows.append({"id": "back", "name": "戻る", "values": [], "index": 0, "action": "close"})
	idx = clampi(idx, 0, maxi(0, rows.size() - 1))
	_draw()


## 選択中の行 (検証用)。
func current_row() -> Dictionary:
	if rows.is_empty():
		return {}
	return rows[idx] as Dictionary


func row_ids() -> Array:
	var out: Array = []
	for r: Dictionary in rows:
		out.append(str(r["id"]))
	return out


func _draw() -> void:
	for c: Node in rows_box.get_children():
		c.queue_free()
	for i: int in range(rows.size()):
		var r: Dictionary = rows[i]
		var action: String = str(r.get("action", ""))
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 10)
		rows_box.add_child(hb)
		# 行の名前 (クリックで選択)。
		var name_l := Label.new()
		name_l.custom_minimum_size = Vector2(300, 34)
		name_l.add_theme_font_size_override("font_size", 22)
		name_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		name_l.mouse_filter = Control.MOUSE_FILTER_STOP
		name_l.gui_input.connect(func(ev: InputEvent) -> void: _on_row_click(ev, i))
		hb.add_child(name_l)
		r["name_label"] = name_l
		r["left_btn"] = null
		r["right_btn"] = null
		r["exec_btn"] = null
		if action == "":
			# D75: 値の行は ◀ / ▶ をボタンにする (マウスで変更できる)。
			var lb: Button = _make_step_btn("◀", i, -1)
			hb.add_child(lb)
			r["left_btn"] = lb
		var val_l := Label.new()
		val_l.add_theme_font_size_override("font_size", 22)
		val_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		val_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		val_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		val_l.mouse_filter = Control.MOUSE_FILTER_STOP
		val_l.gui_input.connect(func(ev: InputEvent) -> void: _on_row_click(ev, i))
		hb.add_child(val_l)
		r["value_label"] = val_l
		if action == "":
			var rb: Button = _make_step_btn("▶", i, 1)
			hb.add_child(rb)
			r["right_btn"] = rb
		else:
			# 実行行 (再生/初期化/戻る) は実行ボタン (D75)。
			var eb := Button.new()
			eb.custom_minimum_size = Vector2(0, 36)
			eb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			eb.focus_mode = Control.FOCUS_NONE
			eb.pressed.connect(func() -> void: _on_exec(i))
			hb.add_child(eb)
			r["exec_btn"] = eb
		_refresh_row(r)
	_highlight()


func _make_step_btn(text: String, row_i: int, dir: int) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(46, 34)
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(func() -> void: _on_step(row_i, dir))
	return b


func _refresh_row(r: Dictionary) -> void:
	var name_l: Label = r["name_label"]
	var val_l: Label = r["value_label"]
	var action: String = str(r.get("action", ""))
	name_l.text = str(r["name"])
	if action == "":
		var vals: Array = r["values"]
		var v: String = str(vals[int(r["index"])])
		var full: bool = str(r["id"]) == "resolution" and str(SaveData.options.get("mode", OptDB.MODE_WINDOW)) == OptDB.MODE_FULLSCREEN
		val_l.text = v if not full else ("%s (フルスクリーン中は無効)" % v)
		val_l.modulate = Color(0.62, 0.62, 0.68, 1) if full else Color(1, 1, 1, 1)
		var lb: Button = r["left_btn"]
		var rb: Button = r["right_btn"]
		if lb != null:
			lb.disabled = full
		if rb != null:
			rb.disabled = full
		return
	val_l.text = ""
	match str(r["id"]):
		"replay":
			(r["exec_btn"] as Button).text = "▶ 再生 (スタッフロール)"
		"reset":
			(r["exec_btn"] as Button).text = "初期化する…"
		"back":
			(r["exec_btn"] as Button).text = "戻る"


func _highlight() -> void:
	for i: int in range(rows.size()):
		var r: Dictionary = rows[i]
		var sel: bool = i == idx
		var name_l: Label = r["name_label"]
		name_l.text = ("> " if sel else "  ") + str(r["name"])
		name_l.modulate = Color(1, 0.85, 0.4, 1) if sel else Color(0.85, 0.87, 0.92, 1)


func _process(_delta: float) -> void:
	if not visible:
		return
	if absf(Input.get_joy_axis(0, JOY_AXIS_LEFT_Y)) < 0.2:
		_axis_armed_v = true
	# D82: 左右もニュートラルに戻ったら再武装する (倒しっぱなしで連続発火させない)。
	if absf(Input.get_joy_axis(0, JOY_AXIS_LEFT_X)) < 0.2:
		_axis_armed_h = true


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and (event as InputEventKey).echo:
		return
	var motion: bool = event is InputEventJoypadMotion
	if confirming:
		_confirm_input(event)
		return
	if event.is_action_pressed("ui_up") or event.is_action_pressed("move_up"):
		if motion and not _axis_armed_v:
			return
		if motion:
			_axis_armed_v = false
		get_viewport().set_input_as_handled()
		_move(-1)
		return
	if event.is_action_pressed("ui_down") or event.is_action_pressed("move_down"):
		if motion and not _axis_armed_v:
			return
		if motion:
			_axis_armed_v = false
		get_viewport().set_input_as_handled()
		_move(1)
		return
	if event.is_action_pressed("ui_left") or event.is_action_pressed("move_left"):
		if motion and not _axis_armed_h:
			return
		if motion:
			_axis_armed_h = false
		get_viewport().set_input_as_handled()
		_change(-1)
		return
	if event.is_action_pressed("ui_right") or event.is_action_pressed("move_right"):
		if motion and not _axis_armed_h:
			return
		if motion:
			_axis_armed_h = false
		get_viewport().set_input_as_handled()
		_change(1)
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()
		return
	if event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		_activate()
		return
	if event is InputEventJoypadButton and (event as InputEventJoypadButton).pressed:
		var bi: int = (event as InputEventJoypadButton).button_index
		if bi == JOY_BUTTON_A:
			get_viewport().set_input_as_handled()
			_activate()
			return
		if bi == JOY_BUTTON_B:
			get_viewport().set_input_as_handled()
			close()


## 初期化の確認中の入力 (D76)。はい/いいえの切替・決定・取消。
func _confirm_input(event: InputEvent) -> void:
	var motion: bool = event is InputEventJoypadMotion
	var horizontal: bool = event.is_action_pressed("ui_left") or event.is_action_pressed("move_left") \
			or event.is_action_pressed("ui_right") or event.is_action_pressed("move_right")
	var vertical: bool = event.is_action_pressed("ui_up") or event.is_action_pressed("move_up") \
			or event.is_action_pressed("ui_down") or event.is_action_pressed("move_down")
	if horizontal or vertical:
		# D82: スティックは倒しっぱなしで連続発火しないよう、軸ごとにラッチする。
		if motion:
			if horizontal and not _axis_armed_h:
				return
			if vertical and not _axis_armed_v:
				return
			if horizontal:
				_axis_armed_h = false
			if vertical:
				_axis_armed_v = false
		get_viewport().set_input_as_handled()
		_set_confirm(1 - confirm_idx)
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_confirm_answer(false)
		return
	if event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		_confirm_answer(confirm_idx == 0)
		return
	if event is InputEventJoypadButton and (event as InputEventJoypadButton).pressed:
		var bi: int = (event as InputEventJoypadButton).button_index
		if bi == JOY_BUTTON_A:
			get_viewport().set_input_as_handled()
			_confirm_answer(confirm_idx == 0)
			return
		if bi == JOY_BUTTON_B:
			get_viewport().set_input_as_handled()
			_confirm_answer(false)


func _move(dir: int) -> void:
	if rows.is_empty():
		return
	idx = clampi(idx + dir, 0, rows.size() - 1)
	_play_ui()
	_highlight()


func _select(row_i: int) -> void:
	if row_i < 0 or row_i >= rows.size():
		return
	if idx != row_i:
		idx = row_i
		_highlight()
		_play_ui()


func _change(dir: int) -> void:
	if rows.is_empty() or confirming:
		return
	var r: Dictionary = rows[idx]
	if str(r.get("action", "")) != "":
		return
	var vals: Array = r["values"]
	if vals.is_empty():
		return
	# フルスクリーン中の解像度は変更しない (ウィンドウに戻してから)。
	if str(r["id"]) == "resolution" and str(SaveData.options.get("mode", OptDB.MODE_WINDOW)) == OptDB.MODE_FULLSCREEN:
		_play_ui()
		return
	r["index"] = (int(r["index"]) + dir + vals.size()) % vals.size()
	_apply_row(r)
	for other: Dictionary in rows:
		_refresh_row(other)
	_highlight()
	_play_ui()


func _activate() -> void:
	if rows.is_empty() or confirming:
		return
	var r: Dictionary = rows[idx]
	var action: String = str(r.get("action", ""))
	if action == "close":
		_play_ui()
		close()
		return
	if action == "replay":
		_play_ui()
		staff_replay_pressed.emit()
		return
	if action == "reset":
		_begin_reset()
		return
	# 表示モード・解像度は決定でも次へ送る (◀▶ と同じ)。
	_change(1)


func _apply_row(r: Dictionary) -> void:
	var id: String = str(r["id"])
	match id:
		"mode":
			var m: String = OptDB.MODE_WINDOW if int(r["index"]) == 0 else OptDB.MODE_FULLSCREEN
			SaveData.set_option("mode", m)
		"resolution":
			SaveData.set_option("resolution", OptDB.resolution_at(int(r["index"])))
		"bgm":
			SaveData.set_option("bgm", OptDB.clamp_volume(float(int(r["index"])) * OptDB.VOL_STEP))
		"se":
			SaveData.set_option("se", OptDB.clamp_volume(float(int(r["index"])) * OptDB.VOL_STEP))
	SaveData.apply_options()


# --- マウス (D75) ---

func _on_row_click(ev: InputEvent, row_i: int) -> void:
	if ev is InputEventMouseButton and ev.pressed and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		_select(row_i)


func _on_step(row_i: int, dir: int) -> void:
	_select(row_i)
	_change(dir)


func _on_exec(row_i: int) -> void:
	_select(row_i)
	_activate()


# --- セーブデータ初期化 (D76) ---

func _begin_reset() -> void:
	confirming = true
	confirm_idx = 1  # 既定は「いいえ」(破壊的操作のため)
	rows_box.hide()
	confirm_box.show()
	hint_label.text = HINT_CONFIRM
	_set_confirm(confirm_idx)
	_play_ui()


## はい/いいえの見た目 (フォーカスを使わないため modulate で示す)。
func _set_confirm(i: int) -> void:
	confirm_idx = clampi(i, 0, 1)
	yes_btn.modulate = Color(1, 0.85, 0.4, 1) if confirm_idx == 0 else Color(0.85, 0.87, 0.92, 1)
	no_btn.modulate = Color(1, 0.85, 0.4, 1) if confirm_idx == 1 else Color(0.85, 0.87, 0.92, 1)


func _confirm_answer(yes_choice: bool) -> void:
	confirming = false
	confirm_box.hide()
	rows_box.show()
	hint_label.text = HINT_NORMAL
	if not yes_choice:
		_play_ui()
		return
	# 進行状況のみ消す (オプション設定は保持)・即保存。
	SaveData.reset_progress()
	idx = 0
	rebuild()
	var audio: Node = get_tree().get_first_node_in_group("audio")
	if audio != null:
		audio.call("play", "beep")
	hint_label.text = HINT_NORMAL + "　※ セーブデータを初期化しました (オプション設定は保持)"


func _play_ui() -> void:
	var audio: Node = get_tree().get_first_node_in_group("audio")
	if audio != null:
		audio.call("play", "ui")
