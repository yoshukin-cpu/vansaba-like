extends SceneTree
## P19 検証: v1.6 (案4) — 難易度・解放セーブ・カードフォールバック・ジェム3色・
## Lv表記・タイトルセレクタ・リザルト/スタッフロール連携。
## 実行: godot --headless --fixed-fps 60 --path <project> --script res://tools/verify_v16.gd
## 全ケースPASSで終了コード0、失敗があれば1。

const DiffDB := preload("res://data/difficulty_db.gd")
const SaveData := preload("res://systems/save_data.gd")
const CardsDB := preload("res://data/cards_db.gd")
const GemScript := preload("res://pickups/xp_gem.gd")
const WavesDB := preload("res://data/waves_db.gd")
const SpawnDirectorScript := preload("res://systems/spawn_director.gd")
const MainScene: PackedScene = preload("res://main.tscn")
const SlimeScene: PackedScene = preload("res://enemies/slime.tscn")
const B01Scene: PackedScene = preload("res://enemies/boss_golem_king.tscn")

const TEST_SAVE := "user://test_v16_save.json"
const FALLBACK_IDS := ["HEAL", "CXP", "CNOVA"]

var failures := 0


func _check(label: String, ok: bool) -> void:
	if ok:
		print("PASS ", label)
	else:
		failures += 1
		print("FAIL ", label)


func _near(a: float, b: float, eps: float = 0.01) -> bool:
	return absf(a - b) <= eps


func _remove_save() -> void:
	if FileAccess.file_exists(TEST_SAVE):
		DirAccess.remove_absolute(TEST_SAVE)


func _init() -> void:
	SaveData.path = TEST_SAVE
	_remove_save()
	_t_diff_table()
	_t_unlock_rules()
	_t_save_roundtrip()
	await _t_game_difficulty()
	await _t_game_cards_gems()
	await _t_title_selector()
	# 後始末 (テストが実セーブを汚さない)
	SaveData.path = SaveData.DEFAULT_PATH
	SaveData.reset()
	DiffDB.current_key = "normal"
	_remove_save()
	print("RESULT: ", "ALL PASS" if failures == 0 else "%d FAILURE(S)" % failures)
	quit(1 if failures > 0 else 0)


# === 1) 難易度の定義 ===

func _t_diff_table() -> void:
	print("\n=== 1) 難易度の定義 ===")
	_check("normal は全部 0", DiffDB.values("normal") == [0, 0, 0, 0, 0, 0, 0])
	_check("hard の値", DiffDB.values("hard") == [25, 25, 10, 20, 20, 5, 25])
	_check("hard の敵HP ×1.25", _near(DiffDB.hp_mult("hard"), 1.25))
	_check("hard のエリート・ボス ×1.5 (加算)", _near(DiffDB.elite_boss_hp_mult("hard"), 1.5))
	_check("hard のエリート比 1.2", _near(DiffDB.elite_ratio("hard"), 1.2))
	_check("insane3 = 300+90", int(DiffDB.values("insane3")[0]) == 390)
	_check("insane3 の敵HP ×4.9", _near(DiffDB.hp_mult("insane3"), 4.9))
	_check("insane の湧き間隔 ×1/3", _near(DiffDB.interval_mult("insane"), 1.0 / 3.0))
	_check("insane の上限は 400 クランプ", DiffDB.cap_for(280, "insane") == 400)
	_check("normal の上限はそのまま", DiffDB.cap_for(280, "normal") == 280)
	_check("エリート間隔 normal 120s", _near(DiffDB.elite_interval("normal"), 120.0))
	_check("エリート間隔 hard 96s", _near(DiffDB.elite_interval("hard"), 96.0))
	_check("名前 hard", DiffDB.display_name("hard") == "ハード")
	_check("名前 insane3", DiffDB.display_name("insane3") == "インセイン3")
	_check("valid: insane3", DiffDB.is_valid("insane3"))
	_check("valid: insane0 は無効", not DiffDB.is_valid("insane0"))
	_check("valid: bogus は無効", not DiffDB.is_valid("bogus"))
	_check("parse: bogus → normal", str(DiffDB.parse_key("bogus")["key"]) == "normal")
	_check("パラメータ行は7行", DiffDB.param_lines("hard").size() == 7)


