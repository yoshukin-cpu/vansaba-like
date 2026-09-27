extends CanvasLayer
## 強化画面 (SPEC §35.8、v1.8/案6)。コインを使って恒久パワーアップを購入する。
## ランの開始時 (main.start_game) に反映される。未強化 (Lv0) は完全 no-op。

signal closed

const SaveData := preload("res://systems/save_data.gd")
const MetaDB := preload("res://data/meta_upgrades.gd")

@onready var coin_label: Label = $Panel/CoinLabel
@onready var rows_box: VBoxContainer = $Panel/Rows

## 行 [{id, name_label, lv_label, desc_label, cost_label}] + 最後に「戻る」行 (id == "back")。
var rows: Array = []
var idx: int = 0
var _axis_armed_v: bool = true


func _ready() -> void:
	visible = false
	add_to_group("modal_ui")
	_build()


func _build() -> void:
	for c: Node in rows_box.get_children():
		c.queue_free()
	rows = []
	for it: Dictionary in MetaDB.ITEMS:
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 14)
		rows_box.add_child(hb)
		var name_l := Label.new()
		name_l.custom_minimum_size = Vector2(170, 34)
		name_l.add_theme_font_size_override("font_size", 22)
		name_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		hb.add_child(name_l)
		var lv_l := Label.new()
		lv_l.custom_minimum_size = Vector2(110, 34)
		lv_l.add_theme_font_size_override("font_size", 20)
		lv_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		hb.add_child(lv_l)
		var desc_l := Label.new()
		desc_l.add_theme_font_size_override("font_size", 20)
		desc_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		desc_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hb.add_child(desc_l)
		var cost_l := Label.new()
		cost_l.custom_minimum_size = Vector2(160, 34)
		cost_l.add_theme_font_size_override("font_size", 20)
		cost_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		cost_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		hb.add_child(cost_l)
		rows.append({
			"id": str(it["id"]), "name_label": name_l, "lv_label": lv_l,
			"desc_label": desc_l, "cost_label": cost_l,
		})
	# 最後に「戻る」行 (Enter/A で閉じる)。
	var hb_back := HBoxContainer.new()
	hb_back.add_theme_constant_override("separation", 14)
	rows_box.add_child(hb_back)
	var back_l := Label.new()
	back_l.custom_minimum_size = Vector2(170, 34)
	back_l.add_theme_font_size_override("font_size", 22)
	back_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hb_back.add_child(back_l)
	rows.append({"id": "back", "name_label": back_l, "lv_label": null, "desc_label": null, "cost_label": null})


func open() -> void:
	refresh()
	visible = true
	_axis_armed_v = true


func close() -> void:
	visible = false
	closed.emit()


## 所持コイン・Lv・コスト表示を更新する。
func refresh() -> void:
	coin_label.text = "所持コイン %d" % SaveData.coins
	for r: Dictionary in rows:
		_update_row(r)
	_highlight()


func _update_row(r: Dictionary) -> void:
	var id: String = str(r["id"])
	if id == "back" or r["lv_label"] == null:
		return
	var lv: int = MetaDB.level_of(SaveData.upgrades, id)
	var maxlv: int = MetaDB.max_level(id)
	var d: Variant = MetaDB.def(id)
	r["name_label"].text = str((d as Dictionary)["name"])
	r["desc_label"].text = str((d as Dictionary)["desc"])
	r["lv_label"].text = "MAX" if lv >= maxlv else "Lv %d/%d" % [lv, maxlv]
	var cost_l: Label = r["cost_label"]
	if lv >= maxlv:
		cost_l.text = "—"
		cost_l.modulate = Color(0.55, 0.55, 0.62, 1)
	else:
		var c: int = MetaDB.cost(id, lv)
		cost_l.text = "%d コイン" % c
		cost_l.modulate = Color(0.95, 0.4, 0.4, 1) if SaveData.coins < c else Color(1, 1, 1, 1)


func _highlight() -> void:
	for i: int in range(rows.size()):
		var r: Dictionary = rows[i]
		var sel: bool = i == idx
		var col: Color = Color(1, 0.85, 0.4, 1) if sel else Color(0.85, 0.87, 0.92, 1)
		if str(r["id"]) == "back":
			(r["name_label"] as Label).text = ("> " if sel else "  ") + "戻る"
			(r["name_label"] as Label).modulate = col
			continue
		(r["name_label"] as Label).text = ("> " if sel else "  ") + str((MetaDB.def(str(r["id"])) as Dictionary)["name"])
		(r["name_label"] as Label).modulate = col
		(r["desc_label"] as Label).modulate = col


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
	_play("ui")
	_highlight()


func _activate() -> void:
	if rows.is_empty():
		return
	var r: Dictionary = rows[idx]
	var id: String = str(r["id"])
	if id == "back":
		_play("ui")
		close()
		return
	if MetaDB.is_max(SaveData.upgrades, id):
		_play("beep")
		return
	var cost: int = MetaDB.cost(id, MetaDB.level_of(SaveData.upgrades, id))
	if SaveData.coins < cost:
		_play("beep")
		return
	SaveData.purchase(id)
	_play("coin")
	refresh()


func _play(sname: String) -> void:
	var audio: Node = get_tree().get_first_node_in_group("audio")
	if audio != null:
		audio.call("play", sname)
