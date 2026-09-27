extends SceneTree
## P20 検証: v1.7 (案5 D44〜D58) — 解放通知スクロール・DiffLock 固定・スティックラッチ・
## ボム投下点・敵ばらつき・ジェム閾値・密着ヒット・見た目係数・煙 (D58)・破片48。
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
	await _t_smoke_d58()
	await _t_chain_thickness_d59()
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


# === 8) D58 ホーミング煙 ===
func _t_smoke_d58() -> void:
	print("\n=== 8) ホーミング煙の見え方 (D58) ===")
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
	var hpool: Node = get_first_node_in_group("pool_homing")
	var hm: Node2D = hpool.call("acquire") as Node2D
	_check("ホーミング弾を取得できる", hm != null)
	if hm == null:
		main.queue_free()
		await process_frame
		return
	var hscript: GDScript = load("res://projectiles/homing_projectile.gd")
	_check("D58: 基準の不透明度を上げた (%.2f >= 0.6・旧 実効0.12)" % float(hscript.SMOKE_ALPHA), float(hscript.SMOKE_ALPHA) >= 0.6)
	_check("D58: 寿命を延ばした (%.2fs >= 1.0・旧 0.4s)" % float(hscript.SMOKE_LIFE), float(hscript.SMOKE_LIFE) >= 1.0)
	# 誰もいない場所をまっすぐ飛ばし、煙を手動噴出して同フレームで角度を測る。
	hm.global_position = player.global_position + Vector2(3000, 3000)
	hm.set("target", null)
	hm.call("setup", Vector2.RIGHT, 420.0, 10.0, 3.0, 1, 1.0)
	hm.set("trail_scale", 1.0)
	var angles: Array = []
	var first: Polygon2D = null
	var first_spawn := Vector2.ZERO
	for i: int in range(12):
		hm.call("_spawn_smoke")
		var arr: Array = hm.get("smokes") as Array
		if arr.is_empty():
			continue
		var sn: Polygon2D = (arr[arr.size() - 1] as Dictionary)["node"]
		if first == null:
			first = sn
			first_spawn = sn.global_position
		var back: Vector2 = -(hm.get("direction") as Vector2)
		angles.append(rad_to_deg(back.angle_to(sn.global_position - hm.global_position)))
	var in_range := true
	var max_abs := 0.0
	for a: float in angles:
		if absf(a) > 5.2:
			in_range = false
		max_abs = maxf(max_abs, absf(a))
	_check("D58: 噴出は後方 ±5° 内 (%d個・最大 %.1f°)" % [angles.size(), max_abs], in_range and angles.size() >= 10)
	_check("D58: ぶれが実際にある (最大 %.1f° > 0.5°)" % max_abs, max_abs > 0.5)
	if first != null:
		_check("D58: 噴出直後の不透明度 (色 %.2f / 基準 %.2f)" % [float(first.color.a), float(hscript.SMOKE_ALPHA)],
			absf(float(first.color.a) - float(hscript.SMOKE_ALPHA)) < 0.001)
	# 残存と流れ: 0.7s 後も残り、薄くなり、ぶれた向きへ流れている (旧仕様は 0.4s で消えていた)。
	for i: int in range(42):
		await process_frame
	var still_listed := false
	var vel := Vector2.ZERO
	for sm: Dictionary in hm.get("smokes") as Array:
		if sm["node"] == first:
			still_listed = true
			vel = sm["vel"] as Vector2
			break
	_check("D58: 0.7s 後も煙が残る (寿命1.0s・旧0.4s)", first != null and is_instance_valid(first) and still_listed)
	if first != null and is_instance_valid(first):
		_check("D58: だんだん薄くなる (modulate.a=%.2f < 0.5)" % float(first.modulate.a), float(first.modulate.a) < 0.5)
		var moved: Vector2 = first.global_position - first_spawn
		_check("D58: ぶれた向きへ流れる (%.0fpx 移動)" % moved.length(),
			moved.length() > 40.0 and vel.length() > 0.0 and moved.normalized().dot(vel.normalized()) > 0.99)
	main.queue_free()
	await process_frame


# === 9) D59 チェインの線の太さ ===
## current_scene 直下の線FXのうち最後 (= 最新) のものを返す。
func _line_fx(script: GDScript) -> Node:
	var found: Node = null
	for c: Node in (current_scene as Node).get_children():
		if c.get_script() == script:
			found = c
	return found


func _t_chain_thickness_d59() -> void:
	print("\n=== 9) チェインライトニングの線の太さ (D59) ===")
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
	player.call("add_weapon", "C04")
	for i: int in range(5):
		await process_frame
	var cm: Node = main.get_node("CardManager")
	var ch: Node = cm.call("weapon_by_id", "C04")
	var e: Node2D = _spawn_slime(player, Vector2(200, 0))
	e.set("max_hp", 1000000.0)
	e.set("hp", 1000000.0)
	for i: int in range(3):
		await process_frame
	var fx_script: GDScript = load("res://weapons/lightning_fx.gd")
	ch.call("fire")
	await process_frame
	var fx1: Node = _line_fx(fx_script)
	_check("Lv1: 線FXが生成される", fx1 != null)
	if fx1 != null:
		var t1: Variant = fx1.get("thickness")
		_check("D59: Lv1 の太さ係数 1.00 (実際 %s)" % str(t1),
			(t1 is float or t1 is int) and absf(float(t1) - 1.0) < 0.001)
	for i: int in range(7):
		ch.call("upgrade")
	ch.call("fire")
	await process_frame
	var fx8: Node = _line_fx(fx_script)
	_check("Lv8: 新しい線FXが生成される", fx8 != null and fx8 != fx1)
	if fx8 != null:
		var t8: Variant = fx8.get("thickness")
		_check("D59: Lv8 の太さ係数 2.05 (実際 %s・Lv1より太い)" % str(t8),
			(t8 is float or t8 is int) and absf(float(t8) - 2.05) < 0.001)
	main.queue_free()
	await process_frame
