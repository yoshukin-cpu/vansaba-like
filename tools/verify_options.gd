extends SceneTree
## P21 検証: v1.8 オプション (SPEC §35.2〜§35.4) — 解像度16件 (4K)・フィット/クランプ・
## 音量バス・セーブ v2 (v1互換・破損時)・オプション画面の行構成 (秘密項目)・強化画面。
## 実行: godot --headless --fixed-fps 60 --path <project> --script res://tools/verify_options.gd

const SaveData := preload("res://systems/save_data.gd")
const MetaDB := preload("res://data/meta_upgrades.gd")
const OptDB := preload("res://data/options_db.gd")
const OptionsScene: PackedScene = preload("res://ui/options_ui.tscn")
const UpgradeScene: PackedScene = preload("res://ui/upgrade_ui.tscn")
const MainScene: PackedScene = preload("res://main.tscn")

const TEST_SAVE := "user://test_options_save.json"

var failures := 0


func _check(label: String, ok: bool) -> void:
	if ok:
		print("PASS ", label)
	else:
		failures += 1
		print("FAIL ", label)


func _near(a: float, b: float, eps: float = 0.02) -> bool:
	return absf(a - b) <= eps


func _remove_save() -> void:
	if FileAccess.file_exists(TEST_SAVE):
		DirAccess.remove_absolute(TEST_SAVE)


func _write_raw(text: String) -> void:
	var f: FileAccess = FileAccess.open(TEST_SAVE, FileAccess.WRITE)
	f.store_string(text)
	f.close()


func _init() -> void:
	SaveData.path = TEST_SAVE
	_remove_save()
	_t_resolutions()
	_t_fit()
	_t_volumes()
	_t_save_v2()
	await _t_options_ui()
	await _t_upgrade_ui()
	await _t_modal_isolation()
	await _t_reset_save()
	# 後始末
	OptDB.apply_volume(OptDB.DEFAULT_BGM, OptDB.DEFAULT_SE)
	SaveData.path = SaveData.DEFAULT_PATH
	SaveData.reset()
	_remove_save()
	print("RESULT: ", "ALL PASS" if failures == 0 else "%d FAILURE(S)" % failures)
	quit(1 if failures > 0 else 0)


# === 1) 解像度定義 ===

func _t_resolutions() -> void:
	print("\n=== 1) 解像度 (16件・4Kまで) ===")
	_check("16件", OptDB.RESOLUTIONS.size() == 16)
	_check("先頭は 1152x648 (既定)", OptDB.resolution_at(0) == "1152x648")
	_check("16:9 の4K 3840x2160 がある", OptDB.is_valid_resolution("3840x2160"))
	_check("16:10 の4K 3840x2400 がある", OptDB.is_valid_resolution("3840x2400"))
	_check("4:3 の4K級 2880x2160 がある", OptDB.is_valid_resolution("2880x2160"))
	_check("2560x1440 がある", OptDB.is_valid_resolution("2560x1440"))
	_check("無効な解像度は false", not OptDB.is_valid_resolution("9999x1"))
	_check("巡回が先頭に戻る", OptDB.resolution_at(16) == "1152x648")
	_check("比率ラベル 16:9", OptDB.aspect_label(Vector2i(1920, 1080)) == "16:9")
	_check("比率ラベル 16:10", OptDB.aspect_label(Vector2i(1920, 1200)) == "16:10")
	_check("比率ラベル 4:3", OptDB.aspect_label(Vector2i(1600, 1200)) == "4:3")
	_check("表示形式", OptDB.resolution_label("1280x720") == "1280×720 (16:9)")


# === 2) フィット・クランプ・中央 ===

