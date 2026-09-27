extends SceneTree
## エンディング最終画面の撮影 (D42/D43の目視確認用)。
## 出力: res://tmp_shots/finale.png
## 実機表示が要るため headless 不可。
## 実行: Godot --path <proj> --script res://tools/capture_finale.gd

const MainScene: PackedScene = preload("res://main.tscn")
const SaveData := preload("res://systems/save_data.gd")
const OUT_DIR := "res://tmp_shots/"


func _initialize() -> void:
	SaveData.path = "user://capture_finale_save.json"
	var main: Node = MainScene.instantiate()
	root.add_child(main)
	current_scene = main
	for i: int in range(10):
		await process_frame
	main.call("start_game")
	for i: int in range(5):
		await process_frame
	# クリア相当: カウントダウン (3秒) → リザルト → スタッフロールへ
	main.call("on_boss2_killed")
	var player: Node2D = main.get_node("Player") as Node2D
	var t0: int = Time.get_ticks_msec()
	while not bool(main.get("result_shown")) and Time.get_ticks_msec() - t0 < 12000:
		player.set("hp", player.get("max_hp"))
		await process_frame
	var result: Node = main.get_node("ResultUI")
	result.call("_on_staff_button")
	var staff: Node = main.get_node("StaffRollUI")
	t0 = Time.get_ticks_msec()
	while not bool(staff.get("rolling")) and Time.get_ticks_msec() - t0 < 8000:
		await process_frame
	# スキップで最終画面 (Thanks + タイトルへ)
	staff.call("_skip")
	for i: int in range(40):
		await process_frame
	var img: Image = root.get_texture().get_image()
	if img == null:
		push_error("capture failed: finale.png")
		quit(1)
		return
	img.save_png(ProjectSettings.globalize_path(OUT_DIR + "finale.png"))
	print("saved " + OUT_DIR + "finale.png")
	quit()
