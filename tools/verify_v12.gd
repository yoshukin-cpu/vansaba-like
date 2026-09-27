extends SceneTree
## P13 検証: スピン複数刃・敵弾消去・アーチャー抑制・撃破スコア・クリア演出。
## 実行: godot --path <project> --script res://tools/verify_v12.gd
## 全ケースPASSで終了コード0、失敗があれば1。

const SlimeScene: PackedScene = preload("res://enemies/slime.tscn")
const ArcherScene: PackedScene = preload("res://enemies/archer.tscn")
const B02Scene: PackedScene = preload("res://enemies/boss_void_emperor.tscn")
const SaveData := preload("res://systems/save_data.gd")

var failures := 0


func _init() -> void:
	# クリア記録が実セーブを汚さないよう、一時パスを使う (v1.6)。
	SaveData.path = "user://test_v12_save.json"
	if FileAccess.file_exists(SaveData.path):
		DirAccess.remove_absolute(SaveData.path)
	SaveData.reset()
	var main := (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	current_scene = main
	await process_frame
	await process_frame
	main.call("start_game")
	main.get_node("SpawnDirector").set("running", false)
	for i: int in range(20):
		await process_frame
	var player: Node2D = main.get_node("Player")
	var director: Node = main.get_node("ChestDirector")
	player.set("max_hp", 1000000.0)
	player.set("hp", 1000000.0)
	player.set("xp_next", 1000000)

	await _t_blades(player)
	await _t_erase(player)
	await _t_score(player, main)
	await _t_item_drop(player, director)
	await _t_item_pickup(player, director, main)
	# 以降はスピンを止める (ノックバックでアーチャーが流されないように)
	var w1: Node = player.get_node_or_null("Weapons/Weapon_C01")
	if w1 != null:
		w1.queue_free()
	for i: int in range(5):
		await process_frame
	await _t_archer(player)
	await _t_clear(player, main)

	SaveData.path = SaveData.DEFAULT_PATH
	SaveData.reset()
	if FileAccess.file_exists("user://test_v12_save.json"):
		DirAccess.remove_absolute("user://test_v12_save.json")
	print("RESULT: ", "ALL PASS" if failures == 0 else "%d FAILURE(S)" % failures)
	quit(1 if failures > 0 else 0)


func _check(label: String, ok: bool) -> void:
	if ok:
		print("PASS ", label)
	else:
		failures += 1
		print("FAIL ", label)


## 1) 刃数と威力テーブル
func _t_blades(player: Node2D) -> void:
	var w: Node = player.get_node_or_null("Weapons/Weapon_C01")
	_check("has Weapon_C01", w != null)
	if w == null:
		return
	_check("Lv1: 1 blade", int(w.call("blade_count")) == 1 and (w.get("blades") as Array).size() == 1)
	_check("Lv1 damage 8", absf(float(w.get("damage")) - 8.0) < 0.01)
	w.call("upgrade")
	w.call("upgrade")
	_check("Lv3: 2 blades", int(w.call("blade_count")) == 2 and (w.get("blades") as Array).size() == 2)
	for i: int in range(5):
		w.call("upgrade")
	_check("Lv8: 3 blades", int(w.call("blade_count")) == 3 and (w.get("blades") as Array).size() == 3)
	_check("Lv8 damage 16", absf(float(w.get("damage")) - 16.0) < 0.01)


## 2) 敵弾消去: 刃の軌道上の静止弾が1周で全滅する
func _t_erase(player: Node2D) -> void:
	var w: Node = player.get_node_or_null("Weapons/Weapon_C01")
	var r: float = float(w.get("radius")) if w != null else 90.0
	var pool: Node = get_first_node_in_group("pool_enemy_shots")
	var shots: Array = []
	for i: int in range(12):
		var s: Node2D = pool.call("acquire") as Node2D
		s.global_position = player.global_position + Vector2.RIGHT.rotated(TAU * float(i) / 12.0) * r
		s.set("speed", 0.0)
		shots.append(s)
	for i: int in range(150):
		await process_frame
	var alive := 0
	for s: Node in shots:
		if is_instance_valid(s) and bool(s.get("active")):
			alive += 1
	_check("spin erases 12 static shots (%d left)" % alive, alive == 0)


## 3b) 開封でアイテムが飛び出す (即時適用はT04/T08のみ)
func _t_item_drop(player: Node2D, director: Node) -> void:
	var valid := ["T01", "T02", "T03", "T06", "T07", "T09", "R_HEAL", "R_COIN", "R_WEAPON"]
	var got := false
	for k: int in range(5):
		var c: Node = director.call("spawn_chest_at", player.global_position + Vector2(100, 0))
		c.call("take_damage", 999.0, Vector2.ZERO, false)
		for i: int in range(10):
			await process_frame
		var items: Array = get_nodes_in_group("items")
		if not items.is_empty():
			got = true
			var ok := true
			for it: Node in items:
				if not str(it.get("kind")) in valid:
					ok = false
			_check("dropped item kinds valid", ok)
			break
	_check("chest drops an item", got)
	for n: Node in get_nodes_in_group("items"):
		n.queue_free()
	for i: int in range(5):
		await process_frame


## 3c) アイテム取得: T02でスコア、爆弾は開封時即時、T09は武器名ポップアップ
func _t_item_pickup(player: Node2D, director: Node, main: Node) -> void:
	# 直前の開封テストで出た奇襲の残党を掃除する (プレイヤー押送による非決定的な拾い漏れを防ぐ)
	for n: Node in get_nodes_in_group("enemies"):
		n.queue_free()
	for i: int in range(5):
		await process_frame
	# 飛び出し中は取得できない。着地 (約0.5秒) して初めて拾える
	var it: Node = director.call("spawn_item", "T02", player.global_position, false)
	player.global_position = (it as Node2D).global_position
	for i: int in range(5):
		await process_frame
	_check("item not picked while flying", is_instance_valid(it))
	var s0: int = int(main.get("score"))
	for i: int in range(40):
		await process_frame
	_check("item landed beyond pickup (%s)" % str((it as Node2D).global_position - player.global_position),
		is_instance_valid(it))
	player.global_position = (it as Node2D).global_position
	for i: int in range(15):
		await process_frame
	_check("coin pickup +100", int(main.get("score")) == s0 + 100 and not is_instance_valid(it))
	_check("coin pickup: コイン +1 (v1.8)", absf(float(main.get("run_coins")) - 1.0) < 0.001)
	# 爆弾は開封時即時 (取得不要): apply_item 直呼びで設置される
	var b0: int = get_nodes_in_group("item_bombs").size()
	director.call("apply_item", "T03", player.global_position)
	for i: int in range(5):
		await process_frame
	_check("bomb applies immediately", get_nodes_in_group("item_bombs").size() == b0 + 1)
	for n: Node in get_nodes_in_group("item_bombs"):
		n.queue_free()
	# T09: 武器名ポップアップが出る
	var fx: Node = get_first_node_in_group("combat_fx")
	var n0: int = (fx.get("nums") as Array).size()
	director.call("apply_item", "T09", player.global_position)
	_check("T09 shows weapon popup", (fx.get("nums") as Array).size() == n0 + 1)
	for i: int in range(5):
		await process_frame
	# 引き寄せなし: 着地後に記録して60フレーム待っても動かない
	var it6: Node = director.call("spawn_item", "T06", player.global_position + Vector2(300, 0), false)
	for i: int in range(40):
		await process_frame
	var p0: Vector2 = (it6 as Node2D).global_position
	for i: int in range(60):
		await process_frame
	_check("item not attracted", (it6 as Node2D).global_position.distance_to(p0) < 1.0)
	for n: Node in get_nodes_in_group("items"):
		n.queue_free()
	for i: int in range(5):
		await process_frame


## 4) 撃破スコア: 通常xp×10、エリート×5
func _t_score(player: Node2D, main: Node) -> void:
	var s0: int = int(main.get("score"))
	var a: Node2D = SlimeScene.instantiate() as Node2D
	(current_scene as Node).add_child(a)
	a.global_position = player.global_position + Vector2(100, 0)
	a.call("take_damage", 99999.0)
	_check("slime kill +10", int(main.get("score")) == s0 + 10)
	var b: Node2D = SlimeScene.instantiate() as Node2D
	(current_scene as Node).add_child(b)
	b.global_position = player.global_position + Vector2(100, 0)
	b.call("make_elite")
	b.call("take_damage", 99999.0)
	_check("elite kill +50", int(main.get("score")) == s0 + 60)
	for i: int in range(5):
		await process_frame


## 4) アーチャー: 150px以内は撃たない、後退・停止中は半分の速度で減る
func _t_archer(player: Node2D) -> void:
	# 近距離 (100px): shot_cd を0.05にしても発射されない (減る一方)
	var near: Node2D = _spawn_archer(player, 100.0)
	near.set("shot_cd", 0.05)
	for i: int in range(30):
		await process_frame
	_check("no fire within 150px (cd=%.2f)" % float(near.get("shot_cd")), float(near.get("shot_cd")) < 0.5)
	near.queue_free()
	# 対照 (300px strafe): すぐ発射される
	var mid: Node2D = _spawn_archer(player, 300.0)
	mid.set("shot_cd", 0.05)
	for i: int in range(10):
		await process_frame
	_check("fires at 300px (cd=%.2f)" % float(mid.get("shot_cd")), float(mid.get("shot_cd")) > 2.0)
	mid.queue_free()
	# 減速の比較: 接近中 (400px) vs 停止中 (300px)、1秒後の残量
	var adv: Node2D = _spawn_archer(player, 400.0)
	var st: Node2D = _spawn_archer(player, 300.0)
	adv.set("shot_cd", 2.0)
	st.set("shot_cd", 2.0)
	for i: int in range(60):
		await process_frame
	var ca: float = float(adv.get("shot_cd"))
	var cs: float = float(st.get("shot_cd"))
	_check("advancing drains faster (%.2f < %.2f)" % [ca, cs], ca < 1.2 and cs > 1.3 and ca < cs)
	adv.queue_free()
	st.queue_free()
	for i: int in range(5):
		await process_frame


func _spawn_archer(player: Node2D, dist: float) -> Node2D:
	var a: Node2D = ArcherScene.instantiate() as Node2D
	(current_scene as Node).add_child(a)
	a.global_position = player.global_position + Vector2(dist, 0)
	a.set("speed", 0.0)
	a.set("max_hp", 1000000.0)
	a.set("hp", 1000000.0)
	return a


## 5) B02撃破 → カウントダウン → CLEAR (報告バグの回帰)
func _t_clear(player: Node2D, main: Node) -> void:
	var s0: int = int(main.get("score"))
	var b: Node2D = B02Scene.instantiate() as Node2D
	(current_scene as Node).add_child(b)
	b.global_position = player.global_position + Vector2(400, 0)
	for i: int in range(5):
		await process_frame
	b.set("max_hp", 10.0)
	b.set("hp", 10.0)
	b.call("take_damage", 999.0, Vector2.ZERO, false)
	_check("B02 dead", bool(b.get("dead")))
	_check("B02 score +1000", int(main.get("score")) == s0 + 1000)
	# カウントダウン (3秒) を待つ
	for i: int in range(260):
		await process_frame
		if bool(main.get("result_shown")):
			break
	_check("result shown after countdown", bool(main.get("result_shown")))
	var title: String = str(main.get_node("ResultUI/Center/VBox/Title").get("text"))
	_check("CLEAR! shown (got '%s')" % title, title == "CLEAR!")