func _t_fit() -> void:
	print("\n=== 2) フィットとクランプ ===")
	var big: Rect2i = Rect2i(0, 0, 1920, 1040)
	var s: Vector2i = OptDB.fitted_window_size("3840x2160", big)
	_check("4K は 1080p 画面に等比で収まる (%dx%d)" % [s.x, s.y], s.x <= 1920 and s.y <= 1040 and s.y >= 1039)
	var s2: Vector2i = OptDB.fitted_window_size("1280x720", Rect2i(0, 0, 1920, 1080))
	_check("収まる解像度はそのまま (1280x720)", s2 == Vector2i(1280, 720))
	var s3: Vector2i = OptDB.fitted_window_size("3840x2160", Rect2i(0, 0, 7680, 4320))
	_check("4K モニタでは 4K のまま", s3 == Vector2i(3840, 2160))
	var s4: Vector2i = OptDB.fitted_window_size("1600x1200", Rect2i(0, 0, 1920, 1040))
	_check("縦が余る解像度は縦基準で縮小 (%dx%d)" % [s4.x, s4.y], s4.y <= 1040 and s4.x <= 1920)
	var p: Vector2i = OptDB.centered_position(Rect2i(0, 0, 1920, 1080), Vector2i(1280, 720))
	_check("中央配置 (320,180)", p == Vector2i(320, 180))


# === 3) 音量バス ===

func _t_volumes() -> void:
	print("\n=== 3) 音量バス ===")
	_check("0.83 は 5% 刻みで 0.85", _near(OptDB.clamp_volume(0.83), 0.85))
	_check("負値は 0 に", OptDB.clamp_volume(-0.5) == 0.0)
	_check("1 超は 1 に", OptDB.clamp_volume(1.5) == 1.0)
	OptDB.apply_volume(0.5, 0.0)
	_check("BGM バス 50%", _near(OptDB.bus_volume("BGM"), 0.5, 0.03))
	var se_idx: int = AudioServer.get_bus_index("SE")
	_check("SE 0% はミュート", AudioServer.is_bus_mute(se_idx))
	OptDB.apply_volume(1.0, 1.0)
	_check("100% でミュート解除・1.0", not AudioServer.is_bus_mute(se_idx) and _near(OptDB.bus_volume("SE"), 1.0))


# === 4) セーブ v2 ===

func _t_save_v2() -> void:
	print("\n=== 4) セーブ v2 ===")
	_remove_save()
	SaveData.reset()
	_check("既定: コイン0・強化なし・オプション既定",
		SaveData.coins == 0 and SaveData.upgrades.is_empty()
		and float(SaveData.options["bgm"]) == 0.8 and float(SaveData.options["se"]) == 1.0)
	SaveData.add_coins(30)
	_check("コイン加算 + 保存", SaveData.coins == 30 and FileAccess.file_exists(TEST_SAVE))
	_check("購入: M01 (10コイン)", SaveData.purchase("M01") and SaveData.coins == 20 and int(SaveData.upgrades["M01"]) == 1)
	_check("2回目は 15 コイン", SaveData.purchase("M01") and SaveData.coins == 5 and int(SaveData.upgrades["M01"]) == 2)
	_check("コイン不足は買えない", not SaveData.purchase("M01") and int(SaveData.upgrades["M01"]) == 2)
	_check("spend_coins は保存しない (残高のみ)",
		SaveData.spend_coins(5) and SaveData.coins == 0 and not SaveData.spend_coins(1))
	SaveData.upgrades["M02"] = 10
	_check("MAX は購入不可", not SaveData.purchase("M02"))
	_check("未知の ID は購入不可", not SaveData.purchase("ZZZ"))
	SaveData.coins = 123
	SaveData.set_option("bgm", 0.5)
	SaveData.save_now()
	SaveData.reset()
	SaveData.load_save()
	_check("往復: コイン 123・M01 lv2・bgm 0.5",
		SaveData.coins == 123 and int(SaveData.upgrades.get("M01", 0)) == 2
		and _near(float(SaveData.options["bgm"]), 0.5))
	# v1 互換 (coins/upgrades/options なし)
	_write_raw('{"version": 1, "cleared": ["normal"], "insane_cleared": 0, "last": "hard"}')
	SaveData.reset()
	SaveData.load_save()
	_check("v1 ファイルが読める",
		SaveData.cleared == ["normal"] and SaveData.last == "hard" and SaveData.coins == 0
		and SaveData.upgrades.is_empty() and _near(float(SaveData.options["bgm"]), 0.8))
	# 壊れたファイル → 初期状態
	_write_raw("{broken json")
	SaveData.reset()
	SaveData.load_save()
	_check("破損時は初期状態", SaveData.cleared.is_empty() and SaveData.coins == 0 and SaveData.last == "normal")
	# 不正値の丸め (MAX 超え・不正な解像度)
	_write_raw('{"version": 2, "cleared": [], "coins": -5, "upgrades": {"M01": 99}, "options": {"mode": "bogus", "resolution": "999x1", "bgm": 9}}')
	SaveData.reset()
	SaveData.load_save()
	_check("不正値は丸める (coins0・M01 MAX・既定解像度・bgm1.0)",
		SaveData.coins == 0 and int(SaveData.upgrades["M01"]) == 10 and str(SaveData.options["mode"]) == "window"
		and str(SaveData.options["resolution"]) == "1152x648" and _near(float(SaveData.options["bgm"]), 1.0))


