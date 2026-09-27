extends SceneTree
## P21 検証: v1.8 オプション (SPEC §35.2〜§35.4) — 解像度16件 (4K)・フィット/クランプ・
## 音量バス・セーブ v2 (v1互換・破損時)・オプション画面の行構成 (秘密項目)・強化画面。
## 実行: godot --headless --fixed-fps 60 --path <project> --script res://tools/verify_options.gd

const SaveData := preload("res://systems/save_data.gd")
const MetaDB := preload("res://data/meta_upgrades.gd")
const OptDB := preload("res://data/options_db.gd")
const OptionsScene: PackedScene = preload("res://ui/options_ui.tscn")
const UpgradeScene: PackedScene = preload("res://ui/upgrade_ui.tscn")

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
	_check("行は 表示/解像度/BGM/SE/戻る", ids0 == ["mode", "resolution", "bgm", "se", "back"])
	SaveData.cleared = ["normal"]
	opts.call("rebuild")
	var ids1: Array = opts.call("row_ids")
	_check("解放後は再演の行が現れる (戻るの上)", ids1.has("replay") and str(ids1[ids1.size() - 2]) == "replay" and str(ids1[ids1.size() - 1]) == "back")
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
	up.free()
