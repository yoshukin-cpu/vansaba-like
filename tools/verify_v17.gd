extends SceneTree
## P20 検証: v1.7 (案5 D44〜D57) — 解放通知スクロール・DiffLock 固定・スティックラッチ・
## ボム投下点・敵ばらつき・ジェム閾値・密着ヒット・見た目係数・煙・破片48。
## 実行: godot --headless --fixed-fps 60 --path <project> --script res://tools/verify_v17.gd
## 全ケースPASSで終了コード0、失敗があれば1。

const DiffDB := preload("res://data/difficulty_db.gd")
const SaveData := preload("res://systems/save_data.gd")
const GemScript := preload("res://pickups/xp_gem.gd")
const ItemBombScript := preload("res://objects/bomb.gd")
const MainScene: PackedScene = preload("res://main.tscn")
const SlimeScene: PackedScene = preload("res://enemies/slime.tscn")
const WolfScene: PackedScene = preload("res://enemies/wolf.tscn")
const B01Scene: PackedScene = preload("res://enemies/boss_golem_king.tscn")
const ItemBombScene: PackedScene = preload("res://objects/bomb.tscn")

const TEST_SAVE := "user://test_v17_save.json"

var failures := 0


func _check(label: String, ok: bool) -> void:
	if ok:
		print("PASS ", label)
	else:
		failures += 1
		print("FAIL ", label)


func _remove_save() -> void:
	if FileAccess.file_exists(TEST_SAVE):
		DirAccess.remove_absolute(TEST_SAVE)


func _init() -> void:
	SaveData.path = TEST_SAVE
	_remove_save()
	_t_consts()
	await _t_variance()
	await _t_orbit()
	await _t_point_blank()
	await _t_visuals()
	await _t_item_bomb()
	await _t_title_latch()
	# 後始末 (テストが実セーブを汚さない)
	SaveData.path = SaveData.DEFAULT_PATH
	SaveData.reset()
	DiffDB.current_key = "normal"
	_remove_save()
	print("RESULT: ", "ALL PASS" if failures == 0 else "%d FAILURE(S)" % failures)
	quit(1 if failures > 0 else 0)


# === 1) 定数・静的仕様 ===
func _t_consts() -> void:
	print("\n=== 1) 定数 ===")
	_check("D47: 最低距離 160", true)  # 下の _t_orbit で実測する
	_check("D50: ウルフXP 4", int((WolfScene.instantiate() as Node2D).get("xp_value")) == 4)
	_check("D50: 3XP=緑/4XP=赤/8XP=白",
		GemScript.color_for_value(3) == GemScript.TIER_SMALL
		and GemScript.color_for_value(4) == GemScript.TIER_MID
		and GemScript.color_for_value(8) == GemScript.TIER_BIG)
	_check("D57: 破片48", ItemBombScript.SHARD_COUNT == 48)
	_check("D57: 速720/450・遅320/350",
		ItemBombScript.SHARD_FAST_SPEED == 720.0 and ItemBombScript.SHARD_FAST_RANGE == 450.0
		and ItemBombScript.SHARD_SLOW_SPEED == 320.0 and ItemBombScript.SHARD_SLOW_RANGE == 350.0)


func _new_main() -> Node:
	SaveData.reset()
	_remove_save()
	DiffDB.current_key = "normal"
	var main: Node = MainScene.instantiate()
	root.add_child(main)
	current_scene = main
	return main


func _spawn_slime(player: Node2D, off: Vector2) -> Node2D:
	var s: Node2D = SlimeScene.instantiate() as Node2D
	(current_scene as Node).add_child(s)
	s.global_position = player.global_position + off
	return s


func _strip_weapons(player: Node2D) -> void:
	for w: Node in player.get_node("Weapons").get_children():
		w.queue_free()