# === 5) オプション画面 (秘密項目) ===

func _t_options_ui() -> void:
	print("\n=== 5) オプション画面 ===")
	SaveData.reset()
	SaveData.cleared = []
	var opts: CanvasLayer = OptionsScene.instantiate() as CanvasLayer
	root.add_child(opts)
	await process_frame
	opts.call("rebuild")
	var ids0: Array = opts.call("row_ids")
	_check("未解放では再演の行が無い (秘密項目)", not ids0.has("replay"))
	_check("行は 表示/解像度/BGM/SE/初期化/戻る", ids0 == ["mode", "resolution", "bgm", "se", "reset", "back"])
	SaveData.cleared = ["normal"]
	opts.call("rebuild")
	var ids1: Array = opts.call("row_ids")
	_check("解放後は再演の行が現れる (初期化の上)", ids1.has("replay") and str(ids1[ids1.size() - 3]) == "replay" and str(ids1[ids1.size() - 2]) == "reset" and str(ids1[ids1.size() - 1]) == "back")
	var rows: Array = opts.get("rows")
	var res_row: Dictionary = {}
	for r: Dictionary in rows:
		if str(r["id"]) == "resolution":
			res_row = r
	_check("解像度の選択肢は16件", (res_row["values"] as Array).size() == 16)
	# 解像度を1つ進める → 保存と値が変わる
	opts.set("idx", rows.find(res_row))
	SaveData.set_option("resolution", "1152x648")
	opts.call("rebuild")
	rows = opts.get("rows")
	for r2: Dictionary in rows:
		if str(r2["id"]) == "resolution":
			res_row = r2
	opts.set("idx", rows.find(res_row))
	opts.call("_change", 1)
	_check("解像度が 1280x720 に進む", str(SaveData.options["resolution"]) == "1280x720")
	opts.call("_change", -1)
	_check("戻すと 1152x648", str(SaveData.options["resolution"]) == "1152x648")
	# 音量行
	for r3: Dictionary in opts.get("rows"):
		if str(r3["id"]) == "bgm":
			opts.set("idx", (opts.get("rows") as Array).find(r3))
	opts.call("_change", -1)
	_check("BGM 音量が 5% 下がる (0.75)", _near(float(SaveData.options["bgm"]), 0.75))
	opts.free()


# === 6) 強化画面 ===

