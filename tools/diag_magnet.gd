extends SceneTree
## 磁石Area2Dの重複検出の内訳を診断する
## 実行: godot --path <project> --script res://tools/diag_magnet.gd

func _init() -> void:
	var main := (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	main.call("start_game")
	for i in 30:
		await process_frame

	var player: Node2D = main.get_node("Player")
	var magnet: Area2D = player.get_node("Magnet")
	var areas := magnet.get_overlapping_areas()
	print("magnet overlaps: ", areas.size())

	var by_name := {}
	var by_parent := {}
	var monitorable_counts := {}
	for a: Area2D in areas:
		by_name[String(a.name)] = int(by_name.get(String(a.name), 0)) + 1
		var parent_name := String(a.get_parent().name)
		by_parent[parent_name] = int(by_parent.get(parent_name, 0)) + 1
		var key := "monitorable=%s active=%s" % [str(a.monitorable), str(a.get("active"))]
		monitorable_counts[key] = int(monitorable_counts.get(key, 0)) + 1
	print("by name: ", by_name)
	print("by parent: ", by_parent)
	print("flags: ", monitorable_counts)

	print("--- 代表5件 ---")
	for i: int in mini(5, areas.size()):
		var a: Area2D = areas[i]
		print("  ", a.get_path(), " pos=", (a as Node2D).global_position,
			" layer=", a.collision_layer, " monitorable=", a.monitorable)

	print("--- プール内のジェムの状態 (先頭3件) ---")
	var pool: Node = main.get_node("PoolGems")
	var count := 0
	for c in pool.get_children():
		print("  ", c.name, " monitorable=", (c as Area2D).monitorable,
			" active=", c.get("active"), " pos=", (c as Node2D).global_position)
		count += 1
		if count >= 3:
			break

	print("--- player 位置のエリア構成 ---")
	print("player=", player.global_position, " pool_gems=", (pool as Node2D).global_position)
	quit()
