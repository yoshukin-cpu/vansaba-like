extends SceneTree
## タイトル画面の撮影 (D30の目視確認用)。出力: res://tmp_shots/title.png

const MainScene: PackedScene = preload("res://main.tscn")
const OUT_DIR := "res://tmp_shots/"

func _initialize() -> void:
	var main: Node = MainScene.instantiate()
	root.add_child(main)
	current_scene = main
	for i: int in range(20):
		await process_frame
	# タイトル表示のまま (start_game は呼ばない)
	await process_frame
	await process_frame
	var img: Image = root.get_texture().get_image()
	if img == null:
		push_error("capture failed: title.png")
		quit(1)
		return
	img.save_png(ProjectSettings.globalize_path(OUT_DIR + "title.png"))
	print("saved " + OUT_DIR + "title.png")
	quit()
