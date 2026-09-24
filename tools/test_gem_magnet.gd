extends SceneTree
## 経験値ジェムの吸い寄せ回帰テスト
## 実行: godot --path <project> --script res://tools/test_gem_magnet.gd
## 全ケースPASSで終了コード0、失敗があれば1

var failures: int = 0


func _init() -> void:
	var main := (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	main.call("start_game")
	for i in 30:
		await process_frame

	var player: Node2D = main.get_node("Player")
	var pool: Node = main.get_node("PoolGems")
	var cards: Node = main.get_node("CardManager")
	print("--- magnet_radius=", player.call("magnet_radius"), " ---")

	# A: プール経由のジェムが磁石範囲内(40px)に出現 (元バグの再現ケース)
	var a: Node2D = pool.call("acquire") as Node2D
	a.global_position = player.global_position + Vector2(40, 0)
	await _expect_collected("A pooled gem spawned inside range ", player, a, 45)

	# B: 範囲外→範囲内
	var b: Node2D = pool.call("acquire") as Node2D
	b.global_position = player.global_position + Vector2(300, 0)
	for i in 20:
		await process_frame
	b.global_position = player.global_position + Vector2(40, 0)
	await _expect_collected("B pooled gem moved into range     ", player, b, 45)

	# C: 新品ジェムを範囲内に直接配置
	var c: Node2D = (load("res://pickups/xp_gem.tscn") as PackedScene).instantiate() as Node2D
	main.add_child(c)
	c.global_position = player.global_position + Vector2(40, 0)
	await _expect_collected("C fresh gem inside range          ", player, c, 45)

	# D: 一度回収されてプールに戻ったジェムを、同じ位置で再取得(再利用)するケース
	var d1: Node2D = pool.call("acquire") as Node2D
	d1.global_position = player.global_position + Vector2(40, 0)
	await _expect_collected("D1 pooled gem collected at player ", player, d1, 45)
	var d2: Node2D = pool.call("acquire") as Node2D
	d2.global_position = player.global_position + Vector2(60, 0)
	print("   (reused same node: ", d2 == d1, ")")
	await _expect_collected("D2 re-acquired pooled gem inside  ", player, d2, 45)

	# E: 範囲外(300px)は吸い寄せされない (誤吸引しないこと)
	var e: Node2D = pool.call("acquire") as Node2D
	e.global_position = player.global_position + Vector2(300, 0)
	await _expect_not_collected("E gem outside range stays         ", player, e, 45)
	if is_instance_valid(e):
		pool.call("release", e)

	# F: マグネットカード(C19)適用後は150pxでも吸い寄せされる
	cards.call("apply_card", "C19")
	print("--- magnet_radius after C19=", player.call("magnet_radius"), " ---")
	var f: Node2D = pool.call("acquire") as Node2D
	f.global_position = player.global_position + Vector2(150, 0)
	await _expect_collected("F gem at 150px after magnet card  ", player, f, 45)

	print("RESULT: ", "ALL PASS" if failures == 0 else "%d FAILURE(S)" % failures)
	quit(1 if failures > 0 else 0)


func _expect_collected(label: String, player: Node2D, gem: Node2D, frames: int) -> void:
	var xp0: int = int(player.get("xp"))
	var collected := false
	for i in frames:
		await process_frame
		if not is_instance_valid(gem):
			collected = true
			break
		if bool(gem.get("active")) == false:
			collected = true
			break
	var xp1: int = int(player.get("xp"))
	if collected and xp1 > xp0:
		print("PASS ", label, " xp ", xp0, "->", xp1)
	elif collected:
		failures += 1
		print("FAIL ", label, " gem despawned but XP did not increase")
	else:
		failures += 1
		print("FAIL ", label, " gem still active, dist=",
			gem.global_position.distance_to(player.global_position),
			" attracted=", gem.get("attracted"))


func _expect_not_collected(label: String, player: Node2D, gem: Node2D, frames: int) -> void:
	for i in frames:
		await process_frame
	if is_instance_valid(gem) and bool(gem.get("active")):
		print("PASS ", label, " dist=",
			snappedf(gem.global_position.distance_to(player.global_position), 0.1))
	else:
		failures += 1
		print("FAIL ", label, " gem was collected unexpectedly")