# === 2) 解放ルール ===

func _t_unlock_rules() -> void:
	print("\n=== 2) 解放ルール ===")
	var e0: Array = DiffDB.selector_entries([], 0)
	_check("未クリア: ノーマル + ハード(鍵) の2件",
		e0.size() == 2 and str((e0[0] as Dictionary)["key"]) == "normal" and not bool((e0[1] as Dictionary)["unlocked"]))
	_check("normal は常に可", DiffDB.is_unlocked("normal", [], 0))
	_check("hard は1度クリアで解放", DiffDB.is_unlocked("hard", ["normal"], 0) and not DiffDB.is_unlocked("hard", [], 0))
	_check("expert は hard クリアで解放",
		DiffDB.is_unlocked("expert", ["normal", "hard"], 0) and not DiffDB.is_unlocked("expert", ["normal"], 0))
	_check("insane は lunatic クリアで解放",
		DiffDB.is_unlocked("insane", ["normal", "hard", "expert", "nightmare", "inferno", "lunatic"], 0))
	_check("insane1 は insane クリアで解放", DiffDB.is_unlocked("insane1", ["insane"], 0))
	_check("insane2 は insane1 クリアで解放",
		DiffDB.is_unlocked("insane2", ["insane"], 1) and not DiffDB.is_unlocked("insane2", ["insane"], 0))
	var e1: Array = DiffDB.selector_entries(["normal"], 0)
	_check("表示: 解放済み + 次の1件 (expert 鍵)",
		e1.size() == 3 and str((e1[2] as Dictionary)["key"]) == "expert" and not bool((e1[2] as Dictionary)["unlocked"]))
	_check("first_locked: expert", DiffDB.first_locked_key(["normal"], 0) == "expert")
	_check("解放条件テキスト", DiffDB.unlock_requirement_text("expert") == "解放条件: ハード をクリア")
	var e2: Array = DiffDB.selector_entries(["normal", "hard", "expert", "nightmare", "inferno", "lunatic", "insane"], 0)
	_check("インセイン後: insane1 解放 + insane2 鍵",
		e2.size() == 9 and bool((e2[7] as Dictionary)["unlocked"]) and not bool((e2[8] as Dictionary)["unlocked"]))


# === 3) セーブと解放記録 ===

func _t_save_roundtrip() -> void:
	print("\n=== 3) セーブと解放記録 ===")
	_remove_save()
	SaveData.reset()
	_check("初回クリア: セレクタ解放の通知", SaveData.record_clear("normal") == "解放: 難易度選択!")
	_check("normal が記録された", SaveData.cleared == ["normal"])
	_check("hard クリア → expert 解放", SaveData.record_clear("hard") == "解放: エキスパート!")
	_check("同じクリアで二重通知なし", SaveData.record_clear("hard") == "")
	SaveData.cleared = ["normal", "hard", "expert", "nightmare", "inferno", "lunatic"]
	_check("insane クリア → インセイン1 解放", SaveData.record_clear("insane") == "解放: インセイン1!")
	_check("insane1 クリア → インセイン2 解放", SaveData.record_clear("insane1") == "解放: インセイン2!")
	_check("insane_cleared = 1", SaveData.insane_cleared == 1)
	SaveData.set_last("insane2")
	SaveData.load_save()
	_check("往復: cleared", SaveData.cleared.has("insane") and SaveData.cleared.has("hard"))
	_check("往復: insane_cleared", SaveData.insane_cleared == 1)
	_check("往復: last", SaveData.last == "insane2")
	# 破損ファイル → 初期状態
	var f: FileAccess = FileAccess.open(TEST_SAVE, FileAccess.WRITE)
	f.store_string("{broken json!!")
	f.close()
	SaveData.load_save()
	_check("破損時は初期状態", SaveData.cleared.is_empty() and SaveData.insane_cleared == 0 and SaveData.last == "normal")
	# unlock_all (保存はしない)
	SaveData.unlock_all()
	_check("unlock_all: 全キー + insane3", SaveData.cleared.size() == DiffDB.KEYS.size() and SaveData.insane_cleared == 3)
	SaveData.reset()


