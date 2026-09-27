extends SceneTree
## P22 検証: v1.8 (案6) — エリート×2/中ボス据え置き/最終ボス×2・コイン倍率・
## コインの入手とリザルト確定・恒久パワーアップ (コスト/適用/no-op)・
## 射程 (C02 1.0s/C03 1.5s・aim_range・追尾の再探索制限)。
## 実行: godot --headless --fixed-fps 60 --path <project> --script res://tools/verify_v18.gd

const DiffDB := preload("res://data/difficulty_db.gd")
const SaveData := preload("res://systems/save_data.gd")
const MetaDB := preload("res://data/meta_upgrades.gd")
const MainScene: PackedScene = preload("res://main.tscn")
const SlimeScene: PackedScene = preload("res://enemies/slime.tscn")
const B01Scene: PackedScene = preload("res://enemies/boss_golem_king.tscn")
const B02Scene: PackedScene = preload("res://enemies/boss_void_emperor.tscn")

const TEST_SAVE := "user://test_v18_save.json"

var failures := 0


func _check(label: String, ok: bool) -> void:
	if ok:
		print("PASS ", label)
	else:
		failures += 1
		print("FAIL ", label)


func _near(a: float, b: float, eps: float = 0.01) -> bool:
	return absf(a - b) <= eps


func _frames(n: int) -> void:
	for i: int in range(n):
		await process_frame


func _remove_save() -> void:
	if FileAccess.file_exists(TEST_SAVE):
		DirAccess.remove_absolute(TEST_SAVE)


func _new_main() -> Node:
	SaveData.reset()
	_remove_save()
	DiffDB.current_key = "normal"
	var main: Node = MainScene.instantiate()
	root.add_child(main)
	current_scene = main
	return main


func _init() -> void:
	SaveData.path = TEST_SAVE
	_remove_save()
	_t_scales()
	_t_meta_table()
	await _t_hp()
	await _t_coins()
	await _t_meta_apply()
	await _t_range()
	await _t_homing_search()
	# 後始末 (テストが実セーブを汚さない)
	SaveData.path = SaveData.DEFAULT_PATH
	SaveData.reset()
	DiffDB.current_key = "normal"
	paused = false
	_remove_save()
	print("RESULT: ", "ALL PASS" if failures == 0 else "%d FAILURE(S)" % failures)
	quit(1 if failures > 0 else 0)


# === 1) 難易度の係数とコイン倍率 ===

func _t_scales() -> void:
	print("\n=== 1) エリート/ボスの係数とコイン倍率 ===")
	_check("エリート比 hard 2.4 (×2)", _near(DiffDB.elite_ratio("hard"), 2.4))
	_check("エリート比 normal 2.0 (×2)", _near(DiffDB.elite_ratio("normal"), 2.0))
	_check("エリート比 insane 3.5 (2×7/4)", _near(DiffDB.elite_ratio("insane"), 3.5))
	_check("中ボス比 hard 1.2 (据え置き)", _near(DiffDB.boss_ratio("hard", false), 1.2))
	_check("中ボス比 normal 1.0 (据え置き)", _near(DiffDB.boss_ratio("normal", false), 1.0))
	_check("最終ボス比 hard 2.4 (×2)", _near(DiffDB.boss_ratio("hard", true), 2.4))
	_check("最終ボス比 normal 2.0 (×2)", _near(DiffDB.boss_ratio("normal", true), 2.0))
	_check("最終ボス比 insane 3.5 (2×7/4)", _near(DiffDB.boss_ratio("insane", true), 3.5))
	_check("生パラメータは据え置き (hard 1.5)", _near(DiffDB.elite_boss_hp_mult("hard"), 1.5))
	_check("コイン倍率 normal 1.0", _near(DiffDB.coin_mult("normal"), 1.0))
	_check("コイン倍率 hard 1.2", _near(DiffDB.coin_mult("hard"), 1.2))
	_check("コイン倍率 insane 3.0", _near(DiffDB.coin_mult("insane"), 3.0))
	_check("コイン倍率 insane3 3.6", _near(DiffDB.coin_mult("insane3"), 3.6))


# === 2) 恒久パワーアップの表 ===

func _t_meta_table() -> void:
	print("\n=== 2) 恒久パワーアップの表 ===")
	_check("8項目", MetaDB.ITEMS.size() == 8)
	_check("コスト M01 Lv0=10 / Lv9=55", MetaDB.cost("M01", 0) == 10 and MetaDB.cost("M01", 9) == 55)
	_check("コスト M02 Lv0=15", MetaDB.cost("M02", 0) == 15)
	_check("コスト M08 Lv4=105", MetaDB.cost("M08", 4) == 105)
	_check("全MAXの合計 = 2205", MetaDB.total_cost_all() == 2205)
	_check("MAX Lv (M01=10 / M03=5)", MetaDB.max_level("M01") == 10 and MetaDB.max_level("M03") == 5)
	_check("未知IDは 0 / false", MetaDB.cost("ZZZ", 0) == 0 and not MetaDB.has_id("ZZZ"))