# === 2) D49 ばらつき ===
func _t_variance() -> void:
	print("\n=== 2) 敵ばらつき (D49) ===")
	var main: Node = _new_main()
	for i: int in range(10):
		await process_frame
	main.call("start_game")
	main.get_node("SpawnDirector").set("running", false)
	main.get_node("ChestDirector").set("running", false)
	var player: Node2D = main.get_node("Player")
	_strip_weapons(player)
	for i: int in range(5):
		await process_frame
	var hps: Array = []
	var ok_range := true
	var ok_xp := true
	for i: int in range(40):
		var s: Node2D = _spawn_slime(player, Vector2(200 + i * 5, 0))
		var hp: float = float(s.get("max_hp"))
		var spd: float = float(s.get("speed"))
		var dmg: float = float(s.get("contact_damage"))
		hps.append(hp)
		if not (12.0 * 0.7 <= hp and hp <= 12.0 * 1.3):
			ok_range = false
		if not (70.0 * 0.7 <= spd and spd <= 70.0 * 1.3):
			ok_range = false
		if not (8.0 * 0.7 <= dmg and dmg <= 8.0 * 1.3):
			ok_range = false
		if int(s.get("xp_value")) != 1:
			ok_xp = false
		s.queue_free()
	_check("40体が HP/速度/接触の ±30% 範囲内", ok_range)
	_check("ばらつきが実際にある (min < max)", hps.min() < hps.max())
	_check("XP は固定 (全て1)", ok_xp)
	var b: Node2D = B01Scene.instantiate() as Node2D
	(current_scene as Node).add_child(b)
	_check("ボスはばらつき対象外 (1500)", float(b.get("max_hp")) == 1500.0)
	b.queue_free()
	main.queue_free()
	await process_frame


# === 3) D47・D48 ボム投下点 ===
func _t_orbit() -> void:
	print("\n=== 3) ボム投下点 (D47・D48) ===")
	var main: Node = _new_main()
	for i: int in range(10):
		await process_frame
	main.call("start_game")
	main.get_node("SpawnDirector").set("running", false)
	main.get_node("ChestDirector").set("running", false)
	var player: Node2D = main.get_node("Player")
	player.set("max_hp", 1000000.0)
	player.set("hp", 1000000.0)
	_strip_weapons(player)
	for i: int in range(5):
		await process_frame
	player.call("add_weapon", "C06")
	for i: int in range(5):
		await process_frame
	var cm: Node = main.get_node("CardManager")
	var w: Node = cm.call("weapon_by_id", "C06")
	# A: 密着目標 (50px) は160まで押し出される
	var s0: Node2D = _spawn_slime(player, Vector2(50, 0))
	for i: int in range(3):
		await process_frame
	w.call("fire")
	# 武器ボムだけを抽出する (プール内の非活性弾も "projectiles" 群にいるため)。
	var bombs: Array = []
	for b4: Node in get_nodes_in_group("projectiles"):
		if (b4 as Node).get("target") != null:
			bombs.append(b4)
	_check("ボムが1発投下される", bombs.size() == 1)
	var t0: Vector2 = (bombs[0] as Node).get("target")
	var d0: float = (t0 - player.global_position).length()
	_check("密着目標は160に押し出される (d=%.1f)" % d0, 159.0 <= d0 and d0 <= 161.0)
	for b2: Node in bombs:
		(b2 as Node).queue_free()
	s0.queue_free()
	for i: int in range(3):
		await process_frame
	# B: 2発で別目標 (300px と -300px)
	w.set("weapon_level", 4)
	var s1: Node2D = _spawn_slime(player, Vector2(300, 0))
	var s2: Node2D = _spawn_slime(player, Vector2(-300, 0))
	for i: int in range(3):
		await process_frame
	w.call("fire")
	var bombs2: Array = []
	for b5: Node in get_nodes_in_group("projectiles"):
		if (b5 as Node).get("target") != null:
			bombs2.append(b5)
	_check("ボムが2発投下される", bombs2.size() == 2)
	if bombs2.size() == 2:
		var t1: Vector2 = (bombs2[0] as Node).get("target")
		var t2: Vector2 = (bombs2[1] as Node).get("target")
		_check("2発の投下点が異なる (%.0fpx)" % t1.distance_to(t2), t1.distance_to(t2) > 1.0)
		_check("両方とも射程内", (t1 - player.global_position).length() <= 420.0
			and (t2 - player.global_position).length() <= 420.0)
	for b3: Node in bombs2:
		(b3 as Node).queue_free()
	s1.queue_free()
	s2.queue_free()
	main.queue_free()
	await process_frame


