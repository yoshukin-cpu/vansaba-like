extends SceneTree
## 実プレイ自動検証: 移動しながら21秒プレイして統計を表示する
## 実行: godot --path <project> --fixed-fps 60 --script res://tools/playtest.gd

func _init() -> void:
	var main := (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	current_scene = main
	await process_frame
	await process_frame
	main.call("start_game")
	var player: Node2D = main.get_node("Player")
	var pool: Node = main.get_node("PoolGems")

	var dirs := ["move_right", "move_down", "move_left", "move_up"]
	for cycle in 7:
		var act: String = dirs[cycle % dirs.size()]
		Input.action_press(act)
		for i in 180:
			await process_frame
		Input.action_release(act)
		print("t=%2ds xp=%d lv=%d hp=%.1f active_gems=%d enemies=%d" % [
			cycle * 3 + 3, int(player.get("xp")), int(player.get("level")),
			float(player.get("hp")), int(pool.call("stats")["active"]),
			get_nodes_in_group("enemies").size()])

	print("--- active gems (dist from player) ---")
	for g: Node in get_nodes_in_group("gems"):
		if bool(g.get("active")):
			var gn: Node2D = g as Node2D
			print("  dist=%.1f attracted=%s" % [
				gn.global_position.distance_to(player.global_position),
				str(g.get("attracted"))])
	print("player: xp=", player.get("xp"), " level=", player.get("level"),
		" hp=", snappedf(float(player.get("hp")), 0.1), " dead=", player.get("dead"))
	quit()