# === 4) 難易度の適用 ===

func _t_game_difficulty() -> void:
	print("\n=== 4) 難易度の適用 ===")
	SaveData.reset()
	_remove_save()
	DiffDB.current_key = "normal"
	var main: Node = MainScene.instantiate()
	root.add_child(main)
	current_scene = main
	for i: int in range(10):
		await process_frame
	main.call("start_game")
	main.get_node("SpawnDirector").set("running", false)
	main.get_node("ChestDirector").set("running", false)
	var player: Node2D = main.get_node("Player")
	player.set("max_hp", 1000000.0)
	player.set("hp", 1000000.0)
	player.set("xp_next", 1000000000)
	for i: int in range(5):
		await process_frame

	# ノーマルは完全 no-op
	var s0: Node2D = _spawn_slime(player)
	_check("normal: HP 12 (no-op)", _near(float(s0.get("max_hp")), 12.0))
	_check("normal: 接触 8", _near(float(s0.get("contact_damage")), 8.0))
	_check("normal: 速度 70", _near(float(s0.get("speed")), 70.0))
	s0.queue_free()

	# ハード
	DiffDB.current_key = "hard"
	var s1: Node2D = _spawn_slime(player)
	_check("hard: HP 12×1.25=15", _near(float(s1.get("max_hp")), 15.0))
	_check("hard: 接触 8×1.2=9.6", _near(float(s1.get("contact_damage")), 9.6))
	_check("hard: 速度 70×1.05=73.5", _near(float(s1.get("speed")), 73.5))
	s1.call("make_elite")
	_check("hard: エリート 15×5×1.2=90", _near(float(s1.get("max_hp")), 90.0))
	s1.queue_free()

	var b: Node2D = B01Scene.instantiate() as Node2D
	(current_scene as Node).add_child(b)
	b.global_position = player.global_position + Vector2(400, 0)
	_check("hard: B01 1500×1.5=2250", _near(float(b.get("max_hp")), 2250.0))
	b.queue_free()

	var pool: Node = get_first_node_in_group("pool_enemy_shots")
	var shot: Node2D = pool.call("acquire") as Node2D
	shot.call("setup", Vector2.RIGHT, 100.0, 10.0)
	_check("hard: 弾速 100×1.1=110", _near(float(shot.get("speed")), 110.0))
	_check("hard: 弾ダメ 10×1.2=12", _near(float(shot.get("damage")), 12.0))
	pool.call("release", shot)

	var dir: Node = SpawnDirectorScript.new()
	main.add_child(dir)
	await process_frame
	_check("hard: エリート間隔 96s", _near(float(dir.get("next_elite_at")), 96.0))
	_check("hard: 上限 22×1.1=24", int(dir.call("cap_for_band", WavesDB.band(0.0))) == 24)
	dir.queue_free()

	# インセイン
	DiffDB.current_key = "insane"
	var s2: Node2D = _spawn_slime(player)
	_check("insane: HP 12×4=48", _near(float(s2.get("max_hp")), 48.0))
	_check("insane: 接触 8×3=24", _near(float(s2.get("contact_damage")), 24.0))
	s2.queue_free()
	_check("insane: 上限 280×2 → 400 クランプ", DiffDB.cap_for(280, "insane") == 400)

	# HUD の難易度名
	DiffDB.current_key = "hard"
	main.call("start_game")
	_check("HUD に難易度名", str(main.get_node("HUD/DiffLabel").get("text")) == "ハード")

	# リザルト: 難易度行 + 解放通知 → スタッフロールで通知が消える
	SaveData.reset()
	SaveData.cleared = ["normal"]
	main.call("show_result", true)
	for i: int in range(5):
		await process_frame
	var res: Node = main.get_node("ResultUI")
	_check("リザルトに難易度行", "難易度: ハード" in str(res.get_node("Center/VBox/Stats").get("text")))
	_check("解放通知 (解放: エキスパート!)",
		(res.get_node("Center/VBox/UnlockLabel") as Label).visible
		and str(res.get_node("Center/VBox/UnlockLabel").get("text")) == "解放: エキスパート!")
	_check("hard がセーブに記録", SaveData.cleared.has("hard"))
	var sr: Node = main.get_node("StaffRollUI")
	sr.call("start_roll", res)
	for i: int in range(5):
		await process_frame
	_check("ロール開始で解放通知が消える", not (res.get_node("Center/VBox/UnlockLabel") as Label).visible)
	var art: TextureRect = sr.get_node("ArtFade") as TextureRect
	var vp: Vector2 = sr.get_viewport().get_visible_rect().size
	_check("背景は上端合わせ (y=%.1f)" % art.position.y, absf(art.position.y) < 0.5)
	_check("背景は横中央", absf(art.position.x - (vp.x - art.size.x) * 0.5) < 0.5)
	_check("背景は画面を覆う (%.0fx%.0f)" % [art.size.x, art.size.y],
		art.size.x >= vp.x - 0.5 and art.size.y >= vp.y - 0.5)
	_check("終了ボタンはタイトルのみ", sr.has_node("BottomBox/EndRow/TitleBtn") and not sr.has_node("BottomBox/EndRow/RetryBtn"))
	main.queue_free()
	await process_frame


