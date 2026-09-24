extends SceneTree
## 実行中のゲーム画面を実機キャプチャする検証用スクリプト。
## 実行: godot --path <project> --script res://tools/capture_test.gd
## 出力: res://tmp_shots/*.png (検証後に削除してよい)

const OUT_DIR := "res://tmp_shots/"


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var main := (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	main.call("start_game")

	for i in 30:
		await process_frame
	await _shot("shot_0_idle.png")

	await _walk("move_right", "shot_1_right.png")
	await _walk("move_up", "shot_2_up.png")
	await _walk("move_left", "shot_3_left.png")
	await _walk("move_down", "shot_4_down.png")

	print("capture done")
	quit()


func _walk(action: String, file_name: String) -> void:
	Input.action_press(action)
	for i in 20:
		await process_frame
	await _shot(file_name)
	Input.action_release(action)
	for i in 3:
		await process_frame


func _shot(file_name: String) -> void:
	await process_frame
	await process_frame
	var img: Image = root.get_texture().get_image()
	if img == null:
		push_error("capture failed: " + file_name)
		return
	img.save_png(ProjectSettings.globalize_path(OUT_DIR + file_name))
	print("saved ", OUT_DIR + file_name)
