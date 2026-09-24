extends SceneTree
## スピンソードの回転表示を確認する (4方向ぶん連続撮影)
## 実行: godot --path <project> --script res://tools/verify_spin_sword.gd

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
	var weapons: Node = player.get_node("Weapons")
	print("weapons: ", weapons.get_children().map(func(w): return w.name))
	for k in 4:
		await _shot("spin_%d.png" % k)
		for i in 24:
			await process_frame
	quit()


func _shot(file_name: String) -> void:
	await process_frame
	var img: Image = root.get_texture().get_image()
	if img == null:
		push_error("capture failed")
		return
	img.save_png(ProjectSettings.globalize_path(OUT_DIR + file_name))
	print("saved ", OUT_DIR + file_name)
