extends SceneTree
## P11 検証: 宝箱の出現・開封・9種+レア枠・爆弾・オートエイムを実機で確認する。
## 実行: godot --path <project> --script res://tools/verify_chests.gd
## 全ケースPASSで終了コード0、失敗があれば1。

const ItemsDB := preload("res://data/items_db.gd")
const SlimeScene: PackedScene = preload("res://enemies/slime.tscn")

var failures := 0


func _init() -> void:
	var main := (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	current_scene = main
	await process_frame
	await process_frame
	main.call("start_game")
	main.get_node("SpawnDirector").set("running", false)
	for i: int in range(30):
		await process_frame
	var player: Node2D = main.get_node("Player")
	var director: Node = main.get_node("ChestDirector")
	# テスト用に不死・レベルアップなしにする (奇襲や爆発で中断しないため)
	player.set("max_hp", 100000.0)
	player.set("hp", 100000.0)
	player.set("xp_next", 1000000)

	_check("game unpaused", not paused)
	_check("chest director running", bool(director.get("running")))
	await _t_distribution()
	await _t_aim(player, director)
	await _t_items(player, director, main)
	await _t_chest_open(player, director)
	await _t_item_bomb(player, director, main)

	print("RESULT: ", "ALL PASS" if failures == 0 else "%d FAILURE(S)" % failures)
	quit(1 if failures > 0 else 0)


func _check(label: String, ok: bool) -> void:
	if ok:
		print("PASS ", label)
	else:
		failures += 1
		print("FAIL ", label)


func _active_gems() -> Array:
	var out: Array = []
	for n: Node in get_nodes_in_group("gems"):
		if bool(n.get("active")):
			out.append(n)
	return out


func _release_all_gems() -> void:
	var pool: Node = get_first_node_in_group("pool_gems")
	for n: Node in _active_gems():
		if pool != null:
			pool.call("release", n)
		else:
			n.queue_free()
	for i: int in range(3):
		await process_frame


## 1) 抽選分布: レア約5%、全通常種が出る
func _t_distribution() -> void:
	var counts := {}
	for i: int in range(2000):
		var id: String = ItemsDB.roll()
		counts[id] = int(counts.get(id, 0)) + 1
	var rare: int = int(counts.get("R_HEAL", 0)) + int(counts.get("R_COIN", 0)) + int(counts.get("R_WEAPON", 0))
	print("   distribution: ", counts)
	_check("rare ~= 5%% (%d/2000)" % rare, rare >= 60 and rare <= 140)
	var all_normal := true
	for t: String in ["T01", "T02", "T03", "T04", "T05", "T06", "T07", "T08", "T09"]:
		if int(counts.get(t, 0)) < 20:
			all_normal = false
	_check("all normal items appear", all_normal)
	var t01share: float = float(counts.get("T01", 0)) / 2000.0
	_check("T01 ~= 22%% (%.1f%%)" % (t01share * 100.0), t01share > 0.16 and t01share < 0.28)


## 2) オートエイム: 敵なし→宝箱、敵あり→敵
func _t_aim(player: Node2D, director: Node) -> void:
	_check("no enemies at start", get_nodes_in_group("enemies").is_empty())
	var w: Node = player.get_node_or_null("Weapons/Weapon_C02")
	_check("has Weapon_C02", w != null)
	if w == null:
		return
	var chest: Node = director.call("spawn_chest_at", player.global_position + Vector2(300, 0))
	# 実マウス位置がエイムに優先されるため、自動照準の判定前に切る (同tick内は新イベントなし)
	player.set("use_mouse_aim", false)
	var d: Vector2 = w.call("get_fire_direction")
	_check("aims at chest when no enemy", d.angle_to(Vector2.RIGHT) < 0.2)
	var slime: Node2D = SlimeScene.instantiate() as Node2D
	(current_scene as Node).add_child(slime)
	slime.global_position = player.global_position + Vector2(-150, 0)
	for i: int in range(5):
		await process_frame
	player.set("use_mouse_aim", false)
	var d2: Vector2 = w.call("get_fire_direction")
	_check("aims at enemy when present", d2.angle_to(Vector2.LEFT) < 0.3)
	slime.call("take_damage", 99999.0)
	for i: int in range(5):
		await process_frame
	_check("test slime gone", get_nodes_in_group("enemies").is_empty())
	chest.call("expire_silent")
	for i: int in range(3):
		await process_frame


## 3) 各アイテムの効果
func _t_items(player: Node2D, director: Node, main: Node) -> void:
	var pp: Vector2 = player.global_position
	# T02: スコア+100
	director.call("apply_item", "T02", pp)
	_check("T02 score+100", int(main.get("score")) == 100)
	# T01: 満タンなら小ジェムに変換
	var g0: int = _active_gems().size()
	director.call("apply_item", "T01", pp)
	_check("T01 full-hp converts to gem", _active_gems().size() == g0 + 1)
	# T01: HP50 → +35
	player.set("hp", 50.0)
	director.call("apply_item", "T01", pp)
	_check("T01 heals +35", absf(float(player.get("hp")) - 85.0) < 0.01)
	player.set("hp", float(player.get("max_hp")))
	# T05: 中3+小5
	var g1: int = _active_gems().size()
	director.call("apply_item", "T05", pp)
	_check("T05 scatters 8 gems", _active_gems().size() == g1 + 8)
	await _release_all_gems()
	# T06: いずれかのバフが付く
	director.call("apply_item", "T06", pp)
	var buffed: bool = float(player.get("buff_attack")) > 1.0 or float(player.get("buff_cd")) < 1.0 \
		or float(player.get("buff_spd")) > 1.0 or float(player.get("buff_inv_t")) > 0.0
	_check("T06 applies a buff", buffed)
	for i: int in range(3):
		await process_frame
	# T07: 1500px以内だけ引き寄せる
	var pool: Node = get_first_node_in_group("pool_gems")
	var near: Node2D = pool.call("acquire") as Node2D
	near.global_position = pp + Vector2(500, 0)
	var far: Node2D = pool.call("acquire") as Node2D
	far.global_position = pp + Vector2(1600, 0)
	for i: int in range(5):
		await process_frame
	_check("T07 setup: both unattracted", not bool(near.get("attracted")) and not bool(far.get("attracted")))
	director.call("apply_item", "T07", pp)
	_check("T07 attracts within 1500", bool(near.get("attracted")) and not bool(far.get("attracted")))
	await _release_all_gems()
	# T08: ラッシュ開始
	director.call("apply_item", "T08", pp)
	_check("T08 rush starts", float(director.get("rush_time")) > 0.0)
	director.set("rush_time", 0.0)
	# T09: 武器が1Lv上がる (C01/C02 のどちらか)
	director.call("apply_item", "T09", pp)
	var w1: Node = player.get_node_or_null("Weapons/Weapon_C01")
	var w2: Node = player.get_node_or_null("Weapons/Weapon_C02")
	_check("T09 upgrades a weapon", int(w1.get("weapon_level")) == 2 or int(w2.get("weapon_level")) == 2)
	# レア枠
	var s0: int = int(main.get("score"))
	director.call("apply_item", "R_COIN", pp)
	_check("R_COIN score+1000", int(main.get("score")) == s0 + 1000)
	player.set("hp", 10.0)
	director.call("apply_item", "R_HEAL", pp)
	_check("R_HEAL full heal", absf(float(player.get("hp")) - float(player.get("max_hp"))) < 0.01)
	player.set("hp", float(player.get("max_hp")))
	# T04: 奇襲 6〜10体
	var e0: int = get_nodes_in_group("enemies").size()
	director.call("apply_item", "T04", pp + Vector2(200, 0))
	var e1: int = get_nodes_in_group("enemies").size()
	_check("T04 ambush 6-10 (%d)" % (e1 - e0), e1 - e0 >= 6 and e1 - e0 <= 10)
	for n: Node in get_nodes_in_group("enemies"):
		n.queue_free()
	for i: int in range(5):
		await process_frame


## 4) 宝箱の開封フロー
func _t_chest_open(player: Node2D, director: Node) -> void:
	var c: Node = director.call("spawn_chest_at", player.global_position + Vector2(100, 0))
	_check("chest in chests group", c.is_in_group("chests"))
	_check("chest not in enemies group", not c.is_in_group("enemies"))
	_check("chest receiver on layer 2", int((c as Node).get_node("Receiver").collision_layer) == 2)
	c.call("take_damage", 10.0, Vector2.ZERO, false)
	_check("chest opened", bool(c.get("opened")))
	for i: int in range(40):
		await process_frame
	_check("chest freed after open", not is_instance_valid(c))


## 5) アイテム爆弾: 範囲200dmg + 破片、プレイヤー無傷
func _t_item_bomb(player: Node2D, director: Node, main: Node) -> void:
	var pos: Vector2 = player.global_position + Vector2(200, 0)
	var before := {}
	for b: Node in get_nodes_in_group("item_bombs"):
		before[(b as Node).get_instance_id()] = true
	director.call("apply_item", "T03", pos)
	# 開封テストのランダム枠で出た爆弾が残っている場合があるため、posに最も近い新規品を選ぶ
	var bomb: Node = null
	var best_d := 1e18
	for b: Node in get_nodes_in_group("item_bombs"):
		if before.has((b as Node).get_instance_id()):
			continue
		var dd: float = ((b as Node2D).global_position - pos).length()
		if dd < best_d:
			best_d = dd
			bomb = b
	_check("T03 places a bomb", bomb != null)
	if bomb == null:
		return
	var slime: Node2D = SlimeScene.instantiate() as Node2D
	(current_scene as Node).add_child(slime)
	slime.global_position = pos
	slime.set("speed", 0.0)
	var hp0: float = float(player.get("hp"))
	bomb.set("age", 2.0)
	var slime_dead := false
	for i: int in range(120):
		await process_frame
		if not is_instance_valid(slime) or bool(slime.get("dead")):
			slime_dead = true
			break
	_check("bomb blast kills slime", slime_dead)
	_check("player unharmed by item bomb", absf(float(player.get("hp")) - hp0) < 0.01)
	for i: int in range(120):
		await process_frame
		if not is_instance_valid(bomb):
			break
	_check("bomb freed after explosion", not is_instance_valid(bomb))