# === 5) カードとジェム ===

func _t_game_cards_gems() -> void:
	print("\n=== 5) カードとジェム ===")
	DiffDB.current_key = "normal"
	var main: Node = MainScene.instantiate()
	root.add_child(main)
	current_scene = main
	for i: int in range(10):
		await process_frame
	main.call("start_game")
	main.get_node("SpawnDirector").set("running", false)
	main.get_node("ChestDirector").set("running", false)
	var player: Node2D = main.get_node("Player")
	player.set("max_hp", 1000000.0)
	player.set("hp", 1000000.0)
	player.set("xp_next", 1000000000)
	# 既存武器を外して、テスト中に敵へ流弾が飛ばないようにする
	for w: Node in player.get_node("Weapons").get_children():
		w.queue_free()
	for i: int in range(5):
		await process_frame
	var cm: Node = main.get_node("CardManager")

	# Lv表記 (D33): 実レベルどおりに出す
	_check("武器Lv1 → Lv1→2", str((cm.call("_entry", "C01", false, 1) as Dictionary)["level_text"]) == "Lv1→2")
	_check("武器Lv7 → Lv7→8", str((cm.call("_entry", "C01", false, 7) as Dictionary)["level_text"]) == "Lv7→8")
	_check("武器 新規 → 新規取得!", str((cm.call("_entry", "C03", true, 0) as Dictionary)["level_text"]) == "新規取得!")
	_check("ステータス初回 → 新規取得!", str((cm.call("_entry", "C07", true, 0) as Dictionary)["level_text"]) == "新規取得!")
	_check("ステータスLv4 → Lv4→5", str((cm.call("_entry", "C07", false, 4) as Dictionary)["level_text"]) == "Lv4→5")

	# プールが十分なときはフォールバックを出さない
	var normal_has_fb := false
	for i: int in range(30):
		for o: Dictionary in cm.call("get_offers"):
			if str(o["id"]) in FALLBACK_IDS:
				normal_has_fb = true
	_check("プール十分: フォールバック無し", not normal_has_fb)

	# 全MAX → プール枯渇 → フォールバック3種のみ (重複なし・1000回)
	for cid: String in CardsDB.WEAPON_IDS:
		var w: Node = cm.call("weapon_by_id", cid)
		if w == null:
			player.call("add_weapon", cid)
			w = cm.call("weapon_by_id", cid)
		if w != null:
			w.set("weapon_level", 8)
	for cid: String in CardsDB.STAT_IDS:
		(cm.get("stat_levels") as Dictionary)[cid] = int(CardsDB.DEFS[cid]["max"])
	for i: int in range(5):
		await process_frame
	var bad := 0
	var dup := 0
	for i: int in range(1000):
		var offers: Array = cm.call("get_offers")
		var seen := {}
		for o: Dictionary in offers:
			var oid: String = str(o["id"])
			if not oid in FALLBACK_IDS:
				bad += 1
			if seen.has(oid):
				dup += 1
			seen[oid] = true
	_check("全MAX: 1000回で MAX カード出現0 (bad=%d)" % bad, bad == 0)
	_check("全MAX: 同一提示に重複なし (dup=%d)" % dup, dup == 0)

	# プール1件 → その1件 + フォールバック2種
	var w1: Node = cm.call("weapon_by_id", "C01")
	w1.set("weapon_level", 7)
	var offers1: Array = cm.call("get_offers")
	var id1: String = str((offers1[1] as Dictionary)["id"])
	var id2: String = str((offers1[2] as Dictionary)["id"])
	_check("プール1: C01 が先頭 (Lv7→8)",
		str((offers1[0] as Dictionary)["id"]) == "C01"
		and str((offers1[0] as Dictionary)["level_text"]) == "Lv7→8")
	_check("プール1: 残り2枚は別々のフォールバック", id1 in FALLBACK_IDS and id2 in FALLBACK_IDS and id1 != id2)

	# 修練の書 (CXP): XP +100
	player.set("xp", 0)
	cm.call("apply_card", "CXP")
	_check("修練の書: XP +100", int(player.get("xp")) == 100)

	# 応急手当 (HEAL): 回復 / 満タンで小ジェム
	player.set("hp", 10.0)
	cm.call("apply_card", "HEAL")
	_check("応急手当: HP +30", _near(float(player.get("hp")), 40.0))
	player.set("hp", float(player.get("max_hp")))
	var gems0: int = _active_gems()
	cm.call("apply_card", "HEAL")
	_check("応急手当: 満タンで小ジェム", _active_gems() == gems0 + 1)

	# ノヴァ (CNOVA): 700px内の敵に80dmg + 敵弾全消去 + 警告
	var e1: Node2D = _spawn_slime(player)
	e1.set("max_hp", 1000.0)
	e1.set("hp", 1000.0)
	var e2: Node2D = _spawn_slime(player)
	e2.set("max_hp", 1000.0)
	e2.set("hp", 1000.0)
	for i: int in range(5):
		await process_frame
	var pool2: Node = get_first_node_in_group("pool_enemy_shots")
	var shot2: Node2D = pool2.call("acquire") as Node2D
	shot2.global_position = player.global_position + Vector2(60, 0)
	cm.call("apply_card", "CNOVA")
	for i: int in range(3):
		await process_frame
	_check("ノヴァ: 2体に80dmg (%.0f / %.0f)" % [float(e1.get("hp")), float(e2.get("hp"))],
		_near(float(e1.get("hp")), 920.0) and _near(float(e2.get("hp")), 920.0))
	_check("ノヴァ: 敵弾を消去", not bool(shot2.get("active")))
	var wtext: String = str(main.get_node("HUD/WarningLabel").get("text"))
	_check("ノヴァ: 警告表示 (got '%s')" % wtext, wtext == "ノヴァ!")
	e1.queue_free()
	e2.queue_free()

	# ジェム: 3段階色 + きらめき (D35)
	_check("色: 1XP = 緑", GemScript.color_for_value(1) == GemScript.TIER_SMALL)
	_check("色: 5XP = 赤", GemScript.color_for_value(5) == GemScript.TIER_MID)
	_check("色: 20XP = 白", GemScript.color_for_value(20) == GemScript.TIER_BIG)
	var gem_pool: Node = get_first_node_in_group("pool_gems")
	var gem: Node2D = gem_pool.call("acquire") as Node2D
	gem.set("value", 20)
	_check("ジェム実体: 白", (gem.get_node("Visual") as Polygon2D).color == GemScript.TIER_BIG)
	gem.set("value", 1)
	_check("ジェム実体: 緑", (gem.get_node("Visual") as Polygon2D).color == GemScript.TIER_SMALL)
	gem.set("sparkle_phase", 0.1)
	gem.call("_process", 0.0)
	var sp: Polygon2D = gem.get_node("Sparkle") as Polygon2D
	_check("きらめき: 点灯 (a=%.2f)" % sp.modulate.a, sp.modulate.a > 0.9)
	_check("きらめき: 本体が膨らむ", (gem.get_node("Visual") as Polygon2D).scale.x > 1.1)
	gem.set("sparkle_phase", 0.9)
	gem.call("_process", 0.0)
	_check("きらめき: 消灯", sp.modulate.a < 0.01)
	gem_pool.call("release", gem)

	main.queue_free()
	await process_frame


