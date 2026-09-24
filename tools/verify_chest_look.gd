extends SceneTree
## P11 検証: 宝箱・アイテム爆弾の見た目を実機キャプチャする。
## 実行: godot --path <project> --script res://tools/verify_chest_look.gd
## 出力: res://tmp_shots/chest_*.png

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
	var director: Node = main.get_node("ChestDirector")
	director.set("running", false)
	for i: int in range(10):
		await process_frame

	# 宝箱 (閉) を3つ並べる
	for k: int in range(3):
		director.call("spawn_chest_at", player.global_position + Vector2(-160.0 + float(k) * 160.0, -120.0))
	for i: int in range(10):
		await process_frame
	await _shot("chest_closed.png")

	# 真ん中を1つ開ける (T02固定ではなくランダム。見た目は開状態の確認が目的)
	var chests: Array = get_nodes_in_group("chests")
	if chests.size() >= 2:
		(chests[1] as Node).call("take_damage", 10.0, Vector2.ZERO, false)
	for i: int in range(10):
		await process_frame
	await _shot("chest_open.png")

	# アイテム爆弾のヒューズ (警告円) と爆発
	for n: Node in get_nodes_in_group("item_bombs"):
		n.queue_free()
	director.call("apply_item", "T03", player.global_position + Vector2(0, -140.0))
	for i: int in range(90):
		await process_frame
	await _shot("chest_bomb_fuse.png")
	for i: int in range(80):
		await process_frame
	await _shot("chest_bomb_blast.png")
	print("chest look done")
	quit()


func _shot(file_name: String) -> void:
	await process_frame
	await process_frame
	var img: Image = root.get_texture().get_image()
	if img == null:
		push_error("capture failed: " + file_name)
		return
	img.save_png(ProjectSettings.globalize_path(OUT_DIR + file_name))
	print("saved ", OUT_DIR + file_name)