# === 3) エリート/ボスの HP (シーン実測) ===

func _spawn_slime(player: Node2D) -> Node2D:
	var s: Node2D = SlimeScene.instantiate() as Node2D
	(current_scene as Node).add_child(s)
	s.global_position = player.global_position + Vector2(200, 0)
	return s


func _t_hp() -> void:
	print("\n=== 3) エリート/ボスの HP ===")
	var main: Node = _new_main()
	await _frames(5)
	main.call("start_game")
	main.get_node("SpawnDirector").set("running", false)
	main.get_node("ChestDirector").set("running", false)
	var player: Node2D = main.get_node("Player")
	player.set("max_hp", 1000000.0)
	player.set("hp", 1000000.0)
	await _frames(3)

	# ノーマル: エリート ×10 (素12 → 120)・中ボス 1500・最終ボス 10000
	DiffDB.current_key = "normal"
	var s0: Node2D = _spawn_slime(player)
	s0.call("make_elite")
	_check("normal: エリート 120±30% (×10)", 120.0 * 0.7 <= float(s0.get("max_hp")) and float(s0.get("max_hp")) <= 120.0 * 1.3)
	s0.queue_free()
	var nb2: Node2D = B02Scene.instantiate() as Node2D
	(current_scene as Node).add_child(nb2)
	_check("normal: B02 5000×2.0=10000", _near(float(nb2.get("max_hp")), 10000.0))
	nb2.queue_free()

	# ハード: エリート ×15 (180)・B01 2250 (据え置き)・B02 15000
	DiffDB.current_key = "hard"
	var s1: Node2D = _spawn_slime(player)
	s1.call("make_elite")
	_check("hard: エリート 180±30% (×15)", 180.0 * 0.7 <= float(s1.get("max_hp")) and float(s1.get("max_hp")) <= 180.0 * 1.3)
	s1.queue_free()
	var b1: Node2D = B01Scene.instantiate() as Node2D
	(current_scene as Node).add_child(b1)
	_check("hard: B01 1500×1.5=2250 (据え置き)", _near(float(b1.get("max_hp")), 2250.0))
	b1.queue_free()
	var b2: Node2D = B02Scene.instantiate() as Node2D
	(current_scene as Node).add_child(b2)
	_check("hard: B02 5000×3.0=15000 (×2)", _near(float(b2.get("max_hp")), 15000.0))
	b2.queue_free()
	main.free()


# === 4) コインの入手とリザルト確定 ===

func _t_coins() -> void:
	print("\n=== 4) コインの入手と確定 ===")
	var main: Node = _new_main()
	await _frames(5)
	main.call("start_game")
	main.get_node("SpawnDirector").set("running", false)
	main.get_node("ChestDirector").set("running", false)
	await _frames(3)
	var chest: Node = main.get_node("ChestDirector")
	var pos: Vector2 = (main.get_node("Player") as Node2D).global_position
	var sc0: int = int(main.get("score"))
	chest.call("apply_item", "T02", pos)
	_check("T02: コイン +1", _near(float(main.get("run_coins")), 1.0))
	_check("T02: スコア +100 (据え置き)", int(main.get("score")) == sc0 + 100)
	chest.call("apply_item", "R_COIN", pos)
	_check("R_COIN: コイン +10 (計11)", _near(float(main.get("run_coins")), 11.0))
	await _frames(2)
	_check("HUD に COIN 11", str(main.get_node("HUD/CoinLabel").get("text")) == "COIN 11")

	# リザルト確定: 12 コイン × ハード 1.2 = 14
	DiffDB.current_key = "hard"
	SaveData.coins = 100
	main.set("run_coins", 12.0)
	main.call("show_result", false)
	await _frames(3)
	_check("リザルトで floor(12 × 1.2) = 14 を加算 (所持 114)", SaveData.coins == 114)
	var coin_lbl: Label = main.get_node("ResultUI/Center/VBox/CoinLabel") as Label
	_check("リザルトにコイン行", coin_lbl.visible and "コイン 12 ×1.2 = 14" in str(coin_lbl.text))
	_check("コイン行に所持を表示", "(所持 114)" in str(coin_lbl.text))
	paused = false
	main.free()


# === 5) 恒久パワーアップの適用 (no-op と乗算) ===

