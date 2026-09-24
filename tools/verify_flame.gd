extends SceneTree
## フレイムスロワー(C05)の炎パーティクルを確認する
## 実行: godot --path <project> --script res://tools/verify_flame.gd

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
	player.call("add_weapon", "C05")

	# 射程内(右方向)に敵を置いて炎を狙わせる
	var e: Node2D = (load("res://enemies/golem.tscn") as PackedScene).instantiate() as Node2D
	main.add_child(e)
	e.global_position = player.global_position + Vector2(150, 0)
	e.set("max_hp", 99999.0)
	e.set("hp", 99999.0)
	e.set("speed", 0.0)

	var c05: Node = null
	for w: Node in player.get_node("Weapons").get_children():
		if str(w.get("weapon_id")) == "C05":
			c05 = w
	print("C05 found: ", c05 != null)
	print("textures loaded: ", (c05.get("textures") as Array).size())

	for k in 5:
		for i in 12:
			await process_frame
		print("shot %d: particles=%d" % [k, (c05.get("particles") as Array).size()])
		await _shot("flame_%d.png" % k)
	quit()


func _shot(file_name: String) -> void:
	await process_frame
	var img: Image = root.get_texture().get_image()
	if img == null:
		push_error("capture failed")
		return
	img.save_png(ProjectSettings.globalize_path(OUT_DIR + file_name))
