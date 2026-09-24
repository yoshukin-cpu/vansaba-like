extends SceneTree
## P9 検証: 実機でプレイヤーが木に阻まれるか (障害物衝突の ground truth)
## 実行: godot --path <project> --script res://tools/verify_obstacle_block.gd

const CG := preload("res://world/chunk_gen.gd")
const OUT_DIR := "res://tmp_shots/"


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var main := (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	current_scene = main
	await process_frame
	await process_frame
	main.call("start_game")
	main.get_node("SpawnDirector").set("running", false)
	var player: Node2D = main.get_node("Player")

	# 原点近くの木を探す
	var tree: Vector2i = _find_tree(Vector2i.ZERO)
	var tree_pos := Vector2(float(tree.x) * 48.0 + 24.0, float(tree.y) * 48.0 + 24.0)
	print("木のセル: ", tree, " 中心 ", tree_pos)
	# 木の左に立って右へ押し続ける
	player.global_position = tree_pos + Vector2(-120.0, 0.0)
	for i: int in range(10):
		await process_frame
	Input.action_press("move_right")
	for i: int in range(90):
		await process_frame
	Input.action_release("move_right")
	var p: Vector2 = player.global_position
	var trunk_left: float = float(tree.x) * 48.0 + 10.0
	print("プレイヤー最終位置: %s (幹の左端 x=%.1f, 半径16なら停止位置は x=%.1f 付近)" % [str(p), trunk_left, trunk_left - 16.0])
	var blocked: bool = p.x < trunk_left - 6.0
	print("木に阻まれた: ", blocked)
	await _shot("obstacle_block.png")

	# 木の上 (奥) から下へ押す → 幹に当たるか
	player.global_position = tree_pos + Vector2(0.0, -120.0)
	for i: int in range(10):
		await process_frame
	Input.action_press("move_down")
	for i: int in range(90):
		await process_frame
	Input.action_release("move_down")
	var p2: Vector2 = player.global_position
	print("上から下へ: 最終位置 %s (幹の上端 y=%.1f)" % [str(p2), float(tree.y) * 48.0 + 32.0])
	await _shot("obstacle_block_from_up.png")
	quit()


func _find_tree(center: Vector2i) -> Vector2i:
	for r: int in range(0, 30):
		for dy: int in range(-r, r + 1):
			for dx: int in range(-r, r + 1):
				if absi(dx) != r and absi(dy) != r:
					continue
				var cell: Vector2i = center + Vector2i(dx, dy)
				var key: Vector2i = CG.chunk_key(int(floor(float(cell.x) / 32.0)), int(floor(float(cell.y) / 32.0)))
				var data: Dictionary = CG.generate_chunk(key.x, key.y)
				for ob: Dictionary in (data["obstacles"] as Array):
					var local: Vector2i = ob["cell"] as Vector2i
					if int(ob["tile"]) >= CG.O_ROCK:
						continue
					if key.x * CG.CHUNK + local.x == cell.x and key.y * CG.CHUNK + local.y == cell.y:
						return cell
	return center


func _shot(file_name: String) -> void:
	await process_frame
	await process_frame
	var img: Image = root.get_texture().get_image()
	if img != null:
		img.save_png(ProjectSettings.globalize_path(OUT_DIR + file_name))
		print("saved ", OUT_DIR + file_name)