func _t_meta_apply() -> void:
	print("\n=== 5) 恒久パワーアップの適用 ===")
	var main: Node = _new_main()
	await _frames(3)
	await _frames(3)
	var player: Node = main.get_node("Player")
	var hp0: float = float(player.get("max_hp"))
	_check("未強化: 適用前は素の値 (HP %.0f)" % hp0, _near(hp0, 120.0))
	main.call("start_game")
	_check("Lv0 は no-op (HP120/攻1.0/速230)",
		_near(float(player.get("max_hp")), 120.0) and _near(float(player.get("attack_mult")), 1.0)
		and _near(float(player.get("speed")), 230.0))
	_check("金運 Lv0 は ×1.0", _near(float(main.get("run_coin_mult")), 1.0))
	main.free()

	var main2: Node = _new_main()
	await _frames(3)
	SaveData.upgrades = {"M01": 2, "M02": 3, "M03": 2, "M04": 2, "M05": 2, "M06": 2, "M07": 2, "M08": 3}
	main2.call("start_game")
	var p2: Node = main2.get_node("Player")
	_check("M01 体力: 最大HP 120+8=128", _near(float(p2.get("max_hp")), 128.0))
	_check("M01: 開始HPも 128", _near(float(p2.get("hp")), 128.0))
	_check("M02 攻撃: +9%", _near(float(p2.get("attack_mult")), 1.09))
	_check("M03 俊足: 230×1.04=239.2", _near(float(p2.get("speed")), 239.2))
	_check("M04 磁力: +12%", _near(float(p2.get("magnet_mult")), 1.12))
	_check("M05 学び: +6%", _near(float(p2.get("xp_mult")), 1.06))
	_check("M06 守り: アーマー+2", _near(float(p2.get("armor")), 2.0))
	_check("M07 再生: +0.30/s", _near(float(p2.get("regen")), 0.30))
	_check("M08 金運: ×1.15", _near(float(main2.get("run_coin_mult")), 1.15))
	# 金運はコイン入手に乗る
	var before: float = float(main2.get("run_coins"))
	main2.call("add_coins", 10.0)
	_check("金運込みのコイン入手 (10 × 1.15 = 11.5)", _near(float(main2.get("run_coins")) - before, 11.5))
	main2.free()


# === 6) 射程 (C02/C03) ===

func _t_range() -> void:
	print("\n=== 6) 射程 ===")
	var main: Node = _new_main()
	await _frames(3)
	main.call("start_game")
	await _frames(3)
	var player: Node = main.get_node("Player")
	var w02: Node = main.get_node("Player/Weapons/Weapon_C02")
	_check("C02 寿命 1.0s", _near(float(w02.get("projectile_lifetime")), 1.0))
	_check("C02 実効射程 500px", _near(float(w02.call("aim_range")), 500.0))
	player.set("duration_mult", 2.5)
	_check("C11 MAX: C02 1250px", _near(float(w02.call("aim_range")), 1250.0))
	player.set("duration_mult", 1.3)
	_check("C11 Lv1: C02 650px", _near(float(w02.call("aim_range")), 650.0))
	player.set("duration_mult", 1.0)
	player.call("add_weapon", "C03")
	await _frames(2)
	var w03: Node = main.get_node("Player/Weapons/Weapon_C03")
	_check("C03 寿命 1.5s", _near(float(w03.get("projectile_lifetime")), 1.5))
	_check("C03 実効射程 630px", _near(float(w03.call("aim_range")), 630.0))
	player.set("duration_mult", 2.5)
	_check("C11 MAX: C03 1575px", _near(float(w03.call("aim_range")), 1575.0))
	player.set("duration_mult", 1.0)
	main.free()


# === 7) 追尾の再探索制限 ===

func _t_homing_search() -> void:
	print("\n=== 7) 追尾の再探索 ===")
	var main: Node = _new_main()
	await _frames(3)
	main.call("start_game")
	await _frames(3)
	var pool: Node = main.get_node("PoolHoming")
	var pr: Node2D = pool.call("acquire") as Node2D
	pr.call("setup", Vector2.RIGHT, 420.0, 10.0, 1.5, 1, 1.0)
	pr.set("age", 0.0)
	_check("残り寿命×速度 (1.5s → 630px)", _near(float(pr.call("_search_range")), 630.0))
	pr.set("age", 1.0)
	_check("寿命が減ると縮む (0.5s → 210px)", _near(float(pr.call("_search_range")), 210.0))
	pr.set("age", 0.0)
	pr.set("life", 5.0)
	_check("700px で頭打ち", _near(float(pr.call("_search_range")), 700.0))
	pool.call("release", pr)
	main.free()