func _t_upgrade_ui() -> void:
	print("\n=== 6) 強化画面 ===")
	SaveData.reset()
	SaveData.coins = 100
	var up: CanvasLayer = UpgradeScene.instantiate() as CanvasLayer
	root.add_child(up)
	await process_frame
	up.call("open")
	var rows: Array = up.get("rows")
	_check("行は 8項目 + 戻る", rows.size() == 9 and str((rows[0] as Dictionary)["id"]) == "M01" and str((rows[8] as Dictionary)["id"]) == "back")
	_check("初期表示 Lv 0/10・10 コイン",
		str((rows[0] as Dictionary)["lv_label"].text) == "Lv 0/10"
		and str((rows[0] as Dictionary)["cost_label"].text) == "10 コイン")
	up.set("idx", 0)
	up.call("_activate")
	_check("購入: コイン 90・M01 lv1・表示更新",
		SaveData.coins == 90 and int(SaveData.upgrades["M01"]) == 1
		and str((rows[0] as Dictionary)["lv_label"].text) == "Lv 1/10"
		and str((rows[0] as Dictionary)["cost_label"].text) == "15 コイン")
	SaveData.coins = 0
	up.call("refresh")
	_check("コイン 0 ではコストが赤 (購入不可表示)",
		(rows[0] as Dictionary)["cost_label"].modulate.r > 0.9 and (rows[0] as Dictionary)["cost_label"].modulate.g < 0.5)
	up.call("_activate")
	_check("コイン 0 では購入されない", int(SaveData.upgrades["M01"]) == 1)
	SaveData.upgrades["M01"] = 10
	up.call("refresh")
	_check("MAX は「—」表示", str((rows[0] as Dictionary)["cost_label"].text) == "—")
	_check("MAX は購入不可", not MetaDB.is_max(SaveData.upgrades, "M02") and MetaDB.is_max(SaveData.upgrades, "M01"))
	_check("MAX の行は購入ボタンが無効", bool((rows[0] as Dictionary)["buy_btn"].disabled))
	_check("コイン不足の行は購入ボタンが無効", bool((rows[1] as Dictionary)["buy_btn"].disabled))
	SaveData.coins = 100
	up.call("refresh")
	_check("コインが足りれば購入ボタンが有効 (クリックで購入)", not bool((rows[1] as Dictionary)["buy_btn"].disabled))
	(rows[1] as Dictionary)["buy_btn"].pressed.emit()
	_check("購入ボタンで M02 が買える (D75)", int(SaveData.upgrades["M02"]) == 1 and int(SaveData.coins) == 100 - MetaDB.cost("M02", 0))
	(rows[8] as Dictionary)["back_btn"].pressed.emit()
	await process_frame
	_check("戻るボタンで閉じる (D75)", not bool(up.visible))
	up.free()


# === 7) モーダルの入力隔離とマウス操作 (D74/D75) ===

func _key_ev(code: Key, pressed: bool) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.pressed = pressed
	return ev


func _action_ev(name: String, pressed: bool) -> InputEventAction:
	var ev := InputEventAction.new()
	ev.action = name
	ev.pressed = pressed
	return ev


func _inject(ev: InputEvent) -> void:
	Input.parse_input_event(ev)
	await process_frame
	await process_frame


func _click_at(pos: Vector2) -> void:
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = pos
	down.global_position = pos
	await _inject(down)
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = pos
	up.global_position = pos
	await _inject(up)