# === 4) D51 密着ヒット ===
func _t_point_blank() -> void:
	print("\n=== 4) 密着ヒット (D51) ===")
	var main: Node = _new_main()
	for i: int in range(10):
		await process_frame
	main.call("start_game")
	main.get_node("SpawnDirector").set("running", false)
	main.get_node("ChestDirector").set("running", false)
	var player: Node2D = main.get_node("Player")
	_strip_weapons(player)
	for i: int in range(5):
		await process_frame
	var s: Node2D = _spawn_slime(player, Vector2(200, 0))
	s.set("max_hp", 1000.0)
	s.set("hp", 1000.0)
	for i: int in range(3):
		await process_frame
	var pool: Node = get_first_node_in_group("pool_shots")
	var pr: Node2D = pool.call("acquire") as Node2D
	pr.global_position = s.global_position
	pr.call("setup", Vector2.RIGHT, 500.0, 25.0, 2.0, 1)
	pr.set("kb_scale", 1.0)
	for i: int in range(5):
		await process_frame
	_check("重なった敵に25dmg (hp=%.0f)" % float(s.get("hp")), float(s.get("hp")) == 975.0)
	s.queue_free()
	main.queue_free()
	await process_frame


# === 5) D53・D54・D55・D56 見た目 ===
func _t_visuals() -> void:
	print("\n=== 5) 見た目 (D53〜D56) ===")
	var main: Node = _new_main()
	for i: int in range(10):
		await process_frame
	main.call("start_game")
	main.get_node("SpawnDirector").set("running", false)
	main.get_node("ChestDirector").set("running", false)
	var player: Node2D = main.get_node("Player")
	_strip_weapons(player)
	for i: int in range(5):
		await process_frame
	# スピン: 拡大率・残像・判定不変
	player.call("add_weapon", "C01")
	for i: int in range(5):
		await process_frame
	var cm: Node = main.get_node("CardManager")
	var spin: Node = cm.call("weapon_by_id", "C01")
	_check("スピンLv1: 拡大率1.0", absf(float(spin.call("vis_scale")) - 1.0) < 0.001)
	for i: int in range(7):
		spin.call("upgrade")
	_check("スピンLv8: 拡大率1.56", absf(float(spin.call("vis_scale")) - 1.56) < 0.001)
	_check("スピンLv8: 刃3×残像6", (spin.get("blades") as Array).size() == 3
		and (spin.get("ghosts") as Array).size() == 6)
	var blade: Node = (spin.get("blades") as Array)[0]
	# コード生成ノードの名前は自動採番のため、型で探す。
	var bshape: CollisionShape2D = null
	for ch: Node in blade.get_children():
		if ch is CollisionShape2D:
			bshape = ch
	_check("スピン: 判定は48x28のまま",
		bshape != null and (bshape.shape as RectangleShape2D).size == Vector2(48, 28))
	# ストレート弾: Visual 拡大・衝突不変
	var pool: Node = get_first_node_in_group("pool_shots")
	var pr: Node2D = pool.call("acquire") as Node2D
	pr.call("setup", Vector2.RIGHT, 500.0, 10.0, 2.0, 1, 1.49)
	_check("弾Visual: 1.49倍", absf((pr.get_node("Visual") as Sprite2D).scale.x - 1.49) < 0.01)
	_check("弾衝突: 半径6のまま", absf(float((pr.get_node("CollisionShape2D").get("shape") as CircleShape2D).radius) - 6.0) < 0.001)
	pool.call("release", pr)
	# ホーミング煙: 10フレームで煙が出る
	var hpool: Node = get_first_node_in_group("pool_homing")
	var hm: Node2D = hpool.call("acquire") as Node2D
	hm.global_position = player.global_position + Vector2(100, 0)
	hm.call("setup", Vector2.RIGHT, 420.0, 10.0, 3.0, 1, 2.0)
	hm.set("trail_scale", 2.0)
	for i: int in range(10):
		await process_frame
	_check("ホーミング: 煙が出る (%d)" % (hm.get("smokes") as Array).size(), (hm.get("smokes") as Array).size() > 0)
	# チェイン: burst で spark が増える
	var fx: Node = get_first_node_in_group("combat_fx")
	player.call("add_weapon", "C04")
	for i: int in range(5):
		await process_frame
	var ch: Node = cm.call("weapon_by_id", "C04")
	var e: Node2D = _spawn_slime(player, Vector2(200, 0))
	e.set("max_hp", 100000.0)
	e.set("hp", 100000.0)
	for i: int in range(3):
		await process_frame
	var before: int = (fx.get("sparks") as Array).size()
	ch.call("fire")
	for i: int in range(3):
		await process_frame
	_check("チェイン: burst で sparks 増加 (%d→%d)" % [before, (fx.get("sparks") as Array).size()],
		(fx.get("sparks") as Array).size() > before)
	e.queue_free()
	main.queue_free()
	await process_frame


