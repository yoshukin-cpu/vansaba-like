extends CanvasLayer
## オプション画面 (SPEC §35.2〜§35.4、v1.8/案6)。
## 表示モード / 解像度16件 (4Kまで) / BGM・SE 音量 / スタッフロール再演 (1回クリアで解放・秘密項目) / 戻る。
## 変更は即時適用 + 即保存する。導線はタイトル画面のみ。

signal closed
signal staff_replay_pressed

const SaveData := preload("res://systems/save_data.gd")
const OptDB := preload("res://data/options_db.gd")

@onready var rows_box: VBoxContainer = $Panel/Rows

## 表示中の行 [{id, name, values, index, action, name_label, value_label}]。
var rows: Array = []
var idx: int = 0
var _axis_armed_v: bool = true


func _ready() -> void:
	visible = false
	add_to_group("modal_ui")


func open() -> void:
	rebuild()
	visible = true
	_axis_armed_v = true


func close() -> void:
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
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 12)
		rows_box.add_child(hb)
		var name_l := Label.new()
		name_l.custom_minimum_size = Vector2(280, 34)
		name_l.add_theme_font_size_override("font_size", 22)
		name_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		hb.add_child(name_l)
		var val_l := Label.new()
		val_l.add_theme_font_size_override("font_size", 22)
		val_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		val_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		val_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hb.add_child(val_l)
		r["name_label"] = name_l
		r["value_label"] = val_l
		_refresh_row(r)
	_highlight()


func _refresh_row(r: Dictionary) -> void:
	var name_l: Label = r["name_label"]
	var val_l: Label = r["value_label"]
	var action: String = str(r.get("action", ""))
	name_l.text = str(r["name"])
	if action == "replay":
		val_l.text = "▶ 再生"
	elif action == "close":
		val_l.text = ""
	else:
		var vals: Array = r["values"]
		var v: String = str(vals[int(r["index"])])
		var full: bool = str(r["id"]) == "resolution" and str(SaveData.options.get("mode", OptDB.MODE_WINDOW)) == OptDB.MODE_FULLSCREEN
		val_l.text = ("◀ %s ▶" % v) if not full else ("◀ %s ▶ (フルスクリーン中は無効)" % v)
		val_l.modulate = Color(0.62, 0.62, 0.68, 1) if full else Color(1, 1, 1, 1)


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


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and (event as InputEventKey).echo:
		return
	var motion: bool = event is InputEventJoypadMotion
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
		get_viewport().set_input_as_handled()
		_change(-1)
		return
	if event.is_action_pressed("ui_right") or event.is_action_pressed("move_right"):
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


func _move(dir: int) -> void:
	if rows.is_empty():
		return
	idx = clampi(idx + dir, 0, rows.size() - 1)
	_play_ui()
	_highlight()


func _change(dir: int) -> void:
	if rows.is_empty():
		return
	var r: Dictionary = rows[idx]
	if str(r.get("action", "")) != "":
		return
	var vals: Array = r["values"]
	if vals.is_empty():
		return
	r["index"] = (int(r["index"]) + dir + vals.size()) % vals.size()
	_apply_row(r)
	for other: Dictionary in rows:
		_refresh_row(other)
	_highlight()
	_play_ui()


func _activate() -> void:
	if rows.is_empty():
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


func _play_ui() -> void:
	var audio: Node = get_tree().get_first_node_in_group("audio")
	if audio != null:
		audio.call("play", "ui")
