extends SceneTree
## 弾のヒット判定テスト (ジェムと同じ area_entered 依存の問題がないか)
## 実行: godot --path <project> --fixed-fps 60 --script res://tools/test_projectile_hit.gd

var failures: int = 0


func _init() -> void:
	var main := (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	current_scene = main
	await process_frame
	await process_frame
	main.call("start_game")
	for i in 30:
		await process_frame

	var player: Node2D = main.get_node("Player")
	var pool_shots: Node = main.get_node("PoolShots")

	# 敵を player のすぐ右に出す (弾の発生位置と hurtbox が重なる)
	var e: Node2D = (load("res://enemies/slime.tscn") as PackedScene).instantiate() as Node2D
	main.add_child(e)
	e.global_position = player.global_position + Vector2(12, 0)
	e.set("max_hp", 9999.0)
	e.set("hp", 9999.0)
	for i in 5:
		await process_frame

	# 1) 重なった位置から新規発射 (至近距離)
	var p1: Node2D = pool_shots.call("acquire") as Node2D
	p1.global_position = player.global_position
	p1.call("setup", Vector2.RIGHT, 500.0, 10.0, 2.0, 1)
	var hit1: bool = await _wait_hit(p1, 20)
	_expect(hit1, "1) point-blank shot from overlapping position")

	# 2) ヒットでプールに戻った同じ弾を再取得して、同じく重なる位置から再発射
	var p2: Node2D = pool_shots.call("acquire") as Node2D
	print("   reused same projectile node: ", p2 == p1)
	p2.global_position = player.global_position
	p2.call("setup", Vector2.RIGHT, 500.0, 10.0, 2.0, 1)
	var hit2: bool = await _wait_hit(p2, 20)
	_expect(hit2, "2) reused projectile, point-blank again")

	# 3) 対照: 少し離れた位置(重なっていない)から発射
	var p3: Node2D = pool_shots.call("acquire") as Node2D
	p3.global_position = player.global_position - Vector2(120, 0)
	p3.call("setup", Vector2.RIGHT, 500.0, 10.0, 2.0, 1)
	var hit3: bool = await _wait_hit(p3, 40)
	_expect(hit3, "3) control shot from 120px away")

	print("RESULT: ", "ALL PASS" if failures == 0 else "%d FAILURE(S)" % failures)
	quit(1 if failures > 0 else 0)


func _expect(ok: bool, label: String) -> void:
	if ok:
		print("PASS ", label)
	else:
		failures += 1
		print("FAIL ", label)


func _wait_hit(p: Node2D, frames: int) -> bool:
	var id: int = p.get_instance_id()
	for i in frames:
		await process_frame
		var obj: Object = instance_from_id(id)
		if obj == null:
			return true
		if bool(obj.get("active")) == false:
			return true
	return false