# === 6) D57 アイテム爆弾 ===
func _t_item_bomb() -> void:
	print("\n=== 6) アイテム爆弾 (D57) ===")
	var main: Node = _new_main()
	for i: int in range(10):
		await process_frame
	main.call("start_game")
	main.get_node("SpawnDirector").set("running", false)
	main.get_node("ChestDirector").set("running", false)
	var player: Node2D = main.get_node("Player")
	player.set("max_hp", 1000000.0)
	player.set("hp", 1000000.0)
	_strip_weapons(player)
	for i: int in range(5):
		await process_frame
	var b: Node2D = ItemBombScene.instantiate() as Node2D
	(current_scene as Node).add_child(b)
	b.global_position = player.global_position + Vector2(100, 0)
	var e: Node2D = _spawn_slime(player, Vector2(100, 0))
	e.set("max_hp", 100000.0)
	e.set("hp", 100000.0)
	e.set("contact_damage", 0.0)
	for i: int in range(3):
		await process_frame
	b.call("_explode")
	var shards: Array = b.get("shards")
	_check("破片48発", shards.size() == 48)
	var alt := true
	for i: int in range(shards.size()):
		var want_spd: float = ItemBombScript.SHARD_FAST_SPEED if i % 2 == 0 else ItemBombScript.SHARD_SLOW_SPEED
		if float((shards[i] as Dictionary)["spd"]) != want_spd:
			alt = false
			break
	_check("速遅交互 (速24/遅24)", alt)
	for i: int in range(120):
		await process_frame
	_check("爆発で敵にダメージ (hp=%.0f)" % float(e.get("hp")), float(e.get("hp")) < 100000.0)
	# 爆弾は敵のみに当たる (接触のチップ1点を除き減らない。爆発なら200+破片で大きく減る)。
	_check("プレイヤーは無傷 (bomb dmgなし)", float(player.get("hp")) > 999990.0)
	e.queue_free()
	main.queue_free()
	await process_frame


# === 7) D45・D46 タイトル ===
func _t_title_latch() -> void:
	print("\n=== 7) タイトル (D45・D46) ===")
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
	# D45: 解放済みでも行は残る (空文字)
	_check("D45: DiffLock は可視のまま空行", (title.get_node("Center/VBox/DiffLock") as Label).visible
		and str(title.get_node("Center/VBox/DiffLock").get("text")) == "")
	# D46: disarm 後にニュートラルで re-arm される
	title.set("_diff_axis_armed", false)
	for i: int in range(5):
		await process_frame
	_check("D46: ニュートラルで re-arm", bool(title.get("_diff_axis_armed")))
	main.queue_free()
	await process_frame