func _t_modal_isolation() -> void:
	print("\n=== 7) モーダルの入力隔離とマウス操作 (D74/D75) ===")
	SaveData.reset()
	SaveData.cleared = ["normal"]
	SaveData.coins = 40
	SaveData.save_now()
	var main: Node = MainScene.instantiate()
	root.add_child(main)
	current_scene = main
	for i: int in range(6):
		await process_frame
	var title: CanvasLayer = main.get_node("TitleUI")
	var opts: CanvasLayer = main.get_node("OptionsUI")
	var start_btn: Button = title.get_node("Center/VBox/StartBtn")
	start_btn.grab_focus()
	await process_frame
	_check("前提: タイトルの「はじめる」にフォーカス", root.gui_get_focus_owner() == start_btn)
	main.call("_on_options")
	for i: int in range(4):
		await process_frame
	_check("オプションを開くとフォーカスが解放される (D74)", root.gui_get_focus_owner() == null)
	_check("オプションが表示されている", bool(opts.visible))
	# --- キーボード (D74: フォーカスが残っているとタイトルに食われて動かない) ---
	opts.set("idx", 0)
	await _inject(_action_ev("ui_down", true))
	await _inject(_action_ev("ui_down", false))
	_check("キーボード ↓ で項目が動く (idx=1)", int(opts.get("idx")) == 1)
	var mode_before: String = str(SaveData.options["mode"])
	opts.set("idx", 0)
	await _inject(_key_ev(KEY_ENTER, true))
	await _inject(_key_ev(KEY_ENTER, false))
	await process_frame
	_check("Enter がオプションに効く (表示モードが切替)", str(SaveData.options["mode"]) != mode_before)
	_check("タイトルは開始しない (操作リークなし)", bool(title.visible) and not bool(main.get("result_shown")))
	# --- マウス: ◀▶ ボタン (D75) ---
	# 注意: headless ではマウスイベントが GUI に届かないため、ここでは配線 (pressed → 変更) を確認し、
	# 実際のクリック (ヒットテスト) は窓ありの tools/verify_options_mouse.gd で確認する。
	SaveData.set_option("mode", OptDB.MODE_WINDOW)
	opts.call("rebuild")
	for i: int in range(3):
		await process_frame
	var rows: Array = opts.get("rows")
	var res_i: int = 1
	opts.set("idx", res_i)
	var res_before: String = str(SaveData.options["resolution"])
	var rb: Button = (rows[res_i] as Dictionary)["right_btn"]
	var lb: Button = (rows[res_i] as Dictionary)["left_btn"]
	_check("値の行に ◀ / ▶ ボタンがある (D75)", rb != null and lb != null)
	_check("◀ / ▶ は画面のフォーカスを奪わない (D74)", rb.focus_mode == Control.FOCUS_NONE and lb.focus_mode == Control.FOCUS_NONE)
	rb.pressed.emit()
	_check("▶ で値が進む (D75: %s → %s)" % [res_before, str(SaveData.options["resolution"])], str(SaveData.options["resolution"]) != res_before)
	lb.pressed.emit()
	_check("◀ で戻る (D75)", str(SaveData.options["resolution"]) == res_before)
	var exec_btn: Button = (rows[rows.size() - 1] as Dictionary)["exec_btn"]
	_check("戻る行に実行ボタンがある (D75)", exec_btn != null and str(exec_btn.text) == "戻る")
	_check("実行ボタンもフォーカスを奪わない", exec_btn.focus_mode == Control.FOCUS_NONE)
	# --- モーダルの Dim がクリックを遮る (D74) ---
	var dim: ColorRect = opts.get_node("Dim")
	var vp: Vector2 = root.get_visible_rect().size
	_check("Dim は全画面 + STOP でクリックを遮る (D74)",
		dim.mouse_filter == Control.MOUSE_FILTER_STOP
		and is_equal_approx(dim.size.x, vp.x) and is_equal_approx(dim.size.y, vp.y))
	var starts := 0
	var quits := 0
	title.connect("start_pressed", func() -> void: starts += 1)
	title.connect("quit_pressed", func() -> void: quits += 1)
	_check("前提: モーダル表示中はタイトルが動いていない", starts == 0 and quits == 0 and bool(title.visible))
	# --- 閉じたらフォーカスが戻る (D74) ---
	opts.call("close")
	for i: int in range(3):
		await process_frame
	_check("閉じるとタイトルへフォーカスが戻る (D74)", root.gui_get_focus_owner() == start_btn)
	main.free()


# === 8) セーブデータ初期化 (D76) ===

