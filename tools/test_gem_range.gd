extends SceneTree
## ジェムが取得範囲外(遠距離)から吸引される事象の再現テスト
## 各距離にジェムを置き、吸引開始までの時間を測る
## 実行: godot --path <project> --fixed-fps 60 --script res://tools/test_gem_range.gd

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
	var pool: Node = main.get_node("PoolGems")
	var magnet_r: float = float(player.call("magnet_radius"))
	print("--- magnet_radius=", magnet_r, " (screen half w=576 h=324) ---")

	var dists: Array[float] = [50.0, 300.0, 700.0, 1500.0]
	var gems: Array[Node2D] = []
	var ids: Array[int] = []
	for d: float in dists:
		var g: Node2D = pool.call("acquire") as Node2D
		g.global_position = player.global_position + Vector2(d, 0)
		gems.append(g)
		ids.append(g.get_instance_id())

	var reported: Dictionary = {}
	var t: float = 0.0
	while t < 20.0:
		await process_frame
		t += 1.0 / 60.0
		for i: int in ids.size():
			if reported.has(i):
				continue
			var obj: Object = instance_from_id(ids[i])
			if obj == null:
				reported[i] = t
				print("dist=%7.1f : 回収済み (collected) t=%.2fs" % [dists[i], t])
				continue
			var gn: Node2D = obj as Node2D
			if bool(gn.get("attracted")):
				reported[i] = t
				print("dist=%7.1f : 吸引開始 t=%.2fs  (現在距離 %.0f)" % [
					dists[i], t, gn.global_position.distance_to(player.global_position)])
	print("--- 20秒経過 ---")
	quit()
