extends SceneTree
## タイトル難易度セレクタの撮影 (D40の目視確認用)。
## 出力: res://tmp_shots/title_diff_locked.png (解放済み+ロック項目) /
##       res://tmp_shots/title_diff_new.png (未クリア: 案内表示)
## 実機表示が要るため headless 不可。
## 実行: Godot --path <proj> --script res://tools/capture_title_diff.gd

const MainScene: PackedScene = preload("res://main.tscn")
const SaveData := preload("res://systems/save_data.gd")
const OUT_DIR := "res://tmp_shots/"
const TEST_SAVE := "user://capture_title_diff_save.json"


func _initialize() -> void:
	SaveData.path = TEST_SAVE
	# 1) 解放済み: normal クリア済み・last=hard → expert はロック (鍵+解放条件)
	SaveData.reset()
	SaveData.cleared = ["normal"]
	SaveData.last = "hard"
	SaveData.save_now()
	await _capture("title_diff_locked.png")

	# 2) 未クリア: セレクタ未解放 (暗転+案内)
	SaveData.reset()
	SaveData.save_now()
	await _capture("title_diff_new.png")

	SaveData.path = SaveData.DEFAULT_PATH
	SaveData.reset()
	if FileAccess.file_exists(TEST_SAVE):
		DirAccess.remove_absolute(TEST_SAVE)
	quit()


func _capture(file_name: String) -> void:
	var main: Node = MainScene.instantiate()
	root.add_child(main)
	current_scene = main
	for i: int in range(20):
		await process_frame
	if file_name == "title_diff_locked.png":
		# ロック中の項目 (expert) を表示した状態も1枚残す
		var title: Node = main.get_node("TitleUI")
		title.call("_cycle", 1)
	for i: int in range(3):
		await process_frame
	var img: Image = root.get_texture().get_image()
	if img == null:
		push_error("capture failed: " + file_name)
		return
	img.save_png(ProjectSettings.globalize_path(OUT_DIR + file_name))
	print("saved " + OUT_DIR + file_name)
	main.queue_free()
	await process_frame