# === 6) タイトルセレクタ ===

func _t_title_selector() -> void:
	print("\n=== 6) タイトルセレクタ ===")
	# セレクタ解放済み: normal クリア済み (hard も解放)、last = hard
	SaveData.reset()
	SaveData.cleared = ["normal"]
	SaveData.insane_cleared = 0
	SaveData.last = "hard"
	SaveData.save_now()
	var main: Node = MainScene.instantiate()
	root.add_child(main)
	current_scene = main
	for i: int in range(10):
		await process_frame
	var title: Node = main.get_node("TitleUI")
	_check("初期カーソルは last=hard", str(title.call("selected_key")) == "hard")
	_check("名前表示", str(title.get_node("Center/VBox/DiffRow/DiffName").get("text")) == "ハード")
	_check("解放済みは鍵なし", not (title.get_node("Center/VBox/DiffLock") as Label).visible)
	_check("はじめる 有効", not (title.get_node("Center/VBox/StartBtn") as Button).disabled)
	var ptext: String = str(title.get_node("ParamsPanel/ParamsText").get("text"))
	_check("右側にパラメータ (敵の硬さ +25% / エリート・ボス +25%)",
		"敵の硬さ +25%" in ptext and "エリート・ボス +25%" in ptext)
	title.call("_cycle", 1)
	_check("→ で expert (ロック)", str(title.call("selected_key")) == "expert")
	_check("ロック中は鍵と解放条件",
		(title.get_node("Center/VBox/DiffLock") as Label).visible
		and "解放条件: ハード" in str(title.get_node("Center/VBox/DiffLock").get("text")))
	_check("ロック中は はじめる 無効", (title.get_node("Center/VBox/StartBtn") as Button).disabled)
	var name_lbl: Label = title.get_node("Center/VBox/DiffRow/DiffName") as Label
	_check("ロック中は名前が暗い", name_lbl.modulate.r < 0.6 and name_lbl.modulate.g < 0.6)
	title.call("_cycle", 1)
	_check("→ で normal に周回", str(title.call("selected_key")) == "normal")
	title.call("_cycle", -1)
	_check("← で expert に戻る", str(title.call("selected_key")) == "expert")
	main.queue_free()
	await process_frame

	# 未クリア: セレクタ未解放 (ノーマル固定・切替不可)
	SaveData.reset()
	SaveData.save_now()
	var main2: Node = MainScene.instantiate()
	root.add_child(main2)
	current_scene = main2
	for i: int in range(10):
		await process_frame
	var title2: Node = main2.get_node("TitleUI")
	_check("未クリア: ノーマル固定", str(title2.call("selected_key")) == "normal")
	_check("未クリア: 解放案内",
		(title2.get_node("Center/VBox/DiffLock") as Label).visible
		and "1度クリア" in str(title2.get_node("Center/VBox/DiffLock").get("text")))
	title2.call("_cycle", 1)
	_check("未クリア: 切替不可", str(title2.call("selected_key")) == "normal")
	_check("未クリア: はじめる 有効 (ノーマル)", not (title2.get_node("Center/VBox/StartBtn") as Button).disabled)
	# 開始で難易度が確定し、last が保存される
	main2.call("_on_start")
	for i: int in range(3):
		await process_frame
	_check("開始で難易度確定 (normal)", DiffDB.current_key == "normal")
	SaveData.load_save()
	_check("開始で last=normal を保存", SaveData.last == "normal")
	main2.queue_free()
	await process_frame


func _spawn_slime(player: Node2D) -> Node2D:
	var s: Node2D = SlimeScene.instantiate() as Node2D
	(current_scene as Node).add_child(s)
	s.global_position = player.global_position + Vector2(200, 0)
	return s


func _active_gems() -> int:
	var n := 0
	for g: Node in get_nodes_in_group("gems"):
		if bool(g.get("active")):
			n += 1
	return n