func _t_reset_save() -> void:
	print("\n=== 8) セーブデータ初期化 (D76) ===")
	SaveData.reset()
	SaveData.cleared = ["normal", "hard"]
	SaveData.insane_cleared = 2
	SaveData.last = "hard"
	SaveData.coins = 123
	SaveData.upgrades = {"M01": 3}
	SaveData.options = {"mode": OptDB.MODE_WINDOW, "resolution": "1600x900", "bgm": 0.6, "se": 0.9}
	SaveData.save_now()
	var opts: CanvasLayer = OptionsScene.instantiate() as CanvasLayer
	root.add_child(opts)
	await process_frame
	opts.call("open")
	for i: int in range(2):
		await process_frame
	var ids: Array = opts.call("row_ids")
	_check("初期化の行がある (戻るの上)", ids.has("reset") and str(ids[ids.size() - 2]) == "reset" and str(ids[ids.size() - 1]) == "back")
	opts.set("idx", ids.find("reset"))
	opts.call("_activate")
	await process_frame
	_check("決定で確認 (はい/いいえ) に移る (D76)", bool(opts.get("confirming")))
	_check("既定は「いいえ」(破壊的操作のため)", int(opts.get("confirm_idx")) == 1)
	var rows_box: Control = opts.get_node("Panel/Rows")
	var confirm_box: Control = opts.get_node("Panel/Confirm")
	_check("確認中は行一覧を隠して確認を出す", not rows_box.visible and confirm_box.visible)
	_check("確認の説明にオプション保持を明記", "オプション設定は保存されます" in str((opts.get_node("Panel/Confirm/ConfirmNote") as Label).text))
	opts.call("_confirm_answer", false)
	await process_frame
	_check("「いいえ」では消えない", SaveData.cleared.size() == 2 and SaveData.coins == 123 and int(SaveData.upgrades.get("M01", 0)) == 3)
	_check("「いいえ」で行一覧へ戻る", rows_box.visible and not confirm_box.visible)
	# はい (マウスクリック) → 進行状況のみ消える
	opts.set("idx", (opts.call("row_ids") as Array).find("reset"))
	opts.call("_activate")
	await process_frame
	var yes: Button = opts.get_node("Panel/Confirm/ConfirmRow/YesBtn")
	var no: Button = opts.get_node("Panel/Confirm/ConfirmRow/NoBtn")
	_check("確認のボタンはフォーカスを奪わない (D74)", yes.focus_mode == Control.FOCUS_NONE and no.focus_mode == Control.FOCUS_NONE)
	yes.pressed.emit()
	await process_frame
	_check("「はい」で進行状況が消える", SaveData.cleared.is_empty() and SaveData.insane_cleared == 0 and int(SaveData.coins) == 0 and SaveData.upgrades.is_empty())
	_check("オプション設定は保持される (D76)",
		str(SaveData.options["resolution"]) == "1600x900" and _near(float(SaveData.options["bgm"]), 0.6)
		and _near(float(SaveData.options["se"]), 0.9) and str(SaveData.options["mode"]) == OptDB.MODE_WINDOW)
	_check("確認は閉じて行一覧へ戻る", bool(rows_box.visible) and not bool(confirm_box.visible) and not bool(opts.get("confirming")))
	_check("初期化後は再演の行が消える (秘密項目)", not (opts.call("row_ids") as Array).has("replay"))
	_check("初期化したことを知らせる", "初期化しました" in str((opts.get_node("Panel/Hint") as Label).text))
	var txt: String = ""
	var f: FileAccess = FileAccess.open(TEST_SAVE, FileAccess.READ)
	if f != null:
		txt = f.get_as_text()
		f.close()
	var parsed: Variant = JSON.parse_string(txt)
	var pd: Dictionary = parsed as Dictionary if parsed is Dictionary else {}
	var op: Dictionary = pd.get("options", {}) as Dictionary
	_check("保存ファイルも初期化済み (cleared 空・コイン0)",
		not pd.is_empty() and (pd.get("cleared", []) as Array).is_empty() and int(pd.get("coins", -1)) == 0)
	_check("保存ファイルにオプションが残る (D76)", str(op.get("resolution", "")) == "1600x900" and _near(float(op.get("bgm", 0.0)), 0.6))
	opts.free()
