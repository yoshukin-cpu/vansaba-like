extends SceneTree
## 実機で歩行アニメが動いているか検証: 各方向で連続フレームを撮影する
## 実行: godot --path <project> --script res://tools/verify_walk.gd

const OUT_DIR := "res://tmp_shots/"


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var main := (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	current_scene = main
	await process_frame
	await process_frame
	main.call("start_game")
	var player: Node2D = main.get_node("Player")
	var body: AnimatedSprite2D = player.get_node("Body")
	for i in 30:
		await process_frame

	var actions := {"down": "move_down", "left": "move_left", "right": "move_right", "up": "move_up"}
	for d: String in actions.keys():
		Input.action_press(actions[d])
		for i in 20:
			await process_frame
		for k in 4:
			await _shot("%s_%d.png" % [d, k])
			print("  ", d, " shot ", k, " anim=", body.animation, " frame=", body.frame)
			for i in 7:
				await process_frame
		Input.action_release(actions[d])
		for i in 5:
			await process_frame

	print("capture done")
	quit()


func _shot(file_name: String) -> void:
	await process_frame
	var img: Image = root.get_texture().get_image()
	if img == null:
		push_error("capture failed")
		return
	img.save_png(ProjectSettings.globalize_path(OUT_DIR + file_name))
